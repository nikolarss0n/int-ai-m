using System;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Domain.ValueObjects;

namespace InterviewMasterApp.Application.UseCases
{
    /// <summary>
    /// Use case for clearing the coding session.
    /// Migrated from Swift: ClearSessionUseCase.swift
    /// </summary>
    public class ClearSessionUseCase
    {
        private readonly CodingSession _session;

        public ClearSessionUseCase(CodingSession session)
        {
            _session = session ?? throw new ArgumentNullException(nameof(session));
        }

        /// <summary>
        /// Clear all screenshots and analysis.
        /// </summary>
        public void ClearAll()
        {
            _session.Clear();
        }

        /// <summary>
        /// Clear only analysis, keep screenshots.
        /// </summary>
        public void ClearAnalysisOnly()
        {
            _session.ClearAnalysis();
        }

        /// <summary>
        /// Remove a specific screenshot.
        /// </summary>
        /// <param name="screenshotId">ID of screenshot to remove</param>
        /// <returns>true if removed, false if not found</returns>
        public bool RemoveScreenshot(ScreenshotId screenshotId)
        {
            return _session.RemoveScreenshot(screenshotId);
        }
    }
}

