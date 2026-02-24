using System;
using System.Collections.Generic;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Presentation.Timeline
{
    /// <summary>
    /// Delegate for streaming message handler callbacks.
    /// Ported from Swift: StreamingMessageHandlerDelegate
    /// </summary>
    public interface IStreamingMessageHandlerDelegate
    {
        List<InterviewMessage> VoiceMessages { get; set; }
        void UpdateFloatingQA();
    }

    /// <summary>
    /// Handles creation and updates of streaming answer messages in the timeline.
    /// UI-agnostic implementation that updates the message list.
    /// </summary>
    public class StreamingMessageHandler
    {
        private readonly MessageViewFactory _messageViewFactory;
        private readonly IStreamingMessageHandlerDelegate _delegate;

        private int? _currentIndex;

        public string? CurrentContent { get; private set; }
        public InterviewMessage? CurrentMessage => _currentIndex.HasValue && _delegate?.VoiceMessages != null && _currentIndex.Value < _delegate.VoiceMessages.Count
            ? _delegate.VoiceMessages[_currentIndex.Value]
            : null;

        public StreamingMessageHandler(MessageViewFactory messageViewFactory, IStreamingMessageHandlerDelegate @delegate)
        {
            _messageViewFactory = messageViewFactory ?? throw new ArgumentNullException(nameof(messageViewFactory));
            _delegate = @delegate;
        }

        /// <summary>
        /// Add an empty streaming message that will be updated.
        /// </summary>
        public void AddStreamingMessage(InterviewMessage.MessageType type, string topic, int? latencyMs = null)
        {
            if (_delegate == null) return;
            var messages = _delegate.VoiceMessages ?? new List<InterviewMessage>();
            var msg = new InterviewMessage(type, "▌", topic, responseLatencyMs: latencyMs);
            messages.Add(msg);
            _delegate.VoiceMessages = messages;
            _currentIndex = messages.Count - 1;
            CurrentContent = string.Empty;
        }

        /// <summary>
        /// Update the streaming message with new content.
        /// </summary>
        public void UpdateStreamingMessage(string content)
        {
            if (_delegate == null || !_currentIndex.HasValue) return;
            var messages = _delegate.VoiceMessages;
            if (_currentIndex.Value >= messages.Count) return;

            CurrentContent = content ?? string.Empty;
            var current = messages[_currentIndex.Value];
            messages[_currentIndex.Value] = new InterviewMessage(current.Type, CurrentContent + " ▌", current.Topic, current.ScreenshotId, current.AudioSource, current.ResponseLatencyMs);
            _delegate.VoiceMessages = messages;
        }

        /// <summary>
        /// Finalize streaming message with proper formatting.
        /// </summary>
        public void FinalizeStreamingMessage(string content)
        {
            if (_delegate == null || !_currentIndex.HasValue) return;
            var messages = _delegate.VoiceMessages;
            if (_currentIndex.Value >= messages.Count) return;

            CurrentContent = content ?? string.Empty;
            var current = messages[_currentIndex.Value];
            messages[_currentIndex.Value] = new InterviewMessage(current.Type, CurrentContent, current.Topic, current.ScreenshotId, current.AudioSource, current.ResponseLatencyMs);
            _delegate.VoiceMessages = messages;
            _delegate.UpdateFloatingQA();
            _currentIndex = null;
        }

        public void ClearStreamingState()
        {
            _currentIndex = null;
            CurrentContent = null;
        }
    }
}
