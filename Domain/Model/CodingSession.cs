using System;
using System.Collections.Generic;
using System.Linq;
using InterviewMasterApp.Domain.Entities;
using InterviewMasterApp.Domain.ValueObjects;

namespace InterviewMasterApp.Domain.Model
{
    /// <summary>
    /// Aggregate root representing a coding session with screenshots and analysis.
    /// Migrated from Swift: CodingSession.swift
    /// </summary>
    public class CodingSession
    {
        public SessionId SessionId { get; }
        private List<Screenshot> _screenshots = new();
        private Analysis? _analysis;

        public CodingSession(SessionId? sessionId = null)
        {
            SessionId = sessionId ?? new SessionId();
        }

        // MARK: - Public Properties

        public IReadOnlyList<Screenshot> Screenshots => _screenshots.AsReadOnly();
        public Analysis? Analysis => _analysis;

        // MARK: - Business Logic

        /// <summary>
        /// Add a screenshot to the session.
        /// </summary>
        public void AddScreenshot(Screenshot screenshot)
        {
            if (screenshot == null)
                throw new ArgumentNullException(nameof(screenshot));

            _screenshots.Add(screenshot);
        }

        /// <summary>
        /// Remove a screenshot by ID.
        /// </summary>
        /// <returns>true if removed, false if not found</returns>
        public bool RemoveScreenshot(Guid screenshotId)
        {
            var screenshot = _screenshots.FirstOrDefault(s => s.Id == screenshotId);
            if (screenshot != null)
            {
                _screenshots.Remove(screenshot);
                return true;
            }
            return false;
        }

        /// <summary>
        /// Set the analysis result.
        /// </summary>
        public void SetAnalysis(Analysis analysis)
        {
            if (analysis == null)
                throw new ArgumentNullException(nameof(analysis));

            _analysis = analysis;
        }

        /// <summary>
        /// Clear the entire session.
        /// </summary>
        public void Clear()
        {
            _screenshots.Clear();
            _analysis = null;
        }

        /// <summary>
        /// Clear only the analysis, keeping screenshots.
        /// </summary>
        public void ClearAnalysis()
        {
            _analysis = null;
        }

        // MARK: - Query Methods

        /// <summary>
        /// Check if session has screenshots.
        /// </summary>
        public bool HasScreenshots => _screenshots.Count > 0;

        /// <summary>
        /// Check if session has analysis.
        /// </summary>
        public bool HasAnalysis => _analysis != null;

        /// <summary>
        /// Get total number of screenshots.
        /// </summary>
        public int ScreenshotCount => _screenshots.Count;

        /// <summary>
        /// Get total size of all screenshots in KB.
        /// </summary>
        public double TotalSizeInKb
        {
            get
            {
                return _screenshots.Sum(s => s.SizeInKb);
            }
        }

        /// <summary>
        /// Check if session is ready for analysis (has at least one screenshot).
        /// </summary>
        public bool IsReadyForAnalysis => HasScreenshots;

        /// <summary>
        /// Get all screenshots as base64 strings for API.
        /// </summary>
        public List<string> ScreenshotsAsBase64
        {
            get
            {
                return _screenshots
                    .Select(s => s.ToBase64())
                    .Where(b => b != null)
                    .ToList();
            }
        }

        public override string ToString()
        {
            return $"CodingSession(ID={SessionId}, Screenshots={ScreenshotCount}, " +
                   $"HasAnalysis={HasAnalysis})";
        }
    }
}
