using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Documents;
using System.Windows.Media;

namespace InterviewMasterApp.Presentation.Styling
{
    /// <summary>
    /// Design tokens for the Windows WPF interview window (ported from Presentation/Styling/DesignTokens.swift).
    /// Three-tier dark-pinned palette tuned for APCA Lc legibility on dark surfaces.
    /// </summary>
    public static class DesignTokens
    {
        public static class Colors
        {
            public static readonly Color White = System.Windows.Media.Colors.White;
            public static readonly Color Black = System.Windows.Media.Colors.Black;

            // Core widget surfaces
            public static readonly Color Graphite = Color.FromRgb(27, 27, 29);       // #1B1B1D answer & code
            public static readonly Color Storm = Color.FromRgb(38, 41, 47);          // #26292F list & CV strip
            public static readonly Color Slate = Color.FromRgb(19, 22, 26);          // #13161A code well
            public static readonly Color Charcoal = Color.FromRgb(9, 9, 10);

            // Role hues (solid + text step for AA/APCA Lc >= 60 on dark tinted washes)
            public static readonly Color AccentSolid = Color.FromRgb(204, 69, 237);  // Magenta
            public static readonly Color AccentText = Color.FromRgb(237, 173, 255);

            public static readonly Color CodeSolid = Color.FromRgb(89, 199, 250);    // Cyan
            public static readonly Color CodeText = Color.FromRgb(158, 227, 255);

            public static readonly Color SuccessSolid = Color.FromRgb(52, 199, 89);  // Green
            public static readonly Color SuccessText = Color.FromRgb(105, 231, 131);

            public static readonly Color WarningSolid = Color.FromRgb(255, 204, 0);  // Gold
            public static readonly Color WarningText = Color.FromRgb(255, 204, 0);

            public static readonly Color DangerSolid = Color.FromRgb(255, 59, 48);   // Red
            public static readonly Color DangerText = Color.FromRgb(255, 224, 219);

            // Text steps (no step below TextMuted 0.72)
            public static readonly Color TextPrimary = Color.FromArgb(255, 255, 255, 255);
            public static readonly Color TextStrong = Color.FromArgb(240, 255, 255, 255);
            public static readonly Color TextBody = Color.FromArgb(217, 255, 255, 255);
            public static readonly Color TextMuted = Color.FromArgb(184, 255, 255, 255);

            public static readonly Color BorderWidget = Color.FromArgb(18, 255, 255, 255);
            public static readonly Color BorderSubtle = Color.FromArgb(28, 255, 255, 255);
            public static readonly Color BgInset = Color.FromArgb(16, 255, 255, 255);
            public static readonly Color BgHover = Color.FromArgb(26, 255, 255, 255);
            public static readonly Color BgSelected = Color.FromArgb(41, 204, 69, 237);
            public static readonly Color BgSkeleton = Color.FromArgb(26, 255, 255, 255);
        }

        public static SolidColorBrush Brush(Color c)
        {
            var b = new SolidColorBrush(c);
            b.Freeze();
            return b;
        }

        public static SolidColorBrush Tint(Color c, double alpha)
        {
            var a = (byte)Math.Clamp((int)Math.Round(alpha * 255), 0, 255);
            return Brush(Color.FromArgb(a, c.R, c.G, c.B));
        }

        public static readonly SolidColorBrush BgCardBrush = Brush(Colors.Graphite);
        public static readonly SolidColorBrush BgWidgetBrush = Brush(Colors.Storm);
        public static readonly SolidColorBrush BgCodeBrush = Brush(Colors.Slate);
        public static readonly SolidColorBrush BorderWidgetBrush = Brush(Colors.BorderWidget);
        public static readonly SolidColorBrush BorderSubtleBrush = Brush(Colors.BorderSubtle);

        public static readonly SolidColorBrush TextPrimaryBrush = Brush(Colors.TextPrimary);
        public static readonly SolidColorBrush TextStrongBrush = Brush(Colors.TextStrong);
        public static readonly SolidColorBrush TextBodyBrush = Brush(Colors.TextBody);
        public static readonly SolidColorBrush TextMutedBrush = Brush(Colors.TextMuted);

