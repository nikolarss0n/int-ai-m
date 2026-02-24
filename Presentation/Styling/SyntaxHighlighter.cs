using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;

namespace InterviewMasterApp.Presentation.Styling
{
    /// <summary>
    /// Syntax highlighter for code blocks using One Dark theme colors (string-based).
    /// Ported from Swift: SyntaxHighlighter.swift
    /// </summary>
    public class SyntaxHighlighter
    {
        // One Dark theme colors
        private readonly Color _keyword = Color.FromArgb(199, 120, 221);
        private readonly Color _type = Color.FromArgb(229, 192, 123);
        private readonly Color _string = Color.FromArgb(152, 195, 121);
        private readonly Color _number = Color.FromArgb(209, 154, 102);
        private readonly Color _comment = Color.FromArgb(229, 192, 76);
        private readonly Color _function = Color.FromArgb(97, 175, 239);
        private readonly Color _plain = Color.FromArgb(223, 229, 234);
        private readonly Color _decorator = Color.FromArgb(229, 192, 123);
        private readonly Color _codeBg = Color.FromArgb(128, 31, 33, 38);

        private readonly float _codeFontSize;

        private readonly Dictionary<string, HashSet<string>> _keywords = new(StringComparer.OrdinalIgnoreCase)
        {
            ["python"] = new HashSet<string>(new [] {"def","class","if","elif","else","for","while","return","import","from","as","try","except","finally","raise","with","yield","lambda","pass","break","continue","and","or","not","in","is","async","await","None","True","False","global","nonlocal","assert","del"}, StringComparer.OrdinalIgnoreCase),
            ["java"] = new HashSet<string>(new [] {"public","private","protected","class","interface","extends","implements","static","final","void","int","long","double","float","boolean","char","byte","short","new","return","if","else","for","while","do","switch","case","default","break","continue","try","catch","finally","throw","throws","import","package","this","super","null","true","false","abstract","synchronized","volatile","instanceof","enum","var","record"}, StringComparer.OrdinalIgnoreCase),
            ["javascript"] = new HashSet<string>(new [] {"function","const","let","var","if","else","for","while","do","switch","case","default","break","continue","return","try","catch","finally","throw","class","extends","new","this","super","import","export","from","as","async","await","yield","of","in","typeof","instanceof","delete","void","null","undefined","true","false","NaN"}, StringComparer.OrdinalIgnoreCase),
            ["sql"] = new HashSet<string>(new [] {"SELECT","FROM","WHERE","JOIN","LEFT","RIGHT","INNER","OUTER","ON","AND","OR","NOT","IN","IS","NULL","LIKE","BETWEEN","GROUP","BY","ORDER","ASC","DESC","LIMIT","OFFSET","HAVING","INSERT","INTO","VALUES","UPDATE","SET","DELETE","CREATE","TABLE","ALTER","DROP","INDEX","VIEW","DISTINCT","AS","CASE","WHEN","THEN","ELSE","END","UNION","ALL","EXISTS","COUNT","SUM","AVG","MAX","MIN","COALESCE","CAST"}, StringComparer.OrdinalIgnoreCase),
            ["swift"] = new HashSet<string>(new [] {"func","class","struct","enum","protocol","extension","var","let","if","else","guard","for","while","repeat","switch","case","default","break","continue","return","try","catch","throw","throws","defer","import","self","Self","super","nil","true","false","public","private","internal","static","final","override","mutating","lazy","weak","async","await"}, StringComparer.OrdinalIgnoreCase),
            ["go"] = new HashSet<string>(new [] {"func","package","import","type","struct","interface","var","const","if","else","for","range","switch","case","default","break","continue","return","go","select","chan","map","make","new","defer","panic","recover","nil","true","false","iota"}, StringComparer.OrdinalIgnoreCase)
        };

        private readonly HashSet<string> _builtinTypes = new(StringComparer.OrdinalIgnoreCase)
        {
            "String","Int","Integer","Long","Double","Float","Boolean","Bool","List","Array","Dict","Dictionary","Map","Set","HashMap","HashSet","ArrayList","Optional","Result","Void","Object","Number","Date","Error","Exception","Promise"
        };

        public SyntaxHighlighter(float fontSize = 14)
        {
            _codeFontSize = fontSize;
        }

        public Color BackgroundColor => _codeBg;

