using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Net;
using System.Text;

namespace InterviewMasterApp.Presentation.Styling
{
    /// <summary>
    /// Style metadata for a text run.
    /// </summary>
    public sealed class TextStyle
    {
        public Color? Foreground { get; set; }
        public Color? Background { get; set; }
        public bool Bold { get; set; }
        public bool Italic { get; set; }
        public bool Underline { get; set; }
        public bool Monospace { get; set; }
        public float? FontSize { get; set; }

        public TextStyle Clone() => (TextStyle)MemberwiseClone();
    }

    /// <summary>
    /// A styled run of text.
    /// </summary>
    public sealed class StyledRun
    {
        public string Text { get; }
        public TextStyle Style { get; }

        public StyledRun(string text, TextStyle style)
        {
            Text = text ?? string.Empty;
            Style = style ?? new TextStyle();
        }
    }

    /// <summary>
    /// Collection of styled runs with helpers to render to HTML.
    /// </summary>
    public sealed class StyledText
    {
        public List<StyledRun> Runs { get; } = new();

        public void Add(string text, TextStyle style)
        {
            if (string.IsNullOrEmpty(text)) return;
            Runs.Add(new StyledRun(text, style));
        }

        public string ToHtml()
        {
            var sb = new StringBuilder();
            sb.AppendLine("<html><head><meta charset=\"utf-8\"/></head><body style=\"background:#111; color:#eee; font-family:Segoe UI, Arial;\">");
            sb.AppendLine("<pre style=\"white-space:pre-wrap;\">" );
            foreach (var run in Runs)
            {
                var style = run.Style ?? new TextStyle();
                var styles = new List<string>();

                if (style.Foreground.HasValue)
                {
                    var c = style.Foreground.Value;
                    styles.Add($"color: rgb({c.R},{c.G},{c.B})");
                }
                if (style.Background.HasValue)
                {
                    var c = style.Background.Value;
                    styles.Add($"background-color: rgba({c.R},{c.G},{c.B},{c.A / 255.0:F2})");
                }
                if (style.Bold) styles.Add("font-weight: 700");
                if (style.Italic) styles.Add("font-style: italic");
                if (style.Underline) styles.Add("text-decoration: underline");
                if (style.Monospace) styles.Add("font-family: Consolas, 'Courier New', monospace");
                if (style.FontSize.HasValue) styles.Add($"font-size: {style.FontSize.Value}px");

                var styleAttr = styles.Count > 0 ? $" style=\"{string.Join("; ", styles)}\"" : string.Empty;
                sb.Append($"<span{styleAttr}>{WebUtility.HtmlEncode(run.Text)}</span>");
            }
            sb.AppendLine("</pre></body></html>");
            return sb.ToString();
        }
    }
}

