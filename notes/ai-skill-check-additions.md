# Additions for a 90-minute AI Solution Engineering skill check

Use this as a copilot playbook, not an EPAM question dump. Nothing here is company-specific.

## Already in the live copilot

Do not rebuild these.

| Surface | What it does for this screen | Source |
| --- | --- | --- |
| Voice cue cards | 3–5 spoken bullets for real questions. RAG cards already ask for definition + retrieve/embed flow + one tradeoff. | `Application/VoiceInterviewProcessor.swift`, `Infrastructure/Speech/GroqInterviewClient.swift` (`RAG/CAG ANSWER SHAPE`) |
| Resume briefing | Interviewer *talk* (not a `?`) updates one CV-badged row when the thread is RAG, agents, evals, or production. Empty if that thread is not on the PDF. | `Domain/Model/InterviewBriefing.swift`, `Infrastructure/Storage/ResumeStore.swift` |
| Stepped coding | “Write a FastAPI service / implement an endpoint” streams `STEP n — file:` + `Why:` + a fenced snippet. Same file can be split. Prompt is SIMPLEST CODE ONLY (no Depends/routers/LangChain unless named). | `Domain/Model/CodingInterviewSteps.swift`, `isImplementationCodingRequest` in `VoiceInterviewProcessor` |
| Screenshot analyze | `⌘S` then `⌘Return` uses the same coding-steps prompt. Overlay shows even while Timeline is open. | `Domain/ValueObjects/AnalysisMode.swift`, `Domain/Model/ScreenshotPresentation.swift` |
| Practice | AI Engineer / interviewer / prep packs plus `llm-interview.json` (embeddings, chunking, RAG, evals) and FastAPI items in `bank.json`. | `Resources/practice/ai-engineer-*.json`, `Resources/practice/llm-interview.json` |

“What is FastAPI?” stays a cue card. “Write a FastAPI service” does not.

## How to sit the screen with what you have

1. Settings: role AI/data, stack FastAPI / LangGraph / RAG / evals. Attach the resume PDF.
2. Practice tab tonight: long-document RAG, LLM eval metrics, agents. Say the answers out loud.
3. Live: let them narrate — briefing only fires CV lines. When they *ask*, watch the cue card. When they *write a service*, type the STEP chunks.
4. If the spec is on screen (chat, CoderPad, platform), screenshot the **text**, then analyze.

## Ranked additions

### 1. Covered — rehearse the RAG book-chunking walkthrough in Practice
- **Interview moment:** “Walk RAG end-to-end, including chunking a whole book.”
- **Outcome:** You have already said: headings first, then size; keep tables; metadata path; embed; hybrid retrieve; rerank; cite. Live cue cards will only refresh that, they will not teach it the first time.
- **Label:** covered

### 2. Covered — resume is the production story, not the cue card
- **Interview moment:** “How did you ship this in production?” / FastAPI + retries / LangSmith.
- **Outcome:** A CV-badged briefing line from the PDF when they talk production or FastAPI. No invented Graph RAG if it is not on the resume.
- **Label:** covered

### 3. Covered — live “write a service” is STEP / file / Why
- **Interview moment:** “Write a FastAPI endpoint for this.”
- **Outcome:** Two to five typeable chunks, usually `main.py` twice (app, then route). Overlay + timeline coding task. Conceptual FastAPI stays bullets.
- **Label:** covered

### 4. Gap — a design-walkthrough card when they narrate without asking
- **Interview moment:** RAG walkthrough, agents, evals.
- **Why it is a gap:** “Let’s walk through RAG, including chunking a whole book” is a *statement*. Today that updates briefing only and does **not** open a staged pipeline card. Cue cards wait for a question.
- **Add:** If the utterance is “walk through / end to end / pipeline” on rag/agents/evals, emit a 4–6 bullet **stage card** (chunk → embed → retrieve → rerank → generate → cite) with one tradeoff, still not a new tab.
- **Outcome:** You see the pipeline while they are still talking, before they pause for a question.
- **Label:** gap

### 5. Gap — evals cue-card shape (not just Practice Qs)
- **Interview moment:** “How would you eval this RAG?” recall, precision, MRR, faithfulness, grounding.
- **Why it is a gap:** Practice has LLM eval questions. Live RAG shape is retrieve/embed, not metric-vs-metric. SOLID has a per-letter template; evals do not.
- **Add:** When topic is evals, one bullet per metric + one failure mode (“faithfulness fails if the model ignores retrieved chunks”).
- **Outcome:** You can contrast metrics without mixing them up under time pressure.
- **Label:** gap

### 6. Gap — agents HITL sketch on the agents thread
- **Interview moment:** LangGraph, ReAct, multi-agent, tool calling, human-in-the-loop.
- **Why it is a gap:** Briefing will surface CV LangGraph lines. Cue cards have no agent-loop template (plan → tool → observe → cap steps → HITL on writes).
- **Add:** Agents topic → short loop card: tool schema, bound steps, validate tool output, human approve destructive tools. Keep it generic, not a LangGraph API dump.
- **Outcome:** You have a failure-mode sketch while they compare LangChain vs LangGraph.
- **Label:** gap

## What not to add

- An EPAM / Glassdoor / LeetCode pack in the app.
- A separate Briefing or Coding tab.
- Vector search over the resume.

If you only implement one gap before the screen: **#4 (walkthrough card)**. That is the shape of this interview more than “What is an embedding?”