        /// <summary>
        /// Highlight code and return styled runs.
        /// </summary>
        public StyledText Highlight(string code, string? language = null)
        {
            var styled = new StyledText();
            if (string.IsNullOrEmpty(code)) return styled;

            var lang = (language ?? DetectLanguage(code)).ToLowerInvariant();
            var langKeywords = _keywords.TryGetValue(lang, out var set) ? set : _keywords["python"].Union(_keywords["java"]).Union(_keywords["javascript"]).ToHashSet(StringComparer.OrdinalIgnoreCase);

            var lines = code.Split('\n');
            bool inMultiComment = false;

            for (int i = 0; i < lines.Length; i++)
            {
                var line = lines[i];
                var (lineRuns, stillIn) = HighlightLine(line, langKeywords, lang, inMultiComment);
                inMultiComment = stillIn;
                styled.Runs.AddRange(lineRuns);
                if (i < lines.Length - 1)
                {
                    styled.Add("\n", BaseStyle());
                }
            }
            return styled;
        }

        private TextStyle BaseStyle()
        {
            return new TextStyle { Foreground = _plain, Monospace = true, FontSize = _codeFontSize };
        }

        private string DetectLanguage(string code)
        {
            var lower = code.ToLowerInvariant();
            if (lower.Contains("def ") && lower.Contains(":")) return "python";
            if (lower.Contains("public class") || lower.Contains("public static void")) return "java";
            if (lower.Contains("function") || lower.Contains("const ") || lower.Contains("=>")) return "javascript";
            if (lower.Contains("select") && lower.Contains("from")) return "sql";
            if (lower.Contains("func ") && lower.Contains("->")) return "swift";
            if (lower.Contains("package ") && lower.Contains("func ")) return "go";
            return "generic";
        }

        private (List<StyledRun> runs, bool stillInComment) HighlightLine(string line, HashSet<string> keywords, string lang, bool inComment)
        {
            var runs = new List<StyledRun>();
            if (string.IsNullOrEmpty(line)) return (runs, inComment);

            if (inComment)
            {
                var endIdx = line.IndexOf("*/", StringComparison.Ordinal);
                if (endIdx >= 0)
                {
                    var commentPart = line.Substring(0, endIdx + 2);
                    runs.Add(new StyledRun(commentPart, CommentStyle()));
                    var rest = line.Substring(endIdx + 2);
                    runs.AddRange(HighlightTokens(rest, keywords));
                    return (runs, false);
                }
                runs.Add(new StyledRun(line, CommentStyle()));
                return (runs, true);
            }

            var singleIdx = FindSingleLineComment(line, lang);
            var multiIdx = line.IndexOf("/*", StringComparison.Ordinal);
            if (multiIdx >= 0 && (singleIdx < 0 || multiIdx < singleIdx))
            {
                var before = line.Substring(0, multiIdx);
                runs.AddRange(HighlightTokens(before, keywords));
                var after = line.Substring(multiIdx);
                var endIdx = after.IndexOf("*/", StringComparison.Ordinal);
                if (endIdx >= 0)
                {
                    var commentText = after.Substring(0, endIdx + 2);
                    runs.Add(new StyledRun(commentText, CommentStyle()));
                    var remaining = after.Substring(endIdx + 2);
                    runs.AddRange(HighlightTokens(remaining, keywords));
                    return (runs, false);
                }
                runs.Add(new StyledRun(after, CommentStyle()));
                return (runs, true);
            }

            if (singleIdx >= 0)
            {
                var code = line.Substring(0, singleIdx);
                var comment = line.Substring(singleIdx);
                runs.AddRange(HighlightTokens(code, keywords));
                runs.Add(new StyledRun(comment, CommentStyle()));
                return (runs, false);
            }

            runs.AddRange(HighlightTokens(line, keywords));
            return (runs, false);
        }

        private int FindSingleLineComment(string line, string lang)
        {
            bool inString = false;
            char stringChar = '"';
            for (int i = 0; i < line.Length; i++)
            {
                var c = line[i];
                if (!inString && (c == '"' || c == '\'')) { inString = true; stringChar = c; }
                else if (inString && c == stringChar)
                {
                    if (i == 0 || line[i - 1] != '\\') inString = false;
                }

                if (!inString)
                {
                    if (c == '/' && i + 1 < line.Length && line[i + 1] == '/') return i;
                    if (c == '#' && lang == "python") return i;
                    if (c == '-' && lang == "sql" && i + 1 < line.Length && line[i + 1] == '-') return i;
                }
            }
            return -1;
        }