        public static readonly SolidColorBrush AccentTextBrush = Brush(Colors.AccentText);
        public static readonly SolidColorBrush AccentWashBrush = Tint(Colors.AccentSolid, 0.16);
        public static readonly SolidColorBrush CodeTextBrush = Brush(Colors.CodeText);
        public static readonly SolidColorBrush CodeWashBrush = Tint(Colors.CodeSolid, 0.14);
        public static readonly SolidColorBrush SuccessTextBrush = Brush(Colors.SuccessText);
        public static readonly SolidColorBrush SuccessWashBrush = Tint(Colors.SuccessSolid, 0.14);
        public static readonly SolidColorBrush WarningTextBrush = Brush(Colors.WarningText);
        public static readonly SolidColorBrush WarningWashBrush = Tint(Colors.WarningSolid, 0.14);
        public static readonly SolidColorBrush DangerTextBrush = Brush(Colors.DangerText);
        public static readonly SolidColorBrush DangerWashBrush = Tint(Colors.DangerSolid, 0.18);

        public static class Radii
        {
            public const double Sm = 6;
            public const double Md = 10;
            public const double Lg = 14;
            public const double Widget = 20;
        }

        public static class FontSizes
        {
            public const double Micro = 11;
            public const double Caption = 12;
            public const double Body = 13;
            public const double Lead = 15;
            public const double Title = 17;
            public const double Code = 13;
        }

        public static readonly FontFamily UiFont = new("Segoe UI");
        public static readonly FontFamily MonoFont = new("Cascadia Mono, Consolas, Courier New");
    }

    /// <summary>
    /// Converts Markdown text (bullets, headings, bold, italic, inline code, fenced code blocks)
    /// into styled WPF <see cref="FlowDocument"/> blocks with syntax highlighting.
    /// </summary>
    public static class FlowDocumentMarkdownRenderer
    {
        private static readonly Regex InlinePattern = new(
            @"(`[^`]+`|\*\*[^*]+\*\*|\*[^*]+\*)",
            RegexOptions.Compiled);

        private static readonly Regex CodeKeywordRegex = new(
            @"\b(def|class|return|import|from|as|if|elif|else|for|while|in|try|except|finally|with|async|await|yield|lambda|None|True|False|const|let|var|function|interface|type|export|public|private|protected|static|readonly|void|int|string|bool|var|new|switch|case|break|continue|using|namespace|struct|enum|record|final|fn|pub|mut|match|impl)\b",
            RegexOptions.Compiled);

        private static readonly Regex CodeStringRegex = new(
            @"(""[^""\\]*(?:\\.[^""\\]*)*""|'[^'\\]*(?:\\.[^'\\]*)*')",
            RegexOptions.Compiled);

        public static FlowDocument Render(string markdown, double baseFontSize = DesignTokens.FontSizes.Lead)
        {
            var doc = new FlowDocument
            {
                FontFamily = DesignTokens.UiFont,
                FontSize = baseFontSize,
                Foreground = DesignTokens.TextBodyBrush,
                PagePadding = new Thickness(0),
                LineHeight = baseFontSize * 1.5
            };

            if (string.IsNullOrEmpty(markdown)) return doc;

            var lines = markdown.Replace("\r\n", "\n").Split('\n');
            bool inCode = false;
            var codeBuf = new List<string>();

            void FlushCode()
            {
                if (codeBuf.Count == 0) return;
                var codePara = new Paragraph
                {
                    FontFamily = DesignTokens.MonoFont,
                    FontSize = DesignTokens.FontSizes.Code,
                    Background = DesignTokens.BgCodeBrush,
                    Padding = new Thickness(12, 8, 12, 8),
                    Margin = new Thickness(0, 6, 0, 8),
                    LineHeight = DesignTokens.FontSizes.Code * 1.4
                };
                AppendHighlightedCode(codePara.Inlines, string.Join("\n", codeBuf));
                doc.Blocks.Add(codePara);
                codeBuf.Clear();
            }

            foreach (var rawLine in lines)
            {
                var trimmed = rawLine.Trim();
                if (trimmed.StartsWith("```", StringComparison.Ordinal))
                {
                    if (inCode) { FlushCode(); inCode = false; }
                    else { inCode = true; codeBuf.Clear(); }
                    continue;
                }

                if (inCode)
                {
                    codeBuf.Add(rawLine);
                    continue;
                }

                if (string.IsNullOrWhiteSpace(trimmed)) continue;

                // Headings
                if (trimmed.StartsWith("### ", StringComparison.Ordinal))
                {
                    doc.Blocks.Add(CreateHeading(trimmed[4..], baseFontSize + 1));
                    continue;
                }
                if (trimmed.StartsWith("## ", StringComparison.Ordinal))
                {
                    doc.Blocks.Add(CreateHeading(trimmed[3..], baseFontSize + 2));
                    continue;
                }
                if (trimmed.StartsWith("# ", StringComparison.Ordinal))
                {
                    doc.Blocks.Add(CreateHeading(trimmed[2..], baseFontSize + 4));
                    continue;
                }

                // Bullet with hanging indent
                if (trimmed.StartsWith("- ", StringComparison.Ordinal) ||
                    trimmed.StartsWith("* ", StringComparison.Ordinal) ||
                    trimmed.StartsWith("• ", StringComparison.Ordinal))
                {
                    var p = new Paragraph
                    {
                        Margin = new Thickness(16, 2, 0, 6),
                        TextIndent = -14
                    };
                    p.Inlines.Add(new Run("•  ") { Foreground = DesignTokens.AccentTextBrush, FontWeight = FontWeights.SemiBold });
                    AppendInlineMarkdown(p.Inlines, trimmed[2..].Trim());
                    doc.Blocks.Add(p);
                    continue;
                }

                var normal = new Paragraph { Margin = new Thickness(0, 2, 0, 6) };
                AppendInlineMarkdown(normal.Inlines, trimmed);
                doc.Blocks.Add(normal);
            }

            if (inCode) FlushCode();
            return doc;
        }

