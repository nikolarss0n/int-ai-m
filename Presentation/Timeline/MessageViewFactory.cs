using System;
using System.Collections.Generic;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Presentation.Styling;

namespace InterviewMasterApp.Presentation.Timeline
{
    /// <summary>
    /// Factory for creating timeline message view models (UI-agnostic).
    /// Ported from Swift: MessageViewFactory.swift
    /// </summary>
    public class MessageViewFactory
    {
        private readonly MarkdownRenderer _markdownRenderer;
        private double _containerWidth;

        public MessageViewFactory(MarkdownRenderer markdownRenderer, double containerWidth = 600)
        {
            _markdownRenderer = markdownRenderer ?? new MarkdownRenderer(MarkdownRenderer.Style.Notes);
            _containerWidth = containerWidth;
        }

        public void UpdateContainerWidth(double width)
        {
            _containerWidth = width;
        }

        public TimelineMessageViewModel CreateMessageViewModel(InterviewMessage message)
        {
            if (message == null) throw new ArgumentNullException(nameof(message));

            // Style content using markdown renderer
            var styled = _markdownRenderer.Render(message.Content ?? string.Empty);

            // Estimate height based on line count (simple heuristic)
            var height = EstimateTextHeight(message.Content ?? string.Empty, _containerWidth - 52);

            return new TimelineMessageViewModel(message, styled, height);
        }

        public StyledText FormatMessageContent(string text, bool isQuestion)
        {
            return _markdownRenderer.Render(text ?? string.Empty);
        }

        public double EstimateTextHeight(string text, double width)
        {
            if (string.IsNullOrEmpty(text)) return 30;
            var lines = text.Split('\n');
            var lineHeight = 18.0;
            return Math.Max(30, lines.Length * lineHeight + 20);
        }
    }

    /// <summary>
    /// UI-agnostic view model for a timeline message.
    /// </summary>
    public class TimelineMessageViewModel
    {
        public InterviewMessage Message { get; }
        public StyledText StyledContent { get; }
        public double EstimatedHeight { get; }

        public TimelineMessageViewModel(InterviewMessage message, StyledText styledContent, double estimatedHeight)
        {
            Message = message;
            StyledContent = styledContent;
            EstimatedHeight = estimatedHeight;
        }
    }
}