        private IEnumerable<StyledRun> HighlightTokens(string text, HashSet<string> keywords)
        {
            var runs = new List<StyledRun>();
            if (string.IsNullOrEmpty(text)) return runs;

            int i = 0;
            while (i < text.Length)
            {
                var c = text[i];

                // Strings (single/double)
                if (c == '"' || c == '\'')
                {
                    var (str, end) = ExtractString(text, i, c);
                    runs.Add(new StyledRun(str, StringStyle()));
                    i = end;
                    continue;
                }

                // Decorator
                if (c == '@')
                {
                    var (word, end) = ExtractWord(text, i, includePrefix: true);
                    runs.Add(new StyledRun(word, DecoratorStyle()));
                    i = end;
                    continue;
                }

                // Numbers
                if (char.IsDigit(c) || (c == '.' && i + 1 < text.Length && char.IsDigit(text[i + 1])))
                {
                    var (num, end) = ExtractNumber(text, i);
                    runs.Add(new StyledRun(num, NumberStyle()));
                    i = end;
                    continue;
                }

                // Words
                if (char.IsLetter(c) || c == '_')
                {
                    var (word, end) = ExtractWord(text, i, includePrefix: false);
                    TextStyle style;
                    if (keywords.Contains(word)) style = KeywordStyle();
                    else if (_builtinTypes.Contains(word) || (word.Length > 1 && char.IsUpper(word[0]))) style = TypeStyle();
                    else if (end < text.Length && text[end] == '(') style = FunctionStyle();
                    else style = BaseStyle();
                    runs.Add(new StyledRun(word, style));
                    i = end;
                    continue;
                }

                // Default char
                runs.Add(new StyledRun(c.ToString(), BaseStyle()));
                i++;
            }

            return runs;
        }

        private (string, int) ExtractString(string text, int start, char quote)
        {
            var result = new List<char> { quote };
            int i = start + 1;
            while (i < text.Length)
            {
                var c = text[i];
                result.Add(c);
                if (c == quote && (i == start + 1 || text[i - 1] != '\\')) return (new string(result.ToArray()), i + 1);
                i++;
            }
            return (new string(result.ToArray()), text.Length);
        }

        private (string, int) ExtractWord(string text, int start, bool includePrefix)
        {
            int i = start;
            var sb = new List<char>();
            if (includePrefix && i < text.Length && text[i] == '@') { sb.Add('@'); i++; }
            while (i < text.Length && (char.IsLetterOrDigit(text[i]) || text[i] == '_'))
            {
                sb.Add(text[i]);
                i++;
            }
            return (new string(sb.ToArray()), i);
        }

        private (string, int) ExtractNumber(string text, int start)
        {
            int i = start;
            var sb = new List<char>();
            bool hasDecimal = false;
            while (i < text.Length)
            {
                var c = text[i];
                if (char.IsDigit(c)) { sb.Add(c); }
                else if (c == '.' && !hasDecimal) { hasDecimal = true; sb.Add(c); }
                else if ((c == 'x' || c == 'X') && sb.Count == 1 && sb[0] == '0') { sb.Add(c); }
                else break;
                i++;
            }
            return (new string(sb.ToArray()), i);
        }

        private TextStyle KeywordStyle() => new TextStyle { Foreground = _keyword, Monospace = true, FontSize = _codeFontSize };
        private TextStyle TypeStyle() => new TextStyle { Foreground = _type, Monospace = true, FontSize = _codeFontSize };
        private TextStyle StringStyle() => new TextStyle { Foreground = _string, Monospace = true, FontSize = _codeFontSize };
        private TextStyle NumberStyle() => new TextStyle { Foreground = _number, Monospace = true, FontSize = _codeFontSize };
        private TextStyle CommentStyle() => new TextStyle { Foreground = _comment, Monospace = true, FontSize = _codeFontSize };
        private TextStyle FunctionStyle() => new TextStyle { Foreground = _function, Monospace = true, FontSize = _codeFontSize };
        private TextStyle DecoratorStyle() => new TextStyle { Foreground = _decorator, Monospace = true, FontSize = _codeFontSize };
    }
}