        private static Paragraph CreateHeading(string text, double fontSize)
        {
            var p = new Paragraph
            {
                FontSize = fontSize,
                FontWeight = FontWeights.SemiBold,
                Foreground = DesignTokens.TextPrimaryBrush,
                Margin = new Thickness(0, 8, 0, 4)
            };
            p.Inlines.Add(new Run(text));
            return p;
        }

        public static void AppendInlineMarkdown(InlineCollection inlines, string text)
        {
            int pos = 0;
            foreach (Match m in InlinePattern.Matches(text))
            {
                if (m.Index > pos)
                    inlines.Add(new Run(text[pos..m.Index]));

                var token = m.Value;
                if (token.StartsWith("`") && token.EndsWith("`") && token.Length >= 2)
                {
                    inlines.Add(new Run($" {token[1..^1]} ")
                    {
                        FontFamily = DesignTokens.MonoFont,
                        FontSize = DesignTokens.FontSizes.Code,
                        Foreground = DesignTokens.CodeTextBrush,
                        Background = DesignTokens.BgCodeBrush
                    });
                }
                else if (token.StartsWith("**") && token.EndsWith("**") && token.Length >= 4)
                {
                    inlines.Add(new Run(token[2..^2])
                    {
                        FontWeight = FontWeights.SemiBold,
                        Foreground = DesignTokens.TextPrimaryBrush
                    });
                }
                else if (token.StartsWith("*") && token.EndsWith("*") && token.Length >= 2)
                {
                    inlines.Add(new Run(token[1..^1]) { FontStyle = FontStyles.Italic });
                }
                else
                {
                    inlines.Add(new Run(token));
                }
                pos = m.Index + m.Length;
            }
            if (pos < text.Length) inlines.Add(new Run(text[pos..]));
        }

        public static void AppendHighlightedCode(InlineCollection inlines, string code)
        {
            var lines = (code ?? string.Empty).Replace("\r\n", "\n").Split('\n');
            for (int i = 0; i < lines.Length; i++)
            {
                var line = lines[i];
                var trimmed = line.TrimStart();
                if (trimmed.StartsWith("#", StringComparison.Ordinal) || trimmed.StartsWith("//", StringComparison.Ordinal))
                {
                    inlines.Add(new Run(line) { Foreground = DesignTokens.TextMutedBrush });
                }
                else
                {
                    HighlightCodeLine(inlines, line);
                }
                if (i < lines.Length - 1) inlines.Add(new LineBreak());
            }
        }

        private static void HighlightCodeLine(InlineCollection inlines, string line)
        {
            // Highlight strings first, then keywords inside non-string spans
            int pos = 0;
            foreach (Match sm in CodeStringRegex.Matches(line))
            {
                if (sm.Index > pos)
                    HighlightKeywords(inlines, line[pos..sm.Index]);
                inlines.Add(new Run(sm.Value) { Foreground = DesignTokens.SuccessTextBrush });
                pos = sm.Index + sm.Length;
            }
            if (pos < line.Length)
                HighlightKeywords(inlines, line[pos..]);
        }

        private static void HighlightKeywords(InlineCollection inlines, string segment)
        {
            int pos = 0;
            foreach (Match km in CodeKeywordRegex.Matches(segment))
            {
                if (km.Index > pos)
                    inlines.Add(new Run(segment[pos..km.Index]) { Foreground = DesignTokens.TextStrongBrush });
                inlines.Add(new Run(km.Value) { Foreground = DesignTokens.CodeTextBrush, FontWeight = FontWeights.Medium });
                pos = km.Index + km.Length;
            }
            if (pos < segment.Length)
                inlines.Add(new Run(segment[pos..]) { Foreground = DesignTokens.TextStrongBrush });
        }
    }
}
