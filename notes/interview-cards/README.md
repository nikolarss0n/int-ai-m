# Interview cards: collected content and integration brief

## Status update, 14 September 2026 (afternoon)

All three decks are now authored and loaded by the app. The Practice tab offers them as card roles with Study Cards and Full Interview modes:

| Role in app | Pack file | Cards | Notes file |
| --- | --- | ---: | --- |
| Claude Architect | `Resources/practice/claude-architect.json` | 453 | [claude-certification-cards.md](claude-certification-cards.md) |
| AI Engineer Cards | `Resources/practice/ai-engineer-cards.json` | 160 | [ai-engineer-cards.md](ai-engineer-cards.md) |
| TypeScript Cards | `Resources/practice/typescript-cards.json` | 45 | [typescript-cards.md](typescript-cards.md) |

The Claude deck grew from 120 to 453 cards so that every testable point in each of the 30 lesson texts (rules, distinctions, commands and flags, exam traps, the practice-scenario concept, and build-exercise outcomes) has a card; the coverage audit is recorded per lesson in the deck notes. Where the guide keys an older exam answer that differs from current tooling, the two are separate cards and the prompt says which is asked. The 120 collected prompts (100 AI engineering, 20 TypeScript) were converted into 205 original four-choice cards; every inventory id maps to its card ids in `question-inventory.json`. Card groups use the `cards-` prefix so free-response roles never pull card questions into their pools. The two content defects flagged on 7 September are fixed: the Recall@k cards in `bank.json` and `llm-interview.json` now distinguish Recall@k from Hit@k, and Active Recall coverage grading is negation-aware. The sections below are the original intake brief and remain accurate as history.

Prepared 14 September 2026. This step gathers questions and records the requested behavior. Card implementation comes next.

## What is ready

- [General interview questions](/Users/nklars0/Projects/int-ai-m/notes/interview-cards/collected-questions.md): **120 prompts** from earlier conversations and preparation guides.
- **Separate [Claude Architect deck](/Users/nklars0/Projects/int-ai-m/notes/interview-cards/claude-certification-cards.md): 120 original four-choice cards**, four per lesson, with correct answers, explanations, distractor rationales and source links. [Structured Claude deck](/Users/nklars0/Projects/int-ai-m/notes/interview-cards/claude-certification-cards.json).
- [Question inventory](/Users/nklars0/Projects/int-ai-m/notes/interview-cards/question-inventory.json): stable intake IDs, provenance, prior-session learning signals, proposed starting 50, and unverified candidate matches to existing app questions.
- The existing [50-question answer guide](/Users/nklars0/Projects/int-ai-m/notes/ai-solution-engineering-top-50.md) remains available as preparation material. Its answers are not automatically approved as multiple-choice answer keys.

There are now **two separate collections**: the general interview inventory has 100 AI-engineering and 20 TypeScript prompts; the standalone Claude Architect deck has 120 fully authored cards. Claude cards are not mixed into the general inventory's questions. It contains only a catalog link to the separate deck. The general prompts still need authored choices. App integration remains pending.

| Topic | Prompts |
| --- | ---: |
| Python runtime, concurrency and language basics | 24 |
| Python OOP and interfaces | 9 |
| FastAPI and production | 16 |
| RAG | 16 |
| Evaluation | 8 |
| Agents | 9 |
| LLM foundations | 5 |
| Coding utility | 1 |
| Submitted review-summarizer project | 12 |
| TypeScript, separate deck | 20 |

