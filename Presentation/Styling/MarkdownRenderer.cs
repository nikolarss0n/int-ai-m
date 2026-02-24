using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text.RegularExpressions;

namespace InterviewMasterApp.Presentation.Styling
{
    /// <summary>
    /// Markdown renderer for plain text. Produces StyledText runs for UI or HTML output.
    /// Ported from Swift: MarkdownRenderer.swift
    /// </summary>
    public class MarkdownRenderer
    {
        public enum Style
        {
            Notes,
            Analysis
        }

        private readonly Style _style;
        private readonly SyntaxHighlighter _syntax;

        // Colors
        private readonly Color _yellow = Color.FromArgb(255, 255, 214, 0);
        private readonly Color _header = Color.FromArgb(255, 255, 214, 0);
        private readonly Color _code = Color.FromArgb(255, 229, 235, 242);
        private readonly Color _codeBg = Color.FromArgb(128, 31, 33, 38);
        private readonly Color _inlineCode = Color.FromArgb(255, 250, 184, 153);
        private readonly Color _inlineCodeBg = Color.FromArgb(204, 38, 38, 51);
        private readonly Color _link = Color.FromArgb(255, 102, 179, 255);
        private readonly Color _marker = Color.FromArgb(153, 128, 128, 128);

        private float HeaderSize => _style == Style.Notes ? 24 : 20;
        private float SubHeaderSize => _style == Style.Notes ? 20 : 18;
        private float BodySize => _style == Style.Notes ? 16 : 15;
        private float CodeSize => _style == Style.Notes ? 15 : 14;

        public MarkdownRenderer(Style style = Style.Notes)
        {
            _style = style;
            _syntax = new SyntaxHighlighter(CodeSize);
        }

        /// <summary>
        /// Render markdown into a StyledText structure.
        /// </summary>
        public StyledText Render(string text)
        {
            var styled = new StyledText();
            if (string.IsNullOrEmpty(text)) return styled;

            int idx = 0;
            while (idx < text.Length)
            {
                var start = text.IndexOf("```", idx, StringComparison.Ordinal);
                if (start < 0)
                {
                    RenderMarkdownSegment(styled, text.Substring(idx));
                    break;
                }

                // Render preceding segment
                if (start > idx)
                {
                    RenderMarkdownSegment(styled, text.Substring(idx, start - idx));
                }

                // Find end of code block
                var end = text.IndexOf("```", start + 3, StringComparison.Ordinal);
                if (end < 0)
                {
                    // Unclosed code block: render as plain
                    RenderMarkdownSegment(styled, text.Substring(start));
                    break;
                }

                // Extract language + code
                var headerEnd = text.IndexOf('\n', start + 3);
                string lang = string.Empty;
                string code = string.Empty;
                if (headerEnd > 0 && headerEnd < end)
                {
                    lang = text.Substring(start + 3, headerEnd - (start + 3)).Trim();
                    code = text.Substring(headerEnd + 1, end - (headerEnd + 1));
                }
                else
                {
                    code = text.Substring(start + 3, end - (start + 3));
                }

                // Opening line
                styled.Add("```" + lang + "\n", MarkerStyle());

                // Highlight code
                var highlighted = _syntax.Highlight(code, string.IsNullOrEmpty(lang) ? null : lang);
                foreach (var run in highlighted.Runs)
                {
                    var s = run.Style.Clone();
                    s.Background = _codeBg;
                    styled.Add(run.Text, s);
                }

                // Closing
                styled.Add("\n```", MarkerStyle());

                idx = end + 3;
            }

            return styled;
        }

        private void RenderMarkdownSegment(StyledText styled, string segment)
        {
            if (string.IsNullOrEmpty(segment)) return;

            var lines = segment.Split('\n');
            for (int i = 0; i < lines.Length; i++)
            {
                var line = lines[i];
                if (IsDivider(line))
                {
                    styled.Add(new string('-', 48) + "\n", new TextStyle { Foreground = Color.FromArgb(80, _yellow), FontSize = BodySize });
                    continue;
                }

                if (line.StartsWith("# "))
                {
                    styled.Add("# ", MarkerStyle());
                    styled.Add(line.Substring(2), new TextStyle { Foreground = _header, Bold = true, FontSize = HeaderSize });
                }
                else if (Regex.IsMatch(line, "^#{2,6}\\s"))
                {
                    var m = Regex.Match(line, "^(#{2,6})\\s(.*)$");
                    styled.Add(m.Groups[1].Value + " ", MarkerStyle());
                    styled.Add(m.Groups[2].Value, new TextStyle { Foreground = _header, Bold = true, FontSize = SubHeaderSize });
                }
                else
                {
                    RenderInline(styled, line);
                }

                if (i < lines.Length - 1) styled.Add("\n", BaseStyle());
            }
        }

        private void RenderInline(StyledText styled, string line)
        {
            if (string.IsNullOrEmpty(line)) return;

            var patterns = new List<(Regex regex, Func<Match, (string text, TextStyle style)> handler)>
            {
                // Links: [text](url)
                (new Regex("\\[([^\\]]+)\\]\\(([^)]+)\\)"), m =>
                {
                    var text = m.Groups[1].Value;
                    var url = m.Groups[2].Value;
                    var style = new TextStyle { Foreground = _link, Underline = true, FontSize = BodySize };
                    return (text, style);
                }),
                // Inline code: `code`
                (new Regex("`([^`\\n]+)`"), m =>
                {
                    var text = m.Groups[1].Value;
                    var style = new TextStyle { Foreground = _inlineCode, Background = _inlineCodeBg, Monospace = true, FontSize = CodeSize };
                    return (text, style);
                }),
                // Bold: **text**
                (new Regex("(?<!\\*)\\*\\*(?!\\*)(.+?)(?<!\\*)\\*\\*(?!\\*)"), m =>
                {
                    var text = m.Groups[1].Value;
                    var style = new TextStyle { Foreground = _style == Style.Analysis ? _yellow : Color.White, Bold = true, FontSize = BodySize };
                    return (text, style);
                }),
                // Italic: *text*
                (new Regex("(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)"), m =>
                {
                    var text = m.Groups[1].Value;
                    var style = new TextStyle { Italic = true, FontSize = BodySize };
                    return (text, style);
                })
            };

            int index = 0;
            while (index < line.Length)
            {
                Match? bestMatch = null;
                Regex? bestRegex = null;
                foreach (var (regex, _) in patterns)
                {
                    var m = regex.Match(line, index);
                    if (m.Success && (bestMatch == null || m.Index < bestMatch.Index))
                    {
                        bestMatch = m;
                        bestRegex = regex;
                    }
                }

                if (bestMatch == null)
                {
                    styled.Add(line.Substring(index), BaseStyle());
                    break;
                }

                // Add text before match
                if (bestMatch.Index > index)
                {
                    styled.Add(line.Substring(index, bestMatch.Index - index), BaseStyle());
                }

                // Add styled match
                var handler = patterns.First(p => p.regex == bestRegex).handler;
                var (text, style) = handler(bestMatch);
                styled.Add(text, style);

                index = bestMatch.Index + bestMatch.Length;
            }
        }

        private bool IsDivider(string line)
        {
            var trimmed = line.Trim();
            return Regex.IsMatch(trimmed, "^[-*_]{3,}$");
        }

        private TextStyle BaseStyle() => new TextStyle { Foreground = Color.FromArgb(242, 242, 242), FontSize = BodySize };
        private TextStyle MarkerStyle() => new TextStyle { Foreground = _marker, Monospace = true, FontSize = BodySize };
    }
}

