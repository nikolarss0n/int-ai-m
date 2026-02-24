using System.Drawing;

namespace InterviewMasterApp.Presentation.Components
{
    /// <summary>
    /// Port of ClaudeLogoView.swift — a small helper representing the ASCII logo.
    /// This is a UI-agnostic representation: integrate into your UI framework (WinUI/WPF) by
    /// rendering the `LogoText` string in a monospaced control and binding `Color`/`Alpha`.
    /// </summary>
    public class ClaudeLogoView
    {
        // The ASCII logo text (same as Swift)
        public string LogoText { get; } = "▐▛███▜▌\n▝▜█████▛▘\n ▘▘ ▝▝";

        public float FontSize { get; set; } = 6f;
        public Color Color { get; private set; } = Color.FromArgb(255, 255, 128, 112); // approximate "claudeCoral"
        public float Alpha { get; private set; } = 1.0f;

        public ClaudeLogoView() { }

        public void SetColor(Color color)
        {
            Color = color;
        }

        public void SetAlpha(float alpha)
        {
            Alpha = MathF.Max(0f, MathF.Min(1f, alpha));
        }

        public override string ToString()
        {
            return LogoText;
        }
    }
}