The separate Claude Architect deck covers all 30 lessons in the [community guide](https://claudecertificationguide.com/learn), including CLAUDE.md scope, imports and context inspection. Its cards cover concepts, decisions and failure cases:

| Claude domain | Lessons | Cards |
| --- | ---: | ---: |
| Agentic architecture | 7 | 28 |
| Tools and MCP | 5 | 20 |
| Claude Code configuration | 6 | 24 |
| Prompting and structured output | 6 | 24 |
| Context and reliability | 6 | 24 |
| **Total** | **30** | **120** |

These are original questions based on the material, not official exam questions or an exhaustive list of everything an exam could ask. Current Anthropic documentation was checked for version-sensitive behavior. Equal coverage per lesson is a study choice, not official exam weighting.

## Conversations reviewed

All available pages were read for these five conversations, totaling **98 turns**:

| Exact task title | Available turns | What it contributes |
| --- | ---: | --- |
| AI Engineer Interview Prep | 34 | GIL, I/O, collections, copying, generators, decorators, context managers, FastAPI and RAG; several actual attempted answers and clarifications. |
| Python и GIL async limitations | 8 | GIL versus async, threads/processes, and requests for repeated concise explanations. |
| Търсене на чат за EPAM | 51 | RAG/embedding flow, metrics, SQL/vector search, FastAPI, threading and softmax. |
| Prepare EPAM AI interview | 2 | Submitted-project walkthrough and saved Python/OOP/production preparation guide. |
| TypeScript Mock Interview | 3 | Twenty prepared questions; only the first has an observed user answer. |

I also checked this task's saved top-50 guide and the recent archived **Improve practice design mockups** task for integration context. The current source code is the evidence for existing functionality, rather than old implementation reports.

Voice evidence is saved transcript/handoff text, not newly replayed raw audio. Repeated transcript tails and restated questions were consolidated. The Bulgarian chat's assistant refers to older June EPAM/S&P conversations, but those originals were not retrieved; that recollection was not treated as verified source content. No old pass percentages or mastery claims were carried over.

## What to put near the front of the deck

The initial 50 IDs are stored in `proposed_first_50` in the JSON. Prioritize these distinctions because they were explicitly revisited in the saved sessions:

1. What the GIL controls, versus what the OS and event loop schedule.
2. Why threads can help I/O despite the GIL.
3. Processes, threads and coroutines.
4. `async def` versus `def` in FastAPI; response order is a separate issue.
5. Hashability, dictionary keys and set membership.
6. Shallow versus deep copying of nested objects.
7. `yield`, `return`, `await`, and who resumes a generator.
8. Why the input source, rather than the `for` loop itself, determines materialization.
9. Decorators as transformations/wrappers rather than only labels.
10. Context managers and the cleanup contract.
11. Retrieval metrics versus generation support, including automatic versus human evaluation.
12. TypeScript versus JavaScript, in the separate frontend deck.

These are historical learning signals, not a diagnosis of present ability. Incorrect earlier explanations must not become the answer key: the old chat confuses hit rate with Recall@k, oversimplifies tuple hashability, and sometimes describes generator memory or resource cleanup too absolutely. Each eventual card needs a reviewed explanation.

## Requested modes

| Behavior | Study cards | Full interview |
| --- | --- | --- |
| Question display | One card with four choices | One card with four choices |
| Before answering | No answer, hint or correctness marker | No answer, hint or correctness marker |
| On selecting an option | Commit the selection; reveal the correct option and explanation | Save the selection with neutral styling; show completion only |
| Explanation | Why the correct answer fits, and why the selected distractor does not | Hidden until the full run is submitted |
| Progress | Answered count; missed cards can be revisited | Answered count only; no scores, green/red states or correctness-derived topic indicators |
| Finish | Review mistakes and schedule another attempt | Reveal total and per-topic results, chosen versus correct options, and explanations |
| Resume | Preserve card, choice order, selection and reveal state | Preserve question/choice order and selections without leaking correctness |

Working assumption: “full interview” here means a full **four-choice assessment** using the same question bank. The existing spoken/free-response Interview mode can remain available separately. Open-ended project ownership questions cannot honestly have one universally correct answer; keep them as optional spoken prompts, or convert them into tightly specified decision scenarios.

Study selections should be scored once before feedback. A retry after seeing the answer is a new practice attempt, not a correction that overwrites the original score. For the full interview, answers may be reviewed and changed before final submission; finish is the reveal boundary. The question and option order should be frozen for that run.

## Fit with current code

- [PracticeQuestion](/Users/nklars0/Projects/int-ai-m/Domain/Practice/PracticeLogic.swift:39) has text, hints, answer and rubric, but no persistent authored options or correct-option ID.
- [practiceShowsMultipleChoice](/Users/nklars0/Projects/int-ai-m/Domain/Practice/PracticeLogic.swift:488) always returns false. Older choice-generation and selection-mark helpers still exist around [practiceLearnChoices](/Users/nklars0/Projects/int-ai-m/Domain/Practice/PracticeLogic.swift:907).
- The older generator takes the first line of unrelated bank answers as distractors. Do not use that as the content strategy: it can produce implausible alternatives, truncated answers or more than one defensible answer.
- The existing [Interview setup](/Users/nklars0/Projects/int-ai-m/Presentation/Practice/PracticeTabController.swift:956) is a scored free-response flow without learning help. [Question rendering](/Users/nklars0/Projects/int-ai-m/Presentation/Practice/PracticeTabController.swift:1480) already withholds prepared help; [submission](/Users/nklars0/Projects/int-ai-m/Presentation/Practice/PracticeTabController.swift:1789) judges typed/spoken answers before advancing, and [report formatting](/Users/nklars0/Projects/int-ai-m/Presentation/Practice/PracticeTabController.swift:2153) summarizes results. Reuse the lifecycle and persistence seams, while adding explicit multiple-choice state and reveal rules.
- Extend the existing Practice tab and saved sessions. Preserve current question identities/progress. The intake IDs in this folder are not replacements for production bank IDs; lexical candidate mappings require review.

## Content contract for implementation

Each approved card should have a stable question ID, a specific prompt, exactly four distinct options with stable IDs, one correct-option ID, a concise explanation, a rationale for each distractor, topic, provenance and content version. Option order is presentation state, never the answer key. Keep the factual answer separate from the richer optional spoken explanation.

Write distractors around realistic misconceptions from the reviewed sessions. Keep their length and grammar comparable; avoid “all of the above,” joke options, answer-length clues, and ambiguous “best” choices without requirements. Split compound questions before converting them. In exam mode, an earlier card's wording should not reveal a later card's answer.

Use deterministic option-ID scoring for these cards. An unavailable LLM judge should have no effect on multiple-choice correctness. Track the result as recognition practice rather than claiming it proves spoken or coding mastery.

Implementation acceptance cases:

- Four unique options and exactly one existing correct ID; malformed cards fail validation.
- Choice order changes across runs without changing correctness, and stays fixed across resume.
- Study feedback appears only after selection and records the original attempt.
- Full interview exposes no correctness through colors, summaries, navigation, Help or accessibility labels before submission.
- End review includes every question, including unanswered ones under an explicit completion policy.
- Old saved runs load safely, and current free-response modes remain usable.

Only question-intake documents/data and temporary collection scripts were added. No production Swift, shipped practice JSON, application settings or saved learner progress were changed. The new files were checked for unique IDs, the 50-card selection, and valid source turn IDs/guide headings. No build or live API/audio test was needed for this collection-only step.
