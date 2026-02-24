using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Infrastructure.API;

namespace InterviewMasterApp.Application.UseCases
{
    /// <summary>
    /// Use case for analyzing coding task screenshots with AI.
    /// Migrated from Swift: AnalyzeCodingTaskUseCase.swift
    /// </summary>
    public class AnalyzeCodingTaskUseCase
    {
        private readonly IAnthropicApiClient _apiClient;
        private readonly CodingSession _session;

        public AnalyzeCodingTaskUseCase(IAnthropicApiClient apiClient, CodingSession session)
        {
            _apiClient = apiClient ?? throw new ArgumentNullException(nameof(apiClient));
            _session = session ?? throw new ArgumentNullException(nameof(session));
        }

        /// <summary>
        /// Execute the use case to analyze coding task screenshots.
        /// </summary>
        /// <param name="customPrompt">Optional custom prompt (uses default if null)</param>
        /// <returns>The analysis result</returns>
        public async Task<Result<Analysis>> ExecuteAsync(string customPrompt = null)
        {
            // Validate session has screenshots
            if (!_session.HasScreenshots)
            {
                return Result<Analysis>.Failure(
                    new AnalysisException("No screenshots to analyze. Please capture at least one screenshot.")
                );
            }

            // Get screenshots as base64
            var imageBase64Strings = _session.ScreenshotsAsBase64;

            // Build prompt
            var prompt = customPrompt ?? BuildDefaultPrompt();

            // Call API
            var apiResult = await _apiClient.SendMessageAsync(
                imageBase64Strings,
                prompt,
                AppConstants.Models.AnthropicHaiku
            );

            // Handle result
            if (apiResult.IsSuccess)
            {
                // Parse response into Analysis
                var analysis = Analysis.FromMarkdown(apiResult.Value);

                // Store in session
                _session.SetAnalysis(analysis);

                return Result<Analysis>.Success(analysis);
            }

            return Result<Analysis>.Failure(apiResult.Error);
        }

        /// <summary>
        /// Build the default prompt for analyzing coding problems.
        /// </summary>
        private static string BuildDefaultPrompt()
        {
            return @"You are an expert coding interview assistant. Analyze the screenshot(s) of the coding problem and provide:

1. **Problem Summary**: Brief description of what the problem is asking
2. **Approach**: High-level strategy to solve it
3. **Solution**: Clean, working code with comments
4. **Complexity**: Time and space complexity analysis
5. **Edge Cases**: Important cases to consider

Format your solution with proper markdown code blocks (e.g., ```python).
Keep explanations clear and concise - this is for a live interview.";
        }
    }

    /// <summary>
    /// Custom exception for analysis errors.
    /// </summary>
    public class AnalysisException : Exception
    {
        public AnalysisException(string message) : base(message) { }
        public AnalysisException(string message, Exception innerException)
            : base(message, innerException) { }
    }
}

