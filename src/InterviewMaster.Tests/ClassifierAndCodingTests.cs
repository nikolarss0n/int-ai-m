using System;
using System.Linq;
using Xunit;
using InterviewMasterApp.Domain.Model;

namespace InterviewMasterApp.Tests
{
    public class ClassifierAndCodingTests
    {
        [Fact]
        public void ClassifierStreamParser_HandlesNormalMissingSeparatorAndDrift()
        {
            var normal = ClassifierStreamParser.Parse("STATUS:question|TOPIC:oop\n---\n- Encapsulation hides state.");
            Assert.Equal("STATUS:question|TOPIC:oop", normal.StatusLine);
            Assert.False(normal.FormatDrift);
            Assert.Equal("- Encapsulation hides state.", normal.Answer);

            var noSep = ClassifierStreamParser.Parse("STATUS:question|TOPIC:rag\n- Retrieve chunks first.");
            Assert.Equal("STATUS:question|TOPIC:rag", noSep.StatusLine);
            Assert.Equal("- Retrieve chunks first.", noSep.Answer);

            var drift = ClassifierStreamParser.Parse("- Direct answer without any status header at all.");
            Assert.Null(drift.StatusLine);
            Assert.True(drift.FormatDrift);
            Assert.Equal("- Direct answer without any status header at all.", drift.Answer);

            // Lone "--" held back mid-stream, released when stream ends
            Assert.Equal(string.Empty, ClassifierStreamParser.Parse("STATUS:question|TOPIC:x\n--", streamEnded: false).Answer);
            Assert.Equal("--", ClassifierStreamParser.Parse("STATUS:question|TOPIC:x\n--", streamEnded: true).Answer);
        }

        [Fact]
        public void CodingRequestDetector_DetectsTasksDeicticAndFollowUps()
        {
            Assert.True(CodingRequestDetector.IsTaskRequest("Write a function that reverses a string"));
            Assert.True(CodingRequestDetector.IsTaskRequest("How to reverse a string in Python"));
            Assert.False(CodingRequestDetector.IsTaskRequest("What is FastAPI?"));
            Assert.False(CodingRequestDetector.IsTaskRequest("I wrote a service in Python last year"));

            Assert.True(CodingRequestDetector.IsDeicticRequest("Write this code"));
            Assert.False(CodingRequestDetector.IsDeicticRequest("Write a function to reverse a string"));

            Assert.Equal(CodingFollowUpKind.Change, CodingRequestDetector.FollowUp("Write it in TypeScript"));
            Assert.Equal(CodingFollowUpKind.Change, CodingRequestDetector.FollowUp("Show me a simpler way"));
            Assert.Equal(CodingFollowUpKind.Change, CodingRequestDetector.FollowUp("Add unit tests for it"));
            Assert.Equal(CodingFollowUpKind.Example, CodingRequestDetector.FollowUp("Show me a sliding window example"));
            Assert.Null(CodingRequestDetector.FollowUp("Why did you use a hash map?"));
        }

        [Fact]
        public void EveryQuickActionChip_IsClassifiedAsSpokenCodeChange()
        {
            foreach (CodeQuickAction action in Enum.GetValues<CodeQuickAction>())
            {
                var instruction = action.GetInstruction("Python");
                Assert.Equal(CodingFollowUpKind.Change, CodingRequestDetector.FollowUp(instruction));
            }
        }

        [Fact]
        public void CodingTurnDecision_InheritsPreviousQuestionForCodeExample()
        {
            var session = new CodingSessionState();
            var now = DateTime.UtcNow;

            var decision = CodingInterviewStepsHelper.DecideTurn(
                "Can you show me that in code?",
                session,
                now,
                previousQuestion: "How does an LRU cache work?");

            Assert.NotNull(decision);
            Assert.Equal(CodingTurnDecisionKind.NewTask, decision!.Kind);
            Assert.Contains("LRU cache", decision.Text);
        }

        [Fact]
        public void StreamingStepsParserAndGroupingAndDiff_WorkAccurately()
        {
            var reply =
@"SAY:
- Use two pointers from both ends.
- O(n) time, O(1) space.

STEP 1 — file: main.py
Why: Reverse list in place.
```python
def rev(s):
    return s[::-1]
```

STEP 2 — file: main.py
Why: Quick test call.
```python
print(rev('abc'))
```";

            var split = CodingInterviewStepsHelper.SplitCodingResponse(reply);
            Assert.Equal(2, split.SayBullets.Count);
            Assert.Equal("Use two pointers from both ends.", CodingInterviewStepsHelper.FirstTalkingPoint(reply));

            var progress = CodingInterviewStepsHelper.ParseStepsStreaming(split.StepsMarkdown);
            Assert.False(progress.LastStepIsOpen);
            Assert.Equal(2, progress.Steps.Count);

            var sections = CodeFileSectionsHelper.GroupCodeSteps(progress.Steps);
            Assert.Single(sections);
            Assert.Equal("main.py", sections[0].FileName);
            Assert.Equal(2, sections[0].Chunks.Count);

            var diff = CodeFileSectionsHelper.ComputeLineChanges("a\nb\nc\nd\ne", "a\nb\nX\nd\ne");
            Assert.NotNull(diff);
            Assert.Contains(2, diff!.Changed);
        }
    }
}
