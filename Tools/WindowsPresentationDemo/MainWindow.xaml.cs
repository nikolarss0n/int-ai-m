using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using InterviewMasterApp.Domain.Entities;
using InterviewMasterApp.Domain.Model;
using InterviewMasterApp.Presentation.Timeline;
using InterviewMasterApp.Presentation.Styling;
using InterviewMasterApp.Presentation.Windows;

namespace WindowsPresentationDemo
{
    public partial class MainWindow : Window, IFloatingSolutionDataSource, IPermissionsPanelDelegate, IStreamingMessageHandlerDelegate
    {
        private readonly FloatingSolutionWindowController _floating;
        private readonly ScreenshotAlertWindow _alert;
        private readonly PermissionsPanelController _permissions;
        private (Window window, Panel container)? _alertWindow;

        public string? CurrentPinnedSolution { get; private set; } = "public class Demo { }";
        public List<InterviewMessage> VoiceMessages { get; set; } = new();
        public MessageViewFactory MessageViewFactory { get; }
        public string DataConsentKey => "InterviewMaster.DataConsent";

        public MainWindow()
        {
            InitializeComponent();
            MessageViewFactory = new MessageViewFactory(new MarkdownRenderer(MarkdownRenderer.Style.Notes));
            _floating = new FloatingSolutionWindowController(this);
            _alert = new ScreenshotAlertWindow();
            _permissions = new PermissionsPanelController(this);
        }

        private void ShowFloatingButton_Click(object sender, RoutedEventArgs e)
        {
            VoiceMessages = new List<InterviewMessage>
            {
                new InterviewMessage(InterviewMessage.MessageType.Question, "What is a hash map?", "hashMap"),
                new InterviewMessage(InterviewMessage.MessageType.Answer, "A hash map stores key/value pairs.", "hashMap")
            };
            _floating.Show();
        }

        private void ShowAlertButton_Click(object sender, RoutedEventArgs e)
        {
            if (_alertWindow == null)
                _alertWindow = _alert.CreateWindow();

            var screenshots = new List<Screenshot>();
            // placeholder: empty list -> no thumbnails
            _alert.CreateThumbnails(screenshots);

            if (_alertWindow != null)
                _alert.Show(_alertWindow.Value.window);
        }

        private void ShowPermissionsButton_Click(object sender, RoutedEventArgs e)
        {
            if (PermissionsHost.Child == null)
            {
                var grid = new Grid();
                PermissionsHost.Child = grid;
                _permissions.Setup(grid);
            }
        }

        public void UpdateFloatingQA() { }
    }
}

