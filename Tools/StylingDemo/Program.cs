using System;
using System.IO;
using InterviewMasterApp.Presentation.Styling;

var sample = @"# Interview Notes

## JavaScript

**Q:** What is a *closure*?
A closure is a function that captures variables from its outer scope.

```javascript
function outer() {
  let count = 0;
  return function inner() {
    count++;
    return count;
  };
}
```

- Bullet one
- Bullet two

[Docs](https://developer.mozilla.org)
";

var renderer = new MarkdownRenderer(MarkdownRenderer.Style.Notes);
var styled = renderer.Render(sample);
var html = styled.ToHtml();

var outputPath = Path.Combine(Directory.GetCurrentDirectory(), "styling_demo.html");
File.WriteAllText(outputPath, html);
Console.WriteLine("Wrote: " + outputPath);

