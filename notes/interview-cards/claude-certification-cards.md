# Claude Architect: 453 questions and answers

**Standalone Claude Architect deck: 453 original four-choice cards across 30 lessons and five domains.** This is separate from the Python, TypeScript and general interview collection.

Each lesson has at least four cards; additional cards were authored on 14 September 2026 so that every testable point in the lesson text (rules, distinctions, commands and flags, exam traps, the practice-scenario concept, and build-exercise outcomes) has a card. The source material guides the topic coverage; these are original questions rather than reproduced exam items. Current product behavior takes precedence over unsupported exam shortcuts.

Select an answer mentally before opening **Reveal answer**. The app loads this deck for the Claude Architect role: Study Cards reveals after selection; Full Interview reveals only after final submission.

| Domain | Lessons | Cards |
| --- | ---: | ---: |
| Agentic architecture | 7 | 102 |
| Tools and MCP | 5 | 75 |
| Claude Code configuration | 6 | 100 |
| Prompting and structured output | 6 | 88 |
| Context and reliability | 6 | 88 |

## Curriculum coverage

| Lesson | Topic | Cards |
| --- | --- | ---: |
| 1.1 | [Agentic Loops](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) | 14 |
| 1.2 | [Multi-Agent Orchestration](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) | 14 |
| 1.3 | [Subagent Invocation and Context Passing](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) | 14 |
| 1.4 | [Workflow Enforcement and Handoff](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) | 16 |
| 1.5 | [Agent SDK Hooks](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) | 15 |
| 1.6 | [Task Decomposition Strategies](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) | 14 |
| 1.7 | [Session State and Resumption](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) | 15 |
| 2.1 | [Tool Interface Design](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) | 15 |
| 2.2 | [Structured Error Responses](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) | 15 |
| 2.3 | [Tool Distribution & Tool Choice](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) | 15 |
| 2.4 | [MCP Server Integration](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) | 15 |
| 2.5 | [Built-in Tools](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) | 15 |
| 3.1 | [CLAUDE.md Hierarchy, Scoping, and Modular Organisation](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) | 21 |
| 3.2 | [Custom Slash Commands and Skills](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) | 18 |
| 3.3 | [Path-Specific Rules for Conditional Convention Loading](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) | 13 |
| 3.4 | [Plan Mode vs Direct Execution](https://claudecertificationguide.com/learn/3-claude-code-config/3-4-plan-mode-execution) | 12 |
| 3.5 | [Iterative Refinement Techniques](https://claudecertificationguide.com/learn/3-claude-code-config/3-5-iterative-refinement) | 12 |
| 3.6 | [CI/CD Integration](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) | 24 |
| 4.1 | [System Prompts with Explicit Criteria](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) | 14 |
| 4.2 | [Few-Shot Prompting](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) | 15 |
| 4.3 | [Structured Output with Tool Use](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) | 14 |
| 4.4 | [Validation, Retry, and Feedback Loops](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) | 15 |
| 4.5 | [Batch Processing Strategies](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) | 15 |
| 4.6 | [Multi-Instance and Multi-Pass Review](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) | 15 |
| 5.1 | [Context Window Management](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) | 13 |
| 5.2 | [Escalation & Ambiguity Resolution](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) | 14 |
| 5.3 | [Error Propagation in Multi-Agent Systems](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) | 14 |
| 5.4 | [Codebase Exploration & Context Degradation](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) | 14 |
| 5.5 | [Human Review & Confidence Calibration](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) | 14 |
| 5.6 | [Information Provenance & Multi-Source Synthesis](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) | 19 |

## Cards

## 1.1 — Agentic Loops

### 1. Tool results must be appended to conversation history and linked to the tool-use ID

`claude-1-1`

A Messages API response requests a client-side tool. After the application runs it, what lets Claude use the result?

- **A.** Send the result linked to its tool-use ID with the conversation history.
- **B.** Start a new conversation containing only the result.
- **C.** Ask the same question again without adding the result.
- **D.** Treat a successful tool execution as completion of the user's task.

<details>
<summary>Reveal answer</summary>

**A. Send the result linked to its tool-use ID with the conversation history.**

Claude needs the observation and its association with the requested tool call.

- **B:** This discards the task and the call that the observation answers.
- **C:** Repeating the prompt does not tell the model what the tool returned.
- **D:** A tool result may require further reasoning or additional actions.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 2. Truncation

`claude-1-1-2`

An answer stops with max_tokens while its JSON is unfinished. How should the application classify it?

- **A.** A completed tool call awaiting execution.
- **B.** A definitive refusal to answer.
- **C.** Incomplete output requiring recovery.
- **D.** Successful output because HTTP returned 200.

<details>
<summary>Reveal answer</summary>

**C. Incomplete output requiring recovery.**

The token limit ended generation before a usable result was established.

- **A:** Truncation is not a valid tool-call completion signal.
- **B:** A token limit and a refusal have different meanings.
- **D:** Transport success does not imply complete generated content.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons)

### 3. Loop budgets

`claude-1-1-3`

An agent reaches its execution budget with required work unfinished. What should the result state?

- **A.** Success because the configured loop has ended.
- **B.** Success if the final sentence sounds confident.
- **C.** No result until another unlimited loop finishes.
- **D.** Partial completion with the unmet work and stop reason.

<details>
<summary>Reveal answer</summary>

**D. Partial completion with the unmet work and stop reason.**

Budget exhaustion is an operational stop, not evidence of task success.

- **A:** Finishing the loop is different from finishing the task.
- **B:** Wording cannot establish that requirements were satisfied.
- **C:** Removing limits defeats the configured resource boundary.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons)

### 4. Control signals

`claude-1-1-4`

The response text says it is finished, but stop_reason is tool_use. What drives the next step?

- **A.** Inspect and handle the requested tool calls under policy.
- **B.** Ignore the calls because the text says finished.
- **C.** Execute a tool inferred only from the final sentence.
- **D.** Treat the response as a final verified answer.

<details>
<summary>Reveal answer</summary>

**A. Inspect and handle the requested tool calls under policy.**

Structured API signals determine control flow; execution still needs validation.

- **B:** Natural-language phrasing is not the protocol signal.
- **C:** Use the actual tool request and arguments, not an inferred action.
- **D:** A requested operation has not yet supplied its result.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons)

### 5. stop_reason end_turn means the loop terminates and the final response is returned

`claude-1-1-5`

A loop iteration returns a response whose stop_reason is end_turn. What should the controlling code do next?

- **A.** Exit the loop and return the final response to the user.
- **B.** Run the most recent tool once more to confirm its result.
- **C.** Append an empty tool result and send the conversation again.
- **D.** Keep iterating until the configured maximum count is reached.

<details>
<summary>Reveal answer</summary>

**A. Exit the loop and return the final response to the user.**

end_turn means Claude has completed its work, so the loop terminates and the final response goes to the user.

- **B:** No tool was requested; re-running one adds work the model never asked for.
- **C:** There is no pending tool call to answer, so another round trip produces nothing.
- **D:** Caps are a safety bound, not a reason to keep calling after the model has finished.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 6. Anti-pattern 1: parsing natural language completion phrases to end the loop

`claude-1-1-6`

An engineer proposes ending the loop when Claude's reply contains a phrase such as "task complete". Why does the lesson reject that?

- **A.** Claude never produces such phrases, so a loop checking for them would never end.
- **B.** Natural language is ambiguous: a finishing phrase may describe one step, not the task.
- **C.** Text blocks are stripped from the response before the application can read them.
- **D.** Those phrases appear only when a response was truncated by the max_tokens limit.

<details>
<summary>Reveal answer</summary>

**B. Natural language is ambiguous: a finishing phrase may describe one step, not the task.**

Natural language is ambiguous: Claude might announce finishing one file while intending to continue, so stop_reason is the authoritative signal.

- **A:** Claude can and does produce completion-sounding phrases; the problem is that they are ambiguous.
- **C:** Text blocks are returned normally; they simply are not a reliable completion signal.
- **D:** Completion phrases are unrelated to truncation and can appear in any response.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 7. Anti-pattern 2: iteration caps as the primary stopping mechanism; acceptable only as a saf

`claude-1-1-7`

Where does a maximum iteration count belong in a well-built agentic loop?

- **A.** As the primary termination check, replacing inspection of stop_reason entirely.
- **B.** As the remedy for an agent that keeps exiting before its work is finished.
- **C.** As a safety bound that logs a warning, with stop_reason still driving termination.
- **D.** As a per-tool limit that cancels any tool invoked more than once in a run.

<details>
<summary>Reveal answer</summary>

**C. As a safety bound that logs a warning, with stop_reason still driving termination.**

Iteration caps are acceptable only as a safety net against runaway agents; stop_reason remains the primary loop control.

- **A:** Caps as the primary mechanism either cut off useful work or run iterations that are not needed.
- **B:** Caps address runaway loops; premature exit is fixed by checking stop_reason correctly.
- **D:** Repeated calls to the same tool are often legitimate, and this is not what a cap does.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 8. Exam trap: forcing tool_choice to any prevents completion and creates an infinite loop

`claude-1-1-8`

To stop an agent from returning plain text, a developer sets tool_choice to "any" on every request. What goes wrong?

- **A.** The model can no longer read tool results from earlier iterations of the loop.
- **B.** The API stops returning a stop_reason field, so the loop loses its signal.
- **C.** Tool results are no longer appended automatically to the conversation history.
- **D.** The model must call a tool even when the task is done, so the loop never terminates.

<details>
<summary>Reveal answer</summary>

**D. The model must call a tool even when the task is done, so the loop never terminates.**

Forcing tool_choice to "any" means Claude cannot end its turn naturally, so the agent keeps calling tools after the work is complete.

- **A:** Forcing tool choice does not affect the model's access to prior tool results.
- **B:** stop_reason is still returned; the damage is that the model is never allowed to finish.
- **C:** Appending results is the application's job either way and is unaffected by tool_choice.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 9. stop_reason is the authoritative, deterministic signal for loop control

`claude-1-1-9`

A loop branches only on tool_use and end_turn, but the live API also returns values such as pause_turn and stop_sequence. Which rule keeps it safe?

- **A.** Treat any value other than end_turn as unfinished work and inspect why before continuing.
- **B.** Treat any value other than tool_use as a completed turn and return the text.
- **C.** Map every unrecognised value onto end_turn so the loop always terminates cleanly.
- **D.** Resend the identical request until one of the two familiar values comes back.

<details>
<summary>Reveal answer</summary>

**A. Treat any value other than end_turn as unfinished work and inspect why before continuing.**

Only end_turn means finished, so a production loop treats every other stop_reason as "not finished, check why" instead of assuming tool_use.

- **B:** This reports truncated, paused, or refused turns to the user as finished answers.
- **C:** Terminating on unknown values hides truncation and refusals behind an apparently normal answer.
- **D:** Blind retries burn tokens and never address the reason the turn stopped.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 10. Model-driven tool selection is favoured over fixed sequences, except where deterministic c

`claude-1-1-10`

An agent chooses its tools from the current context rather than following a developer-defined order. Which statement matches the lesson's position?

- **A.** Fixed tool sequences are preferred because a predetermined order is easier to audit and log.
- **B.** Model-driven selection is favoured for its adaptability, but deterministic compliance needs override it.
- **C.** Model-driven selection removes any need for programmatic enforcement in financial workflows.
- **D.** Model-driven selection applies only to the first call; later calls follow a fixed chain.

<details>
<summary>Reveal answer</summary>

**B. Model-driven selection is favoured for its adaptability, but deterministic compliance needs override it.**

Model-driven decision-making is preferred because it handles cases the developer never mapped, with programmatic enforcement taking over when compliance must be deterministic.

- **A:** The lesson favours model-driven selection; auditability does not outweigh its flexibility.
- **C:** High-stakes workflows still require code-level enforcement regardless of how the model selects tools.
- **D:** There is no such restriction; the model keeps choosing tools throughout the loop.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 11. Each loop iteration sends the conversation history: system prompt, prior messages and the 

`claude-1-1-11`

Each iteration of the loop sends a request to the Messages API. What must that request carry?

- **A.** Only the newest tool result, since the service retains the earlier turns for you.
- **B.** The tool definitions alone, because the model re-derives the task from the schemas.
- **C.** The conversation history: system prompt, prior messages, and the previous iteration's tool results.
- **D.** Only the original question, with the tool results condensed into a single sentence.

<details>
<summary>Reveal answer</summary>

**C. The conversation history: system prompt, prior messages, and the previous iteration's tool results.**

Every iteration sends the accumulated conversation history, including the system prompt, prior messages, and the tool results from the previous turn.

- **A:** The API is stateless for this purpose; omitting history strips the task and prior reasoning.
- **B:** Schemas describe capabilities, not the user's request or what has happened so far.
- **D:** Condensing away the actual results loses the detail the next decision depends on.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 12. The live Messages API returns further stop_reason values: pause_turn, max_tokens, stop_seq

`claude-1-1-12`

A request returns HTTP 200 with stop_reason set to refusal. How should the loop classify it?

- **A.** As a transport failure to retry with the identical payload.
- **B.** As a normal completion, because the HTTP status code was 200.
- **C.** As a tool_use turn whose tool block was omitted from the response body.
- **D.** As a turn that ended without doing the work, handled separately from end_turn.

<details>
<summary>Reveal answer</summary>

**D. As a turn that ended without doing the work, handled separately from end_turn.**

Refusal is its own stop_reason on a successful HTTP response: the turn ended without completing the task and needs handling separate from end_turn.

- **A:** Nothing failed in transport; resending the same request invites the same outcome.
- **B:** A 200 status says the call succeeded, not that the model produced the requested work.
- **C:** No tool was requested; treating it as a tool turn leaves the loop waiting for a call that does not exist.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 13. An agentic loop is deterministic control flow written in code, not a prompt trick, retry l

`claude-1-1-13`

Which description matches an agentic loop as the lesson defines it?

- **A.** Deterministic control flow in application code that drives repeated Messages API calls.
- **B.** A prompt pattern that asks Claude to keep working until it declares itself finished.
- **C.** A retry wrapper that resends failed requests using increasing backoff intervals.
- **D.** A chat feature that holds a single conversation turn open for a longer period.

<details>
<summary>Reveal answer</summary>

**A. Deterministic control flow in application code that drives repeated Messages API calls.**

An agentic loop is deterministic control flow defined in code, not a prompt trick, a retry wrapper, or a chatbot turn.

- **B:** Relying on the model to announce completion in prose is the natural-language anti-pattern.
- **C:** Retrying failures is error handling, not the execution cycle behind an agent.
- **D:** The loop spans many request and response cycles rather than extending one turn.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 14. Tool results must be appended to conversation history and linked to the tool-use ID

`claude-1-1-14`

After executing a tool Claude requested, how does the application add the outcome to the conversation?

- **A.** Replace the assistant's tool_use block with the raw output before resending the history.
- **B.** Append the assistant's response, then a user message carrying the tool_result for that call.
- **C.** Append the output as a system message placed ahead of the original instructions.
- **D.** Store the output in the tool definition so the model reads it on the next call.

<details>
<summary>Reveal answer</summary>

**B. Append the assistant's response, then a user message carrying the tool_result for that call.**

The assistant response is appended, followed by a user message containing the tool_result, so Claude sees both the call and its outcome.

- **A:** Overwriting the request loses the call the result answers and corrupts the history.
- **C:** Tool results are not system instructions and do not belong at the front of the conversation.
- **D:** Tool definitions describe inputs and behaviour; they are not a channel for results.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-1-agentic-loops) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

## 1.2 — Multi-Agent Orchestration

### 15. Hub-and-spoke with a coordinator at the centre is the orchestration pattern the exam tests

`claude-1-2`

Three independent analyses must feed a single report. Which design permits parallel work while keeping ownership of the final result clear?

- **A.** Let workers continually delegate the complete task among themselves.
- **B.** Run specialist workers concurrently and have a coordinator reconcile their findings.
- **C.** Run the analyses sequentially because there is one final report.
- **D.** Let each worker publish its own final report as the combined answer.

<details>
<summary>Reveal answer</summary>

**B. Run specialist workers concurrently and have a coordinator reconcile their findings.**

The coordinator owns synthesis while independent work can overlap.

- **A:** Unbounded delegation obscures ownership and creates unnecessary coordination.
- **C:** A shared output does not make the analyses depend on each other.
- **D:** Separate reports do not resolve inconsistent findings or missing coverage.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 16. Dependent work

`claude-1-2-2`

An analyst needs the researcher's evidence before drawing conclusions. What should the coordinator do?

- **A.** Remove the researcher and keep the dependency unchanged.
- **B.** Obtain the evidence, then pass it into the analysis task.
- **C.** Start both with no evidence exchange.
- **D.** Ask the analyst to invent likely research findings.

<details>
<summary>Reveal answer</summary>

**B. Obtain the evidence, then pass it into the analysis task.**

A data dependency must be satisfied even when other work can run concurrently.

- **A:** Deleting a worker does not supply the missing facts.
- **C:** The analyst would lack its required input.
- **D:** Guessed evidence cannot replace the upstream result.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 17. Routing

`claude-1-2-3`

A user asks a simple question already supported by available context. Must every specialist run?

- **A.** Yes; the agent with the longest prompt must run first.
- **B.** No; multi-agent systems cannot answer simple questions.
- **C.** No; invoke only the work needed for this request.
- **D.** Yes; every request must use the complete agent roster.

<details>
<summary>Reveal answer</summary>

**C. No; invoke only the work needed for this request.**

Unnecessary delegation adds cost and failure paths without supplying missing evidence.

- **A:** Prompt length does not determine task relevance.
- **B:** The architecture can still handle simple requests directly.
- **D:** A fixed roster can waste work on irrelevant stages.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 18. Conflicting findings

`claude-1-2-4`

Two workers give incompatible recommendations. What is the coordinator's strongest next action?

- **A.** Choose whichever worker answered first.
- **B.** Combine both recommendations without mentioning the conflict.
- **C.** Ask each worker to repeat its conclusion unchanged.
- **D.** Compare assumptions and supporting evidence before resolving or reporting disagreement.

<details>
<summary>Reveal answer</summary>

**D. Compare assumptions and supporting evidence before resolving or reporting disagreement.**

Different premises or evidence quality can explain the conflict.

- **A:** Response speed is not a correctness criterion.
- **B:** That conceals a decision the evidence has not resolved.
- **C:** Repetition supplies no new basis for resolution.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 19. Cardinal rule: subagents never communicate directly with each other

`claude-1-2-5`

A team proposes letting the search subagent hand its output straight to the synthesis subagent to save a coordinator round trip. What does hub-and-spoke require?

- **A.** Allow it whenever both subagents were given the same tool restrictions.
- **B.** Allow it while the coordinator is busy aggregating other subagents' results.
- **C.** Reject it; every message moving between subagents passes through the coordinator.
- **D.** Reject it only when the two subagents run with different system prompts.

<details>
<summary>Reveal answer</summary>

**C. Reject it; every message moving between subagents passes through the coordinator.**

All inter-subagent communication flows through the coordinator; direct subagent-to-subagent messaging is never the right answer here.

- **A:** Matching tool access does not change the routing rule; the coordinator still owns every exchange.
- **B:** Convenience is exactly the justification the pattern rejects for bypassing the hub.
- **D:** The rule is unconditional rather than dependent on how the subagents are configured.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 20. Centralised routing delivers observability, consistent error handling and controlled infor

`claude-1-2-6`

Why does hub-and-spoke orchestration insist that every message pass through the coordinator?

- **A.** It concentrates observability, consistent error handling, and controlled information flow in one place.
- **B.** It lets subagents share a memory store that survives between their invocations.
- **C.** It removes the need for decomposition because subagents negotiate scope among themselves.
- **D.** It guarantees every subagent inherits the coordinator's system prompt automatically.

<details>
<summary>Reveal answer</summary>

**A. It concentrates observability, consistent error handling, and controlled information flow in one place.**

Routing everything through the coordinator gives one point for observability, one error-handling policy, and deliberate control over what each subagent sees.

- **B:** No shared store exists; subagent invocations are independent of one another.
- **C:** Decomposition is the coordinator's job, and subagents negotiating scope would mean direct communication.
- **D:** Nothing is inherited automatically; context must be written into each subagent's prompt.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 21. Subagents do not inherit the coordinator's conversation history, system prompt or other su

`claude-1-2-7`

A coordinator spawns a synthesis subagent after two research subagents finish. What context does the synthesis subagent begin with?

- **A.** The coordinator's full conversation history, including both research subagents' outputs.
- **B.** The coordinator's system prompt plus every tool result produced earlier in the run.
- **C.** A shared workspace holding whatever findings the other subagents have written so far.
- **D.** Only the information the coordinator explicitly wrote into its prompt for this invocation.

<details>
<summary>Reveal answer</summary>

**D. Only the information the coordinator explicitly wrote into its prompt for this invocation.**

Subagent context is isolated: the synthesis agent sees only what the coordinator deliberately placed in its prompt.

- **A:** Subagents inherit no conversation history from the coordinator.
- **B:** The coordinator's system prompt is not inherited, and prior tool results are not visible.
- **C:** There is no shared memory or global state between agents in this architecture.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 22. There is no shared memory or global state between agents

`claude-1-2-8`

A coordinator invokes the same web search subagent twice during one workflow. What does the second invocation know about the first?

- **A.** Everything, because each subagent role keeps a memory that persists across invocations.
- **B.** Nothing, unless the coordinator restates the earlier results inside the second prompt.
- **C.** Its earlier queries only, which the runtime caches to prevent duplicate searches.
- **D.** Its earlier results only, which are appended automatically to the new context.

<details>
<summary>Reveal answer</summary>

**B. Nothing, unless the coordinator restates the earlier results inside the second prompt.**

Every subagent invocation is independent, so the second call knows nothing of the first unless the coordinator repeats that information in the prompt.

- **A:** Subagents do not share memory between invocations; every call starts clean.
- **C:** No query cache carries forward between invocations.
- **D:** Nothing is appended automatically; the coordinator must supply it.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 23. Trace failures to their origin: check the coordinator's input before blaming the subagent 

`claude-1-2-9`

A multi-agent system delivers a market report covering two of the company's six product lines. Every subagent handled its assignment thoroughly. Where is the defect?

- **A.** In the coordinator's decomposition, which never assigned the other four product lines.
- **B.** In the search subagent's queries, which were worded too narrowly to surface the rest.
- **C.** In the synthesis subagent, which dropped sections it could not attribute to a source.
- **D.** In the document analysis subagent, which had no access to the missing material.

<details>
<summary>Reveal answer</summary>

**A. In the coordinator's decomposition, which never assigned the other four product lines.**

Output that is incomplete in scope traces to the coordinator's task decomposition, not to the subagents that executed their assignments.

- **B:** The search agent covered what it was given; it was never asked about the missing lines.
- **C:** Synthesis combined everything it received; the missing material never reached it.
- **D:** Access was not the constraint; no agent was assigned those product lines at all.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 24. Adding more subagents does not fix narrow decomposition; they receive equally narrow assig

`claude-1-2-10`

A coordinator consistently splits topics too narrowly. Does adding more subagents close the coverage gap?

- **A.** Yes, because extra capacity lets the system reach subtopics nobody assigned.
- **B.** Yes, because each additional subagent widens its own scope when it finds a gap.
- **C.** No, because additional subagents simply receive equally narrow assignments.
- **D.** No, because the correct fix is to let the subagents compare coverage with each other.

<details>
<summary>Reveal answer</summary>

**C. No, because additional subagents simply receive equally narrow assignments.**

More subagents receive equally narrow assignments; the fix is improving the coordinator's decomposition logic.

- **A:** Unassigned subtopics stay unassigned no matter how many agents are available.
- **B:** Subagents work within the assignment they are given; they do not expand it.
- **D:** Subagents comparing notes would be direct communication, which the pattern forbids.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 25. Research scope partitioning assigns distinct subtopics or source types to minimise duplica

`claude-1-2-11`

A coordinator delegates one broad research question to four subagents. How should it assign the work?

- **A.** Send all four the same question and keep whichever answer arrives first.
- **B.** Send all four the same question and merge the four answers into the report.
- **C.** Send each a different phrasing of the same question to improve overall recall.
- **D.** Give each a distinct subtopic or source type so their searches do not overlap.

<details>
<summary>Reveal answer</summary>

**D. Give each a distinct subtopic or source type so their searches do not overlap.**

The coordinator partitions research scope, assigning distinct subtopics or source types so subagents do not cover the same ground.

- **A:** Four identical searches duplicate effort and still leave the topic partly uncovered.
- **B:** Merging duplicate coverage wastes capacity that distinct subtopics would have used.
- **C:** Rewording the same question still points every agent at the same ground.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 26. Iterative refinement: evaluate synthesis for gaps, re-delegate targeted queries, re-invoke

`claude-1-2-12`

Reviewing a synthesis draft, the coordinator finds two subtopics thinly covered. What does the lesson expect next?

- **A.** Re-delegate targeted queries for the thin subtopics, then re-invoke synthesis.
- **B.** Publish the draft and record the thin coverage in a caveat at the end.
- **C.** Ask the synthesis subagent to expand those sections from what it already holds.
- **D.** Spawn a second synthesis subagent to rewrite the draft more thoroughly.

<details>
<summary>Reveal answer</summary>

**A. Re-delegate targeted queries for the thin subtopics, then re-invoke synthesis.**

Coordination is iterative: the coordinator detects gaps, re-delegates targeted research, and re-runs synthesis until coverage is adequate.

- **B:** Documenting a gap is not the same as closing it, and the coordinator can still act.
- **C:** Synthesis cannot add coverage it was never given; new research has to be delegated.
- **D:** A second writer faces the same missing input as the first.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 27. Trace failures to their origin: check the coordinator's input before blaming the subagent 

`claude-1-2-13`

A combined report treats each topic it covers in depth but omits whole categories. Which diagnostic does the lesson prescribe?

- **A.** Missing scope usually means the subagents exhausted their token budgets early.
- **B.** Missing scope points at the coordinator's decomposition rather than at any subagent.
- **C.** Missing scope points at the synthesis step that assembled the finished sections.
- **D.** Missing scope means the subagents' tool restrictions were configured too tightly.

<details>
<summary>Reveal answer</summary>

**B. Missing scope points at the coordinator's decomposition rather than at any subagent.**

When output is incomplete in scope rather than depth, the coordinator's decomposition is almost always the root cause.

- **A:** Budget exhaustion would shorten depth within assigned topics, not remove categories entirely.
- **C:** Synthesis works from what it receives, so absent categories were absent upstream.
- **D:** Tool restrictions would limit how an assigned topic is researched, not which topics exist.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 28. Hub-and-spoke with a coordinator at the centre is the orchestration pattern the exam tests

`claude-1-2-14`

Which responsibility belongs to the coordinator rather than to a subagent?

- **A.** Performing the specialised retrieval or analysis for one assigned subtopic.
- **B.** Choosing the exact query wording for its own assigned source type.
- **C.** Deciding which specialists to invoke and aggregating what they return.
- **D.** Returning finished results to whichever agent most recently requested them.

<details>
<summary>Reveal answer</summary>

**C. Deciding which specialists to invoke and aggregating what they return.**

The coordinator decomposes the task, selects and invokes subagents, passes context, and aggregates results; subagents execute their assigned specialty.

- **A:** That is precisely the spoke's job, not the hub's.
- **B:** A subagent works out its own method within the goal it was handed.
- **D:** Results always go back to the coordinator, and subagents do not request work from each other.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-2-orchestration-patterns) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

## 1.3 — Subagent Invocation and Context Passing

### 29. Subagent context is isolated: only what the coordinator writes into the prompt is availabl

`claude-1-3`

A fresh subagent must investigate one failing test. Which handoff is most useful?

- **A.** Send the full repository as text before stating the task.
- **B.** Pass the parent's conclusion and require the worker to confirm it.
- **C.** Provide the failure, relevant files, constraints and expected result format.
- **D.** Pass only the worker's role name and assume it knows the failure.

<details>
<summary>Reveal answer</summary>

**C. Provide the failure, relevant files, constraints and expected result format.**

A focused handoff supplies the information needed to perform and report the task.

- **A:** An indiscriminate dump adds noise without defining the investigation.
- **B:** This encourages confirmation rather than independent examination.
- **D:** A role label does not communicate the current task evidence.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 30. Approval versus availability

`claude-1-3-2`

In the current Agent SDK, what does allowedTools primarily configure?

- **A.** Tools that can run without individual approval prompts.
- **B.** The only tool names that can exist in the session.
- **C.** The text of the subagent's system instructions.
- **D.** A guarantee that the model will invoke each listed tool.

<details>
<summary>Reveal answer</summary>

**A. Tools that can run without individual approval prompts.**

Auto-approval is distinct from defining the complete available tool set.

- **B:** Availability and approval are separate configuration concerns.
- **C:** Tool approval does not define the agent's role prompt.
- **D:** Permission to call a tool does not require a call.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/permissions)

### 31. Evidence handoff

`claude-1-3-3`

A researcher sends facts to a synthesis worker. Which handoff preserves traceability?

- **A.** A count of sources with no content.
- **B.** Claims paired with source identifiers and supporting excerpts.
- **C.** Claims stripped of metadata to save a few tokens.
- **D.** Source titles with no associated findings.

<details>
<summary>Reveal answer</summary>

**B. Claims paired with source identifiers and supporting excerpts.**

Attribution requires evidence associations to survive the handoff.

- **A:** A source count supplies neither findings nor evidence.
- **C:** The synthesizer would lose the ability to attribute them.
- **D:** Titles alone do not identify which claims are supported.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 32. Task contract

`claude-1-3-4`

Which instruction gives a specialist a useful bounded assignment?

- **A.** Require agreement with the coordinator's unverified guess.
- **B.** Ask it to improve everything it can find.
- **C.** State the outcome, scope, constraints and required evidence.
- **D.** Provide a role name with no current objective.

<details>
<summary>Reveal answer</summary>

**C. State the outcome, scope, constraints and required evidence.**

A task contract defines success without assuming undisclosed context.

- **A:** That turns investigation into confirmation.
- **B:** Unbounded scope obscures completion and ownership.
- **D:** A role is not a concrete task.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 33. The Task tool spawns subagents; current Claude Code renamed it Agent and keeps Task as an 

`claude-1-3-5`

Which name does the exam guide give the subagent-spawning mechanism, and what does current Claude Code call it?

- **A.** The Spawn tool; current Claude Code renamed it Task and retired the original name.
- **B.** The Agent tool; the exam guide itself offers no separate name for the mechanism.
- **C.** The Task tool; current Claude Code removed it in favour of MCP subagent servers.
- **D.** The Task tool; current Claude Code renamed it Agent and still accepts Task as an alias.

<details>
<summary>Reveal answer</summary>

**D. The Task tool; current Claude Code renamed it Agent and still accepts Task as an alias.**

The exam guide calls it the Task tool; current Claude Code renamed it Agent while keeping Task as a working alias.

- **A:** There is no Spawn tool; the guide's name is Task.
- **B:** The guide names it the Task tool; Agent is the newer product name.
- **C:** The mechanism was renamed, not removed, and MCP servers are a separate concern.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 34. The coordinator's allowedTools must include Task or Agent, or it cannot spawn subagents at

`claude-1-3-6`

A coordinator with file and search tools configured never manages to start a single subagent. What is the most likely cause?

- **A.** Task, or Agent under its current name, is missing from the coordinator's allowedTools.
- **B.** The subagent definitions omit the description field the coordinator reads.
- **C.** The coordinator's system prompt never mentions delegation as part of its role.
- **D.** The subagents' tool restrictions exclude the tools the coordinator itself holds.

<details>
<summary>Reveal answer</summary>

**A. Task, or Agent under its current name, is missing from the coordinator's allowedTools.**

The coordinator's allowedTools must include Task, or Agent under its current name, or it has no mechanism to invoke subagents.

- **B:** A missing description weakens selection but does not make spawning impossible.
- **C:** Prompt wording influences behaviour but is not the gate on the spawning mechanism.
- **D:** Subagent tool scoping affects what they can do once running, not whether they start.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 35. An AgentDefinition specifies a description, a system prompt and tool restrictions

`claude-1-3-7`

What does an AgentDefinition specify for a subagent?

- **A.** A description, a token budget, and the model version the subagent must run on.
- **B.** A description, a system prompt, and the tools the subagent is allowed to use.
- **C.** A system prompt, a retry policy, and the coordinator that the subagent reports to.
- **D.** A name, a session identifier, and the conversation history the subagent inherits.

<details>
<summary>Reveal answer</summary>

**B. A description, a system prompt, and the tools the subagent is allowed to use.**

An AgentDefinition carries a description used for selection, a system prompt, and the tool restrictions scoped to the subagent's role.

- **A:** Budget and model pinning are not the three fields the definition covers.
- **C:** Retry policy and reporting target are not part of the definition.
- **D:** Subagents inherit no conversation history, so no such field exists.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 36. Attribution failure root cause: the coordinator passed content without source metadata

`claude-1-3-8`

A synthesis subagent returns a polished report with no citations, although both research subagents returned properly sourced output. What is the root cause?

- **A.** The synthesis subagent needs direct search-tool access so it can verify sources itself.
- **B.** The synthesis subagent's system prompt omits an instruction to cite its sources.
- **C.** The coordinator forwarded the claim text without the accompanying source metadata.
- **D.** The research subagents used an output format the synthesis agent cannot parse.

<details>
<summary>Reveal answer</summary>

**C. The coordinator forwarded the claim text without the accompanying source metadata.**

The synthesis agent can only cite what it receives; passing content without structured metadata is what removes the attribution.

- **A:** Giving it tools works around the real problem instead of fixing the handoff.
- **B:** No instruction can make it cite sources it was never given.
- **D:** Both upstream agents are verified as returning correct, well-formed results.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 37. Rule 2: use structured formats that separate content from metadata while passing both

`claude-1-3-9`

Which record shape lets a downstream agent attribute every claim it receives?

- **A.** The claim paired with a running count of how many documents were searched.
- **B.** A list of source URLs kept separate from the claims to keep payloads small.
- **C.** The claim rewritten to mention its origin in prose, with metadata fields removed.
- **D.** The claim together with source URL, document name, page number, and confidence.

<details>
<summary>Reveal answer</summary>

**D. The claim together with source URL, document name, page number, and confidence.**

Inter-agent findings should separate content from metadata while passing both, so each claim arrives with its source URL, document name, page number, and confidence.

- **A:** A count says nothing about where any individual claim came from.
- **B:** Separating them breaks the link between each claim and its origin.
- **C:** Prose mentions are not structured metadata and are easily lost in summarisation.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 38. Parallel spawning: emit multiple Task tool calls in a single coordinator response to cut l

`claude-1-3-10`

A coordinator needs a web search and an unrelated document analysis, neither depending on the other. How should it invoke them?

- **A.** Emit both Task tool calls in a single response so the two run at the same time.
- **B.** Invoke the search first and feed its output into the document analysis call.
- **C.** Invoke them in separate turns so each result is logged before the next starts.
- **D.** Invoke the search twice and let the second call cover the documents as well.

<details>
<summary>Reveal answer</summary>

**A. Emit both Task tool calls in a single response so the two run at the same time.**

Independent subagents should be spawned in parallel by emitting multiple Task tool calls in one coordinator response, which removes the latency of sequential turns.

- **B:** Manufacturing a dependency that does not exist serialises work for no benefit.
- **C:** Sequential turns add latency, and logging happens at the coordinator either way.
- **D:** A search agent is not scoped to document analysis, and the duplicate call wastes a turn.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 39. Rule 3: coordinator prompts specify goals and quality criteria, not step-by-step procedure

`claude-1-3-11`

How should a coordinator word a subagent's assignment?

- **A.** Spell out each step in order so the subagent cannot improvise its own approach.
- **B.** State the outcome and the quality criteria, leaving the method to the subagent.
- **C.** State only the role name and let the subagent infer the goal from its description.
- **D.** State the conclusion the coordinator expects so the subagent can confirm it.

<details>
<summary>Reveal answer</summary>

**B. State the outcome and the quality criteria, leaving the method to the subagent.**

Coordinator prompts should specify goals and quality criteria rather than procedures, which keeps subagents able to adapt their approach.

- **A:** Procedural instructions constrain the subagent and stop it adapting to what it finds.
- **C:** A role without a current objective gives the subagent nothing concrete to deliver.
- **D:** Handing over a conclusion invites confirmation rather than investigation.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 40. fork_session creates independent branches from a shared analysis baseline that cannot see 

`claude-1-3-12`

After an initial codebase analysis, you want to compare two refactoring strategies from that same starting point. Which session control fits?

- **A.** Resume the session twice so both strategies append to the same conversation.
- **B.** Resume the session and explore both strategies inside one continuing thread.
- **C.** Fork the session once per strategy so each explores from a copy of the analysis.
- **D.** Start two fresh sessions and re-read the whole codebase separately in each one.

<details>
<summary>Reveal answer</summary>

**C. Fork the session once per strategy so each explores from a copy of the analysis.**

Fork creates independent branches from a shared analysis baseline, which is the right control when comparing divergent approaches.

- **A:** Appending both strategies to one history mixes them instead of isolating each line of work.
- **B:** Continuation is what resume is for; this scenario calls for independent branches.
- **D:** Discarding the completed analysis repeats work the fork would have preserved.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 41. fork versus resume: branch for divergent exploration, resume to continue the same line of 

`claude-1-3-13`

In the current Agent SDK, how is fork_session actually used?

- **A.** Instead of resume: fork_session itself names the session to branch from.
- **B.** Only when a session is first created, marking it as branchable later on.
- **C.** Only on the command line, since the SDK exposes no equivalent behaviour.
- **D.** Alongside resume: resume names the session and fork_session branches from it.

<details>
<summary>Reveal answer</summary>

**D. Alongside resume: resume names the session and fork_session branches from it.**

Fork is a modifier on resume: resume names the session to start from, and fork_session makes the run branch off instead of appending.

- **A:** fork_session is a modifier and carries no session identifier of its own.
- **B:** It is not a creation-time flag; it applies when starting from an existing session.
- **C:** The SDK exposes it as an option, and the CLI has a matching flag.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 42. Subagent context is isolated: only what the coordinator writes into the prompt is availabl

`claude-1-3-14`

A synthesis subagent must work from the output of two earlier agents. What does the coordinator pass into its prompt?

- **A.** Both agents' findings in full, written into the synthesis subagent's prompt.
- **B.** A pointer to where both agents' findings were stored during this run.
- **C.** The shorter output in full, with the longer one reduced to a single line.
- **D.** Neither, since the synthesis subagent can request them from the other agents.

<details>
<summary>Reveal answer</summary>

**A. Both agents' findings in full, written into the synthesis subagent's prompt.**

Prior agents' findings must be passed in full inside the synthesis subagent's prompt, because it has no way to retrieve them itself.

- **B:** There is no shared store the subagent can follow a pointer into.
- **C:** Compressing one agent's work discards the detail synthesis depends on.
- **D:** Subagents never communicate directly, so it cannot request anything from its peers.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-3-subagent-invocation-context) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

## 1.4 — Workflow Enforcement and Handoff

### 43. Prompt-based guidance is probabilistic (roughly 90-95%); programmatic enforcement is deter

`claude-1-4`

A deployment tool must reject requests unless required checks have passed. Where should that prerequisite be enforced?

- **A.** Only in the assistant's instruction to remember the checks.
- **B.** In a review message produced after the deployment finishes.
- **C.** By asking the model for a confidence score before deployment.
- **D.** In application logic that validates the prerequisite before executing deployment.

<details>
<summary>Reveal answer</summary>

**D. In application logic that validates the prerequisite before executing deployment.**

The executable boundary must check the state that authorizes the action.

- **A:** Prompt guidance does not establish an execution gate.
- **B:** Post-action feedback cannot prevent the deployment.
- **C:** Confidence is not evidence that required checks passed.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 44. Missing prerequisite

`claude-1-4-2`

A sensitive tool receives no trustworthy proof that its prerequisite passed. What should the execution gate do?

- **A.** Accept the model's statement that it probably passed.
- **B.** Execute first and collect the proof afterward.
- **C.** Treat missing state as an earlier successful check.
- **D.** Decline execution until the prerequisite is established.

<details>
<summary>Reveal answer</summary>

**D. Decline execution until the prerequisite is established.**

Absence of evidence must not silently become authorization.

- **A:** A generated assertion is not verified state.
- **B:** That reverses the required dependency.
- **C:** Missing data does not establish a successful check.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/permissions)

### 45. Changed approval

`claude-1-4-3`

A human approved one operation, but its target changes before execution. What is required?

- **A.** Validate the new proposal and obtain any required approval for it.
- **B.** Reuse approval because the tool name is unchanged.
- **C.** Execute both targets to preserve the original intent.
- **D.** Record the change only after the operation succeeds.

<details>
<summary>Reveal answer</summary>

**A. Validate the new proposal and obtain any required approval for it.**

Approval is tied to the reviewed action, not arbitrary future variants.

- **B:** The target is part of the operation's meaning.
- **C:** That introduces an extra unapproved effect.
- **D:** An audit record cannot replace a required precondition.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/permissions)

### 46. Handoff evidence

`claude-1-4-4`

A workflow says it transferred a case, but the handoff API failed. What should it report?

- **A.** Transfer completed after writing a local summary.
- **B.** The handoff failed, with a supported recovery path.
- **C.** Transfer completed because the assistant announced it.
- **D.** Case resolved because the automated portion ended.

<details>
<summary>Reveal answer</summary>

**B. The handoff failed, with a supported recovery path.**

User-visible status must match the actual operation outcome.

- **A:** Preparing context is not delivering the handoff.
- **C:** An announcement is not a successful API result.
- **D:** Ending automation does not resolve the user's case.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/permissions)

### 47. Prompt-based guidance is probabilistic (roughly 90-95%); programmatic enforcement is deter

`claude-1-4-5`

An agent issues account credits without confirming ownership in about 7% of cases, although the system prompt requires the check. Which fix does the lesson call correct?

- **A.** Rewrite the system prompt so the verification requirement is stated more forcefully.
- **B.** Add a code-level gate that blocks the credit tool until verification has returned a result.
- **C.** Supply few-shot examples that show verification performed before every credit issued.
- **D.** Add a routing classifier that sends credit requests into a verification-first pipeline.

<details>
<summary>Reveal answer</summary>

**B. Add a code-level gate that blocks the credit tool until verification has returned a result.**

Money movement needs deterministic guarantees, so a prerequisite gate in code is the fix rather than any prompt-side improvement.

- **A:** A stronger prompt lowers the failure rate but never reaches zero, which a financial operation needs.
- **C:** Examples shift probabilities; they cannot guarantee the ordering a money movement requires.
- **D:** Classifiers decide which agent handles a request, not the tool order inside that agent's run.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 48. Financial operations such as refunds and transfers require programmatic enforcement

`claude-1-4-6`

Which requirement is the lesson willing to leave to prompt-based guidance?

- **A.** Cross-border transfers must pass an anti-money-laundering check before executing.
- **B.** Refunds must be preceded by a verified customer identity within the session.
- **C.** Responses should follow the team's preferred formatting and section ordering.
- **D.** Administrative endpoints must be reached only after an authorisation check.

<details>
<summary>Reveal answer</summary>

**C. Responses should follow the team's preferred formatting and section ordering.**

Formatting and style preferences are low-stakes, so prompt guidance is acceptable; money, security, and compliance require programmatic enforcement.

- **A:** A single missed compliance check can bring legal penalties, so this needs enforcement in code.
- **B:** A refund on the wrong account is a financial loss, which prompts cannot reliably prevent.
- **D:** Bypassing authorisation is a security breach and belongs behind a programmatic gate.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 49. Routing classifiers decide which agent handles a request and cannot enforce ordering insid

`claude-1-4-7`

Why does the lesson reject a routing classifier as the fix for a per-agent compliance failure?

- **A.** Classifiers cannot be trained on enough labelled compliance examples to be accurate.
- **B.** Classifiers add latency that pushes long compliance workflows past their timeouts.
- **C.** Classifiers run after the tool call, so the non-compliant action has already happened.
- **D.** Classifiers pick which agent handles a request; the failure sits inside that agent's run.

<details>
<summary>Reveal answer</summary>

**D. Classifiers pick which agent handles a request; the failure sits inside that agent's run.**

A routing classifier only picks which agent handles a request; the compliance failure happens within the agent's execution sequence.

- **A:** Accuracy of the classifier is not the issue; it operates at the wrong layer entirely.
- **B:** Latency is not the objection raised against this distractor.
- **C:** Classifiers run before routing, not after tool execution; that timing argument belongs to post-execution hooks.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 50. Required handoff fields: customer ID, conversation summary, root cause analysis, refund am

`claude-1-4-8`

Which set of fields does the lesson require in a structured escalation summary?

- **A.** Customer ID, conversation summary, root cause, refund amount, and recommended action.
- **B.** Customer ID, transcript link, agent name, session duration, and sentiment score.
- **C.** Conversation summary, tool call log, model version, latency, and retry count.
- **D.** Customer ID, recommended action, and a pointer to the conversation for the details.

<details>
<summary>Reveal answer</summary>

**A. Customer ID, conversation summary, root cause, refund amount, and recommended action.**

A handoff summary must carry customer ID, conversation summary, root cause analysis, refund amount where applicable, and recommended action.

- **B:** A transcript link is no help when the human agent has no transcript access, and the operational metrics do not resolve the case.
- **C:** Engineering telemetry does not tell the human who the customer is or what to do next.
- **D:** Omitting the summary, root cause, and amount forces the customer to repeat everything.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 51. Human agents receiving an escalation cannot read the conversation transcript, so the summa

`claude-1-4-9`

Why must an escalation summary be self-contained?

- **A.** The transcript is deleted as soon as the escalation ticket is opened.
- **B.** The receiving human agent cannot read the conversation transcript at all.
- **C.** The summary replaces the customer's record in the support system entirely.
- **D.** The receiving agent reads only the first line of any escalation note.

<details>
<summary>Reveal answer</summary>

**B. The receiving human agent cannot read the conversation transcript at all.**

Human agents receive only the handoff summary, so an incomplete one forces the customer to repeat everything.

- **A:** Deletion is not the reason; the human agent simply never has transcript access.
- **C:** A handoff note does not overwrite account records.
- **D:** No such limit exists; the issue is access to the conversation, not attention.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 52. Multi-concern requests are decomposed, investigated in parallel on shared context and answ

`claude-1-4-10`

A customer's single message raises a return, an address change, and a loyalty points question. What does the lesson prescribe?

- **A.** Handle the first item now and ask the customer to raise the others separately.
- **B.** Open three separate conversations so each item gets its own isolated context.
- **C.** Split the message into three items, investigate them together on shared context, and answer once.
- **D.** Escalate the entire message to a human because compound requests exceed agent scope.

<details>
<summary>Reveal answer</summary>

**C. Split the message into three items, investigate them together on shared context, and answer once.**

Compound requests are decomposed into distinct items, investigated in parallel using shared context, and answered in one unified resolution.

- **A:** Addressing only the first item and dropping the rest is the failure mode the lesson names.
- **B:** Sequential separate conversations discard the shared account context and burden the customer.
- **D:** Compound requests are within scope; they simply need decomposing.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 53. SubagentStart is observational: it receives type and id and cannot block the spawn or inje

`claude-1-4-11`

What can a SubagentStart hook do when a subagent is spawned?

- **A.** Block the spawn whenever the coordinator omitted context the subagent needs.
- **B.** Rewrite the subagent's prompt before the subagent begins running.
- **C.** Attach additional tools to the subagent for the duration of that run.
- **D.** Observe and log the spawn, including the subagent's type and id.

<details>
<summary>Reveal answer</summary>

**D. Observe and log the spawn, including the subagent's type and id.**

SubagentStart is observational, receiving the subagent's type and id; it cannot block the spawn or inject context into the run.

- **A:** Its documented output fields cannot deny the invocation.
- **B:** It cannot inject context into the subagent's run.
- **C:** The event is observational and does not reconfigure the subagent.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 54. Enforcement on spawning uses a PreToolUse hook attached to the Agent tool, which can deny 

`claude-1-4-12`

You need to deny subagent spawns that arrive without required context. Which mechanism does that?

- **A.** A PreToolUse hook on the Agent tool, which can deny or rewrite the invocation.
- **B.** A SubagentStart hook, which inspects the spawn just before the subagent runs.
- **C.** A SubagentStop hook, which validates the invocation once results come back.
- **D.** A PostToolUse hook on the Agent tool, which screens the spawn afterwards.

<details>
<summary>Reveal answer</summary>

**A. A PreToolUse hook on the Agent tool, which can deny or rewrite the invocation.**

Enforcing rules on spawning itself requires a PreToolUse hook attached to the Agent tool, which can deny or rewrite the invocation before the subagent starts.

- **B:** SubagentStart cannot block the invocation; its output fields do not include a decision.
- **C:** By then the subagent has already done the work with the wrong context.
- **D:** Post-execution screening cannot prevent a spawn that has already happened.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 55. SubagentStop fires on subagent completion, receiving the id and final message for validati

`claude-1-4-13`

A SubagentStop hook finds that the subagent's output does not match the expected schema. What does exiting with code 2 achieve?

- **A.** It discards the output and returns an empty result to the coordinator.
- **B.** It prevents the subagent from stopping and sends it back to keep working.
- **C.** It rewrites the output into the expected schema before the coordinator sees it.
- **D.** It ends the whole session so the coordinator can restart the workflow cleanly.

<details>
<summary>Reveal answer</summary>

**B. It prevents the subagent from stopping and sends it back to keep working.**

SubagentStop blocks completion by exiting with code 2, which returns the subagent to work rather than letting it finish.

- **A:** Nothing is discarded; the subagent is sent back to continue.
- **C:** SubagentStop does not transform the returned output.
- **D:** The block is scoped to the subagent's completion, not the session.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 56. Stop hooks defined in subagent frontmatter auto-convert to SubagentStop events

`claude-1-4-14`

A subagent's frontmatter defines a Stop hook. What happens to it?

- **A.** It is ignored, because Stop is valid only in the coordinator's configuration.
- **B.** It fires when the coordinator's own turn ends rather than the subagent's.
- **C.** It is converted automatically into a SubagentStop event for that subagent.
- **D.** It is rejected when the definition loads and the subagent fails to start.

<details>
<summary>Reveal answer</summary>

**C. It is converted automatically into a SubagentStop event for that subagent.**

Stop hooks declared in a subagent's frontmatter are automatically converted to SubagentStop, the event that fires when that subagent completes.

- **A:** Subagents may define hooks in their own frontmatter, including Stop.
- **B:** Subagent-scoped hooks are bound to that subagent's lifetime.
- **D:** Nothing is rejected; the event is simply mapped to the subagent equivalent.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 57. Subagent frontmatter hooks are scoped to that subagent's own lifetime and tool calls

`claude-1-4-15`

A billing subagent declares a PreToolUse hook in its own frontmatter. Which tool calls does that hook intercept?

- **A.** Every tool call in the session, including calls the coordinator makes itself.
- **B.** Tool calls made by any subagent the coordinator spawns after that point.
- **C.** Only calls the coordinator makes on the billing subagent's behalf.
- **D.** Only the tool calls made by that billing subagent during its own run.

<details>
<summary>Reveal answer</summary>

**D. Only the tool calls made by that billing subagent during its own run.**

Hooks declared in a subagent's frontmatter are scoped to that component's lifetime and intercept only its own tool calls.

- **A:** Component-scoped hooks do not reach the coordinator's own calls.
- **B:** Other subagents run under their own configuration, not the billing agent's.
- **C:** The coordinator's calls are outside the subagent's scope entirely.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 58. Decision rule: a single failure causing financial loss, security breach or compliance viol

`claude-1-4-16`

Which question does the lesson use to choose between prompt guidance and programmatic enforcement?

- **A.** Would one failure cause financial loss, a security breach, or a compliance violation?
- **B.** Does the workflow involve more than one tool call in a predetermined order?
- **C.** Is the operation frequent enough to justify the engineering effort of a gate?
- **D.** Can the model describe the required workflow correctly when it is asked to?

<details>
<summary>Reveal answer</summary>

**A. Would one failure cause financial loss, a security breach, or a compliance violation?**

The decision rule turns on consequence: if a single failure means financial loss, a security breach, or a compliance violation, enforcement must be programmatic.

- **B:** Step count does not decide the mechanism; consequence of failure does.
- **C:** Frequency is not the criterion the lesson applies.
- **D:** Describing a workflow correctly says nothing about executing it every time.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-4-workflow-enforcement-handoff) · [Technical reference](https://code.claude.com/docs/en/hooks)

## 1.5 — Agent SDK Hooks

### 59. PreToolUse runs before execution and can block, modify or redirect the outgoing call

`claude-1-5`

A hook must stop an impermissible file write before the filesystem changes. Which lifecycle point fits?

- **A.** PreToolUse.
- **B.** PostToolUse.
- **C.** A hook that runs when the session ends.
- **D.** A summary generated after the tool result.

<details>
<summary>Reveal answer</summary>

**A. PreToolUse.**

A pre-execution check can deny the proposed call before its side effect.

- **B:** The tool has already executed at this point.
- **C:** Ending the session is too late to prevent an earlier write.
- **D:** A summary describes the action rather than intercepting it.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 60. Post-action limits

`claude-1-5-2`

A post-tool check detects that an external write violated policy. What can you conclude?

- **A.** The original tool never ran.
- **B.** The violation is harmless if hidden from the model.
- **C.** The write may already have happened; recovery is a separate operation.
- **D.** The hook automatically undid the external write.

<details>
<summary>Reveal answer</summary>

**C. The write may already have happened; recovery is a separate operation.**

An after-execution hook does not rewind external side effects.

- **A:** A post-execution event follows execution.
- **B:** Hiding a result does not remove its effect.
- **D:** Detection does not imply rollback support.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 61. Normalization

`claude-1-5-3`

Two backends return dates in different formats. Where can a consistent output contract be applied?

- **A.** Only in the model's guess about each date.
- **B.** By discarding dates from every result.
- **C.** By changing all dates to today's date.
- **D.** In deterministic adapter or supported result-processing logic.

<details>
<summary>Reveal answer</summary>

**D. In deterministic adapter or supported result-processing logic.**

Normalization should preserve meaning, including time zone and units.

- **A:** Repeated inference is less explicit than a defined conversion.
- **B:** That can remove task-relevant information.
- **C:** That destroys the underlying facts.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 62. Gate coverage

`claude-1-5-4`

A write is available through two tools, but a policy hook covers only one. What is missing?

- **A.** Equivalent enforcement on every path that can perform the write.
- **B.** A longer description of the protected tool.
- **C.** A lower temperature for the unprotected path.
- **D.** An additional post-run success message.

<details>
<summary>Reveal answer</summary>

**A. Equivalent enforcement on every path that can perform the write.**

A bypassable gate does not establish the intended boundary.

- **B:** Description text does not cover the other execution path.
- **C:** Sampling settings are not access controls.
- **D:** A message cannot prevent the unguarded action.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 63. PreToolUse returns a permissionDecision of allow, deny, ask or defer, with optional update

`claude-1-5-5`

What does a PreToolUse hook return in the current Agent SDK?

- **A.** A boolean approved flag together with a message shown to the user.
- **B.** An exit code of 0 or 2, because the event exposes no structured decision.
- **C.** A permissionDecision naming allow, deny, ask or defer, optionally with updatedInput.
- **D.** A permissionDecision of allow or deny only, applied once the tool has run.

<details>
<summary>Reveal answer</summary>

**C. A permissionDecision naming allow, deny, ask or defer, optionally with updatedInput.**

A PreToolUse hook returns a permissionDecision of allow, deny, ask, or defer, and may supply updatedInput to rewrite the tool's arguments.

- **A:** The hook answers with a structured permission decision, not a bare boolean.
- **B:** Exit-code blocking is how SubagentStop works; PreToolUse has a decision field.
- **D:** Two values is incomplete, and PreToolUse is evaluated before execution, not after.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 64. PreToolUse runs before execution and can block, modify or redirect the outgoing call

`claude-1-5-6`

A hook must cap an oversized page-size argument before a search tool runs. Which mechanism fits?

- **A.** PreToolUse returning updatedInput with the corrected arguments.
- **B.** PostToolUse returning updatedToolOutput with the oversized result trimmed.
- **C.** SubagentStop returning the corrected arguments back to the coordinator.
- **D.** A system prompt rule stating the maximum page size the tool will accept.

<details>
<summary>Reveal answer</summary>

**A. PreToolUse returning updatedInput with the corrected arguments.**

PreToolUse runs before execution and can supply updatedInput, which rewrites the tool's arguments before the call goes out.

- **B:** That repairs the output after the expensive call has already run.
- **C:** SubagentStop fires on subagent completion and does not touch tool arguments.
- **D:** Prompt guidance is probabilistic and cannot guarantee the argument is capped.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 65. PostToolUse sets updatedToolOutput for built-in and MCP tools; updatedMCPToolOutput is MCP

`claude-1-5-7`

Which field lets a PostToolUse hook change what the model sees, for built-in and MCP tools alike?

- **A.** updatedInput
- **B.** updatedToolOutput
- **C.** updatedMCPToolOutput
- **D.** permissionDecision

<details>
<summary>Reveal answer</summary>

**B. updatedToolOutput**

PostToolUse sets updatedToolOutput to replace the result the model sees; the older updatedMCPToolOutput was MCP-only and is deprecated.

- **A:** updatedInput belongs to PreToolUse and rewrites arguments, not results.
- **C:** This older field covered MCP tools only and is deprecated.
- **D:** permissionDecision governs whether a call proceeds; it does not alter results.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 66. PostToolUse runs after a tool executes and before the model processes the result

`claude-1-5-8`

When exactly does a PostToolUse hook run?

- **A.** After the model has processed the result and before the next request is sent.
- **B.** Before the tool executes, as soon as the model has emitted the tool call.
- **C.** After the whole turn ends, once the assistant's final message is complete.
- **D.** After the tool executes and before the model processes its result.

<details>
<summary>Reveal answer</summary>

**D. After the tool executes and before the model processes its result.**

PostToolUse runs after the tool has executed but before the model processes the result, which is why it can transform what the model sees.

- **A:** The hook fires earlier than that, while the result is still on its way to the model.
- **B:** That is PreToolUse; confusing the direction is a documented exam trap.
- **C:** It runs per tool result rather than once per turn.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 67. Exam trap: using PostToolUse to block policy-violating actions that have already executed

`claude-1-5-9`

Refunds above $500 must always go to a human. Where does that rule belong?

- **A.** In a PreToolUse hook that denies the refund call and routes it to escalation.
- **B.** In a PostToolUse hook that flags oversized refunds for review after the fact.
- **C.** In the system prompt, which already describes the escalation threshold clearly.
- **D.** In the refund tool's description, so the model avoids requesting large amounts.

<details>
<summary>Reveal answer</summary>

**A. In a PreToolUse hook that denies the refund call and routes it to escalation.**

A threshold that must hold every time is enforced by a PreToolUse hook, which blocks the call before the refund can execute.

- **B:** By then the refund has been processed; flagging does not undo it.
- **C:** Prompt instructions are probabilistic and a single miss is a large unapproved refund.
- **D:** A description guides the model but enforces nothing.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 68. A markdown formatting preference does not justify a hook

`claude-1-5-10`

Responses should normally use markdown headings and bullet points. What does the lesson recommend?

- **A.** A PreToolUse hook that blocks any reply lacking markdown structure.
- **B.** A PostToolUse hook that rewrites every tool result into markdown first.
- **C.** Prompt guidance, because an occasional plain-text reply is not a business risk.
- **D.** A prerequisite gate that checks formatting before the turn is allowed to end.

<details>
<summary>Reveal answer</summary>

**C. Prompt guidance, because an occasional plain-text reply is not a business risk.**

Formatting preferences carry no business risk from a single deviation, so prompt-based guidance is the right mechanism and a hook is unnecessary overhead.

- **A:** Blocking machinery is unnecessary overhead for a presentation preference.
- **B:** Normalising tool results does not control how the assistant formats its reply, and the requirement does not warrant a hook.
- **D:** Gates exist for financial, security, and compliance prerequisites, not style.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 69. Without normalisation the model must reinterpret mixed formats every iteration, producing 

`claude-1-5-11`

Three tools return dates in three different formats. Why not simply instruct the model to convert them?

- **A.** The model cannot read date fields that arrive as Unix timestamps at all.
- **B.** Model-side conversion is probabilistic, so parsing stays inconsistent across iterations.
- **C.** Format instructions are stripped from the system prompt before each request.
- **D.** Converting inside the prompt roughly doubles the token cost of each tool result.

<details>
<summary>Reveal answer</summary>

**B. Model-side conversion is probabilistic, so parsing stays inconsistent across iterations.**

Leaving normalisation to the model reintroduces inconsistency, such as misreading day and month order, which a PostToolUse hook eliminates.

- **A:** It can read them; the problem is that it does so inconsistently.
- **C:** Nothing strips those instructions; their weakness is reliability, not delivery.
- **D:** Token cost is not the objection the lesson raises.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 70. Normalisation targets: timestamps, status codes, currency values and regional date formats

`claude-1-5-12`

Which transformation is a PostToolUse normalisation hook responsible for?

- **A.** Deciding whether a tool should have been called with the arguments it received.
- **B.** Converting Unix timestamps and DD/MM/YYYY dates into one ISO 8601 format.
- **C.** Blocking a status update that would violate the refund approval policy.
- **D.** Choosing which of three backend systems the next tool call should target.

<details>
<summary>Reveal answer</summary>

**B. Converting Unix timestamps and DD/MM/YYYY dates into one ISO 8601 format.**

PostToolUse normalisation rewrites heterogeneous results into one schema, such as every date as ISO 8601 and every status as a readable string.

- **A:** That judgement happens before execution, in a PreToolUse hook.
- **C:** Blocking is policy enforcement and must happen before the tool runs.
- **D:** Routing decisions are not part of result normalisation.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 71. Exam trap: using PostToolUse to block policy-violating actions that have already executed

`claude-1-5-13`

Cross-border payments must always pass a sanctions screen, but prompt instructions let a few through. Which design meets the requirement?

- **A.** A PostToolUse hook that queues any unscreened payment for manual review.
- **B.** A stronger system prompt that spells out the penalties for skipping the screen.
- **C.** Few-shot examples showing the screen performed before each payment executes.
- **D.** A PreToolUse hook that denies the payment tool until the screen records a pass.

<details>
<summary>Reveal answer</summary>

**D. A PreToolUse hook that denies the payment tool until the screen records a pass.**

A regulatory requirement needs deterministic enforcement, so a PreToolUse hook blocks the payment tool until the screening result is recorded.

- **A:** The payment has already executed by the time this fires, so the requirement is still violated.
- **B:** Stronger wording reduces the failure rate without eliminating it.
- **C:** Examples improve behaviour probabilistically and cannot guarantee compliance.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 72. Decision framework: requirements that must hold 100% of the time use hooks; preferences us

`claude-1-5-14`

Which mapping matches the lesson's decision framework?

- **A.** Requirements that must hold every time use hooks; preferences use prompts.
- **B.** Requirements that must hold every time use prompts; preferences use hooks.
- **C.** Both requirements and preferences use hooks, since hooks are deterministic.
- **D.** Both use prompts, with hooks reserved solely for normalising tool output.

<details>
<summary>Reveal answer</summary>

**A. Requirements that must hold every time use hooks; preferences use prompts.**

Anything that must be followed 100% of the time is enforced with hooks; preferences where occasional deviation is tolerable are handled with prompts.

- **B:** This inverts the framework and leaves absolute requirements unenforced.
- **C:** Hooks for style preferences are unnecessary overhead.
- **D:** Normalisation is one hook use, but policy enforcement is the other.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

### 73. PreToolUse use case: discounts above 20% are routed to a manager approval queue before app

`claude-1-5-15`

Discounts above 20% require manager sign-off before they take effect. How is that implemented?

- **A.** A PostToolUse hook records each applied discount and notifies the manager.
- **B.** The discount tool applies the change and emails the manager for confirmation.
- **C.** A PreToolUse hook intercepts the call and routes it to a manager approval queue.
- **D.** The system prompt instructs the agent to seek approval before large discounts.

<details>
<summary>Reveal answer</summary>

**C. A PreToolUse hook intercepts the call and routes it to a manager approval queue.**

A PreToolUse hook intercepts the discount call above the threshold and pauses it for manager approval, so the tool executes only once approval is granted.

- **A:** The discount is already applied when this fires, so approval is not a precondition.
- **B:** Applying first and confirming later defeats the purpose of an approval requirement.
- **D:** Prompt guidance cannot guarantee that approval precedes every large discount.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-5-agent-sdk-hooks) · [Technical reference](https://code.claude.com/docs/en/hooks)

## 1.6 — Task Decomposition Strategies

### 74. Fixed pipelines suit predictable, structured tasks such as code review and compliance chec

`claude-1-6`

A review needs both local file checks and checks of contracts between files. Which decomposition covers both?

- **A.** Repeat the same local check several times without inspecting interfaces.
- **B.** Analyze files, then run an integration pass over their interfaces and findings.
- **C.** Analyze files independently and assume their contracts are compatible.
- **D.** Inspect only the largest file and infer how the rest behaves.

<details>
<summary>Reveal answer</summary>

**B. Analyze files, then run an integration pass over their interfaces and findings.**

Local review and cross-file review answer different questions.

- **A:** Repetition does not add the missing integration analysis.
- **C:** Correct files can still disagree at their boundaries.
- **D:** File size does not establish dependency or coverage.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 75. Dynamic decomposition

`claude-1-6-2`

The next investigation depends on what an initial search discovers. Which plan fits?

- **A.** Skip follow-ups because they were not known initially.
- **B.** Use findings to choose bounded follow-up tasks.
- **C.** Commit to every possible follow-up before reading results.
- **D.** Run synthesis before retrieving any evidence.

<details>
<summary>Reveal answer</summary>

**B. Use findings to choose bounded follow-up tasks.**

Discovery-driven work needs a way to adapt after new evidence.

- **A:** Unknown initial details do not eliminate required investigation.
- **C:** That can waste work on irrelevant branches.
- **D:** The dependency is not satisfied.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 76. Coverage

`claude-1-6-3`

A large review is detailed on two files and superficial on the rest. What should decomposition make explicit?

- **A.** Only the average number of comments per file.
- **B.** A rule to ignore files without immediate findings.
- **C.** Bounded review units and a record of which units were examined.
- **D.** Only a larger final response length.

<details>
<summary>Reveal answer</summary>

**C. Bounded review units and a record of which units were examined.**

Explicit coverage reduces the chance that fluent output conceals omissions.

- **A:** Comment quantity is not evidence of adequate review.
- **B:** No quick finding does not mean the file was reviewed.
- **D:** Longer output does not demonstrate broader inspection.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 77. Parallel boundaries

`claude-1-6-4`

Two tasks edit the same shared artifact and assume incompatible states. What must be resolved before parallel execution?

- **A.** Only the order in which their names appear.
- **B.** Only the total model token budget.
- **C.** Nothing; concurrency automatically merges intent.
- **D.** Their write ownership and dependency or merge contract.

<details>
<summary>Reveal answer</summary>

**D. Their write ownership and dependency or merge contract.**

Parallelism needs an explicit way to prevent or reconcile conflicting updates.

- **A:** Display order does not coordinate writes.
- **B:** A budget does not define shared-state semantics.
- **C:** Independent writers can overwrite or contradict each other.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 78. Fixed sequential pipelines (prompt chaining) run predetermined steps in order, each output

`claude-1-6-5`

What characterises a fixed sequential pipeline?

- **A.** Steps are chosen at run time from whatever the previous step happened to discover.
- **B.** Steps run concurrently and a final step merges whichever results arrive first.
- **C.** Steps are defined in advance and run in the same order whatever they find.
- **D.** Steps repeat until an evaluator judges the accumulated output complete enough.

<details>
<summary>Reveal answer</summary>

**C. Steps are defined in advance and run in the same order whatever they find.**

A fixed sequential pipeline runs predetermined steps in order, each feeding the next, and the sequence does not change based on intermediate results.

- **A:** That describes dynamic adaptive decomposition, not a fixed pipeline.
- **B:** Concurrency and racing are not what defines prompt chaining.
- **D:** Looping on an evaluator is a refinement pattern rather than a fixed chain.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 79. Fixed pipeline advantages: consistency, reliability, easy debugging and step-level monitor

`claude-1-6-6`

What does a fixed sequential pipeline give up?

- **A.** The ability to change later steps when an earlier step finds something unexpected.
- **B.** The ability to log the output of every step for later debugging and monitoring.
- **C.** The ability to feed one step's output into the next step's input.
- **D.** The ability to produce the same result for the same input on a repeat run.

<details>
<summary>Reveal answer</summary>

**A. The ability to change later steps when an earlier step finds something unexpected.**

Fixed pipelines trade adaptability for consistency: if a step discovers something that should change the approach, the sequence cannot adjust.

- **B:** Per-step logging is one of the pattern's advantages, not a cost.
- **C:** Chaining outputs into inputs is the definition of the pattern.
- **D:** Consistency is precisely what fixed pipelines provide.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 80. Dynamic adaptive decomposition generates and revises subtasks from what it discovers

`claude-1-6-7`

While adding tests to a legacy system, the agent finds that the module it planned to test depends on an untested one. Which approach handles this?

- **A.** A fixed pipeline, which keeps the planned order and records the dependency.
- **B.** A fixed pipeline with extra steps inserted before execution begins.
- **C.** One large pass across every module so no dependency can come as a surprise.
- **D.** Dynamic adaptive decomposition, which reorders the plan around the new dependency.

<details>
<summary>Reveal answer</summary>

**D. Dynamic adaptive decomposition, which reorders the plan around the new dependency.**

Dynamic adaptive decomposition generates and reorders subtasks from what it discovers, which is what lets it test the depended-on module first.

- **A:** A fixed pipeline cannot reorder itself around a finding made mid-run.
- **B:** Steps added in advance still cannot respond to a dependency nobody knew about.
- **C:** A single pass over many modules invites attention dilution and still needs a plan.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 81. Dynamic decomposition limitations: unpredictable runtime and resource use, harder debuggin

`claude-1-6-8`

What is the cost of dynamic adaptive decomposition?

- **A.** It cannot respond to new findings that appear midway through the work.
- **B.** Execution time and resource use are less predictable, and debugging is harder.
- **C.** It always requires more subagents than an equivalent fixed pipeline.
- **D.** It produces shallower results on the open-ended tasks it targets.

<details>
<summary>Reveal answer</summary>

**B. Execution time and resource use are less predictable, and debugging is harder.**

Because the plan evolves with what is discovered, execution time and resource use are hard to estimate and failures are harder to trace.

- **A:** Responding to findings is its defining strength.
- **C:** Agent count is not what distinguishes the patterns.
- **D:** It produces more thorough results on exactly those tasks.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 82. Fixed pipelines suit predictable, structured tasks such as code review and compliance chec

`claude-1-6-9`

A workflow extracts the same eight fields from thousands of invoices. Which pattern fits?

- **A.** A fixed sequential pipeline, because the fields and format are known in advance.
- **B.** Dynamic decomposition, so the agent can decide which fields matter per invoice.
- **C.** Dynamic decomposition, because the volume of documents makes the scope open-ended.
- **D.** A single combined pass over batches of invoices with no separate integration step.

<details>
<summary>Reveal answer</summary>

**A. A fixed sequential pipeline, because the fields and format are known in advance.**

Document extraction has predetermined fields and formats, which is the structured, predictable case that fixed pipelines serve best.

- **B:** The fields are already determined, so adaptability buys nothing and costs predictability.
- **C:** Volume is not the same as unknown scope; the task itself is fully specified.
- **D:** Processing many items in one pass is how attention dilution appears.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 83. Attention dilution: processing too many items in one pass produces inconsistent depth

`claude-1-6-10`

A review shows thorough comments on the first files, thin comments on later ones, and the same pattern flagged in one file but ignored in another. What is this?

- **A.** A context window overflow that silently dropped the later files from the prompt.
- **B.** A tool restriction that hid part of the codebase from the reviewing agent.
- **C.** Attention dilution caused by processing too many items in a single pass.
- **D.** A sampling setting that made later judgements inconsistent with earlier ones.

<details>
<summary>Reveal answer</summary>

**C. Attention dilution caused by processing too many items in a single pass.**

Degrading depth across items, plus identical code judged differently in different files, are the telltale symptoms of attention dilution.

- **A:** The later files were reviewed, just shallowly, so nothing was dropped.
- **B:** Restricted access would remove files entirely rather than degrade depth gradually.
- **D:** Inconsistency here comes from how attention is spread, not from sampling parameters.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 84. Fix: multi-pass architecture combining per-item local passes with a cross-item integration

`claude-1-6-11`

What does the lesson say about fixing attention dilution with a larger context window or a stronger model?

- **A.** It works, because all the items then fit comfortably inside one prompt.
- **B.** It works when combined with a prompt demanding equal thoroughness for every item.
- **C.** It fixes the depth drop-off but still leaves cross-item issues undetected.
- **D.** It does not work, because the problem is architectural and needs multiple passes.

<details>
<summary>Reveal answer</summary>

**D. It does not work, because the problem is architectural and needs multiple passes.**

Attention dilution is an architectural problem, so a bigger model or wider context does not solve it; multi-pass decomposition does.

- **A:** Fitting the items was never the constraint; attention allocation is.
- **B:** Better prompts raise average quality without guaranteeing per-item attention.
- **C:** It does not fix the depth drop-off at all.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 85. Exam trap: batching items into groups without adding a cross-item integration pass

`claude-1-6-12`

A team splits fourteen files into three batches and reviews each batch separately. What still goes wrong?

- **A.** Issues spanning batches, such as data flow and inconsistent patterns, go unnoticed.
- **B.** Each batch loses depth toward its end in the same way a single pass would.
- **C.** The batches cannot be reviewed using the same agent configuration.
- **D.** The review becomes non-deterministic because the batch ordering varies.

<details>
<summary>Reveal answer</summary>

**A. Issues spanning batches, such as data flow and inconsistent patterns, go unnoticed.**

Batching reduces dilution inside each batch but misses cross-batch data flow and pattern inconsistencies without a dedicated integration pass.

- **B:** Smaller batches largely restore per-item depth; the gap is between batches.
- **C:** Reusing one configuration across batches is perfectly possible.
- **D:** Ordering is not the weakness the lesson identifies in batching.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 86. Cause: attention is allocated across all items, so per-item attention falls as item count 

`claude-1-6-13`

Why does analysis depth fall off across items in a single large pass?

- **A.** Later items are truncated out of the prompt once the token limit is reached.
- **B.** Attention is spread across all items, so each additional item receives less of it.
- **C.** The model forgets its instructions after a fixed number of files are processed.
- **D.** Tool results from the earlier items overwrite the later items in the context.

<details>
<summary>Reveal answer</summary>

**B. Attention is spread across all items, so each additional item receives less of it.**

The model allocates attention across every item in context, so more items means less attention each, and later items get skimmed.

- **A:** The items are still present; they simply receive less attention.
- **C:** There is no fixed forgetting threshold; the effect is gradual attention spreading.
- **D:** Nothing overwrites anything; all items remain in context.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 87. Dynamic decomposition suits open-ended investigation: legacy exploration, audits, unfamili

`claude-1-6-14`

An agent must find the root cause of an intermittent failure in a system nobody on the team knows. Which decomposition fits?

- **A.** A fixed pipeline running the team's standard debugging steps in their usual order.
- **B.** A fixed pipeline that runs every available diagnostic once and reports the output.
- **C.** Dynamic adaptive decomposition, because the investigation must follow what it finds.
- **D.** A single combined pass over all logs and source files at the same time.

<details>
<summary>Reveal answer</summary>

**C. Dynamic adaptive decomposition, because the investigation must follow what it finds.**

Debugging an unfamiliar system has unknown scope, so the investigation has to generate its next steps from what it discovers.

- **A:** A predetermined order cannot follow evidence that only appears mid-investigation.
- **B:** Running everything blindly is still a predetermined sequence that ignores what it learns.
- **D:** One large pass over many items dilutes attention and produces uneven analysis.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-6-task-decomposition) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

## 1.7 — Session State and Resumption

### 88. The naive fix of resuming and re-reading leaves stale results in history where they can st

`claude-1-7`

You resume a debugging session after another developer changed the implicated files. What is the most reliable way to continue without reasoning from stale tool results?

- **A.** Ask the model to remember the old files more precisely.
- **B.** Resume the session and ask the agent to re-read the changed files.
- **C.** Start a fresh session with a structured summary of prior findings and re-analyse only the changed files.
- **D.** Trust all earlier tool results because the session was restored.

<details>
<summary>Reveal answer</summary>

**C. Start a fresh session with a structured summary of prior findings and re-analyse only the changed files.**

A resumed session keeps the old tool results in history, so they can still steer reasoning; a fresh session seeded with a structured summary and the list of changed files keeps the knowledge without the stale evidence.

- **A:** Better recall cannot verify newly changed code.
- **B:** The old tool results stay in the conversation history and can still influence reasoning, so this is only a partial fix.
- **D:** Restoring a record does not make its contents current.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 89. Alternative exploration

`claude-1-7-2`

You want to compare a new approach while preserving an existing conversation path. Which session operation fits?

- **A.** Fork the conversation, then verify how workspace changes are isolated.
- **B.** Overwrite the old session's messages.
- **C.** Reuse the same conversation and hide previous decisions.
- **D.** Assume a new conversation always clones the filesystem.

<details>
<summary>Reveal answer</summary>

**A. Fork the conversation, then verify how workspace changes are isolated.**

Conversation branching does not by itself guarantee filesystem isolation.

- **B:** That destroys the branch you wanted to preserve.
- **C:** That does not create an independent comparison path.
- **D:** Conversation state and workspace state are different resources.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 90. External effects

`claude-1-7-3`

A saved session shows a tool request immediately before a crash. What must recovery establish?

- **A.** That a new operation ID is always safe.
- **B.** Whether the external operation already completed before retrying it.
- **C.** That every unrecorded result means the operation never happened.
- **D.** That resuming the session reverses the tool automatically.

<details>
<summary>Reveal answer</summary>

**B. Whether the external operation already completed before retrying it.**

Conversation history alone may not resolve the side effect's actual state.

- **A:** A new ID may defeat deduplication and repeat the effect.
- **C:** A crash can occur after execution but before persistence.
- **D:** Resumption does not undo external actions.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 91. Session identity

`claude-1-7-4`

Why retain the identifier of a resumable agent session?

- **A.** It replaces every tool's authorization checks.
- **B.** It proves the task was successfully completed.
- **C.** It selects the saved conversation to continue.
- **D.** It makes all future sessions share one filesystem snapshot.

<details>
<summary>Reveal answer</summary>

**C. It selects the saved conversation to continue.**

The identifier locates historical session state; it does not verify external facts.

- **A:** Resuming context does not grant new permissions.
- **B:** A session can be saved while work remains unfinished.
- **D:** Session identity does not supply that isolation guarantee.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 92. The stale context problem: restored tool results predate the file changes, so the agent re

`claude-1-7-5`

What is the stale context problem?

- **A.** A resumed session loses its tool results, so the agent must re-read every file again.
- **B.** A long session exceeds the context window and silently drops its earliest messages.
- **C.** A forked branch cannot observe the changes made in the session it came from.
- **D.** Restored history holds file reads from before the edits, so the agent uses old contents.

<details>
<summary>Reveal answer</summary>

**D. Restored history holds file reads from before the edits, so the agent uses old contents.**

Resuming restores the whole history, including file reads taken before the edits, so the agent reasons from contents that no longer exist.

- **A:** Resume restores the results; the difficulty is that it restores outdated ones.
- **B:** Dropping old messages is a different issue from reasoning on outdated file contents.
- **C:** Branch isolation is expected behaviour, not the stale context problem.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 93. Three session management options: resume, fork_session, and a fresh start with summary inj

`claude-1-7-6`

After editing four files in a sixty-file project, a resumed agent recommends changes that are already in place. What does the lesson advise?

- **A.** Start fresh with an injected summary of prior findings and target the four changed files.
- **B.** Resume the existing session and ask the agent to re-read the four changed files first.
- **C.** Start fresh with no carried context and re-analyse all sixty files before continuing.
- **D.** Fork the existing session so the four edited files are examined on a separate branch.

<details>
<summary>Reveal answer</summary>

**A. Start fresh with an injected summary of prior findings and target the four changed files.**

A fresh session with a structured summary removes the stale tool results while preserving prior knowledge and scoping re-analysis to the changed files.

- **B:** The outdated tool results stay in history and can still influence tangential reasoning.
- **C:** Full re-exploration discards knowledge that a summary would have preserved.
- **D:** A fork copies the same stale history into the new branch.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 94. Exam trap: forking to handle stale context, since the fork inherits the outdated history

`claude-1-7-7`

Why is forking a poor answer to stale context after file edits?

- **A.** The fork discards the analysis baseline the original session produced.
- **B.** The fork copies the existing history, so the outdated tool results come with it.
- **C.** The fork cannot read files that were changed after the original session ended.
- **D.** The fork merges back into the original session and overwrites its history.

<details>
<summary>Reveal answer</summary>

**B. The fork copies the existing history, so the outdated tool results come with it.**

Fork branches from the existing session, so the stale tool results are inherited along with everything else.

- **A:** A fork preserves the baseline; that is its purpose.
- **C:** A forked session reads current files normally.
- **D:** Branches stay independent and do not merge back.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 95. Targeted re-analysis of the changed files beats full re-exploration of the whole codebase

`claude-1-7-8`

Three of fifty files changed since the last session. What does targeted re-analysis mean here?

- **A.** Re-read all fifty files so the analysis is uniformly current across the project.
- **B.** Re-read the three changed files plus the ten modules that import from them.
- **C.** Re-read only the three changed files and rely on the summary for the rest.
- **D.** Skip re-reading entirely and let the agent infer the edits from the summary alone.

<details>
<summary>Reveal answer</summary>

**C. Re-read only the three changed files and rely on the summary for the rest.**

Targeted re-analysis re-reads only the files that changed, with the prior summary covering everything that did not.

- **A:** Re-reading forty-seven unchanged files is the wasteful full re-exploration the lesson rejects.
- **B:** Expanding the set beyond what changed reintroduces the cost the approach avoids.
- **D:** The summary describes prior findings, not the new contents of the edited files.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 96. Do not resume once files have been modified, because the restored results are stale

`claude-1-7-9`

The project's dependencies were upgraded between sessions. Which strategy does the decision matrix give?

- **A.** A fresh start with a summary, because many files may have changed indirectly.
- **B.** Resume, because the team did not hand-edit any of its own source files.
- **C.** Fork, because the upgrade is one alternative worth comparing against the old state.
- **D.** Resume with a longer history limit so more prior tool results stay available.

<details>
<summary>Reveal answer</summary>

**A. A fresh start with a summary, because many files may have changed indirectly.**

Dependency updates can change many files indirectly, so the matrix calls for a fresh start with an injected summary.

- **B:** Indirect changes still invalidate cached results, so resuming carries stale context.
- **C:** Forking is for divergent exploration and would inherit the outdated reads anyway.
- **D:** Keeping more outdated results makes the problem worse rather than better.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 97. A fresh start with summary injection gives a clean baseline while preserving prior knowled

`claude-1-7-10`

A session has run long and its history is crowded with irrelevant tool results. What does the lesson advise?

- **A.** Resume and instruct the agent to ignore the results that are no longer relevant.
- **B.** Fork the session so the accumulated clutter stays behind on the original branch.
- **C.** Resume and ask the agent to summarise and compress its own history in place.
- **D.** Start fresh and inject a curated summary of what the session established.

<details>
<summary>Reveal answer</summary>

**D. Start fresh and inject a curated summary of what the session established.**

When context has degraded over a long session, a fresh start with an injected summary gives a clean baseline while preserving the findings.

- **A:** Instructing the model to disregard context is unreliable and leaves the clutter in place.
- **B:** A fork copies the history, clutter included.
- **C:** The original results remain in the conversation regardless of any summary written into it.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 98. Three session management options: resume, fork_session, and a fresh start with summary inj

`claude-1-7-11`

Which statement about --resume in the current Claude Code CLI is accurate?

- **A.** It creates a session under the given name when no such session exists yet.
- **B.** It continues an existing session by id or name, or opens an interactive picker.
- **C.** It always branches from the named session instead of appending to it.
- **D.** It requires the fork flag to be set before it will restore any history at all.

<details>
<summary>Reveal answer</summary>

**B. It continues an existing session by id or name, or opens an interactive picker.**

--resume only continues sessions that already exist, taking a session id or name or offering a picker; sessions are named at start with --name or renamed later.

- **A:** Resume never creates a session; it only continues one that already exists.
- **C:** Appending is the default; branching requires the fork flag alongside it.
- **D:** Resume restores history on its own; the fork flag only changes append into branch.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 99. -c / --continue resumes the most recent conversation in the current directory without nami

`claude-1-7-12`

How do you continue the most recent conversation in the current directory without naming it?

- **A.** Pass --resume with no argument, which silently selects the newest session.
- **B.** Pass --name with the directory path so the session is located by folder.
- **C.** Pass -c, the continue flag, which resumes the most recent conversation there.
- **D.** Pass --fork-session, which reopens the newest session as an independent branch.

<details>
<summary>Reveal answer</summary>

**C. Pass -c, the continue flag, which resumes the most recent conversation there.**

The -c or --continue flag resumes the most recent conversation in the current directory without requiring a session name.

- **A:** Resume without an argument opens a picker rather than auto-selecting.
- **B:** --name assigns a session name when starting; it does not look sessions up by path.
- **D:** The fork flag only has an effect alongside resume or continue and creates a branch.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 100. Three session management options: resume, fork_session, and a fresh start with summary inj

`claude-1-7-13`

You want to compare a testing-focused plan against a documentation-focused plan, both built on one completed analysis. Which option fits?

- **A.** Fork the session once per plan so each branch builds on the same baseline.
- **B.** Resume the session twice so both plans append to the same conversation history.
- **C.** Start two fresh sessions with summaries so the two plans stay entirely separate.
- **D.** Run both plans inside one resumed session and compare them at the very end.

<details>
<summary>Reveal answer</summary>

**A. Fork the session once per plan so each branch builds on the same baseline.**

Comparing two independent approaches from a shared analysis baseline is the case fork_session exists for.

- **B:** Appending both plans to one history mixes them instead of keeping them independent.
- **C:** Summaries would be needed only if the baseline were stale, and this discards a valid analysis.
- **D:** Each plan then reasons about the other's output rather than exploring independently.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 101. Resume restores the entire conversation history, including every tool result

`claude-1-7-14`

What does resuming a session restore?

- **A.** A condensed summary of the prior session, with raw tool results discarded.
- **B.** Only the messages recorded since the last successful tool call in the session.
- **C.** The prior session's file reads, automatically refreshed against current contents.
- **D.** The entire conversation history, including every tool result from that session.

<details>
<summary>Reveal answer</summary>

**D. The entire conversation history, including every tool result from that session.**

Resume restores the whole conversation history, including all tool results, analyses, and reasoning from the prior session.

- **A:** Summarising is what a fresh start with summary injection does instead.
- **B:** Resume does not truncate the history in that way.
- **C:** Nothing is refreshed automatically, which is why stale reads persist.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

### 102. The injected summary carries findings, affected files and recommendations, not raw tool ou

`claude-1-7-15`

What belongs in the structured summary injected into a fresh session?

- **A.** The complete text of every file the prior session read during its analysis.
- **B.** Prior findings, the files they concern, and recommendations, without raw tool output.
- **C.** The prior session identifier so the agent can retrieve the old history itself.
- **D.** The prompts used previously, so the agent can repeat the same analysis steps.

<details>
<summary>Reveal answer</summary>

**B. Prior findings, the files they concern, and recommendations, without raw tool output.**

The injected summary captures findings, affected files, and recommendations, preserving knowledge without carrying raw or outdated tool output.

- **A:** Carrying raw file contents forward recreates the stale data the fresh start removes.
- **C:** An identifier pulls back the stale history rather than replacing it.
- **D:** Repeating the analysis wastes the knowledge the summary was meant to carry.

</details>

[Lesson material](https://claudecertificationguide.com/learn/1-agentic-architecture/1-7-session-state-resumption) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/sessions)

## 2.1 — Tool Interface Design

### 103. A production-grade description carries five elements: purpose, inputs, example queries, ed

`claude-2-1`

An assistant repeatedly confuses two similar lookup tools. What should you improve first?

- **A.** Rename both tools to shorter but less descriptive names.
- **B.** Increase the response token budget for every call.
- **C.** Tell the model to choose randomly when descriptions overlap.
- **D.** Clarify each tool's purpose, input constraints and selection boundaries.

<details>
<summary>Reveal answer</summary>

**D. Clarify each tool's purpose, input constraints and selection boundaries.**

Descriptions should distinguish when each operation is appropriate.

- **A:** Shorter ambiguous names do not clarify the boundary.
- **B:** More output tokens do not fix an unclear tool contract.
- **C:** Random choice makes errors less predictable, not less likely.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 104. Argument contracts

`claude-2-1-2`

A tool needs a project ID and a bounded result count. What makes its interface safer to use?

- **A.** A prose example with no validation.
- **B.** A single unparsed string containing any command.
- **C.** Defaulting every missing project ID to an unrelated project.
- **D.** Explicit argument types and constraints, validated by application code.

<details>
<summary>Reveal answer</summary>

**D. Explicit argument types and constraints, validated by application code.**

A model-facing schema and runtime checks serve complementary roles.

- **A:** Examples do not enforce input boundaries.
- **B:** That obscures the permitted argument structure.
- **C:** A convenient default can change the operation's target.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 105. Tool boundaries

`claude-2-1-3`

When should two similar tools remain distinct rather than be merged?

- **A.** When their authorization or effects require separate contracts.
- **B.** Whenever their names have different lengths.
- **C.** Never; all tools should become one unrestricted executor.
- **D.** Only when one tool returns more characters.

<details>
<summary>Reveal answer</summary>

**A. When their authorization or effects require separate contracts.**

Similar inputs do not make operations equivalent in risk or semantics.

- **B:** Name length is not a meaningful design boundary.
- **C:** An unrestricted interface can erase useful capability limits.
- **D:** Output size alone does not determine the contract.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 106. Output contract

`claude-2-1-4`

A lookup returns a monetary value. Which output best preserves its meaning?

- **A.** A sentence saying the amount looks reasonable.
- **B.** Amount with currency, units and the relevant source identity.
- **C.** A bare number with currency inferred later.
- **D.** A rounded value that discards required precision.

<details>
<summary>Reveal answer</summary>

**B. Amount with currency, units and the relevant source identity.**

A number alone may be ambiguous to downstream reasoning.

- **A:** A judgment is not the requested factual result.
- **C:** Inference can attach the wrong interpretation.
- **D:** Rounding can change a decision-relevant quantity.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 107. A production-grade description carries five elements: purpose, inputs, example queries, ed

`claude-2-1-5`

A reviewer checks a tool description that already states the tool's purpose, the input formats it accepts, and a few example queries. Which two elements are still missing from a production-grade description?

- **A.** The edge cases it does not handle, and boundaries naming which sibling tool to use instead.
- **B.** A schema version number, and the average latency of the backend call it performs.
- **C.** The endpoint it calls internally, and the authorisation scope the caller has to hold.
- **D.** An estimate of token cost, and the name of the team that maintains the integration.

<details>
<summary>Reveal answer</summary>

**A. The edge cases it does not handle, and boundaries naming which sibling tool to use instead.**

The five elements are purpose, expected inputs, example queries, edge cases and limitations, and explicit boundaries against similar tools.

- **B:** Neither is part of the five elements; latency and versioning do not help the model choose between tools.
- **C:** Implementation and auth details are not among the five elements and do not disambiguate overlapping tools.
- **D:** Ownership and token accounting are operational metadata, not selection signal for the model.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 108. Minimal, overlapping descriptions cause misrouting between tools that serve adjacent purpo

`claude-2-1-6`

Traffic logs show a support agent answering 'where is my order #44120?' by calling get_customer rather than lookup_order. Each tool carries a single short sentence of description and both accept similar identifiers. What is the most effective first step?

- **A.** Add six worked examples to the system prompt showing which tool each phrasing should reach.
- **B.** Rewrite both descriptions with accepted identifier formats, example queries, limits, and when to use the other tool.
- **C.** Merge the pair into one lookup_entity tool that inspects the identifier and picks the backend itself.
- **D.** Put a keyword classifier in front of the model that selects the tool before the turn begins.

<details>
<summary>Reveal answer</summary>

**B. Rewrite both descriptions with accepted identifier formats, example queries, limits, and when to use the other tool.**

Tool descriptions are the primary mechanism for selection, so expanding them is the lowest-effort fix that removes the ambiguity causing the misroute.

- **A:** Few-shot examples add token overhead while leaving the descriptions that confuse the model untouched.
- **C:** Consolidation is a defensible long-term choice but costs far more effort than rewriting two descriptions.
- **D:** A routing classifier is over-engineered as a first response and bypasses the model's own language understanding.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 109. Few-shot examples are the wrong fix: token overhead without addressing the cause

`claude-2-1-7`

Why do few-shot tool-selection examples fail to cure misrouting that comes from one-sentence tool descriptions?

- **A.** Few-shot examples are ignored whenever a request also carries tool definitions.
- **B.** Examples can only travel in the tool schema itself, never in a system prompt.
- **C.** They add token overhead on every turn while the descriptions that confuse the model stay the same.
- **D.** They force a tool call on every turn, so the model can no longer answer in plain text.

<details>
<summary>Reveal answer</summary>

**C. They add token overhead on every turn while the descriptions that confuse the model stay the same.**

Few-shot examples pay a recurring token cost without changing the descriptions that caused the confusion.

- **A:** Models do read few-shot examples alongside tools; the objection is effectiveness, not whether they are read.
- **B:** Examples can be placed in a system prompt; the lesson's objection is that they do not fix the cause.
- **D:** That is what forcing tool choice does; few-shot examples impose no such constraint.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 110. A routing classifier is over-engineered as a first step and bypasses the model's language 

`claude-2-1-8`

A team proposes a keyword routing layer that picks the tool before each model turn, to settle selection errors between two vaguely described tools. Why does the lesson treat this as the wrong first response?

- **A.** Routing layers cannot be built without first extending the tool-use protocol they sit in front of.
- **B.** Classifiers only become the right answer once an agent is carrying more than twenty tools.
- **C.** A classifier removes the need for tool descriptions, so the remaining schemas decay over time.
- **D.** It adds infrastructure and sidesteps the language understanding a rewrite would have fixed.

<details>
<summary>Reveal answer</summary>

**D. It adds infrastructure and sidesteps the language understanding a rewrite would have fixed.**

A routing classifier is over-engineered as a first step: it adds infrastructure and bypasses the natural language understanding that would work once descriptions are clear.

- **A:** Nothing prevents a team from building one; the objection is proportionality, not feasibility.
- **B:** The lesson never endorses classifiers at any toolkit size; large toolkits are handled by consolidation or scoping.
- **C:** The problem is not schema decay; the descriptions are simply never repaired.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 111. Tool consolidation is a valid long-term choice but costs more effort than a description re

`claude-2-1-9`

Which ordering reflects the preference the lesson says the exam applies?

- **A.** Improve descriptions before adding a classifier, scope access before granting it, evaluate community servers before custom builds.
- **B.** Build a custom server before surveying the community ones, and grant broad access first so that a later audit can narrow it.
- **C.** Consolidate the toolkit before reading the descriptions, and force a specific tool before ever allowing a free choice.
- **D.** Add few-shot examples first, then a routing classifier, and rewrite the descriptions only once neither has helped.

<details>
<summary>Reveal answer</summary>

**A. Improve descriptions before adding a classifier, scope access before granting it, evaluate community servers before custom builds.**

The exam consistently rewards the cheapest fix that addresses the cause: better descriptions, scoped access, and existing servers before custom work.

- **B:** Both halves invert the guidance: community servers come first and access starts scoped.
- **C:** Consolidation and forced tool choice are targeted remedies, not the default opening move.
- **D:** This is the exact ordering the lesson rejects; descriptions come first, not last.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 112. A generic broad tool should be split into purpose-specific tools with defined input/output

`claude-2-1-10`

A single analyze_document tool is described as 'Analyses a document and returns results', and the agent invokes it for jobs it cannot actually perform. What does the lesson recommend?

- **A.** Keep the single tool and add a free-text instruction argument that says which analysis it should run this time.
- **B.** Split it into purpose-specific tools for extraction, summarisation and claim verification, each with its own contract.
- **C.** Leave the tool exactly as it stands and describe each supported analysis in the system prompt instead.
- **D.** Register it on a second MCP server so the client presents it to the model under a clearer namespace.

<details>
<summary>Reveal answer</summary>

**B. Split it into purpose-specific tools for extraction, summarisation and claim verification, each with its own contract.**

A broad tool with one vague description should be split into purpose-specific tools, each doing one narrow job with a defined input and output contract.

- **A:** A free-text argument leaves the contract undefined and the ambiguity the model faces unchanged.
- **C:** The system prompt cannot supply the per-tool contracts the model needs at selection time.
- **D:** Server placement is invisible to the model and changes nothing about the tool's contract.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 113. Renaming resolves name overlap at the interface level without touching the implementation

`claude-2-1-11`

Two tools carry confusingly similar names though their implementations are sound and distinct. What does renaming one of them accomplish?

- **A.** It alters the tool's behaviour so ambiguous calls start failing loudly instead of succeeding.
- **B.** It makes the client reload the toolkit, which clears the model's earlier selection habits.
- **C.** It resolves the overlap at the interface level without any change to the implementation behind it.
- **D.** It lets both tools keep the same description, because the names now carry the distinction.

<details>
<summary>Reveal answer</summary>

**C. It resolves the overlap at the interface level without any change to the implementation behind it.**

Renaming a confusingly similar tool fixes the overlap at the interface level, and the implementation behind it does not need to change.

- **A:** Renaming is an interface change; the behaviour behind the name is untouched.
- **B:** There is no selection habit to clear; the model reads the tool definitions afresh each request.
- **D:** The lesson pairs the rename with a specific description; names alone are not the selection mechanism.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 114. Keyword-sensitive system prompt instructions can override well-written tool descriptions

`claude-2-1-12`

You rewrite two tool descriptions to production grade, yet customer-related phrasings keep reaching the wrong tool. Which cause does the lesson point to?

- **A.** Tool descriptions are cached by the client, so the text from before the rewrite is still being sent.
- **B.** The model weighs tool names more heavily than descriptions whenever a request carries both of them.
- **C.** Descriptions running beyond three sentences are truncated before the model ever gets to see them.
- **D.** A keyword-sensitive system prompt instruction is creating a tool association that overrides them.

<details>
<summary>Reveal answer</summary>

**D. A keyword-sensitive system prompt instruction is creating a tool association that overrides them.**

Keyword-sensitive system prompt instructions can silently override well-written descriptions, so the prompt has to be reread after any description rewrite.

- **A:** The lesson describes no such caching; it points at a conflict inside the prompt.
- **B:** Descriptions are the primary selection mechanism, not a tiebreaker behind names.
- **C:** No such truncation exists; production-grade descriptions are expected to run several sentences.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 115. Descriptions are not the fix past roughly 4-5 tools, where selection degrades on decision 

`claude-2-1-13`

An agent holds twenty-two tools and picks the wrong one frequently. Why is rewriting all twenty-two descriptions the wrong remedy?

- **A.** Past roughly four or five tools the failure is decision complexity, which better wording does not reduce.
- **B.** Descriptions stop influencing selection once a request carries more than ten tool definitions.
- **C.** Requests are rejected when every tool description runs to several sentences.
- **D.** Rewritten descriptions only take effect after the agent's session restarts from scratch.

<details>
<summary>Reveal answer</summary>

**A. Past roughly four or five tools the failure is decision complexity, which better wording does not reduce.**

Descriptions fix misrouting when a small toolkit contains two lookalike tools; with twenty-two tools the problem is decision complexity, which rewriting does not touch.

- **B:** There is no such cutoff; descriptions still matter, they simply cannot carry a toolkit this large.
- **C:** No length limit forces this; the objection is that rewriting leaves the decision complexity intact.
- **D:** Definitions are sent with each request, so a rewrite applies immediately; that is not the issue.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 116. Selection accuracy is validated by re-running a fixed query set before and after a descrip

`claude-2-1-14`

You want evidence that weak descriptions, rather than the model, caused the misrouting. What does the lesson's exercise have you do?

- **A.** Run the same toolkit against a second model and keep whichever one routes more accurately.
- **B.** Run a fixed set of queries before and after the rewrite and compare which tool was chosen each time.
- **C.** Count the tokens each description contributes and keep the rewrite only if the total falls.
- **D.** Ask the model to justify each choice afterwards and treat the justification as ground truth.

<details>
<summary>Reveal answer</summary>

**B. Run a fixed set of queries before and after the rewrite and compare which tool was chosen each time.**

Logging which tool is selected for a fixed query set before and after the rewrite gives concrete evidence that description quality drove the change.

- **A:** Swapping models tests the model, not the hypothesis that the descriptions were at fault.
- **C:** Production-grade descriptions are longer; token count is not the measure of success here.
- **D:** A self-reported rationale is not evidence of selection accuracy against known-correct answers.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 117. Tool descriptions are the primary mechanism an LLM uses to select a tool, not supplementar

`claude-2-1-15`

What role does a tool's description play when a model decides which tool to call?

- **A.** It is metadata for human reviewers, while selection is driven by the input schema's field names.
- **B.** It is consulted only to break ties when two tools accept identical argument types.
- **C.** It is the primary signal the model reads when choosing among the tools it has been given.
- **D.** It is attached to the result so the model can verify afterwards that its choice was right.

<details>
<summary>Reveal answer</summary>

**C. It is the primary signal the model reads when choosing among the tools it has been given.**

Tool descriptions are the primary mechanism a model uses for tool selection, which is why weak ones produce misrouting.

- **A:** Descriptions are not supplementary documentation; they are what the model reads to choose.
- **B:** The description is the main input to every selection decision, not a tiebreaker.
- **D:** Descriptions are presented before the call, as part of the tool definition, not with the result.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-1-tool-schema-design) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

## 2.2 — Structured Error Responses

### 118. The MCP isError flag signals that tool execution failed, so the model can reason about rec

`claude-2-2`

An MCP tool reaches its backend, but the requested operation is denied. How should the result support recovery?

- **A.** Return a tool error with a clear permission-failure category in application metadata.
- **B.** Return an empty success result to avoid interrupting the model.
- **C.** Return a success message and place the failure only in a private log.
- **D.** Repeat the same denied operation until the tool returns data.

<details>
<summary>Reveal answer</summary>

**A. Return a tool error with a clear permission-failure category in application metadata.**

The caller needs to distinguish an operation failure from a successful result.

- **B:** Empty success hides the access failure.
- **C:** The orchestrator cannot act on evidence it does not receive.
- **D:** An unchanged request does not repair missing permission.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture)

### 119. Validation failure

`claude-2-2-2`

A tool rejects an invalid date argument. What is the appropriate recovery?

- **A.** Treat the response as an empty valid search.
- **B.** Raise the maximum output tokens.
- **C.** Correct the argument using the tool's validation details.
- **D.** Retry the identical input indefinitely.

<details>
<summary>Reveal answer</summary>

**C. Correct the argument using the tool's validation details.**

Repeating an unchanged invalid request is not a transient-failure strategy.

- **A:** The search did not successfully execute.
- **B:** Output capacity does not correct input syntax.
- **D:** Time does not fix the invalid format.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/specification/2025-06-18/server/tools)

### 120. Retry policy

`claude-2-2-3`

A backend temporarily times out. Which retry policy is defensible?

- **A.** Retry immediately without a limit.
- **B.** Retry every error, including denied access.
- **C.** Hide the failure and return fabricated data.
- **D.** Bound attempts and elapsed time, with delay and safe repeat semantics.

<details>
<summary>Reveal answer</summary>

**D. Bound attempts and elapsed time, with delay and safe repeat semantics.**

A transient fault may recover, but retries still need limits and side-effect awareness.

- **A:** That can amplify the failure and exhaust resources.
- **B:** Different failure classes need different recovery.
- **C:** That produces false success instead of recovery.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/specification/2025-06-18/server/tools)

### 121. Protocol versus domain error

`claude-2-2-4`

Which distinction matters when reporting an MCP tool failure?

- **A.** Protocol failures differ from failures inside a successfully invoked tool.
- **B.** Every backend rejection must be reported as successful text.
- **C.** Custom retry categories are mandatory MCP envelope fields.
- **D.** A tool error necessarily means the MCP server is unreachable.

<details>
<summary>Reveal answer</summary>

**A. Protocol failures differ from failures inside a successfully invoked tool.**

Tool execution errors can be represented with isError; malformed protocol requests are a different layer.

- **B:** That hides the failure signal.
- **C:** Application metadata must not be mistaken for protocol-required fields.
- **D:** The server can be reachable while the operation fails.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/specification/2025-06-18/server/tools)

### 122. The four error categories are transient, validation, business and permission

`claude-2-2-5`

Which set names the four tool-failure categories the exam guide uses?

- **A.** Transient, syntax, network, and fatal.
- **B.** Retryable, non-retryable, partial, and unknown.
- **C.** Client, server, protocol, and application.
- **D.** Transient, validation, business, and permission.

<details>
<summary>Reveal answer</summary>

**D. Transient, validation, business, and permission.**

The guide names transient, validation, business and permission, because each one demands a different recovery action.

- **A:** Syntax, network and fatal are not the guide's categories; they cut across the four it defines.
- **B:** Retryability is a boolean attached to a category, not a category in its own right.
- **C:** This is a layer taxonomy, not the recovery-oriented categories the guide names.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture)

### 123. Business errors are policy violations that never resolve by retrying; escalate or take ano

`claude-2-2-6`

A refund tool rejects a request for 750 because automatic refunds stop at 500. How should the calling agent respond?

- **A.** Treat it as a business error, skip the retry entirely, and escalate with the refund details.
- **B.** Retry twice after a short delay, since the limit may be recalculated between attempts.
- **C.** Resend the same amount under a different customer identifier to clear the check.
- **D.** Report it as a validation error and ask the user to reformat the refund request.

<details>
<summary>Reveal answer</summary>

**A. Treat it as a business error, skip the retry entirely, and escalate with the refund details.**

Refund limits are business errors: the request is technically valid but breaks a policy, so the agent escalates rather than retries.

- **B:** Business errors never resolve through retrying; the same violation recurs each time.
- **C:** Changing the identifier does not change the policy and misrepresents the request.
- **D:** The request is well formed; it violates a business rule rather than an input contract.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture)

### 124. isRetryable answers only whether resending this exact call can work; only transient is tru

`claude-2-2-7`

What question does the isRetryable flag answer?

- **A.** Whether the caller rather than the service was responsible for the failure.
- **B.** Whether resending this exact request, unchanged, could succeed.
- **C.** Whether the agent should continue working on the task at all.
- **D.** Whether the tool has side effects that make a second call unsafe.

<details>
<summary>Reveal answer</summary>

**B. Whether resending this exact request, unchanged, could succeed.**

isRetryable answers only whether resending the identical call can work, so transient failures are true and every other category is false.

- **A:** Fault attribution is implied by the category, not by this boolean.
- **C:** A false value never means abandon the task; validation errors are recovered by the agent unaided.
- **D:** Side-effect safety is a separate retry concern and is not what the flag encodes.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture)

### 125. Validation errors mean malformed input: correct the argument and send a new call

`claude-2-2-8`

A tool rejects the value 'order-abc' because order IDs must take the form #NNNNN. Which combination is correct?

- **A.** isRetryable true, because the agent is able to recover from the failure on its own.
- **B.** isRetryable true, because the format check may pass on a subsequent attempt.
- **C.** isRetryable false, though the agent still recovers by correcting the ID and issuing a new call.
- **D.** isRetryable false, which means the task should be handed to a human reviewer.

<details>
<summary>Reveal answer</summary>

**C. isRetryable false, though the agent still recovers by correcting the ID and issuing a new call.**

Validation errors are isRetryable false because the same call fails identically, but errorCategory and the description let the agent fix the input itself.

- **A:** Agent recoverability is not what the flag measures; resending this exact call still fails.
- **B:** The same string fails the same check every time, so nothing changes on a retry.
- **D:** That reading confuses validation with business and permission errors, the two that need another party.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture)

### 126. A successful query with no matches is a valid empty result: isError false, resultCount 0, 

`claude-2-2-9`

A customer lookup runs successfully against the database and matches nobody. What should the tool return?

- **A.** isError true with errorCategory validation, echoing the search terms that were supplied.
- **B.** isError true with errorCategory transient, so the agent can attempt the query again later.
- **C.** isError true with an empty content array, leaving the agent to infer that nothing matched.
- **D.** isError false, text stating the query ran and found no matches, and a result count of zero.

<details>
<summary>Reveal answer</summary>

**D. isError false, text stating the query ran and found no matches, and a result count of zero.**

A successful query that matches nothing is a valid empty result: isError false, an explicit statement that the query ran, and a zero result count.

- **A:** Nothing about the input was malformed; the query was valid and simply matched no rows.
- **B:** Marking a successful query as transient is exactly what triggers the wasted retry loop.
- **C:** Any isError true response tells the agent execution failed, which is not what happened.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture)

### 127. Confusing access failure with a valid empty result causes wasted retries and false escalat

`claude-2-2-10`

An agent retries a contact lookup three times and then escalates to a human, and investigation shows the contact was never in the database. What is the root cause?

- **A.** The tool's empty response is shaped like a failure, so the agent reads no matches as retriable.
- **B.** The retry ceiling is too low, so the lookup never gets enough attempts to surface the record.
- **C.** The escalation threshold fires too early and should wait for further retry attempts first.
- **D.** The agent should never retry a lookup at all, so every miss ought to reach a human at once.

<details>
<summary>Reveal answer</summary>

**A. The tool's empty response is shaped like a failure, so the agent reads no matches as retriable.**

Confusing a valid empty result with an access failure is the canonical anti-pattern: the tool has to make the two responses structurally different.

- **B:** More attempts return the same empty result; the record does not exist.
- **C:** Escalation timing is not the issue; the escalation should never have been reached.
- **D:** Blanket escalation would send genuine no-match answers to humans and drop legitimate transient retries.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture)

### 128. CallToolResult defines only content, structuredContent and isError; errorCategory/isRetrya

`claude-2-2-11`

Where do errorCategory, isRetryable and description belong in an MCP tool result?

- **A.** In dedicated envelope fields that CallToolResult defines alongside isError.
- **B.** In structuredContent, as an application-level convention layered on top of the protocol.
- **C.** In the JSON-RPC error object that replaces the tool result when a call fails.
- **D.** In the tool's input schema, so the model can read them before deciding to call.

<details>
<summary>Reveal answer</summary>

**B. In structuredContent, as an application-level convention layered on top of the protocol.**

CallToolResult defines only content, structuredContent and isError, so the error metadata rides in structuredContent as an application-level convention.

- **A:** The protocol result defines only content, structuredContent and isError; these three are not envelope fields.
- **C:** That object is for protocol-level failures, not for a tool that ran and reported a failure.
- **D:** The input schema describes arguments; error metadata is produced by the call, not declared ahead of it.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture)

### 129. Generic messages such as 'Operation failed' leave the agent unable to choose a recovery

`claude-2-2-12`

A tool fails and returns the text 'Operation failed' with no other detail. What does the calling agent lose?

- **A.** Any way to see which tool produced the failure in the first place.
- **B.** Any way to present the failure to the user in readable language.
- **C.** Any basis for deciding whether to retry, correct the input, or take an entirely different path.
- **D.** Any record that the call happened, since untyped errors are dropped from the history.

<details>
<summary>Reveal answer</summary>

**C. Any basis for deciding whether to retry, correct the input, or take an entirely different path.**

Generic messages strip out the metadata that lets an agent distinguish a transient timeout from a policy violation and choose the right recovery.

- **A:** The tool-use identity is preserved regardless of how uninformative the message is.
- **B:** The agent can relay the message; what it cannot do is choose a recovery.
- **D:** The call and its result stay in the conversation; only the diagnostic detail is missing.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture)

### 130. Propagated errors must carry partial results and what was attempted

`claude-2-2-13`

A research subagent queried five sources, and two of them still timed out after its own retries. What should it report upward?

- **A.** A success carrying the three results, since the coordinator consumes only finished findings.
- **B.** A single failure for the whole step, so the coordinator can restart it from the beginning.
- **C.** An empty result, leaving the coordinator to decide whether the step should run again.
- **D.** The three results it did obtain, together with which sources failed and what it had already attempted.

<details>
<summary>Reveal answer</summary>

**D. The three results it did obtain, together with which sources failed and what it had already attempted.**

Local recovery first, then selective propagation: report what succeeded, what failed and what was already tried, so the coordinator is not deciding blind.

- **A:** Reporting partial work as complete success hides the failure and misleads the coordinator.
- **B:** Discarding three successful results terminates a workflow over a partial failure.
- **C:** Silently suppressing the error as an empty result is the anti-pattern the lesson warns against.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture)

### 131. Transient errors (timeouts, unavailability, rate limits) are retryable after a delay, with

`claude-2-2-14`

In a multi-agent system, which failures should a subagent resolve itself before involving the coordinator?

- **A.** Transient failures such as a timed-out search, which it retries locally before escalating.
- **B.** Permission failures, by retrying under whichever credentials it happens to be able to reach.
- **C.** Business-rule failures, by relaxing the rule far enough that the call is accepted.
- **D.** Every failure it encounters, so the coordinator never has to reason about tool errors.

<details>
<summary>Reveal answer</summary>

**A. Transient failures such as a timed-out search, which it retries locally before escalating.**

Subagents recover locally from transient faults and propagate only what they cannot resolve themselves.

- **B:** Permission errors need a different principal, which is a decision above the subagent.
- **C:** A subagent must not weaken a policy constraint; those failures escalate.
- **D:** Suppressing unresolvable failures leaves the coordinator making decisions without the facts.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture)

### 132. Permission errors need a different principal: escalate or use credentials with the require

`claude-2-2-15`

A tool returns access denied because the service account cannot read financial records. What recovery does the lesson prescribe?

- **A.** Retry after a short delay, since credential checks often clear on a second attempt.
- **B.** Escalate, or reissue the call as a principal that holds the required access.
- **C.** Reformat the request arguments and resend the same call under the same account.
- **D.** Return an empty result so the surrounding workflow can carry on without the data.

<details>
<summary>Reveal answer</summary>

**B. Escalate, or reissue the call as a principal that holds the required access.**

Permission errors are resolved by a different principal: escalate, or retry with credentials that carry the required access.

- **A:** Permission errors are not retryable; the same account is refused every time.
- **C:** The arguments were fine; the account lacked authorisation.
- **D:** That disguises a failure as a valid empty result, the exact confusion the lesson warns about.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-2-structured-error-responses) · [Technical reference](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture)

## 2.3 — Tool Distribution & Tool Choice

### 133. Tool overload degrades selection; 18 tools on one agent is the named anti-pattern

`claude-2-3`

A read-only summarizer has been given search, write, billing and reporting tools. What is the best first change?

- **A.** Select a fixed tool count without considering the task.
- **B.** Expose the tools required by its task and enforce read-only permissions.
- **C.** Keep all tools and mention read-only behavior only in its prompt.
- **D.** Add a second copy of each read tool to make reads more prominent.

<details>
<summary>Reveal answer</summary>

**B. Expose the tools required by its task and enforce read-only permissions.**

Role-appropriate capability limits reduce unnecessary choices and side effects.

- **A:** A count is not a substitute for relevant capability design.
- **C:** Guidance alone does not remove executable write capabilities.
- **D:** Duplicating choices increases ambiguity.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 134. Forced selection

`claude-2-3-2`

After a required first tool call, the next turn should allow normal decisions. What should change?

- **A.** Treat the forced call as proof that its result was valid.
- **B.** Use an appropriate flexible tool_choice on the next request.
- **C.** Force the same tool on every later request.
- **D.** Delete the first tool result from history.

<details>
<summary>Reveal answer</summary>

**B. Use an appropriate flexible tool_choice on the next request.**

Tool choice applies to requests; repeatedly forcing the same operation can create a loop.

- **A:** Selection does not validate execution or content.
- **C:** That conflicts with the requested flexible continuation.
- **D:** The model still needs that observation.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 135. Discoverability

`claude-2-3-3`

Moving an unchanged collection of tools to another server does not improve selection. Why?

- **A.** Every server can expose only one tool.
- **B.** The model automatically forgets tools on older servers.
- **C.** The model may still receive the same ambiguous tool interfaces.
- **D.** Server names always override all tool descriptions.

<details>
<summary>Reveal answer</summary>

**C. The model may still receive the same ambiguous tool interfaces.**

Server placement alone does not clarify names, contracts or relevance.

- **A:** MCP does not impose that general restriction.
- **B:** That behavior cannot be assumed.
- **D:** Selection depends on the exposed interfaces and context.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 136. Scoped capability

`claude-2-3-4`

A worker needs approved-document lookup but not arbitrary network access. Which tool fits?

- **A.** A universal URL fetcher with a polite warning.
- **B.** An unrestricted shell with a document-search example.
- **C.** A tool that copies all documents into every response.
- **D.** A document lookup restricted to the authorized collection.

<details>
<summary>Reveal answer</summary>

**D. A document lookup restricted to the authorized collection.**

A narrow capability encodes the intended access boundary.

- **A:** A warning does not enforce collection restrictions.
- **B:** That exposes much more capability than the task requires.
- **C:** That creates unnecessary disclosure and context volume.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)

### 137. Tool overload degrades selection; 18 tools on one agent is the named anti-pattern

`claude-2-3-5`

What tool count per agent does the lesson give as the target?

- **A.** One tool per agent, with a coordinator assembling every multi-step task from them.
- **B.** Ten to twelve tools, which keeps most workflows inside one agent.
- **C.** Four to five tools, each scoped to that agent's defined role.
- **D.** As many as the context window allows, since unused tools only cost tokens.

<details>
<summary>Reveal answer</summary>

**C. Four to five tools, each scoped to that agent's defined role.**

The lesson puts the optimal range at four to five tools per agent, scoped to that agent's role.

- **A:** Splitting to a single tool each multiplies coordination overhead well beyond what the lesson advises.
- **B:** Selection reliability is already degrading well before this range.
- **D:** Every extra tool adds decision complexity, so the cost is selection accuracy, not just tokens.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 138. Relevance matters as much as count: out-of-role tools get misused and duplicate work

`claude-2-3-6`

Why should a synthesis agent be denied a web search tool, even when its toolkit is well under the limit?

- **A.** Search tools cannot function for an agent that has not also been given a fetch tool.
- **B.** Two agents in one system are not permitted to expose the same tool name.
- **C.** Search results are too large to hand between agents without truncating them.
- **D.** It will tend to run its own searches instead of using the results it was handed, duplicating work.

<details>
<summary>Reveal answer</summary>

**D. It will tend to run its own searches instead of using the results it was handed, duplicating work.**

Relevance matters as much as count: an agent handed a capability outside its role tends to use it, duplicating work and burning context.

- **A:** Nothing technically prevents it; the objection is behavioural.
- **B:** Tool names may repeat across agents; scoped cross-role tools rely on exactly that.
- **C:** Payload size is not the reason; the lesson is about misuse of out-of-role capability.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 139. Near-duplicate tools sharing one shape consolidate into a single parameterised tool with a

`claude-2-3-7`

A data platform server exposes three query tools plus nineteen transformation tools that all take a dataset, apply one operation, and return data. What is the right fix?

- **A.** Collapse the nineteen into one transform_data tool whose transform_type enum selects the operation.
- **B.** Give a dedicated transformation agent all nineteen tools so every agent keeps to one role.
- **C.** Move the transformation tools to a second MCP server so the client presents two smaller sets.
- **D.** Rewrite all nineteen descriptions with inputs, examples, and boundaries against one another.

<details>
<summary>Reveal answer</summary>

**A. Collapse the nineteen into one transform_data tool whose transform_type enum selects the operation.**

Nineteen near-identical transformations share a shape, so they collapse into one parameterised tool and every operation stays reachable as an enum value.

- **B:** Splitting by role here just relocates a nineteen-tool selection problem one level down.
- **C:** Server boundaries are invisible to the model, which still receives one flat list.
- **D:** Description quality cannot rescue selection once decision complexity is the binding constraint.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 140. Misrouting among ~5 tools is a description problem; the same symptom at 22 tools is decisi

`claude-2-3-8`

Two agents both misroute. One is choosing among five tools, the other among twenty-two. What does the lesson say about the remedies?

- **A.** Both are description problems, because tool selection always reduces to how clearly the tools are described.
- **B.** The five-tool case is a description problem; the twenty-two-tool case is complexity and needs fewer tools.
- **C.** Both are overload problems, since misrouting only ever appears once a toolkit has passed four or five tools.
- **D.** The five-tool case needs forced tool choice, and the twenty-two-tool case needs much richer descriptions.

<details>
<summary>Reveal answer</summary>

**B. The five-tool case is a description problem; the twenty-two-tool case is complexity and needs fewer tools.**

Same symptom, different disease: ambiguity among a handful of tools is fixed by descriptions, while a twenty-two-tool toolkit has to shrink.

- **A:** The same symptom has two different diseases, and only one of them is an ambiguity problem.
- **C:** A five-tool agent that cannot tell two lookalike tools apart has an ambiguity problem, not overload.
- **D:** This reverses both remedies and forces a tool where clearer wording was the fix.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 141. Consolidation shrinks the choice while constraining shrinks the reach; consolidation does 

`claude-2-3-9`

Does collapsing nineteen transformations into one parameterised tool weaken least privilege?

- **A.** Yes, because a single tool that accepts an enum can reach operations the agent could not previously reach.
- **B.** Yes, because least privilege requires one tool for each distinct operation an agent is permitted to perform.
- **C.** No, the agent gains no new capability: consolidation shrinks the choice, constraining shrinks the reach.
- **D.** No, because least privilege governs MCP server boundaries rather than individual tool definitions.

<details>
<summary>Reveal answer</summary>

**C. No, the agent gains no new capability: consolidation shrinks the choice, constraining shrinks the reach.**

Every one of those operations was reachable before the merge, so no privilege is added. Shrinking the menu and shrinking a tool's reach are separate moves.

- **A:** Every one of those operations was already reachable as its own tool; nothing new is granted.
- **B:** Least privilege constrains what can be reached, not how many tool definitions express it.
- **D:** Least privilege applies directly to tool design, as the fetch_url and load_document example shows.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 142. tool_choice auto is the default: the model decides between a tool call and text

`claude-2-3-10`

Which description matches tool_choice set to auto?

- **A.** The model has to call a tool, and the caller names in advance which tool that will be.
- **B.** The model has to call a tool but is free to pick which one it calls.
- **C.** The model is prevented from calling tools and must answer in text.
- **D.** The model decides for itself whether to call a tool or reply in text.

<details>
<summary>Reveal answer</summary>

**D. The model decides for itself whether to call a tool or reply in text.**

'auto' is the default: the model chooses between calling a tool and returning text.

- **A:** That is forced selection, which pins the call to one named tool.
- **B:** That is the 'any' setting, which guarantees a tool call without naming the tool.
- **C:** None of the three settings blocks tool use in this way.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 143. tool_choice any forces a tool call while letting the model pick, which guarantees structur

`claude-2-3-11`

An extraction pipeline holds separate schemas for invoices, receipts and contracts, and the document type is unknown when the call is made. Which setting guarantees structured output?

- **A.** tool_choice 'any', which compels a tool call while leaving the schema choice to the model.
- **B.** tool_choice 'auto', which lets the model answer in prose whenever no schema quite fits.
- **C.** Forced selection of the invoice tool, with the model correcting the type inside its arguments.
- **D.** Three sequential requests, one per schema, keeping whichever result happens to parse.

<details>
<summary>Reveal answer</summary>

**A. tool_choice 'any', which compels a tool call while leaving the schema choice to the model.**

'any' forces a tool call while letting the model select among the schemas, which is what an extraction pipeline with an unknown document type needs.

- **B:** Under 'auto' the model may return text, which is exactly the failure to avoid here.
- **C:** Forcing the wrong schema produces structured output in the wrong shape.
- **D:** This triples cost and still does not guarantee the model calls a tool on any given request.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 144. Forced selection names a specific tool and enforces a mandatory first step

`claude-2-3-12`

Metadata extraction has to run before any enrichment tool. How do you guarantee the ordering?

- **A.** State the ordering in the system prompt and rely on the model to follow the stated sequence.
- **B.** Set tool_choice to the tool type naming extract_metadata on the first request.
- **C.** Set tool_choice to 'any', which makes the model call whichever tool is listed first.
- **D.** Withhold the enrichment tools until extraction returns, then add them back mid-turn.

<details>
<summary>Reveal answer</summary>

**B. Set tool_choice to the tool type naming extract_metadata on the first request.**

Forced selection, tool_choice with type tool and the tool's name, is the mechanism for enforcing a mandatory first step.

- **A:** A prompt instruction is guidance, not a guarantee; the model can still skip or reorder.
- **C:** 'any' guarantees a call but not which tool, and list order does not decide it.
- **D:** Tools are declared per request; juggling the toolkit is neither the documented nor the simplest mechanism.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 145. Scoped cross-role tools handle the high-frequency simple case locally, avoiding 2-3 coordi

`claude-2-3-13`

A synthesis agent bounces every fact check back to the coordinator, adding two or three hops and around 40% latency, and 85% of those checks are simple single-source lookups. What is the best fix?

- **A.** Strip fact checking out of the synthesis stage so the workflow no longer pays for verification hops.
- **B.** Let the coordinator serve verification requests concurrently so the queue behind them clears faster.
- **C.** Hand the synthesis agent a narrow verification tool it calls itself for single-source checks, escalating the rest.
- **D.** Keep a verification cache on the coordinator so a check already answered once comes back immediately.

<details>
<summary>Reveal answer</summary>

**C. Hand the synthesis agent a narrow verification tool it calls itself for single-source checks, escalating the rest.**

A scoped cross-role tool handles the high-frequency simple case directly, leaving the coordinator round trip for the complex minority.

- **A:** Removing the check trades latency for unverified output, which is not a fix at all.
- **B:** Concurrency does nothing about the extra hops each individual request still has to make.
- **D:** A cache helps only on repeats; a first-time simple lookup still pays for the whole round trip.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 146. The coordinator holds only workflow tools (spawn subagents, review output, request revisio

`claude-2-3-14`

In the lesson's multi-agent research system, what does the coordinator's own toolset look like?

- **A.** Every tool in the system, so it can take over any step a subagent leaves unfinished.
- **B.** The union of the search and analysis toolsets, minus the synthesis tools.
- **C.** Only search tools, on the grounds that coordination is mostly evidence gathering.
- **D.** Workflow tools: spawning subagents, reviewing their output, and requesting revisions.

<details>
<summary>Reveal answer</summary>

**D. Workflow tools: spawning subagents, reviewing their output, and requesting revisions.**

The coordinator carries only workflow tools such as subagent spawning, output review and revision requests, and no domain-specific capability.

- **A:** That recreates the overload problem in the one agent that most needs clear decisions.
- **B:** The coordinator holds no domain tools at all, let alone most of them.
- **C:** Search belongs to the web search agent; the coordinator does not gather evidence itself.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

### 147. Splitting by role is wrong when the tools are variations of one job; splitting fits genuin

`claude-2-3-15`

An agent's toolkit covers genuinely distinct jobs, querying, transforming and exporting, and there are far too many tools in total. Which remedy does the lesson's table give?

- **A.** Split the tools across agents by role, giving each roughly four or five.
- **B.** Collapse them into a single parameterised tool whose enum selects the job.
- **C.** Expand every description with inputs, examples and explicit boundaries.
- **D.** Register each job's tools on its own MCP server so the sets are presented separately.

<details>
<summary>Reveal answer</summary>

**A. Split the tools across agents by role, giving each roughly four or five.**

Tools that do different jobs split by role, with roughly four or five per agent; consolidation is reserved for variations on a single job.

- **B:** Consolidation is for variations on one job that share a shape, not for genuinely different jobs.
- **C:** Descriptions cure ambiguity in a small toolkit, not a toolkit that is simply too large.
- **D:** The client flattens every server's tools into one list, so the agent's choice is unchanged.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-3-tool-distribution-choice) · [Technical reference](https://code.claude.com/docs/en/agent-sdk/subagents)

## 2.4 — MCP Server Integration

### 148. Project-level .mcp.json at the repo root is version-controlled and shared with the team

`claude-2-4`

A team needs a shared Claude Code MCP server definition without committing personal credentials. Which setup fits?

- **A.** Place the server URL only in a prose instruction file.
- **B.** Require every developer to copy credentials from the shared README.
- **C.** Version a project .mcp.json and obtain credentials through an appropriate private mechanism.
- **D.** Commit one developer's complete personal Claude configuration.

<details>
<summary>Reveal answer</summary>

**C. Version a project .mcp.json and obtain credentials through an appropriate private mechanism.**

Share the connection definition while keeping personal secrets out of source control.

- **A:** Instructions do not register the server connection.
- **B:** Publishing credentials is not a private authentication mechanism.
- **D:** That can expose private settings and credentials unrelated to the project.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 149. Transport configuration

`claude-2-4-2`

What distinguishes a typical local stdio MCP connection from a remote HTTP one?

- **A.** The local entry launches a process; the remote entry specifies the supported network transport and endpoint.
- **B.** Both require placing access tokens inside CLAUDE.md.
- **C.** A local process is identified only by a public HTTPS URL.
- **D.** The remote entry is configured as a local executable regardless of server type.

<details>
<summary>Reveal answer</summary>

**A. The local entry launches a process; the remote entry specifies the supported network transport and endpoint.**

Transport configuration must match how the server communicates.

- **B:** Instruction files are not an appropriate secret configuration mechanism.
- **C:** That describes a network endpoint rather than launching stdio.
- **D:** Using the wrong transport prevents the intended connection.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 150. Shared configuration

`claude-2-4-3`

A shared MCP definition exists, but a teammate cannot access the service. What else may be required?

- **A.** Assuming a committed definition bypasses server-side policy.
- **B.** Workspace trust, connection approval and that teammate's authentication or service permissions.
- **C.** Copying another teammate's private tokens into version control.
- **D.** Running a memory-inspection command to authorize the server.

<details>
<summary>Reveal answer</summary>

**B. Workspace trust, connection approval and that teammate's authentication or service permissions.**

Sharing connection metadata does not share or grant every user's access.

- **A:** The server still controls access to its resources.
- **C:** That is not a proper access setup.
- **D:** Memory inspection is not service authorization.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 151. Secret handling

`claude-2-4-4`

A project MCP definition needs a token on each developer's machine. Which arrangement fits?

- **A.** Encode the token with Base64 and commit it.
- **B.** Write the token into generated answer explanations.
- **C.** Reference privately supplied credentials through supported configuration.
- **D.** Commit a long-lived token as a convenience default.

<details>
<summary>Reveal answer</summary>

**C. Reference privately supplied credentials through supported configuration.**

Share the definition while provisioning secrets separately.

- **A:** Encoding does not make a credential secret.
- **B:** Output text is not an appropriate credential store.
- **D:** Source control would distribute the credential.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 152. Evaluate community MCP servers first for standard integrations such as Jira or GitHub

`claude-2-4-5`

An engineering team is standing up issue-tracker access for their Claude Code setup, and one developer volunteers to write the server from scratch. Where should they start?

- **A.** Skip MCP and call the Jira REST API from shell commands, avoiding server configuration entirely.
- **B.** Evaluate the maintained community Jira servers first, and build only if team workflows need more.
- **C.** Build the custom server so the tool surface matches exactly the endpoints this team uses.
- **D.** Add Jira to each developer's user-level configuration so everyone connects independently.

<details>
<summary>Reveal answer</summary>

**B. Evaluate the maintained community Jira servers first, and build only if team workflows need more.**

For standard integrations the pragmatic answer is always to evaluate community servers first and build custom only when they cannot meet team-specific needs.

- **A:** This abandons the integration layer the question is about and gives up tool discovery and scoping.
- **C:** Custom work is justified only when community servers cannot meet specific team requirements.
- **D:** This is a scoping answer to a build-versus-use question, and it also fragments a team-wide server.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 153. Custom servers are justified only by team-specific workflows, custom business logic, or pr

`claude-2-4-6`

Which situation justifies building a custom MCP server rather than adopting a community one?

- **A.** The community server is maintained by volunteers instead of by the vendor.
- **B.** The team would prefer a different naming convention for the exposed tools.
- **C.** The integration targets a proprietary internal system for which no community server exists.
- **D.** The community server exposes more tools than the team expects to actually use.

<details>
<summary>Reveal answer</summary>

**C. The integration targets a proprietary internal system for which no community server exists.**

Custom servers are justified by team-specific workflows, custom business logic, or proprietary systems with no community equivalent.

- **A:** Maintenance model alone is not the criterion; community servers are the default for standard integrations.
- **B:** Cosmetic preferences do not justify the development and maintenance burden of a custom build.
- **D:** An oversized tool surface is handled by scoping what the agent receives, not by rewriting the server.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 154. A url with no type is a configuration error: read as stdio, skipped, with a prompt to add 

`claude-2-4-7`

A .mcp.json entry supplies a url but omits the type field. What does Claude Code do with it?

- **A.** It infers HTTP from the presence of a url and connects to the remote endpoint as normal.
- **B.** It connects anyway but withholds the server's tools until a type is added later.
- **C.** It rejects the entire file, so none of the project's configured servers load.
- **D.** It reads the entry as a stdio server, skips it, and tells you to add the type.

<details>
<summary>Reveal answer</summary>

**D. It reads the entry as a stdio server, skips it, and tells you to add the type.**

Without a type field the entry is treated as a local launcher, so the server never connects and you are told to declare its transport.

- **A:** No such inference happens; the missing type is treated as a configuration error.
- **B:** The server is not connected at all, so there are no withheld tools.
- **C:** Only the malformed entry is skipped; the rest of the configuration still loads.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 155. All tools from all configured, reachable servers are discovered at connection time with no

`claude-2-4-8`

How do tools from configured MCP servers become available to an agent?

- **A.** Every reachable server's tools are discovered at connection time and usable at once.
- **B.** Each server has to be activated within the session before its tools enter the toolkit.
- **C.** Project-level servers load automatically while user-level ones load on first use.
- **D.** Tools appear only after the model requests them by name through a listing call.

<details>
<summary>Reveal answer</summary>

**A. Every reachable server's tools are discovered at connection time and usable at once.**

All tools from all configured and reachable servers, project-level and user-level, are discovered at connection time and available simultaneously.

- **B:** No activation step exists in the model the lesson describes.
- **C:** Both scopes are discovered the same way; the difference between them is sharing, not loading.
- **D:** Tool listing is a protocol detail handled by the client, not something the model triggers per tool.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 156. ${VAR:-default} expands to the variable when set and the default when unset

`claude-2-4-9`

What does ${WORKSPACE_ROOT:-.} do when it appears in a .mcp.json argument?

- **A.** It expands only when WORKSPACE_ROOT is unset, substituting the current directory in that case.
- **B.** It expands to WORKSPACE_ROOT when that variable is set, and falls back to the current directory otherwise.
- **C.** It expands to both values, passing the variable and the directory as two separate arguments.
- **D.** It requires WORKSPACE_ROOT to be set and checks that it resolves to the current directory.

<details>
<summary>Reveal answer</summary>

**B. It expands to WORKSPACE_ROOT when that variable is set, and falls back to the current directory otherwise.**

${VAR:-default} expands to the variable when set and to the default when it is not, which suits machine-specific paths.

- **A:** The logic is the other way round: the variable wins when it is set.
- **C:** Expansion produces one value, not a pair of arguments.
- **D:** The form exists precisely so an unset variable is tolerated.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 157. An unset variable with no default warns and lets loading continue, so it fails quietly

`claude-2-4-10`

A developer clones the repository but never sets the token that .mcp.json references, and there is no default form on it. What happens?

- **A.** Claude Code refuses to start until every referenced variable has a value.
- **B.** The literal text of the variable reference is sent to the server as the credential.
- **C.** Claude Code warns and carries on loading, so the missing token fails quietly.
- **D.** Every other server in the file is skipped alongside the one that needed the token.

<details>
<summary>Reveal answer</summary>

**C. Claude Code warns and carries on loading, so the missing token fails quietly.**

An unset variable with no default does not halt configuration loading: Claude Code warns and continues, so the failure is quiet.

- **A:** Startup is not blocked by an unset variable.
- **B:** The reference is not passed through verbatim as a credential value.
- **D:** The remaining configuration continues to load; only that server is affected.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 158. MCP resources expose content catalogues (schemas, doc hierarchies, issue lists) to avoid e

`claude-2-4-11`

What problem do MCP resources solve for an agent working against a database server?

- **A.** They let the agent write to the tables without holding a separate write tool in its toolkit.
- **B.** They compress large query results so that considerably more rows fit inside the context window.
- **C.** They authenticate the agent against the database before its very first tool call is issued.
- **D.** They present the schema up front, sparing the agent a round of exploratory listing calls.

<details>
<summary>Reveal answer</summary>

**D. They present the schema up front, sparing the agent a round of exploratory listing calls.**

Resources expose content catalogues such as a database schema up front, so the agent does not spend tool calls discovering what data exists.

- **A:** Resources expose content for reading; acting on data is what tools are for.
- **B:** Resources are catalogues of available content, not a compression mechanism.
- **C:** Authentication is handled by the server's configuration, not by resources.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 159. Resources are application-controlled: the server lists, the client decides when to attach

`claude-2-4-12`

How does the MCP specification describe control over resources?

- **A.** They are application-controlled: the server lists them and the client decides when to attach one to context.
- **B.** They are model-controlled: the model pulls in any listed resource whenever it judges it useful.
- **C.** They are server-controlled: the server pushes each resource into the model's context as it changes.
- **D.** They are user-controlled: a resource reaches the model only after a per-message manual approval.

<details>
<summary>Reveal answer</summary>

**A. They are application-controlled: the server lists them and the client decides when to attach one to context.**

Resources are application-controlled: the server lists them, and the client decides when one is attached to the model's context.

- **B:** Model-controlled is the description of tools, not resources.
- **C:** Servers list resources; they do not decide when one enters the model's context.
- **D:** User-controlled describes prompts in the specification, not resources.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 160. Sparse MCP tool descriptions lose selection to richly described built-in tools such as Gre

`claude-2-4-13`

Your MCP server exposes a semantic code search tool described as 'Searches code', and the agent keeps reaching for the built-in Grep instead. Why?

- **A.** Built-in tools are always presented to the model ahead of tools from MCP servers.
- **B.** The model prefers the tool it understands best, and the built-in description is far richer.
- **C.** MCP tools are only considered once the built-in tools have returned no results.
- **D.** Semantic search tools cannot be selected unless the request disables the built-in set.

<details>
<summary>Reveal answer</summary>

**B. The model prefers the tool it understands best, and the built-in description is far richer.**

Sparse MCP tool descriptions lose to the rich descriptions of built-in tools, so they must spell out capabilities, outputs, and when to use them instead.

- **A:** Ordering is not the cause; the model is choosing on the strength of the descriptions.
- **C:** There is no such fallback ordering between built-in and MCP tools.
- **D:** Nothing prevents selection; the description simply gives the model no reason to prefer it.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 161. Project-level .mcp.json at the repo root is version-controlled and shared with the team

`claude-2-4-14`

Which file should hold an MCP server definition that every developer on the team needs?

- **A.** The user-level configuration in each developer's home directory, copied during onboarding.
- **B.** A section of CLAUDE.md, so the connection details sit beside the rest of the project guidance.
- **C.** A .mcp.json at the project root, committed alongside the repository.
- **D.** A shell profile on each machine that exports the server's launch command.

<details>
<summary>Reveal answer</summary>

**C. A .mcp.json at the project root, committed alongside the repository.**

Team-wide servers belong in the version-controlled .mcp.json at the project root; the user-level file is for personal or experimental servers.

- **A:** That scope is personal and unversioned, so team-wide servers drift between machines.
- **B:** CLAUDE.md carries prose guidance; it is not where server definitions are read from.
- **D:** Environment variables carry credentials, not the server definitions themselves.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

### 162. ${VARIABLE} expansion keeps credentials out of version control while the config stays shar

`claude-2-4-15`

What does referencing an environment variable, rather than a literal token, in .mcp.json give a team?

- **A.** A shared team token that the MCP server rotates automatically on everyone's behalf.
- **B.** Encryption of the credential at rest inside the committed configuration file.
- **C.** A hard failure at startup whenever a developer has not yet set the token.
- **D.** A committable file where each developer supplies their own token and rotation needs no edit.

<details>
<summary>Reveal answer</summary>

**D. A committable file where each developer supplies their own token and rotation needs no edit.**

Environment variable expansion keeps the configuration safe to commit, lets each developer authenticate with their own credentials, and makes rotation a local change.

- **A:** Expansion does not create or rotate credentials; each developer supplies their own.
- **B:** The file contains no credential at all, encrypted or otherwise.
- **C:** An unset variable warns and loading continues, so the failure is quiet rather than hard.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-4-mcp-server-integration) · [Technical reference](https://code.claude.com/docs/en/mcp)

## 2.5 — Built-in Tools

### 163. Grep searches file contents; use it for callers, error strings and import statements

`claude-2-5`

You know a function name but not which files reference it. Which search should you start with?

- **A.** Glob for filenames equal to the function name.
- **B.** Write a file with that name and inspect the generated content.
- **C.** Edit the largest source file and look for compilation errors.
- **D.** Grep for the function name in file contents.

<details>
<summary>Reveal answer</summary>

**D. Grep for the function name in file contents.**

The known value is text inside files rather than a filename pattern.

- **A:** Call sites need not have matching filenames.
- **B:** Creating a file does not find existing references.
- **C:** Changing code is unnecessary for locating references.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](None)

### 164. File discovery

`claude-2-5-2`

You need files ending in .spec.ts before reading their contents. Which search fits?

- **A.** Grep for the text '.spec.ts' inside every file.
- **B.** Edit every TypeScript file to identify its role.
- **C.** Run deployment and infer test names from success.
- **D.** Glob with a matching filename pattern.

<details>
<summary>Reveal answer</summary>

**D. Glob with a matching filename pattern.**

This is a path-discovery task.

- **A:** File contents need not include their filenames.
- **B:** Discovery does not require mutation.
- **C:** Deployment is unrelated to locating the files.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](https://code.claude.com/docs/en/best-practices)

### 165. Surgical edits

`claude-2-5-3`

One known expression must change in a file containing unrelated work. What is the most appropriate operation?

- **A.** Read the relevant content and apply a targeted edit.
- **B.** Replace the file from an unverified remembered copy.
- **C.** Append a second complete version below the first.
- **D.** Rename the file and leave the expression unchanged.

<details>
<summary>Reveal answer</summary>

**A. Read the relevant content and apply a targeted edit.**

A bounded change preserves unrelated content and is easy to review.

- **B:** That can discard changes or restore stale code.
- **C:** Duplicating the file does not implement a clean replacement.
- **D:** That does not satisfy the requested behavior change.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](https://code.claude.com/docs/en/best-practices)

### 166. Execution evidence

`claude-2-5-4`

An agent needs to know whether a local test command passes. What provides that evidence?

- **A.** Write 'tests passed' into a report before running them.
- **B.** Execute the command in the correct environment and inspect its result.
- **C.** Predict success from the command's filename.
- **D.** Search the repository for an old 'passed' string.

<details>
<summary>Reveal answer</summary>

**B. Execute the command in the correct environment and inspect its result.**

A test outcome requires an actual run or clearly identified prior evidence.

- **A:** A report does not create verification evidence.
- **C:** A name does not demonstrate execution.
- **D:** An unrelated historical string is not the current result.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](https://code.claude.com/docs/en/best-practices)

### 167. The six built-in tools are Read, Write, Edit, Bash, Grep and Glob

`claude-2-5-5`

Which set lists the built-in Claude Code tools the lesson covers?

- **A.** Read, Write, Edit, Bash, Grep, and Glob.
- **B.** Read, Write, Patch, Shell, Search, and Find.
- **C.** Open, Save, Replace, Execute, Match, and List.
- **D.** Read, Edit, Bash, Grep, Glob, and WebFetch.

<details>
<summary>Reveal answer</summary>

**A. Read, Write, Edit, Bash, Grep, and Glob.**

The lesson covers six built-in tools for codebase work: Read, Write, Edit, Bash, Grep and Glob.

- **B:** Patch, Shell, Search and Find are not the names of the built-in tools.
- **C:** None of these is a built-in tool name.
- **D:** This drops Write and substitutes a tool the lesson does not include in the six.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](None)

### 168. Grep searches file contents; use it for callers, error strings and import statements

`claude-2-5-6`

A developer runs Glob with a pattern built from a function's name to find the code that calls it, and turns up nothing useful. Why?

- **A.** Glob needs an explicit directory, and the search defaulted to the repository root.
- **B.** Glob matches file paths, so it never looks at the code inside the files.
- **C.** Glob only accepts complete filenames, so partial patterns are rejected.
- **D.** Glob skips source directories by default and only searches configuration files.

<details>
<summary>Reveal answer</summary>

**B. Glob matches file paths, so it never looks at the code inside the files.**

Glob matches file paths by naming pattern, so finding callers requires a content search with Grep.

- **A:** The scope is not the problem; the tool is searching the wrong thing entirely.
- **C:** Glob handles wildcard patterns fine; the mismatch is paths versus contents.
- **D:** No such default exists; the tool simply does not read file contents.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](None)

### 169. A non-unique match is a deliberate safety mechanism, not a bug

`claude-2-5-7`

Edit reports that the supplied text matches three locations in a file. What does that tell you?

- **A.** The file changed between the moment it was read and the moment the edit was applied to it.
- **B.** The tool will not edit a file above a certain size without a fresh read of it first.
- **C.** Edit refuses an ambiguous match on purpose, so it never changes the occurrence you did not mean.
- **D.** Edit requires the replacement text to differ in length from the original text it replaces.

<details>
<summary>Reveal answer</summary>

**C. Edit refuses an ambiguous match on purpose, so it never changes the occurrence you did not mean.**

Edit requires a unique anchor and fails on multiple matches on purpose, so it cannot silently change the wrong occurrence.

- **A:** Staleness would be a different error; this one is about ambiguity in the anchor.
- **B:** File size is unrelated to a non-unique match.
- **D:** There is no such constraint on replacement length.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](None)

### 170. The exam's keyed fallback when Edit has no unique anchor is Read then Write

`claude-2-5-8`

On the exam, what is the documented fallback when Edit cannot find unique anchor text?

- **A.** Run the change through Bash with a stream editor instead of a built-in tool.
- **B.** Split the file so each occurrence lands in its own module, then edit one of them.
- **C.** Call Edit repeatedly and keep whichever attempt reports a single replacement.
- **D.** Read the full file, then Write the complete modified version back.

<details>
<summary>Reveal answer</summary>

**D. Read the full file, then Write the complete modified version back.**

The exam guide keys Read plus Write as the fallback when Edit cannot find unique anchor text, even though it costs a file's worth of context.

- **A:** Shelling out is not the documented fallback and gives up the built-in tool's safeguards.
- **B:** Restructuring the code to enable an edit is not a recovery the guide describes.
- **C:** Repeating the same ambiguous call produces the same failure each time.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](None)

### 171. Current Edit docs prefer widening old_string or setting replace_all before falling back to

`claude-2-5-9`

Working in current Claude Code rather than answering an exam item, Edit reports a non-unique match. What does the Edit tool reference give as the cheaper recovery?

- **A.** Widen the search text with surrounding context until it pins one location, or set replace_all to change them all.
- **B.** Read the whole file and Write it back, which resolves the ambiguity in every case you are likely to meet.
- **C.** Remove the duplicate occurrences from the file first so that only a single edit target remains.
- **D.** Pass a line number alongside the search text so the tool knows which of the three matches to take.

<details>
<summary>Reveal answer</summary>

**A. Widen the search text with surrounding context until it pins one location, or set replace_all to change them all.**

Current Edit documentation says to widen the anchor or use replace_all on a non-unique match; the exam still keys Read plus Write as the fallback.

- **B:** This is the exam's keyed fallback, but it spends a file of context on what is usually a one-line change.
- **C:** Removing code to make an edit possible changes behaviour that was not meant to change.
- **D:** Edit disambiguates by text context, not by line number.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](None)

### 172. Reading all files upfront is the costliest exploration mistake for the context budget

`claude-2-5-10`

Before starting a change in a two-hundred-file service, an agent reads every source file. What is wrong with that?

- **A.** Reads are rate limited, so a large batch of them stalls the session.
- **B.** It spends the context budget on files that have nothing to do with the task.
- **C.** Files read early are evicted from context as later files are read in.
- **D.** Reading a file locks it, so edits attempted at the end of the pass fail.

<details>
<summary>Reveal answer</summary>

**B. It spends the context budget on files that have nothing to do with the task.**

Loading every file before knowing which ones matter swallows the context window on code irrelevant to the task.

- **A:** Throughput is not the issue the lesson raises.
- **C:** The lesson's objection is the wasted budget, not an eviction mechanism.
- **D:** Reads do not lock files.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](None)

### 173. Incremental discovery: Grep entry points, Read to trace, Grep again for new names, Read on

`claude-2-5-11`

What is the incremental order the lesson recommends for understanding unfamiliar code?

- **A.** Glob the whole tree, Read every match, then Grep whatever still looks unclear.
- **B.** Read the entry file, Write notes summarising it, then Grep for whatever the notes missed.
- **C.** Grep for an anchoring name, Read the files that surfaces, then Grep again for the names those files reveal.
- **D.** Run a build through Bash to list the compiled modules, then Read them in dependency order.

<details>
<summary>Reveal answer</summary>

**C. Grep for an anchoring name, Read the files that surfaces, then Grep again for the names those files reveal.**

Incremental discovery is Grep for entry points, Read to trace flows, Grep again for names those files expose, and Read only what each step justifies.

- **A:** This reads everything first, which is the context-budget mistake the lesson warns against.
- **B:** Writing summaries is not part of the sequence, and it skips the anchoring content search.
- **D:** A build listing does not tell you which files are relevant to the task at hand.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](None)

### 174. Consumers importing a renamed re-export never contain the original name, so the alias must

`claude-2-5-12`

A function is defined in one module and re-exported under a different name by a barrel file. A search for the original name finds the definition, the barrel line and two consumers, but three consumers are missing. Why?

- **A.** Those three import the module lazily, so their import statements are constructed at runtime.
- **B.** Content search skips files that re-export a symbol rather than defining it.
- **C.** The barrel file shadows the original name, removing it from the other files' scope.
- **D.** Those files never contain the original string at all; they call the function under its exported alias.

<details>
<summary>Reveal answer</summary>

**D. Those files never contain the original string at all; they call the function under its exported alias.**

Consumers importing through a renamed re-export never contain the original name, so you read the barrel, spot the alias, and search for that name too.

- **A:** The lesson's example is a static re-export, not dynamic importing.
- **B:** The barrel file was found; the missing files are the ones that never mention the original name.
- **C:** Scoping is not the issue; the string simply does not occur in those files.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](None)

### 175. The deprecation sequence is Grep, then Glob for sibling tests, then Grep again; not Glob f

`claude-2-5-13`

You have to find every caller of a deprecated function and the test files that exercise those callers. Which sequence does the lesson give?

- **A.** Grep for the function to find the callers, then Glob for each caller's sibling test file.
- **B.** Glob for files whose names contain the function, then Grep inside that reduced set.
- **C.** Read every source file, then Read every test file and pair them up by their imports.
- **D.** Pipe a find into grep from Bash, covering callers and tests in a single shell pass.

<details>
<summary>Reveal answer</summary>

**A. Grep for the function to find the callers, then Glob for each caller's sibling test file.**

The pattern is content search for direct callers, then path matching for their sibling test files, which catches tests that exercise the function indirectly.

- **B:** Glob first cannot find callers, because call sites are contents rather than filenames.
- **C:** Reading everything is the context-budget mistake the lesson explicitly penalises.
- **D:** The lesson's answer uses the purpose-built tools in sequence rather than a shell pipeline.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](None)

### 176. The second Grep catches tests that cover the function transitively through a wrapper name

`claude-2-5-14`

After a content search finds the callers and a path search pulls in their sibling tests, why does the lesson add one more content search?

- **A.** To confirm that the earlier path patterns matched the naming convention actually in use.
- **B.** To catch tests that reach the function through a wrapper name it is called under.
- **C.** To count the remaining call sites so the refactor can be scheduled.
- **D.** To re-check files that were edited since the first search returned its results.

<details>
<summary>Reveal answer</summary>

**B. To catch tests that reach the function through a wrapper name it is called under.**

The third step is a content search for wrapper names, which finds tests that cover the deprecated function transitively.

- **A:** Verifying the pattern is not the stated purpose of the third step.
- **C:** Estimation is not why the step exists.
- **D:** The sequence is about discovery coverage, not about changes made mid-search.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](None)

### 177. Edit is the default modification tool and relies on unique text matching

`claude-2-5-15`

An agent's habit is to Read a file and Write it back for every change, even a single-line one. Why does the lesson penalise this?

- **A.** Write cannot preserve file permissions, so each rewrite alters the file mode.
- **B.** Write requires the file to have been read in the same turn, which some sessions cannot satisfy.
- **C.** Edit touches only the target text, so a full rewrite spends a file's worth of context needlessly.
- **D.** Rewrites defeat version control, which can no longer produce a line-level diff.

<details>
<summary>Reveal answer</summary>

**C. Edit touches only the target text, so a full rewrite spends a file's worth of context needlessly.**

Edit is the default because it changes only the targeted text; Read plus Write loads and rewrites the whole file and is reserved for when Edit cannot find a unique anchor.

- **A:** Permissions are not the concern the lesson raises.
- **B:** The read-before-write expectation is easily met; the objection is cost.
- **D:** Version control still diffs the result line by line.

</details>

[Lesson material](https://claudecertificationguide.com/learn/2-tool-design-mcp/2-5-built-in-tools) · [Technical reference](None)

## 3.1 — CLAUDE.md Hierarchy, Scoping, and Modular Organisation

### 178. Load order is not precedence; contradicting rules may be resolved arbitrarily

`claude-3-1`

Two applicable CLAUDE.md files give conflicting instructions. What is the sound way to resolve a rule that must always hold?

- **A.** Remove the contradiction and enforce the hard constraint through permissions or an appropriate hook.
- **B.** Assume the more deeply nested file deterministically overrides every other file.
- **C.** Repeat the preferred instruction until it becomes a security boundary.
- **D.** Move both conflicting rules into personal memory without reconciling them.

<details>
<summary>Reveal answer</summary>

**A. Remove the contradiction and enforce the hard constraint through permissions or an appropriate hook.**

Memory instructions are context; an execution constraint needs an enforcement mechanism.

- **B:** Instruction loading does not supply that strict override guarantee.
- **C:** Repetition does not turn guidance into a permission check.
- **D:** Changing their location does not resolve the conflict.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 179. Shared standards

`claude-3-1-2`

Where should conventions shared through a repository normally live?

- **A.** Only in a temporary conversation message.
- **B.** Inside a private uncommitted credential file.
- **C.** In the project's versioned CLAUDE.md or appropriate project rules.
- **D.** Only in one developer's home-level CLAUDE.md.

<details>
<summary>Reveal answer</summary>

**C. In the project's versioned CLAUDE.md or appropriate project rules.**

Repository-shared instructions travel with the project when committed.

- **A:** That does not establish persistent shared project instructions.
- **B:** A secret file is not the team convention source.
- **D:** Personal configuration is not distributed by cloning the project.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 180. Imports and context

`claude-3-1-3`

A CLAUDE.md is split into several eagerly imported files. What changes automatically?

- **A.** All imported instructions become free of token cost.
- **B.** Each import becomes a separately enforced permission policy.
- **C.** Imports resolve relative to an arbitrary tool's current directory.
- **D.** Source organization improves, but imported text still occupies context.

<details>
<summary>Reveal answer</summary>

**D. Source organization improves, but imported text still occupies context.**

Splitting files does not by itself make their content conditional.

- **A:** Loaded text remains context.
- **B:** Imports supply instructions, not enforcement boundaries.
- **C:** Relative imports resolve from the importing file under documented rules.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 181. Loaded memory

`claude-3-1-4`

Which current Claude Code command helps confirm which memory files are in the session context?

- **A.** /context.
- **B.** /init as a mandatory activation step for every existing file.
- **C.** /compact as a guarantee that every nested file loads immediately.
- **D.** A git commit as the only mechanism that loads local instructions.

<details>
<summary>Reveal answer</summary>

**A. /context.**

Its memory-file information helps inspect loaded context; this does not activate missing files.

- **B:** Initialization creates or improves configuration rather than being a per-file activation requirement.
- **C:** Compaction does not guarantee eager loading of all scoped files.
- **D:** Local loading is not conditional on creating a commit.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 182. Claude Code reads CLAUDE.md at three levels: user, project and directory

`claude-3-1-5`

You want Claude Code to give you terser explanations, a preference none of your teammates share. Which level of the hierarchy does the lesson reserve for that kind of setting?

- **A.** User-level ~/.claude/CLAUDE.md, the level kept for strictly personal preferences.
- **B.** Project-level .claude/CLAUDE.md, so the preference travels with every clone.
- **C.** Directory-level CLAUDE.md in whichever package you happen to edit most often.
- **D.** A .claude/rules/ file with no frontmatter, so the preference loads in every session.

<details>
<summary>Reveal answer</summary>

**A. User-level ~/.claude/CLAUDE.md, the level kept for strictly personal preferences.**

Verbosity and output-style preferences are personal, so they belong in the user-level ~/.claude/CLAUDE.md rather than in anything version-controlled.

- **B:** Project level is version-controlled and applies to everyone, which is exactly what a personal preference should not do.
- **C:** Directory level scopes conventions to one package, not to one person, and teammates editing that package would inherit it.
- **D:** That file is committed with the repository and loads for all sessions, so the preference would reach the whole team.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 183. User-level config lives outside the repository, is not version-controlled and never travel

`claude-3-1-6`

A teammate who joined last month gets Claude Code output that ignores the team's error-handling patterns, while everyone else's sessions follow them. Both work from the same clone and the same branch. What should you check first?

- **A.** Whether the teammate is missing an MCP server that publishes the error-handling patterns.
- **B.** Whether the patterns live in one developer's ~/.claude/CLAUDE.md rather than in the repository.
- **C.** Whether the teammate's Claude Code build is too old to read .claude/rules/ files.
- **D.** Whether the teammate has run the diagnostic command that pulls project files into the session.

<details>
<summary>Reveal answer</summary>

**B. Whether the patterns live in one developer's ~/.claude/CLAUDE.md rather than in the repository.**

This is the lesson's signature trap: conventions stored at user level never travel through git, so a new clone behaves inconsistently until they are moved to project level.

- **A:** Nothing in the lesson routes conventions through an MCP server; memory files are the mechanism.
- **C:** The lesson traces this scenario to configuration placement, not to a version mismatch between installations.
- **D:** No command pulls memory files in; configuration loads automatically from its location.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 184. Both .claude/CLAUDE.md and a repository-root CLAUDE.md are valid project-level locations

`claude-3-1-7`

A reviewer argues that a repository's conventions cannot count as project-level because they sit in a CLAUDE.md at the repository root instead of inside the .claude directory. How should you answer?

- **A.** Only .claude/CLAUDE.md is project-level; a root file is read as personal memory instead.
- **B.** A root CLAUDE.md counts only while the repository has no .claude directory at all.
- **C.** Both are valid project-level locations, and the exam may present either path.
- **D.** A root CLAUDE.md is directory-level, so it governs only files sitting at the root.

<details>
<summary>Reveal answer</summary>

**C. Both are valid project-level locations, and the exam may present either path.**

The lesson names .claude/CLAUDE.md and a repository-root CLAUDE.md as equally valid project-level locations.

- **A:** A root CLAUDE.md is committed with the repository and is shared, so it is not personal memory.
- **B:** The lesson sets no such condition; both paths are valid project-level locations.
- **D:** Directory-level means a CLAUDE.md inside a subdirectory; the repository root file is the project-level one.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 185. Directory-level CLAUDE.md holds package-specific conventions and applies to that directory

`claude-3-1-8`

Component test files sit beside their sources in dozens of directories, and one set of test conventions should govern all of them. Why does the lesson rule out a directory-level CLAUDE.md?

- **A.** Directory-level files are ignored whenever a project-level CLAUDE.md already exists.
- **B.** Directory-level files return only after compaction, so early edits would miss them.
- **C.** Directory-level files may only reference imported standards, never hold conventions.
- **D.** It covers a single directory, so cross-directory conventions belong in .claude/rules/ globs.

<details>
<summary>Reveal answer</summary>

**D. It covers a single directory, so cross-directory conventions belong in .claude/rules/ globs.**

A directory-level CLAUDE.md applies to one directory only, so conventions spread across many directories belong in .claude/rules/ with glob patterns.

- **A:** Applicable files are concatenated together; a project-level file does not suppress a directory-level one.
- **B:** Compaction affects when nested files come back, not whether they can express a cross-directory scope.
- **C:** A directory-level CLAUDE.md can hold conventions directly; its limitation is scope, not content.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 186. All discovered memory files are concatenated into context rather than overriding one anoth

`claude-3-1-9`

Three CLAUDE.md files apply to your current working directory. According to the memory documentation the lesson quotes, what happens to them?

- **A.** They are merged section by section, with later definitions replacing earlier ones.
- **B.** The narrowest file loads and the broader ones are discarded before the session begins.
- **C.** Each file is scored for relevance and only the best-scoring one enters the context.
- **D.** All discovered files are concatenated into context rather than overriding one another.

<details>
<summary>Reveal answer</summary>

**D. All discovered files are concatenated into context rather than overriding one another.**

The memory documentation is explicit that discovered memory files are concatenated into context instead of overriding each other.

- **A:** CLAUDE.md is not a structured config that merges by key; the files are simply concatenated.
- **B:** Nothing is discarded; every applicable file enters the same context window.
- **C:** There is no relevance scoring step in the documented loading behaviour.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 187. Load order runs from broadest scope to most specific, filesystem root down to the working 

`claude-3-1-10`

How does the lesson describe the order in which memory content is assembled across the directory tree?

- **A.** Instructions nearest your working directory are read first so they anchor the context.
- **B.** Content is ordered from the filesystem root down to your working directory.
- **C.** Files are ordered alphabetically by full path so the sequence stays stable between runs.
- **D.** Ordering copies the settings precedence chain, with managed policy content read first.

<details>
<summary>Reveal answer</summary>

**B. Content is ordered from the filesystem root down to your working directory.**

Content is ordered from the filesystem root down to the working directory, which is a documented load order rather than a precedence chain.

- **A:** The order runs the other way: the closest instructions are read last, not first.
- **C:** Ordering follows the directory tree, not the alphabet.
- **D:** The managed-policy chain belongs to settings.json; memory files do not use it.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 188. CLAUDE.local.md is appended after CLAUDE.md at the same level

`claude-3-1-11`

Your personal notes in a CLAUDE.local.md are read after the CLAUDE.md sitting beside them. What does that ordering settle when the two contradict each other?

- **A.** Nothing about precedence, since reading last does not settle a contradiction.
- **B.** The local file wins, since the last instruction read is the one that applies.
- **C.** The shared file wins, since team rules outrank anything with a .local suffix.
- **D.** The conflict is surfaced as a load error and neither instruction enters context.

<details>
<summary>Reveal answer</summary>

**A. Nothing about precedence, since reading last does not settle a contradiction.**

Appending CLAUDE.local.md after CLAUDE.md is load order, not precedence, so a contradiction between them may still be resolved arbitrarily.

- **B:** Reading last is not winning; the documentation gives no such override guarantee.
- **C:** No ranking by suffix exists; both files are concatenated into the same context.
- **D:** Contradictions are not detected or reported; both texts load and one may be picked arbitrarily.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 189. CLAUDE.md is delivered as a user message, not the system prompt, with no guarantee of stri

`claude-3-1-12`

The lesson is specific about how CLAUDE.md content reaches the model. Which description matches?

- **A.** It is injected into the system prompt, which is why compliance is deterministic.
- **B.** It arrives as a user message, with no guarantee of strict compliance.
- **C.** It is compiled into tool definitions so each rule becomes a callable constraint.
- **D.** It is applied by the client after generation, rewriting output that violates it.

<details>
<summary>Reveal answer</summary>

**B. It arrives as a user message, with no guarantee of strict compliance.**

CLAUDE.md is delivered as a user message rather than as part of the system prompt, and Anthropic gives no guarantee of strict compliance.

- **A:** It is not part of the system prompt, and compliance is not deterministic.
- **C:** Memory content is prose context, not tool schema.
- **D:** No post-generation rewriting happens; the client enforces settings rules, not memory text.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 190. settings.json has a strict precedence chain (managed > local > project > user) unlike CLAU

`claude-3-1-13`

Which statement correctly contrasts settings.json with CLAUDE.md?

- **A.** Both follow managed policy, then local, then project, then user when two files disagree.
- **B.** Both concatenate their contents, so neither one resolves a conflict deterministically.
- **C.** settings.json resolves conflicts by modification time and CLAUDE.md by directory depth.
- **D.** settings.json follows managed policy over local over project over user; CLAUDE.md files are concatenated.

<details>
<summary>Reveal answer</summary>

**D. settings.json follows managed policy over local over project over user; CLAUDE.md files are concatenated.**

settings.json has a strict precedence chain with managed policy always winning, while CLAUDE.md files are concatenated and conflicts among them may resolve arbitrarily.

- **A:** Only settings.json has that chain; memory files are concatenated instead.
- **B:** settings.json does resolve conflicts deterministically through its precedence chain.
- **C:** Neither mechanism is described this way; depth does not decide a CLAUDE.md conflict.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 191. The import directive is @ followed by a path; there is no @import keyword

`claude-3-1-14`

You are splitting a long CLAUDE.md into separate standards files. Which line correctly pulls one of them back in?

- **A.** @import ./standards/naming-conventions.md, written on its own line in the file.
- **B.** {{ include: ./standards/naming-conventions.md }}, placed beneath the relevant heading.
- **C.** @./standards/naming-conventions.md, written on its own line with no keyword.
- **D.** paths: ["./standards/naming-conventions.md"], declared in the file's YAML frontmatter.

<details>
<summary>Reveal answer</summary>

**C. @./standards/naming-conventions.md, written on its own line with no keyword.**

The import directive is an @ immediately followed by the path, on its own line, with no @import keyword.

- **A:** There is no @import keyword, even though many third-party write-ups show one.
- **B:** No template include syntax exists for memory files.
- **D:** A paths field scopes a rules file to matching globs; it does not inline another file.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 192. Imports load eagerly and are inlined, so splitting a file does not shrink the context Clau

`claude-3-1-15`

Your project CLAUDE.md is long and you want each session to carry less of it. Which change actually reduces what a given session loads?

- **A.** Split it into several files and reference each one with an @ path import.
- **B.** Move the file from the repository root into the .claude directory instead.
- **C.** Move sections into .claude/rules/ files carrying path-scoped frontmatter.
- **D.** Wrap the longest sections in HTML comments so the loader skips over them.

<details>
<summary>Reveal answer</summary>

**C. Move sections into .claude/rules/ files carrying path-scoped frontmatter.**

Imports are eager and do not shrink context; .claude/rules/ files with path-scoped frontmatter load only for matching paths, which is what reduces per-session context.

- **A:** Imports inline eagerly, so the context Claude sees stays the same size.
- **B:** Both are project-level locations; moving the file changes nothing about how much loads.
- **D:** Comment syntax does not exclude text from what gets loaded into context.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 193. CLAUDE.local.md is gitignored by convention and holds personal quirks for one repository

`claude-3-1-16`

Which use fits CLAUDE.local.md as the lesson describes it?

- **A.** A favourite scratchpad path and a debugging note you keep for yourself in this repository.
- **B.** The team's error-handling rules, held back from git until review signs off on them.
- **C.** API tokens and other secrets, which the .local suffix encrypts before any commit.
- **D.** Session summaries that Claude Code writes to disk automatically after compaction.

<details>
<summary>Reveal answer</summary>

**A. A favourite scratchpad path and a debugging note you keep for yourself in this repository.**

CLAUDE.local.md is a project-scoped version of your personal memory: your own quirks for this repository, gitignored by convention.

- **B:** A team rule belongs in the shared CLAUDE.md, not in a personal local file.
- **C:** The suffix is a naming convention for gitignoring, and it performs no encryption.
- **D:** Nothing is written there automatically; the file holds instructions you write yourself.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 194. .claude/rules/ holds topic-specific rule files; without frontmatter they load for all sess

`claude-3-1-17`

A file in .claude/rules/ carries no YAML frontmatter at all. What scope does the lesson give it?

- **A.** It is skipped, because a rules file without a paths field has nothing to match against.
- **B.** It loads only when the edited file's name matches the rules file's own name.
- **C.** It loads only once an @ path import in the project CLAUDE.md references it.
- **D.** It loads for all sessions, because the path scoping is the optional part.

<details>
<summary>Reveal answer</summary>

**D. It loads for all sessions, because the path scoping is the optional part.**

Path scoping in .claude/rules/ is optional, so a rules file without frontmatter loads for all sessions.

- **A:** Frontmatter is optional, and a file without it is not skipped.
- **B:** Filename matching is not a loading mechanism for rules files.
- **C:** Rules files are discovered from the directory; no import is needed.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 195. The exam guide keys /memory as the command that shows which memory files are loaded

`claude-3-1-18`

An exam item asks which command shows the memory files a session has loaded. Which answer does the exam guide key, even though current Claude Code splits that job across two commands?

- **A.** /init
- **B.** /memory
- **C.** /context
- **D.** /compact

<details>
<summary>Reveal answer</summary>

**B. /memory**

Exam guide v1.0 predates the split between the two commands and treats /memory as the one that shows which files are loaded, so /memory is the keyed answer.

- **A:** That command scaffolds a CLAUDE.md; it does not report what a session loaded.
- **C:** This is what you run at a real keyboard today, but it is not the guide's keyed answer.
- **D:** Compaction summarises a long session; it reports nothing about memory files.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 196. Neither /memory nor /context loads anything; configuration loads automatically by level an

`claude-3-1-19`

A developer plans to open each session by running /memory so that the project conventions get pulled in. What is wrong with the plan?

- **A.** The command works only in a session that has already been compacted once.
- **B.** The command reaches user-level files but never project or directory-level ones.
- **C.** Memory files load automatically from their location; the command only reveals what is there.
- **D.** The command loads the files but discards them again at the first tool call.

<details>
<summary>Reveal answer</summary>

**C. Memory files load automatically from their location; the command only reveals what is there.**

Neither /memory nor /context loads configuration. Files load automatically based on their level and location, and the commands exist to diagnose that.

- **A:** Compaction is unrelated to whether the command can be used.
- **B:** It lists memory locations across levels; the flaw in the plan is different.
- **D:** Nothing is discarded mid-session; the command never loaded anything in the first place.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 197. The project-root CLAUDE.md survives /compact because Claude re-reads it from disk and re-i

`claude-3-1-20`

After /compact, the instructions from the project-root CLAUDE.md are still in force. What explains that?

- **A.** The summariser is instructed to preserve any text that originated in a memory file.
- **B.** Claude re-reads the file from disk after compaction and re-injects it.
- **C.** Root memory is pinned into the system prompt, which compaction never touches.
- **D.** Compaction summarises only tool results, so every instruction survives it intact.

<details>
<summary>Reveal answer</summary>

**B. Claude re-reads the file from disk after compaction and re-injects it.**

The root CLAUDE.md survives compaction because Claude re-reads it from disk and re-injects it, and its text was never part of the conversation history being summarised.

- **A:** The memory text was never in the conversation history for the summariser to preserve.
- **C:** CLAUDE.md is delivered as a user message, not pinned into the system prompt.
- **D:** Compaction is free to summarise conversation content, including instructions that only lived there.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

### 198. Nested CLAUDE.md files and paths-scoped rules load on demand, returning only when a matchi

`claude-3-1-21`

Two kinds of configuration do not return the moment compaction finishes. Which pair does the lesson name?

- **A.** Files pulled in by @ path imports, and anything in the user-level CLAUDE.md.
- **B.** Permission rules from settings and hooks registered earlier in the session.
- **C.** The project-root CLAUDE.md and any CLAUDE.local.md sitting beside it.
- **D.** Nested subdirectory CLAUDE.md files, and .claude/rules/ files scoped with paths.

<details>
<summary>Reveal answer</summary>

**D. Nested subdirectory CLAUDE.md files, and .claude/rules/ files scoped with paths.**

Nested CLAUDE.md files and paths-scoped rules load on demand, so after compaction they return only when Claude next reads a matching file.

- **A:** Imported content is inlined into the CLAUDE.md that references it and comes back with it.
- **B:** Settings and hooks are enforced by the client and are unaffected by compaction.
- **C:** The root file is exactly what does come back, because it is re-read from disk.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy) · [Technical reference](https://code.claude.com/docs/en/memory)

## 3.2 — Custom Slash Commands and Skills

### 199. A skill is a directory containing SKILL.md; a command is a flat Markdown file in .claude/c

`claude-3-2`

You want a repository-shared /audit skill with supporting files. Which layout uses the skill directory convention?

- **A.** An audit section in README.md with no skill entry point.
- **B.** .claude/skills/audit/SKILL.md, with supporting files in that directory.
- **C.** .claude/skills/audit.md, with no skill directory.
- **D.** .claude/audit/SKILL.md, outside the skills directory.

<details>
<summary>Reveal answer</summary>

**B. .claude/skills/audit/SKILL.md, with supporting files in that directory.**

A skill has its own directory containing the SKILL.md entry point.

- **A:** Documentation alone does not define a discoverable skill.
- **C:** A flat file there does not use the skill directory layout.
- **D:** That is not the conventional project skill discovery location.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 200. Isolated skill work

`claude-3-2-2`

A skill performs lengthy exploration but should return a concise result to the main conversation. Which mechanism is relevant?

- **A.** Treating isolation as permission to ignore tool restrictions.
- **B.** A supported forked skill context with a clear task and result contract.
- **C.** Appending every intermediate result to the root instruction file.
- **D.** Removing the skill's task description.

<details>
<summary>Reveal answer</summary>

**B. A supported forked skill context with a clear task and result contract.**

Isolated execution can keep exploratory output from filling the main conversation.

- **A:** Context separation does not override permissions.
- **C:** That creates persistent noise rather than isolating exploration.
- **D:** That makes its purpose harder to identify.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 201. Argument hints

`claude-3-2-3`

What does argument-hint metadata do for a Claude Code skill?

- **A.** Enforces argument types by parsing the wording of the hint.
- **B.** Uses the hint examples as default values for missing arguments.
- **C.** Shows expected arguments in autocomplete; the workflow still validates input.
- **D.** Automatically opens a required-input dialog when arguments are omitted.

<details>
<summary>Reveal answer</summary>

**C. Shows expected arguments in autocomplete; the workflow still validates input.**

A hint helps discoverability but is not runtime validation.

- **A:** Descriptive text is not a type-validation schema.
- **B:** An example is not automatically a default assignment.
- **D:** A displayed hint does not itself implement an interactive input flow.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 202. Tool approval metadata

`claude-3-2-4`

Which statement about a skill's allowed-tools field is accurate?

- **A.** It removes every unlisted tool from the available tool set.
- **B.** It requires every listed tool to run in the written order.
- **C.** It permanently rewrites project permissions for later sessions.
- **D.** It pre-approves listed tools while other capabilities remain subject to applicable permissions.

<details>
<summary>Reveal answer</summary>

**D. It pre-approves listed tools while other capabilities remain subject to applicable permissions.**

Pre-approval is not an exclusive tool allowlist; the grant is scoped to the invoking turn.

- **A:** Tool availability needs the documented restriction mechanisms.
- **B:** Permission metadata does not define a mandatory execution sequence.
- **C:** The skill grant is not a permanent project-settings edit.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 203. A skill is a directory containing SKILL.md; a command is a flat Markdown file in .claude/c

`claude-3-2-5`

A developer adds .claude/skills/review.md to the repository and restarts Claude Code, but no /review command appears. What is wrong?

- **A.** A skill is a directory holding a SKILL.md, so a loose .md file there is not picked up.
- **B.** A skill must declare a description in frontmatter before its command is registered.
- **C.** The skills directory registers commands only once the files are committed and pushed.
- **D.** Only user-scoped skills create commands, so the project path needs a settings entry.

<details>
<summary>Reveal answer</summary>

**A. A skill is a directory holding a SKILL.md, so a loose .md file there is not picked up.**

Skills are directories with a SKILL.md entrypoint. A flat Markdown file only creates a command when it sits in .claude/commands/.

- **B:** The description shapes automatic invocation, but its absence does not stop the command from existing.
- **C:** Discovery reads the working tree; committing is about sharing with teammates, not registration.
- **D:** Project-scoped skills create commands too, and no settings entry is involved.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 204. Custom commands and skills are one unified Skills system, and both paths create the same /

`claude-3-2-6`

Your repository still holds several .claude/commands/*.md files from before skills became the unified system. What does the lesson say about them?

- **A.** They must be converted into SKILL.md directories before Claude Code will register them.
- **B.** They are treated as user-scoped, so teammates stop receiving them on a fresh clone.
- **C.** They now load as always-on context the way CLAUDE.md does for every session.
- **D.** They keep working unchanged, with .claude/skills/ as the canonical location going forward.

<details>
<summary>Reveal answer</summary>

**D. They keep working unchanged, with .claude/skills/ as the canonical location going forward.**

The two locations create the same commands, so existing .claude/commands/ files keep working while .claude/skills/ is the canonical, fuller-featured path.

- **A:** No conversion is required; the commands path still works for backward compatibility.
- **B:** Anything under .claude/ in the repository is project-scoped and travels through git.
- **C:** Commands and skills load on demand; they are not always-on context.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 205. The skills path adds supporting files, automatic discovery, and precedence over a same-nam

`claude-3-2-7`

A repository defines /deploy both as .claude/skills/deploy/SKILL.md and as .claude/commands/deploy.md. Which behaviour does the lesson describe?

- **A.** Claude Code registers neither until the duplicate name is removed from one path.
- **B.** The two bodies are concatenated, so both sets of steps run on each invocation.
- **C.** The command wins, because the flat file is discovered later in the scan.
- **D.** The skill wins, one of the advantages the skills path holds over the alias.

<details>
<summary>Reveal answer</summary>

**D. The skill wins, one of the advantages the skills path holds over the alias.**

When a skill and a command share a name the skill takes precedence, alongside supporting files and automatic discovery as advantages of the skills path.

- **A:** The collision is resolved rather than blocking registration.
- **B:** Nothing concatenates the two definitions.
- **C:** Precedence runs the other way: the skill takes it.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 206. Project-scoped .claude/ is shared through git; user-scoped ~/.claude/ is personal and unsh

`claude-3-2-8`

Every developer who clones the repository should get a /deploy-check command. Which placement achieves that?

- **A.** ~/.claude/skills/deploy-check/SKILL.md, created on each developer's own machine.
- **B.** ~/.claude/commands/deploy-check.md, with a README note telling people to copy it.
- **C.** .claude/skills/deploy-check/SKILL.md, committed inside the repository itself.
- **D.** A deploy-check section in the project CLAUDE.md describing the steps to follow.

<details>
<summary>Reveal answer</summary>

**C. .claude/skills/deploy-check/SKILL.md, committed inside the repository itself.**

Project-scoped paths inside the repository are version-controlled, so every clone gets the command; user-scoped paths under the home directory are personal.

- **A:** The home directory path is user-scoped and not version-controlled, so it is not shared on clone.
- **B:** This is the lesson's trap: a shared workflow parked in a personal path.
- **D:** That makes it always-on prose rather than an invocable command, and task procedures do not belong in CLAUDE.md.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 207. Without context: fork, skill output flows into the main conversation and degrades later re

`claude-3-2-9`

A codebase-analysis skill runs without context: fork in its frontmatter. What does the lesson say follows?

- **A.** It can no longer be invoked automatically, only by typing the command name.
- **B.** Its output is discarded entirely, so the main conversation receives no findings.
- **C.** It runs with read-only tools by default until the fork setting is supplied.
- **D.** Its verbose output flows into the main conversation and degrades later responses.

<details>
<summary>Reveal answer</summary>

**D. Its verbose output flows into the main conversation and degrades later responses.**

Without context: fork, skill output flows into the main conversation and consumes context window tokens, which degrades the quality of later responses.

- **A:** Automatic invocation depends on the description and paths matching, not on forking.
- **B:** Output is not discarded; it lands in the main conversation, which is the problem.
- **C:** Tool access is governed by the tools fields and permissions, not by the context setting.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 208. Exam guide v1.0 keys allowed-tools as restricting a skill's tool access

`claude-3-2-10`

An exam item asks what the allowed-tools frontmatter field does for a skill. Which answer does the exam guide key?

- **A.** It orders the listed tools so the skill attempts them in the sequence written.
- **B.** It restricts which tools the skill is able to access while it runs.
- **C.** It pre-approves the listed tools so they run without a permission prompt.
- **D.** It gives the skill its own permission mode for the duration of its turn.

<details>
<summary>Reveal answer</summary>

**B. It restricts which tools the skill is able to access while it runs.**

Exam guide v1.0 describes allowed-tools as restricting a skill's tool access, so "restricts" is the keyed answer even though current Claude Code treats the list as pre-approval.

- **A:** No field imposes an execution order on tools.
- **C:** This is what current Claude Code actually does, but it is not the answer the guide keys.
- **D:** The field names tools, not a permission mode.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 209. disallowed-tools or permission deny rules are the actual boundary that removes tools

`claude-3-2-11`

You need a skill that genuinely cannot call Write or Bash while it runs. What does the lesson tell you to reach for?

- **A.** An allowed-tools list naming only Read, Grep and Glob for that skill.
- **B.** A context: fork setting, since a forked skill inherits no write-capable tools.
- **C.** A disallowed-tools list, or deny rules in your permission settings.
- **D.** An argument-hint documenting the skill as a read-only analysis workflow.

<details>
<summary>Reveal answer</summary>

**C. A disallowed-tools list, or deny rules in your permission settings.**

To remove tools from Claude's pool while a skill runs, list them in disallowed-tools or add deny rules in permission settings; that is the real boundary.

- **A:** In current Claude Code that list pre-approves tools rather than removing the others.
- **B:** Forking isolates output; it is not a tool boundary.
- **D:** A hint is a label shown in autocomplete and enforces nothing.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 210. Exam guide v1.0 keys argument-hint as prompting the developer for required parameters

`claude-3-2-12`

Exam guide v1.0 describes argument-hint in terms of what happens when a developer invokes a skill with no arguments. Which behaviour does the guide describe?

- **A.** It prompts the developer for the required parameters before the skill runs.
- **B.** It substitutes the example values from the hint and continues without interruption.
- **C.** It cancels the invocation and prints the hint text as an error message.
- **D.** It shows the hint during autocomplete and otherwise changes nothing at all.

<details>
<summary>Reveal answer</summary>

**A. It prompts the developer for the required parameters before the skill runs.**

Exam guide v1.0 presents argument-hint as prompting for required parameters, while current documentation defines it as an autocomplete hint that does not interrupt invocation.

- **B:** No field supplies default argument values.
- **C:** Nothing cancels the run; the guide describes prompting, not failing.
- **D:** That is the current documented behaviour, not what the exam guide describes.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 211. description is what Claude matches intent against; it is recommended, and without it the b

`claude-3-2-13`

What job does the description field do in a skill's frontmatter?

- **A.** It is what Claude reads to decide whether the skill applies to the current request.
- **B.** It replaces the argument hint in autocomplete once the skill has been used once.
- **C.** It is required, and a skill missing one fails to register as a command at all.
- **D.** It sets the summary text a forked skill returns to the main conversation.

<details>
<summary>Reveal answer</summary>

**A. It is what Claude reads to decide whether the skill applies to the current request.**

Claude matches a request against a skill's description to decide whether the skill applies, which is why a skill without a good one effectively only runs when typed by name.

- **B:** The two fields are separate and neither replaces the other.
- **C:** Documentation marks it Recommended, not required; without it Claude falls back to the first paragraph of the body.
- **D:** What a forked skill reports back is produced by the run, not copied from frontmatter.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 212. Skills with disable-model-invocation: true require explicit user invocation

`claude-3-2-14`

Which frontmatter setting makes a skill run only when a developer types its command explicitly?

- **A.** context: fork
- **B.** argument-hint
- **C.** disable-model-invocation: true
- **D.** allowed-tools

<details>
<summary>Reveal answer</summary>

**C. disable-model-invocation: true**

Skills with disable-model-invocation set to true cannot be auto-invoked by the model and must be called explicitly.

- **A:** This isolates the skill's execution and output; it does not govern who may trigger it.
- **B:** This is an autocomplete label describing expected input.
- **D:** This concerns tool access, not invocation.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 213. Always-on conventions belong in CLAUDE.md or .claude/rules/, never in a skill

`claude-3-2-15`

A team wants its API naming conventions applied to every code-generation request, with nobody having to invoke anything. Where do the conventions belong?

- **A.** In a skill under .claude/skills/ whose description matches code-generation requests.
- **B.** In CLAUDE.md or in .claude/rules/, which load automatically into the session.
- **C.** In a skill with disable-model-invocation set to false so Claude reliably picks it up.
- **D.** In an argument-hint attached to the team's existing review skill, as a reminder.

<details>
<summary>Reveal answer</summary>

**B. In CLAUDE.md or in .claude/rules/, which load automatically into the session.**

CLAUDE.md and .claude/rules/ load automatically for every session or every matching file, which is what always-on conventions require; skills are on-demand workflows.

- **A:** Skills load on demand as workflows, which is not the same as shaping every session by default.
- **C:** Allowing model invocation still makes it an on-demand workflow rather than standing context.
- **D:** A hint appears in autocomplete and shapes nothing about code generation.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 214. Skill descriptions are always in context while the body loads only on invocation

`claude-3-2-16`

What does a session hold for a skill that nobody has invoked yet?

- **A.** Nothing at all, because skills are discovered only at the moment of invocation.
- **B.** The whole SKILL.md body, which is why skills are charged against the context budget.
- **C.** Its description, so Claude knows the skill exists, with the body loading on invocation.
- **D.** Its allowed-tools list, which is applied to every turn until the skill is called.

<details>
<summary>Reveal answer</summary>

**C. Its description, so Claude knows the skill exists, with the body loading on invocation.**

Skill descriptions are always in context so Claude knows what exists, but the full body only loads when the skill is invoked.

- **A:** Claude has to know the skill exists in order to match it, so something is present.
- **B:** The body loads on invocation; keeping every body resident is exactly what skills avoid.
- **D:** Tool configuration applies while the skill is active, not before it runs.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 215. Personal skill variants use a different name in ~/.claude/skills/ and do not override the 

`claude-3-2-17`

Your team ships an /analyse skill, but you want a more verbose version for your own sessions. What does the lesson recommend?

- **A.** Create a differently named skill in ~/.claude/skills/ and leave the team one alone.
- **B.** Create a same-named skill in ~/.claude/skills/ so your copy takes precedence for you.
- **C.** Edit the project skill and guard your additions with a check on your username.
- **D.** Copy the team skill into ~/.claude/commands/ and delete the project version.

<details>
<summary>Reveal answer</summary>

**A. Create a differently named skill in ~/.claude/skills/ and leave the team one alone.**

Personal variants go in the user-scoped skills directory under a different name, so they neither override nor conflict with the team's version.

- **B:** The lesson's advice is a different name, not a shadowing override.
- **C:** That changes the shared workflow for everyone who reads the file.
- **D:** Deleting the project version removes the workflow from every teammate's clone.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

### 216. Team-shared commands placed in a user-scoped path never reach teammates on clone

`claude-3-2-18`

A repository needs a /release-check command available to everyone, and one developer wants a private /explore skill whose long analysis stays out of the main conversation. Which layout fits?

- **A.** Both under ~/.claude/commands/, with release-check documented in the README for copying.
- **B.** Both under .claude/skills/ in the repository, with context: fork on the explore skill only.
- **C.** release-check documented in CLAUDE.md, and explore under .claude/skills/ with allowed-tools.
- **D.** release-check under .claude/skills/ in the repository, explore under ~/.claude/skills/ with context: fork.

<details>
<summary>Reveal answer</summary>

**D. release-check under .claude/skills/ in the repository, explore under ~/.claude/skills/ with context: fork.**

Team workflows go in the project-scoped skills directory, while a personal verbose skill belongs in the user-scoped directory with context: fork to keep its output out of the main conversation.

- **A:** A team command parked in a personal path is the scoping trap the lesson warns about.
- **B:** The fork setting is right, but the private skill should not be shared with the whole team.
- **C:** CLAUDE.md is for always-on standards, not task procedures, and allowed-tools does not isolate output.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-2-slash-commands-skills) · [Technical reference](https://code.claude.com/docs/en/skills)

## 3.3 — Path-Specific Rules for Conditional Convention Loading

### 217. Rule files live in .claude/rules/ and carry YAML frontmatter with a paths field of globs

`claude-3-3`

Test conventions should apply to matching test files across several packages. Which approach expresses that scope?

- **A.** Put them in global personal memory for every project and file.
- **B.** Import the conventions unconditionally and expect imports to filter by file type.
- **C.** A .claude/rules Markdown file with paths frontmatter matching those tests.
- **D.** Put the conventions only in one package's CLAUDE.md.

<details>
<summary>Reveal answer</summary>

**C. A .claude/rules Markdown file with paths frontmatter matching those tests.**

Path-scoped rules can target matching files across directory boundaries.

- **A:** That broadens the rule beyond the intended scope.
- **B:** An import does not itself provide conditional path matching.
- **D:** That does not express a rule covering the other packages.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) · [Technical reference](https://code.claude.com/docs/en/memory)

### 218. Path matching

`claude-3-3-2`

Which pattern targets files named *.test.ts at arbitrary nesting depths?

- **A.** `**/*.test.ts`
- **B.** `*.test.ts`
- **C.** `**/*.spec.ts`
- **D.** `packages/api/**/*.test.ts`

<details>
<summary>Reveal answer</summary>

**A. `**/*.test.ts`**

The recursive path pattern matches that naming convention at different depths.

- **B:** This lacks the recursive directory part needed for arbitrary nesting.
- **C:** It matches a different filename convention.
- **D:** It restricts coverage to one package instead of arbitrary locations.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) · [Technical reference](https://code.claude.com/docs/en/memory)

### 219. Unscoped rule

`claude-3-3-3`

A rules file has no paths frontmatter. What scope should you expect from the documented project-rules behavior?

- **A.** It automatically becomes a tool permission denial.
- **B.** It is loaded as general project guidance rather than only for one file pattern.
- **C.** It can never load in any session.
- **D.** It applies only when its filename matches the edited file.

<details>
<summary>Reveal answer</summary>

**B. It is loaded as general project guidance rather than only for one file pattern.**

Conditional path loading requires an expressed path scope.

- **A:** Instruction scope does not turn guidance into enforcement.
- **C:** Absence of a condition does not disable the rule.
- **D:** The rule filename is not an implicit glob condition.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) · [Technical reference](https://code.claude.com/docs/en/memory)

### 220. Rules versus procedure

`claude-3-3-4`

You need standing conventions for matching files and a multi-step audit invoked when needed. Which separation fits?

- **A.** One always-loaded instruction that executes the audit on every edit.
- **B.** An MCP server URL with no rule or workflow definition.
- **C.** Path-scoped rules for conventions and a skill for the audit workflow.
- **D.** A personal memory file containing every audit result forever.

<details>
<summary>Reveal answer</summary>

**C. Path-scoped rules for conventions and a skill for the audit workflow.**

Persistent scoped guidance and a task procedure have different roles.

- **A:** That runs an on-demand procedure too broadly.
- **B:** A connection alone does not define either behavior.
- **D:** That mixes temporary outputs with reusable guidance.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) · [Technical reference](https://code.claude.com/docs/en/memory)

### 221. Rule files live in .claude/rules/ and carry YAML frontmatter with a paths field of globs

`claude-3-3-5`

You are writing a rule that should load only while Terraform files are being edited. Which arrangement does the lesson show?

- **A.** A file in .claude/rules/ whose frontmatter reads paths: ["terraform/**/*"].
- **B.** A file in .claude/rules/ whose frontmatter reads globs: ["terraform/**/*"].
- **C.** A paths: ["terraform/**/*"] block at the top of the project root CLAUDE.md.
- **D.** A file in .claude/skills/ whose frontmatter reads when: ["terraform/**/*"].

<details>
<summary>Reveal answer</summary>

**A. A file in .claude/rules/ whose frontmatter reads paths: ["terraform/**/*"].**

Path-specific rules are files in .claude/rules/ carrying YAML frontmatter with a paths field of glob patterns, and they load only while matching files are in play.

- **B:** The field is named paths; globs is not the frontmatter key.
- **C:** Root CLAUDE.md has no conditional scoping; it loads for every session.
- **D:** There is no when field, and a skill is an on-demand workflow rather than standing conventions.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) · [Technical reference](https://code.claude.com/docs/en/memory)

### 222. Directory-level CLAUDE.md would need one copy per directory, causing fan-out edits and dri

`claude-3-3-6`

Test files live beside their sources across more than fifty directories. What is the lesson's objection to dropping a CLAUDE.md into each one?

- **A.** Claude Code loads at most one directory-level file per session, so most copies are ignored.
- **B.** Directory-level files can only reference shared standards, never hold conventions directly.
- **C.** Fifty copies of the same conventions drift apart, and every new directory needs another.
- **D.** Directory-level files load for every session, so they would burn tokens constantly.

<details>
<summary>Reveal answer</summary>

**C. Fifty copies of the same conventions drift apart, and every new directory needs another.**

Covering scattered test files with directory-level CLAUDE.md means dozens of duplicate copies, an edit in every one whenever a convention changes, and drift as copies fall behind.

- **A:** There is no such limit; the objection is maintenance, not a cap.
- **B:** They can hold conventions; the problem is how many copies you would need.
- **D:** That criticism belongs to root CLAUDE.md; directory-level files apply within their directory.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) · [Technical reference](https://code.claude.com/docs/en/memory)

### 223. Root CLAUDE.md loads every session, so file-type conventions there burn tokens on unrelate

`claude-3-3-7`

Why does the lesson reject putting Terraform conventions into the root CLAUDE.md?

- **A.** Root CLAUDE.md is reserved for imports and cannot carry conventions of its own.
- **B.** Root CLAUDE.md loads every session, so the rules cost tokens while you edit React.
- **C.** Root CLAUDE.md is user-scoped, so teammates editing Terraform never receive it.
- **D.** Root CLAUDE.md is dropped at compaction, so long sessions silently lose the rules.

<details>
<summary>Reveal answer</summary>

**B. Root CLAUDE.md loads every session, so the rules cost tokens while you edit React.**

Root CLAUDE.md loads for every session regardless of the files in play, so file-type conventions parked there spend tokens during unrelated work.

- **A:** It can carry conventions directly; the objection is about when they load.
- **C:** The root file is project-level and shared through the repository.
- **D:** It is re-read from disk after compaction, so it comes back intact.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) · [Technical reference](https://code.claude.com/docs/en/memory)

### 224. Path-scoped rules load only while editing files that match their globs

`claude-3-3-8`

What makes path-scoped rules more token-efficient than the same content in root CLAUDE.md?

- **A.** Rule files are summarised before loading, so only their headings enter context.
- **B.** Rule files are cached between sessions and charged only on their first load.
- **C.** Rule files load only when you edit matching files, so irrelevant context is skipped.
- **D.** Rule files count against the tool budget rather than against the context window.

<details>
<summary>Reveal answer</summary>

**C. Rule files load only when you edit matching files, so irrelevant context is skipped.**

Path-scoped rules load only while matching files are being edited, so irrelevant conventions never enter the context window at all.

- **A:** Rules load in full when they match; nothing summarises them first.
- **B:** Token efficiency here comes from conditional loading, not from caching.
- **D:** There is no separate budget; rules occupy context like any other loaded text.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) · [Technical reference](https://code.claude.com/docs/en/memory)

### 225. One rule file's paths array can list several glob patterns covering directories and filena

`claude-3-3-9`

Route handlers in your project appear under src/api, inside any routes directory, and as files ending in .controller.ts. How does the lesson cover all three with one rule?

- **A.** Three separate rule files, because a paths field accepts exactly one pattern.
- **B.** One rule file whose paths array lists all three glob patterns together.
- **C.** One rule file with no paths field, relying on its filename to imply the scope.
- **D.** One rule file, referenced by an @ path import from each package's own CLAUDE.md.

<details>
<summary>Reveal answer</summary>

**B. One rule file whose paths array lists all three glob patterns together.**

A single rules file can carry several glob patterns in its paths array, which is how the lesson's API conventions cover directories and filename suffixes at once.

- **A:** The field takes an array, so one file can list several patterns.
- **C:** Omitting the field makes the rules load for every session instead of conditionally.
- **D:** Imports inline eagerly and bypass the conditional loading that path scoping provides.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) · [Technical reference](https://code.claude.com/docs/en/memory)

### 226. Decision table: conventions for one package directory go in a directory-level CLAUDE.md

`claude-3-3-10`

A set of conventions applies to exactly one package directory and nowhere else. Which approach does the lesson's decision table name?

- **A.** A skill in .claude/skills/ that developers invoke before editing that package.
- **B.** A path-scoped rules file whose globs match every file in the repository.
- **C.** The root CLAUDE.md, with a heading naming the package the rules apply to.
- **D.** A directory-level CLAUDE.md placed inside that package.

<details>
<summary>Reveal answer</summary>

**D. A directory-level CLAUDE.md placed inside that package.**

The decision table sends conventions for a single package directory to a directory-level CLAUDE.md inside that directory.

- **A:** Skills are for task workflows invoked on demand, not for standing conventions.
- **B:** That widens the scope to the whole codebase instead of the one package.
- **C:** Root memory loads everywhere, so a heading does not scope anything.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) · [Technical reference](https://code.claude.com/docs/en/memory)

### 227. Decision table: universal team standards stay in root CLAUDE.md

`claude-3-3-11`

Which case does the lesson's decision table still assign to the root CLAUDE.md?

- **A.** Universal team standards that apply to all code in the project.
- **B.** Conventions for one file type scattered throughout many directories.
- **C.** A multi-step workflow that developers run only when they need it.
- **D.** Conventions belonging to a single package inside the repository.

<details>
<summary>Reveal answer</summary>

**A. Universal team standards that apply to all code in the project.**

Root CLAUDE.md remains the place for universal team standards that apply to all code, since those are relevant in every session anyway.

- **B:** Those go to path-specific rules with glob patterns.
- **C:** That is a skill in .claude/skills/.
- **D:** That is a directory-level CLAUDE.md in the package.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) · [Technical reference](https://code.claude.com/docs/en/memory)

### 228. Rules stay in context as background guidance for matching files; skills load on demand as 

`claude-3-3-12`

Both a skill and a rules file can carry a paths field. For conventions that must shape every edit to a matching file, which one fits and why?

- **A.** A skill, because a paths match fires model invocation on every matching file automatically.
- **B.** A rules file, because rules stay in context as background guidance whenever a matching file is read.
- **C.** A skill, because its body is loaded earlier in the session than any rules file.
- **D.** A rules file, because skills can only ever be triggered by a typed command.

<details>
<summary>Reveal answer</summary>

**B. A rules file, because rules stay in context as background guidance whenever a matching file is read.**

Rules load as background guidance alongside matching files and stay in context to shape each edit, while skills load on demand as task-style workflows.

- **A:** Skills still load as invocation-style workflows rather than as standing background guidance.
- **C:** Load position is not the distinction; the distinction is on-demand workflow versus standing context.
- **D:** Skills can also be auto-invoked by description match or a paths match, so this reason is wrong.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) · [Technical reference](https://code.claude.com/docs/en/memory)

### 229. /context verifies which rule files loaded, and non-matching rule files do not appear

`claude-3-3-13`

While editing a .test.ts file you want to confirm that the test rules loaded and the Terraform rules did not. What does the lesson have you do?

- **A.** Run /memory, which enumerates every rules file the project defines.
- **B.** Run /compact, which reprints the loaded rule set while it summarises the session.
- **C.** Add a paths field to the Terraform rules so that it reports itself as skipped.
- **D.** Run /context and read which rule files appear in the loaded list.

<details>
<summary>Reveal answer</summary>

**D. Run /context and read which rule files appear in the loaded list.**

Running /context while editing a matching file lists the rules that loaded, and the non-matching rule files are absent from that list.

- **A:** That command deals with memory file locations rather than reporting this session's loaded set.
- **B:** Compaction summarises a session; it is not a diagnostic for loaded rules.
- **C:** Rules do not announce that they were skipped; they simply do not appear as loaded.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-3-path-specific-rules) · [Technical reference](https://code.claude.com/docs/en/memory)

## 3.4 — Plan Mode vs Direct Execution

### 230. Plan mode suits large-scale changes, architectural decisions, multi-file modifications and

`claude-3-4`

A change crosses service boundaries and has two viable migration strategies. What is the best initial workflow?

- **A.** Implement both migrations in the same branch before comparing them.
- **B.** Start changing the first file that mentions either service.
- **C.** Skip discovery because the requested outcome is clear.
- **D.** Inspect dependencies and compare a plan before making the migration edits.

<details>
<summary>Reveal answer</summary>

**D. Inspect dependencies and compare a plan before making the migration edits.**

Unresolved architectural choices benefit from investigation before implementation.

- **A:** That creates conflicting work before choosing a strategy.
- **B:** A text match does not establish the appropriate migration boundary.
- **C:** A clear outcome does not resolve implementation tradeoffs.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-4-plan-mode-execution) · [Technical reference](None)

### 231. Small bounded change

`claude-3-4-2`

A verified one-line typo fix has a clear scope and no architectural choice. What workflow is usually proportionate?

- **A.** Require a full service migration plan before editing.
- **B.** Rewrite the surrounding module to make the task larger.
- **C.** Skip all inspection because the change is small.
- **D.** Make the targeted edit and verify the relevant result.

<details>
<summary>Reveal answer</summary>

**D. Make the targeted edit and verify the relevant result.**

Planning effort should match the uncertainty and impact of the task.

- **A:** That adds unrelated work.
- **B:** That expands scope without need.
- **C:** Small changes still need correct targeting.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-4-plan-mode-execution) · [Technical reference](https://code.claude.com/docs/en/best-practices)

### 232. Unresolved requirement

`claude-3-4-3`

A migration plan depends on an unspecified compatibility requirement. What should happen before dependent edits?

- **A.** Clarify that requirement while continuing independent investigation.
- **B.** Assume compatibility is irrelevant because a plan exists.
- **C.** Implement every incompatible interpretation together.
- **D.** Declare the migration verified before choosing an interpretation.

<details>
<summary>Reveal answer</summary>

**A. Clarify that requirement while continuing independent investigation.**

A material unknown should be resolved rather than guessed into the implementation.

- **B:** A written plan does not answer an open requirement.
- **C:** That does not produce a coherent contract.
- **D:** Verification needs a defined expected behavior.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-4-plan-mode-execution) · [Technical reference](https://code.claude.com/docs/en/best-practices)

### 233. Plan versus proof

`claude-3-4-4`

A plan lists a test run. What establishes that validation actually happened?

- **A.** The number of files mentioned in the plan.
- **B.** The executed check and its observed outcome.
- **C.** The presence of a checked-looking bullet in the plan.
- **D.** A confident estimate of the likely result.

<details>
<summary>Reveal answer</summary>

**B. The executed check and its observed outcome.**

Intended work and completed evidence are different states.

- **A:** File count does not establish validation.
- **C:** Formatting does not execute a check.
- **D:** Confidence is not runtime evidence.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-4-plan-mode-execution) · [Technical reference](https://code.claude.com/docs/en/best-practices)

### 234. The mode is decided by ambiguity, not by difficulty

`claude-3-4-5`

Which pairing matches the lesson's key distinction about choosing a mode?

- **A.** A hard but well-defined fix goes direct; a simple-sounding feature with several designs gets a plan.
- **B.** A hard fix always gets a plan; a simple-sounding feature always goes to direct execution.
- **C.** Deadline pressure decides it, with plan mode reserved for work that has time to spare.
- **D.** File count decides it, with anything under ten files going straight to direct execution.

<details>
<summary>Reveal answer</summary>

**A. A hard but well-defined fix goes direct; a simple-sounding feature with several designs gets a plan.**

The lesson's key concept is that ambiguity picks the mode, not difficulty: a difficult but well-defined fix is direct execution, while an easy-sounding change with several viable designs needs a plan.

- **B:** This substitutes difficulty for ambiguity, which is the confusion the lesson warns against.
- **C:** Schedule is not one of the criteria the lesson gives.
- **D:** File count matters only as a signal of ambiguity; it is not the rule by itself.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-4-plan-mode-execution) · [Technical reference](None)

### 235. The Explore subagent runs discovery in isolation and returns summaries, keeping main conte

`claude-3-4-6`

A multi-phase task opens with discovery that throws off long file listings, dependency graphs and code excerpts. What does the lesson recommend, and why?

- **A.** Run the discovery twice in plan mode so the second pass produces a shorter report.
- **B.** Paste the discovery output into CLAUDE.md so that it survives the rest of the session.
- **C.** Use the Explore subagent, which runs discovery in isolation and returns summaries.
- **D.** Skip discovery and begin implementing, letting dependencies surface as things break.

<details>
<summary>Reveal answer</summary>

**C. Use the Explore subagent, which runs discovery in isolation and returns summaries.**

The Explore subagent runs the verbose discovery in isolation and returns only summaries, keeping the main context window clean for implementation.

- **A:** Repeating discovery adds output rather than containing it.
- **B:** That makes the verbose output permanent context, the opposite of the goal.
- **D:** Codebase exploration is one of the lesson's stated reasons to plan, not something to skip.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-4-plan-mode-execution) · [Technical reference](None)

### 236. The hybrid pattern is plan then execute, not plan or execute, as in a multi-file library m

`claude-3-4-7`

A swap from one logging library to another touches thirty files. What does the lesson prescribe?

- **A.** Direct execution throughout, since each file edit is mechanical once the first is done.
- **B.** Plan mode throughout, including the per-file edits, to keep the strategy visible.
- **C.** Plan mode to map the API differences, then direct execution to apply the pattern.
- **D.** Direct execution first, moving to plan mode if the edits stop being mechanical.

<details>
<summary>Reveal answer</summary>

**C. Plan mode to map the API differences, then direct execution to apply the pattern.**

Library migrations are the lesson's example of the hybrid pattern: plan the migration strategy, then execute it file by file. It is plan then direct, not plan or direct.

- **A:** Without a strategy the migration risks being applied inconsistently across files.
- **B:** Planning covers the strategy; the repetitive edits are then executed directly.
- **D:** Waiting for complexity to appear is the trap; here it is stated in the task.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-4-plan-mode-execution) · [Technical reference](None)

### 237. Trap: starting in direct execution and switching to plan mode only once complexity emerges

`claude-3-4-8`

The task is stated up front as restructuring a monolith into microservices. What does the lesson call out as the wrong move?

- **A.** Beginning with direct execution and reaching for a plan once the work turns messy.
- **B.** Choosing plan mode before reading any of the existing service boundaries.
- **C.** Evaluating more than one decomposition before committing to a strategy.
- **D.** Using a subagent to gather the dependency map before the plan is written.

<details>
<summary>Reveal answer</summary>

**A. Beginning with direct execution and reaching for a plan once the work turns messy.**

When the requirements already state that the work is complex, plan mode is the upfront choice; waiting for surprises before switching is the trap.

- **B:** Reading the existing structure is part of what plan mode is for.
- **C:** Weighing multiple approaches is a reason to plan, not an error.
- **D:** That is the recommended way to keep discovery output out of the main context.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-4-plan-mode-execution) · [Technical reference](None)

### 238. Plan mode explores and proposes an approach without modifying any files

`claude-3-4-9`

What should you observe while Claude Code works through a task in plan mode?

- **A.** Files are edited, but the changes are staged rather than written to the working tree.
- **B.** Each proposed edit is applied and then reverted so that its effect can be measured.
- **C.** Only test files are touched, leaving production sources unchanged until approval.
- **D.** No files are modified at all; the codebase is read and an approach is proposed.

<details>
<summary>Reveal answer</summary>

**D. No files are modified at all; the codebase is read and an approach is proposed.**

Plan mode reads the codebase, analyses dependencies and proposes an approach without modifying any files.

- **A:** Plan mode does not produce staged edits; it produces an approach.
- **B:** No apply-and-revert cycle happens during planning.
- **C:** The distinction is not between test and production files; nothing is modified.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-4-plan-mode-execution) · [Technical reference](None)

### 239. Practice scenario: restructuring plans, a clear single-function fix goes direct, a 30-file

`claude-3-4-10`

Three items are queued: splitting a shared library into two packages, correcting an off-by-one error with a clear stack trace, and moving forty files from one HTTP client to another. Which assignment follows the lesson's framework?

- **A.** Plan mode for all three, since every item ends in code changes.
- **B.** Plan mode for the split and the client move, direct execution for the off-by-one fix.
- **C.** Direct execution for all three, given a detailed enough opening prompt.
- **D.** Plan mode for the split only, direct execution for the other two items.

<details>
<summary>Reveal answer</summary>

**B. Plan mode for the split and the client move, direct execution for the off-by-one fix.**

Architectural restructuring and a multi-file migration both call for plan mode, while a single-function fix with a clear stack trace is the textbook direct execution case.

- **A:** The well-scoped fix with a known cause gains nothing from planning.
- **C:** Multi-file architectural work risks costly rework without a strategy.
- **D:** A forty-file migration needs a consistent strategy, so it plans before it executes.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-4-plan-mode-execution) · [Technical reference](None)

### 240. Plan mode suits large-scale changes, architectural decisions, multi-file modifications and

`claude-3-4-11`

An integration can be built two ways, each carrying different infrastructure requirements. What does that fact alone tell you about the mode?

- **A.** Direct execution fits, because both approaches are already understood in outline.
- **B.** Either mode fits, because the choice depends only on how many files are touched.
- **C.** Plan mode fits, because competing approaches need evaluating before you commit.
- **D.** Direct execution fits, because implementing one approach reveals which is better.

<details>
<summary>Reveal answer</summary>

**C. Plan mode fits, because competing approaches need evaluating before you commit.**

Multiple valid approaches with different downstream requirements is one of the lesson's stated triggers for plan mode.

- **A:** Understanding the options is not the same as having chosen between them.
- **B:** Multiple valid approaches is its own criterion, independent of file count.
- **D:** Building first and comparing afterwards is the costly rework the lesson wants to avoid.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-4-plan-mode-execution) · [Technical reference](None)

### 241. Direct execution suits well-scoped changes where the approach and location are already kno

`claude-3-4-12`

Which of these does the lesson's decision framework send to direct execution?

- **A.** Updating a configuration value whose location and new setting are both known.
- **B.** Reorganising a module system so that imports flow in a single direction.
- **C.** Mapping data flows through the codebase before any change has been chosen.
- **D.** Deciding where a new service boundary should fall between two teams.

<details>
<summary>Reveal answer</summary>

**A. Updating a configuration value whose location and new setting are both known.**

A configuration value update has a known location, a known change and no design decision, which is the framework's direct execution profile.

- **B:** Restructuring a module system is listed under plan mode.
- **C:** Codebase exploration is a plan mode trigger, ideally with the Explore subagent.
- **D:** Service boundaries are architectural decisions, which the framework sends to plan mode.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-4-plan-mode-execution) · [Technical reference](None)

## 3.5 — Iterative Refinement Techniques

### 242. Concrete input/output examples are the first technique for inconsistent interpretation

`claude-3-5`

A requested transformation repeatedly handles one edge case incorrectly. What feedback is most actionable?

- **A.** Give a minimal failing input, actual output, expected output and relevant constraint.
- **B.** Repeat that the result should be better.
- **C.** Ask for a longer explanation of the unchanged implementation.
- **D.** Remove the edge case from the examples.

<details>
<summary>Reveal answer</summary>

**A. Give a minimal failing input, actual output, expected output and relevant constraint.**

A concrete counterexample makes the required correction testable.

- **B:** That does not identify the failed behavior.
- **C:** More explanation does not supply the missing acceptance case.
- **D:** Removing the evidence conceals the defect.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-5-iterative-refinement) · [Technical reference](None)

### 243. Regression examples

`claude-3-5-2`

A correction fixes one example but breaks a previously valid case. What should the next iteration include?

- **A.** Removal of the earlier expected result.
- **B.** A larger prompt with no concrete examples.
- **C.** Both examples as explicit acceptance cases.
- **D.** Only the latest failing case, forgetting earlier requirements.

<details>
<summary>Reveal answer</summary>

**C. Both examples as explicit acceptance cases.**

Refinement must preserve known-good behavior while fixing the defect.

- **A:** Deleting a requirement hides the regression.
- **B:** More text does not necessarily preserve the missing case.
- **D:** That encourages oscillating regressions.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-5-iterative-refinement) · [Technical reference](https://code.claude.com/docs/en/best-practices)

### 244. Useful failures

`claude-3-5-3`

Generated code fails a meaningful assertion. What is the right refinement target?

- **A.** Delete the assertion because the model wrote the code.
- **B.** Add a skip for every generated-code failure.
- **C.** Rename the test so it is no longer discovered.
- **D.** The implementation or a demonstrated mismatch in the test's intended contract.

<details>
<summary>Reveal answer</summary>

**D. The implementation or a demonstrated mismatch in the test's intended contract.**

The failure needs diagnosis; a valid assertion should not be weakened just to pass.

- **A:** Authorship does not establish correctness.
- **B:** Skipping removes the evidence rather than repairing behavior.
- **C:** That disguises an unresolved failure.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-5-iterative-refinement) · [Technical reference](https://code.claude.com/docs/en/best-practices)

### 245. Focused iteration

`claude-3-5-4`

A small bug fix keeps accumulating unrelated formatting and architecture changes. What feedback helps?

- **A.** Restate the affected behavior and constrain the patch to the necessary scope.
- **B.** Request a complete rewrite without identifying the bug.
- **C.** Judge quality only by the number of changed lines.
- **D.** Accept unrelated changes because they look modern.

<details>
<summary>Reveal answer</summary>

**A. Restate the affected behavior and constrain the patch to the necessary scope.**

A focused diff makes cause, effect and verification easier to assess.

- **B:** That further expands uncertainty.
- **C:** Diff size alone is not correctness.
- **D:** Appearance does not establish relevance to the task.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-5-iterative-refinement) · [Technical reference](https://code.claude.com/docs/en/best-practices)

### 246. Test-driven iteration is most effective for complex transformations

`claude-3-5-5`

A data migration is complex, with many edge cases around nulls, empty inputs and boundary values. Which technique does the lesson call most effective for that situation?

- **A.** Rewriting the request in more precise technical prose before trying again.
- **B.** Asking Claude to interview you about the migration's requirements first.
- **C.** Writing the tests first and iterating by sharing the failures.
- **D.** Supplying one worked example and asking for the remaining cases by analogy.

<details>
<summary>Reveal answer</summary>

**C. Writing the tests first and iterating by sharing the failures.**

Test-driven iteration is the lesson's most effective technique for complex transformations, because a failure message stating expected versus actual leaves no room for interpretation.

- **A:** More prose still leaves the work to interpretation, which is the failure mode the lesson names.
- **B:** The interview pattern is for domains you do not know well, not for pinning down edge cases you can already state.
- **D:** A single example is thinner than the lesson's own guidance and does not cover the edge cases.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-5-iterative-refinement) · [Technical reference](None)

### 247. The interview pattern suits unfamiliar domains, surfacing considerations you would miss

`claude-3-5-6`

You need a caching layer for an API but have never designed one. Which opening does the lesson recommend?

- **A.** Ask Claude to pose questions about requirements and constraints before implementing.
- **B.** Give two input and output examples of the cache API you expect back.
- **C.** Write failing tests for the cache and share them before any implementation exists.
- **D.** Describe the cache in as much technical detail as you can manage up front.

<details>
<summary>Reveal answer</summary>

**A. Ask Claude to pose questions about requirements and constraints before implementing.**

In an unfamiliar domain the interview pattern has Claude ask about invalidation, TTL, consistency and failure modes, surfacing considerations you would not have raised.

- **B:** Examples pin a transformation you already know; here you do not yet know what to ask for.
- **C:** You cannot write meaningful tests for requirements you have not identified yet.
- **D:** Detail you supply cannot cover the invalidation and consistency questions you do not know to ask.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-5-iterative-refinement) · [Technical reference](None)

### 248. The interview pattern and the examples technique solve different problems and are easily c

`claude-3-5-7`

What separates the interview pattern from the concrete-examples technique?

- **A.** The interview pattern suits long transformations, while examples suit short simple ones.
- **B.** The interview pattern is for batched feedback, while examples are for sequential feedback.
- **C.** The interview pattern applies to generated tests, while examples apply to generated code.
- **D.** The interview pattern surfaces requirements you would miss; examples pin a transformation you know.

<details>
<summary>Reveal answer</summary>

**D. The interview pattern surfaces requirements you would miss; examples pin a transformation you know.**

The interview pattern is for unfamiliar domains where you might overlook requirements; concrete examples are for when you know the exact transformation but the model keeps interpreting it differently.

- **A:** Length of the transformation is not what distinguishes them.
- **B:** Batching and sequencing are a separate axis about interdependent versus independent issues.
- **C:** Neither technique is tied to a particular kind of artefact.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-5-iterative-refinement) · [Technical reference](None)

### 249. Concrete input/output examples are the first technique for inconsistent interpretation

`claude-3-5-8`

The same prose instruction produces a differently structured result on each run. The lesson warns against one instinctive response. Which one?

- **A.** Reaching for more precise prose, which still leaves the request open to interpretation.
- **B.** Providing two before-and-after pairs that fix the transformation exactly.
- **C.** Testing the result on a fresh case to confirm the pattern generalised.
- **D.** Adding one further example that demonstrates a specific edge case.

<details>
<summary>Reveal answer</summary>

**A. Reaching for more precise prose, which still leaves the request open to interpretation.**

Refining prose still depends on interpretation; concrete input and output examples remove the ambiguity, so examples come first.

- **B:** This is the recommended first move, not the mistake.
- **C:** Verifying generalisation is a step in the recommended process.
- **D:** Adding an edge case example is the recommended follow-up when the standard case works.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-5-iterative-refinement) · [Technical reference](None)

### 250. Batch interacting fixes into a single message so the model sees all constraints at once

`claude-3-5-9`

Changing the error response shape also forces a change to the log format and to the client SDK type definitions. How should that feedback reach Claude?

- **A.** As three separate turns, so each change can be reviewed before the next begins.
- **B.** As one message listing all three, so the model sees the interacting constraints together.
- **C.** As one message naming only the response shape, letting the other two follow from it.
- **D.** As three separate turns in reverse order, beginning with the SDK type definitions.

<details>
<summary>Reveal answer</summary>

**B. As one message listing all three, so the model sees the interacting constraints together.**

When fixes interact, all of the feedback belongs in a single message so the model can produce one coherent change across the interacting constraints.

- **A:** Sequencing interdependent fixes lets each one conflict with the others.
- **C:** Leaving constraints unstated invites a fix that satisfies one and breaks the rest.
- **D:** Ordering does not fix the underlying problem of splitting interdependent constraints.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-5-iterative-refinement) · [Technical reference](None)

### 251. Iterate sequentially on independent issues, since batching them can confuse the model

`claude-3-5-10`

Two unrelated complaints remain: the function names are not camelCase, and the indentation uses four spaces instead of two. What does the lesson advise?

- **A.** Combine them, since fewer turns always yield a more coherent overall result.
- **B.** Drop the smaller one, since style issues rarely justify another iteration.
- **C.** Fix them one at a time, since batching independent issues can confuse the model.
- **D.** Restate both inside the original prompt and regenerate the whole file from scratch.

<details>
<summary>Reveal answer</summary>

**C. Fix them one at a time, since batching independent issues can confuse the model.**

Independent issues are corrected sequentially, because batching feedback that does not interact can confuse the model about which correction applies to which part of the code.

- **A:** Fewer turns is not the goal; batching independent issues can confuse which feedback applies where.
- **B:** The lesson does not advise dropping feedback; it advises sequencing it.
- **D:** Regenerating discards working output and is not the lesson's refinement path.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-5-iterative-refinement) · [Technical reference](None)

### 252. Two or three well-chosen examples suffice, then verify generalisation on a new case

`claude-3-5-11`

How many examples does the lesson consider enough, and what comes immediately after supplying them?

- **A.** Two or three well-chosen ones, then a test on a new case to confirm it generalised.
- **B.** One canonical example, then a prose summary restating the rule it demonstrates.
- **C.** As many examples as there are cases, since the model applies only patterns it has seen.
- **D.** Ten or more, then a ranking exercise so the model learns which cases matter most.

<details>
<summary>Reveal answer</summary>

**A. Two or three well-chosen ones, then a test on a new case to confirm it generalised.**

Two or three well-chosen examples set the pattern, and the next step is trying a new case to confirm the model generalised it correctly.

- **B:** Falling back to prose reintroduces the interpretation problem examples were meant to remove.
- **C:** The lesson explicitly says you do not need to hand it every possible case.
- **D:** Piling on examples is not the technique; a few well-chosen ones suffice.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-5-iterative-refinement) · [Technical reference](None)

### 253. Tests should cover the happy path, edge cases such as nulls and empty inputs, and performa

`claude-3-5-12`

When you define expected behaviour through tests before iterating, which set of cases does the lesson name?

- **A.** Randomly generated inputs, so that the transformation cannot simply be memorised.
- **B.** Happy path only, because failures on edge cases muddy the refinement signal.
- **C.** Regression cases drawn from the previous session's transcript of failures.
- **D.** Happy path, edge cases such as nulls and empty inputs, and performance requirements.

<details>
<summary>Reveal answer</summary>

**D. Happy path, edge cases such as nulls and empty inputs, and performance requirements.**

Test-driven iteration defines expected behaviour through the happy path, edge cases such as nulls, empty inputs and boundaries, and performance requirements where they apply.

- **A:** Random inputs are not part of the described technique.
- **B:** Edge cases are exactly where the lesson expects the informative failures.
- **C:** The lesson defines cases from expected behaviour, not from an earlier transcript.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-5-iterative-refinement) · [Technical reference](None)

## 3.6 — CI/CD Integration

### 254. The -p (--print) flag runs Claude Code non-interactively so a CI job does not hang

`claude-3-6`

A CI job must send a prompt to Claude Code and collect its output without an interactive conversation. Which invocation mode fits?

- **A.** A prompt instruction saying the terminal has no keyboard.
- **B.** Print mode using claude -p, with credentials and permissions configured for the job.
- **C.** An interactive session that waits for a developer to type the prompt.
- **D.** Resume mode alone, without specifying how the job supplies input or receives output.

<details>
<summary>Reveal answer</summary>

**B. Print mode using claude -p, with credentials and permissions configured for the job.**

Print mode supports programmatic invocation; it does not bypass authentication or permission policy.

- **A:** Prompt text does not choose the CLI's execution mode.
- **C:** That requires the interaction the job is meant to avoid.
- **D:** Session selection does not replace programmatic invocation.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 255. Machine-readable CI output

`claude-3-6-2`

A CI step must parse Claude Code's result. What should it request and handle explicitly?

- **A.** The absence of comments as proof the process executed successfully.
- **B.** A supported structured output format, with separate error and incomplete-result handling.
- **C.** Only prose formatted differently on each run.
- **D.** Any stdout as proof the review passed.

<details>
<summary>Reveal answer</summary>

**B. A supported structured output format, with separate error and incomplete-result handling.**

Automation needs a parseable contract and failure semantics.

- **A:** No findings and no successful execution are different outcomes.
- **C:** Unstable prose is a fragile machine interface.
- **D:** Output can describe failure or partial work.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 256. Read-only review

`claude-3-6-3`

A CI review is authorized to inspect code but not modify it. How should that be implemented?

- **A.** Allow writes and delete the audit trail afterward.
- **B.** Give deployment credentials to simplify repository reads.
- **C.** Use permissions or an execution environment that enforces read-only access.
- **D.** Rely only on the phrase 'please do not edit'.

<details>
<summary>Reveal answer</summary>

**C. Use permissions or an execution environment that enforces read-only access.**

The boundary belongs in executable policy, not only review instructions.

- **A:** That conceals effects rather than preventing them.
- **B:** That adds unnecessary privilege.
- **D:** A request is not an enforced capability limit.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 257. Incremental findings

`claude-3-6-4`

A review reruns after a new commit. How should it use earlier findings?

- **A.** Repost every old comment without inspecting the changes.
- **B.** Suppress every previously seen location forever.
- **C.** Assume the newest commit resolves all previous findings.
- **D.** Re-check them against the new diff and report new or still-relevant issues with stable references.

<details>
<summary>Reveal answer</summary>

**D. Re-check them against the new diff and report new or still-relevant issues with stable references.**

Historical findings are context to verify, not conclusions to repeat blindly.

- **A:** That can resurrect fixed issues.
- **B:** A later change may introduce a new defect there.
- **C:** A commit's existence is not proof of repair.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 258. CLAUDE_HEADLESS and --batch do not exist, and stdin redirection does not address interacti

`claude-3-6-5`

A colleague proposes fixing a Claude Code job that hangs in CI by exporting CLAUDE_HEADLESS=true before the command. How should you respond?

- **A.** It works, but only if the runner also redirects stdin from /dev/null.
- **B.** It works, though --batch is the documented flag for the same purpose.
- **C.** No such variable exists; print mode through the -p flag is the documented fix.
- **D.** It must be exported before the checkout step in order to take effect.

<details>
<summary>Reveal answer</summary>

**C. No such variable exists; print mode through the -p flag is the documented fix.**

CLAUDE_HEADLESS and --batch do not exist, and stdin redirection does not address interactive mode. The documented fix is the -p flag.

- **A:** Redirecting stdin does not properly address interactive mode, and the variable still does not exist.
- **B:** Neither the variable nor that flag exists in Claude Code.
- **D:** Export ordering is irrelevant to a variable Claude Code never reads.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 259. --json-schema validates the final output against a schema, in print mode only

`claude-3-6-6`

A CI job runs claude -p with both --output-format json and --json-schema. Where does the schema-validated data end up?

- **A.** At the top level of the JSON object, replacing the envelope that would otherwise wrap it.
- **B.** In the envelope's structured_output field, which the job reads with jq .structured_output.
- **C.** In a sidecar file named after the schema, written beside the working directory.
- **D.** Inside the result text as fenced JSON, which the job extracts by string matching.

<details>
<summary>Reveal answer</summary>

**B. In the envelope's structured_output field, which the job reads with jq .structured_output.**

Schema-conforming data lands in the JSON envelope's structured_output field, extracted with jq .structured_output rather than from the top level.

- **A:** The envelope is still there; the validated data sits inside it.
- **C:** No sidecar file is produced.
- **D:** Schema validation exists precisely so the job does not have to scrape prose.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 260. --output-format json wraps the run in an envelope with result text, session ID, and cost a

`claude-3-6-7`

What does --output-format json wrap around a print-mode run?

- **A.** A stream of newline-delimited events, one for each tool call the run performs.
- **B.** A diff of every file the run touched, for the pipeline to apply or reject.
- **C.** A schema definition the job can publish so downstream steps agree on the shape.
- **D.** An envelope carrying the result text, the session ID, and cost and usage metadata.

<details>
<summary>Reveal answer</summary>

**D. An envelope carrying the result text, the session ID, and cost and usage metadata.**

The json output format wraps the run in an envelope holding the result text, the session ID and cost and usage metadata instead of human-readable text.

- **A:** That shape belongs to stream-json, not to the json envelope.
- **B:** The run does not emit a patch as its output format.
- **C:** The schema is something you supply with --json-schema, not something the envelope emits.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 261. Review should run as a separate invocation with no shared session context

`claude-3-6-8`

A pipeline generates an authentication middleware and then asks the same session to review it. What does the lesson recommend instead?

- **A.** Keep the one session but word the review request differently on the second turn.
- **B.** Keep the one session and raise the turn cap so the review has room to work.
- **C.** Run the review in the same session after compacting the generation history first.
- **D.** Run the review as a separate invocation that shares no session context.

<details>
<summary>Reveal answer</summary>

**D. Run the review as a separate invocation that shares no session context.**

Session context isolation means a second, independent claude -p invocation reviews the code with no access to the generation session's reasoning.

- **A:** The reasoning context that biases the review is still present regardless of wording.
- **B:** More turns do not remove the prior justification the session is carrying.
- **C:** Compaction shortens the history rather than giving the review a genuinely independent view.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 262. Self-review is weaker because the generating session retains the reasoning that justified 

`claude-3-6-9`

Why does the lesson call same-session self-review a measurably weaker check?

- **A.** The session has already spent most of its turn budget producing the code.
- **B.** The session retains the reasoning that justified its choices, so it questions them less.
- **C.** The session's tools are downgraded to read-only once it has written code.
- **D.** The session drops its memory files after the first file has been written.

<details>
<summary>Reveal answer</summary>

**B. The session retains the reasoning that justified its choices, so it questions them less.**

A session that generated code still holds the tradeoffs it weighed and the alternatives it rejected, so it is less likely to question decisions it already justified.

- **A:** The effect is about retained reasoning, not about how many turns remain.
- **C:** No such downgrade happens after a write.
- **D:** Memory files are not discarded partway through a session.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 263. Incremental review passes prior findings and asks only for new or still-present issues

`claude-3-6-10`

An automated review reruns on every push with no memory of earlier runs. Which findings keep reappearing in its comments?

- **A.** The ones the developer fixed, since the reviewer cannot see which commit fixed them.
- **B.** The ones raised by the generation session rather than by the review session.
- **C.** The ones the schema marked low severity, which get re-ranked on each run.
- **D.** The ones the developer read, weighed and decided to leave exactly as they are.

<details>
<summary>Reveal answer</summary>

**D. The ones the developer read, weighed and decided to leave exactly as they are.**

Fixed issues disappear because the code changed, so the findings that recur are the ones the developer consciously declined to act on, and a review without prior context re-flags them every push.

- **A:** A genuine fix drops out on its own, because the changed code no longer triggers the finding.
- **B:** Which session raised a finding does not determine whether it reappears.
- **C:** Severity ranking is not what makes findings recur.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 264. Duplicate comments erode developer trust until developers stop reading them

`claude-3-6-11`

What reason does the lesson give for carrying prior findings into each subsequent review run?

- **A.** Reruns cost roughly double once a pull request passes twenty commits.
- **B.** Repeated comments erode developer trust until people stop reading them.
- **C.** Findings expire from the API after a day and cannot be fetched again later.
- **D.** Review platforms reject a second comment posted at the same file and line.

<details>
<summary>Reveal answer</summary>

**B. Repeated comments erode developer trust until people stop reading them.**

If the same comments appear on every push regardless of what was fixed, developers stop reading them, so incremental review context protects the signal.

- **A:** Cost is not the argument the lesson makes here.
- **C:** Findings are stored by the pipeline; nothing expires them.
- **D:** No such platform restriction is described.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 265. Claude Code reads CLAUDE.md in CI, which is how project standards, fixtures and review cri

`claude-3-6-12`

CI-invoked test generation keeps producing generic boilerplate that ignores the project's factories and fixtures. What does the lesson prescribe?

- **A.** Raise the turn cap so the run has time to discover the factories for itself.
- **B.** Move the job onto the Batch API so a longer run can explore the repository.
- **C.** Replace the system prompt with one describing the testing framework in use.
- **D.** Document the testing standards, fixtures and review criteria in CLAUDE.md, which CI also reads.

<details>
<summary>Reveal answer</summary>

**D. Document the testing standards, fixtures and review criteria in CLAUDE.md, which CI also reads.**

Claude Code reads project CLAUDE.md files in CI just as in interactive use, so testing standards, fixture paths and review criteria documented there turn boilerplate into tests that follow team patterns.

- **A:** The problem is missing project context, which more turns do not supply.
- **B:** Batch changes latency and cost, not the project knowledge available to the run.
- **C:** Replacing the prompt discards the defaults and still omits the project's own standards.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 266. --system-prompt and --system-prompt-file replace the default prompt; the append variants a

`claude-3-6-13`

A CI run should stay a coding assistant while also following three extra house rules. Which flag fits?

- **A.** --append-system-prompt, which keeps the default prompt and adds your rules to it.
- **B.** --system-prompt, which supplies the house rules as the entire prompt for the run.
- **C.** --system-prompt-file, which swaps in a file containing just the house rules.
- **D.** --output-format json, which attaches the rules to the response envelope.

<details>
<summary>Reveal answer</summary>

**A. --append-system-prompt, which keeps the default prompt and adds your rules to it.**

Appending keeps Claude Code's default prompt, including its tool guidance and safety instructions, so you supply only what differs.

- **B:** That drops the default prompt, so everything the task still needs must be resupplied.
- **C:** This also replaces the default prompt rather than adding to it.
- **D:** The output format shapes results; it carries no instructions.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 267. Replace the system prompt when identity or permission model differs; append when Claude st

`claude-3-6-14`

When does the lesson say replacing the entire system prompt is the right call?

- **A.** Whenever the run is non-interactive, since the default prompt assumes a human is present.
- **B.** Whenever the prompt text is long enough to justify keeping it in a version-controlled file.
- **C.** When the agent's identity and permission model differ from Claude Code's own.
- **D.** When the job needs the default tool guidance but a different set of coding conventions.

<details>
<summary>Reveal answer</summary>

**C. When the agent's identity and permission model differ from Claude Code's own.**

Replace when the identity or permission model differs from Claude Code's, such as a non-coding agent in an unattended pipeline; replacing drops the default prompt, so you own everything the task still needs.

- **A:** Print mode alone is no reason to discard the default prompt.
- **B:** File versus inline is about the flag variant, not about replace versus append.
- **D:** Needing the defaults is precisely the case for appending instead.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 268. --output-format takes text, json or stream-json; --input-format shapes print-mode input

`claude-3-6-15`

Which flag caps how many agentic turns a print-mode run takes before it exits?

- **A.** --permission-mode
- **B.** --max-turns
- **C.** --input-format
- **D.** --bare

<details>
<summary>Reveal answer</summary>

**B. --max-turns**

--max-turns caps the number of agentic turns a run may take, after which it exits.

- **A:** This sets the starting permission mode for the session.
- **C:** This selects the input shape for print mode.
- **D:** This skips auto-discovery of project configuration.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 269. --permission-mode starts the run in default, acceptEdits, plan, auto, dontAsk, bypassPermi

`claude-3-6-16`

Which value is a documented setting for --permission-mode?

- **A.** readonly
- **B.** headless
- **C.** acceptEdits
- **D.** strict

<details>
<summary>Reveal answer</summary>

**C. acceptEdits**

The documented modes are default, acceptEdits, plan, auto, dontAsk, bypassPermissions and manual, the last being an alias for default from v2.1.200.

- **A:** Read-only behaviour comes from tool and permission rules, not from a mode of this name.
- **B:** Non-interactive execution is the -p flag, not a permission mode.
- **D:** No such mode is listed.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 270. --allowedTools pre-approves tools; a bare name in --disallowedTools removes the tool from 

`claude-3-6-17`

What does a bare tool name listed in --disallowedTools do, according to the lesson?

- **A.** It asks for confirmation the first time that tool is called during the run.
- **B.** It removes the tool from context entirely rather than merely denying its calls.
- **C.** It downgrades the tool so it runs but cannot write outside the working directory.
- **D.** It applies only to subagents, leaving the main loop's tool set unchanged.

<details>
<summary>Reveal answer</summary>

**B. It removes the tool from context entirely rather than merely denying its calls.**

In --disallowedTools a bare tool name removes the tool from context entirely, while --allowedTools names the tools that may run without a permission prompt.

- **A:** Deny rules do not degrade into a prompt.
- **C:** No scoping-down behaviour is described for deny rules.
- **D:** The rule applies to the run, not just to subagents.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 271. --add-dir grants file access to a directory without configuration discovery there

`claude-3-6-18`

A run needs to read and edit a sibling repository checked out next to the project. What does --add-dir give it?

- **A.** File access to that directory, without configuration discovery inside it.
- **B.** File access plus that directory's CLAUDE.md and skills as loaded configuration.
- **C.** Read access only, since edits stay confined to the launch directory.
- **D.** A second session scoped to that directory, resumable by its own identifier.

<details>
<summary>Reveal answer</summary>

**A. File access to that directory, without configuration discovery inside it.**

--add-dir adds a directory Claude may read and edit; it grants file access and does not pull that directory's configuration into the session.

- **B:** Configuration in the added directory is not discovered by this flag.
- **C:** The flag adds a directory Claude may read and edit.
- **D:** No additional session is created.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 272. -c/--continue resumes the most recent conversation in the directory; -r/--resume takes an 

`claude-3-6-19`

Which description of the session flags matches the lesson?

- **A.** -c resumes a session by name, while -r resumes the most recent one in this directory.
- **B.** -c starts a fresh session in print mode, while -r replays the previous run's transcript.
- **C.** -c resumes the most recent conversation in the current directory, while -r resumes a specific session.
- **D.** -c and -r are aliases that differ only in whether the session identifier is quoted.

<details>
<summary>Reveal answer</summary>

**C. -c resumes the most recent conversation in the current directory, while -r resumes a specific session.**

-c (--continue) resumes the most recent conversation in the current directory, while -r (--resume) takes a session id or name.

- **A:** The two are the other way round.
- **B:** Neither flag starts a fresh session or replays a transcript.
- **D:** They are distinct flags with distinct behaviour.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 273. --bare skips auto-discovery of hooks, skills, plugins, MCP servers, auto memory and CLAUDE

`claude-3-6-20`

A scripted call should start quickly and load no project configuration at all. Which flag does the lesson name, and what does it skip?

- **A.** --bare, which skips hooks, skills, plugins, MCP servers, auto memory and CLAUDE.md.
- **B.** --bare, which skips MCP servers and plugins while memory files still load normally.
- **C.** --tools, which restricts the built-in tool set and therefore skips discovery too.
- **D.** --max-turns, which shortens a run by skipping its discovery phase entirely.

<details>
<summary>Reveal answer</summary>

**A. --bare, which skips hooks, skills, plugins, MCP servers, auto memory and CLAUDE.md.**

--bare is minimal mode: it skips auto-discovery of hooks, skills, plugins, MCP servers, auto memory and CLAUDE.md, leaving only Bash and file read and edit tools.

- **B:** Auto memory and CLAUDE.md are skipped as well.
- **C:** That flag restricts available built-in tools and does not affect configuration discovery.
- **D:** The turn cap limits agentic turns; it does not change what configuration loads.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 274. The Message Batches API gives 50% savings with up to 24-hour processing and no latency SLA

`claude-3-6-21`

What trade-off does the lesson attach to the Message Batches API?

- **A.** Half the cost, with processing up to twenty-four hours and no latency guarantee.
- **B.** Half the cost, with a guaranteed one-hour turnaround for every queued request.
- **C.** The same cost, with higher rate limits and priority scheduling for long jobs.
- **D.** Half the cost, but only for runs that produce schema-validated structured output.

<details>
<summary>Reveal answer</summary>

**A. Half the cost, with processing up to twenty-four hours and no latency guarantee.**

The Message Batches API offers 50% cost savings with processing times up to 24 hours and no guaranteed latency.

- **B:** There is no guaranteed turnaround.
- **C:** The defining benefit is the cost saving, not priority scheduling.
- **D:** The saving is not conditional on the output format.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 275. Blocking pre-merge checks use the real-time API; overnight and weekly analyses use batch

`claude-3-6-22`

Which workload does the lesson keep on the real-time API rather than moving it to batch?

- **A.** An overnight technical debt report that someone reads the following morning.
- **B.** A weekly code audit scheduled to run outside working hours.
- **C.** A nightly test generation run reviewed by developers the next day.
- **D.** A pre-merge check that blocks the merge until it reports back.

<details>
<summary>Reveal answer</summary>

**D. A pre-merge check that blocks the merge until it reports back.**

Pre-merge checks are blocking workflows where developers wait for the result, so they need the real-time API; overnight and weekly analyses are the batch candidates.

- **A:** Not time-sensitive, so it is a batch candidate.
- **B:** Scheduled and latency-tolerant, so batch suits it.
- **C:** Runs overnight and is reviewed later, so batch suits it.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 276. Include existing test files in context so CI test generation finds gaps instead of duplica

`claude-3-6-23`

A CI test-generation job keeps proposing tests that the suite already contains. What does the lesson suggest?

- **A.** Lower the turn cap so that fewer tests are proposed on each invocation.
- **B.** Include the existing test files in context so the run identifies coverage gaps.
- **C.** Ask for prose recommendations instead of generated test code.
- **D.** Move the job to the Batch API so a slower pass can compare more files.

<details>
<summary>Reveal answer</summary>

**B. Include the existing test files in context so the run identifies coverage gaps.**

Including existing test files in context lets Claude Code identify coverage gaps instead of duplicating scenarios the suite already has.

- **A:** Fewer suggestions does not make the remaining ones aware of existing coverage.
- **C:** Changing the output shape does not address the duplication.
- **D:** Batch affects latency and cost, not what the run can see.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

### 277. --tools restricts which built-in tools are available at all, and --model sets the session 

`claude-3-6-24`

A pipeline should expose only Bash, Edit and Read to the run, with every other built-in tool unavailable. Which flag expresses that?

- **A.** --allowedTools naming those three, which is what removes every other tool from the run.
- **B.** --tools naming those three, which restricts which built-in tools are available at all.
- **C.** --model with a restricted alias, which limits the tool set the session exposes.
- **D.** --permission-mode dontAsk, which narrows the session down to the three named tools.

<details>
<summary>Reveal answer</summary>

**B. --tools naming those three, which restricts which built-in tools are available at all.**

--tools restricts which built-in tools are available at all, while --allowedTools only pre-approves tools so they run without a prompt.

- **A:** That flag names tools that run without a permission prompt; it does not limit availability.
- **C:** That flag sets the session model and has nothing to do with tools.
- **D:** A permission mode governs prompting behaviour, not which tools exist.

</details>

[Lesson material](https://claudecertificationguide.com/learn/3-claude-code-config/3-6-cicd-integration) · [Technical reference](https://code.claude.com/docs/en/headless)

## 4.1 — System Prompts with Explicit Criteria

### 278. Vague instructions such as 'be conservative' or 'use your best judgement' give the model n

`claude-4-1`

A classifier labels similar tickets inconsistently. Which instruction best defines a testable decision boundary?

- **A.** Ask it to use the most impressive-sounding label.
- **B.** Tell it to choose whichever label appears first.
- **C.** Specify the label conditions, exclusions and treatment of ambiguous cases.
- **D.** Ask for careful decisions without defining the labels.

<details>
<summary>Reveal answer</summary>

**C. Specify the label conditions, exclusions and treatment of ambiguous cases.**

Explicit criteria let outputs be compared against a known policy.

- **A:** Presentation quality is unrelated to the intended classification rule.
- **B:** List order is not a valid classification criterion.
- **D:** Carefulness does not define category membership.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](None)

### 279. Decision policy

`claude-4-1-2`

An instruction says 'report important problems' but never defines important. What is missing?

- **A.** Operational inclusion and exclusion criteria.
- **B.** A longer greeting before the request.
- **C.** A different name for the model.
- **D.** A requirement to make every report longer.

<details>
<summary>Reveal answer</summary>

**A. Operational inclusion and exclusion criteria.**

A testable boundary needs more than an evaluative adjective.

- **B:** A greeting does not define the policy.
- **C:** Model naming does not resolve the ambiguity.
- **D:** Length is not a severity definition.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)

### 280. Instructions versus data

`claude-4-1-3`

A document being classified contains text telling the model to change its labels. How should the application treat that text?

- **A.** As authorization to run any requested tool.
- **B.** As task data, while enforcing the trusted classification contract.
- **C.** As a replacement for the application's instructions.
- **D.** As automatic proof that every label is invalid.

<details>
<summary>Reveal answer</summary>

**B. As task data, while enforcing the trusted classification contract.**

Embedded source text does not gain authority over the application task.

- **A:** Data content does not grant tool permission.
- **C:** That promotes untrusted data into control.
- **D:** Hostile text does not determine all classification outcomes.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)

### 281. Output requirements

`claude-4-1-4`

A review prompt needs actionable findings. Which output contract helps?

- **A.** Require one finding per file regardless of evidence.
- **B.** Require only praise so the report is concise.
- **C.** Require the location, violated criterion and supporting evidence for each finding.
- **D.** Require only a numeric confidence value.

<details>
<summary>Reveal answer</summary>

**C. Require the location, violated criterion and supporting evidence for each finding.**

Those fields let a reviewer inspect and reproduce the claim.

- **A:** A quota can force unsupported findings.
- **B:** That cannot satisfy a defect-review task.
- **D:** Confidence alone does not explain the issue.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)

### 282. Vague instructions such as 'be conservative' or 'use your best judgement' give the model n

`claude-4-1-5`

A code review system prompt currently reads 'be conservative and use your best judgement.' Which replacement gives the model an actionable decision boundary?

- **A.** Report bugs and security vulnerabilities, and skip style preferences and local patterns.
- **B.** Report any issue you are more than eighty percent certain is a genuine defect.
- **C.** Report issues that an experienced engineer would consider genuinely important.
- **D.** Report issues in priority order and keep the finding count under ten per file.

<details>
<summary>Reveal answer</summary>

**A. Report bugs and security vulnerabilities, and skip style preferences and local patterns.**

Explicit categorical criteria state what to report and what to skip, which is the lesson's replacement for vague instructions such as 'be conservative'.

- **B:** A confidence threshold is not a criterion; self-reported confidence is poorly calibrated and gives no definition of a valid finding.
- **C:** This is another evaluative adjective with no operational boundary, exactly the class of instruction the lesson rejects.
- **D:** A volume cap limits output without ever defining what qualifies as a finding.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](None)

### 283. High false positive rates in one category destroy developer trust in all categories becaus

`claude-4-1-6`

Your review bot's documentation-mismatch findings are wrong about 40 percent of the time, while its security findings run at high accuracy. Developers now ignore the security findings too. What does this demonstrate?

- **A.** Security findings degrade in accuracy when documentation findings share the same prompt.
- **B.** Reviewers only ever read the category that appears first in a generated report.
- **C.** Trust is not category-specific, so one noisy category degrades confidence in the whole output.
- **D.** Precision only matters as an average across categories rather than per category.

<details>
<summary>Reveal answer</summary>

**C. Trust is not category-specific, so one noisy category degrades confidence in the whole output.**

High false positive rates in one category destroy developer trust in every category, because trust is not category-specific.

- **A:** The security category's accuracy is unchanged; what changed is whether developers read it.
- **B:** The lesson attributes the behaviour to lost trust, not to report ordering.
- **D:** The opposite holds: a single bad category drags down a system whose average precision looks acceptable.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](None)

### 284. Trust recovery: temporarily disable the high false positive category while reworking its p

`claude-4-1-7`

That same pipeline emits documentation-mismatch findings that are wrong roughly 40 percent of the time, and developers have stopped reading all categories. Which response restores trust fastest?

- **A.** Raise the temperature, run the review repeatedly, and keep findings that appear in every run.
- **B.** Switch off the documentation-mismatch category while you rewrite its criteria with concrete code examples.
- **C.** Append an instruction telling the model to report only high-confidence documentation issues.
- **D.** Add a second model pass that silently discards documentation findings it cannot confirm.

<details>
<summary>Reveal answer</summary>

**B. Switch off the documentation-mismatch category while you rewrite its criteria with concrete code examples.**

Temporarily disabling the high false positive category restores system-wide trust immediately while its criteria are rebuilt with concrete code examples.

- **A:** Sampling variation is not the cause, and repeated runs do not supply the missing criteria.
- **C:** Self-reported confidence is poorly calibrated, so this does not reduce false positives.
- **D:** An extra pass adds cost without defining what a valid documentation finding is, and the noisy category keeps running.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](None)

### 285. Severity levels must be calibrated with concrete code examples, not prose descriptions

`claude-4-1-8`

Your prompt defines severity in prose, such as 'Critical: issues that could cause system failures or data loss.' Classifications still vary between runs. What does the lesson prescribe?

- **A.** Add a numeric score range beside each label so the model can calculate severity.
- **B.** Ask the model to justify its severity choice in prose before it assigns a label.
- **C.** Cut the number of severity levels to two so there is less room for interpretation.
- **D.** Replace the prose definitions with actual code snippets that exemplify each severity level.

<details>
<summary>Reveal answer</summary>

**D. Replace the prose definitions with actual code snippets that exemplify each severity level.**

Severity calibration needs concrete code examples for each level, because prose definitions force the model to interpret what a phrase like 'system failures' covers.

- **A:** A numeric range still leaves the model to decide which issues land in it.
- **B:** Justification does not remove the ambiguity in the definition being applied.
- **C:** Fewer levels do not fix the underlying problem, which is that prose definitions must be interpreted.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](None)

### 286. Confidence-based filtering fails because model self-reported confidence is poorly calibrat

`claude-4-1-9`

Why does adding 'only report high-confidence findings' fail to reduce false positives?

- **A.** Self-reported confidence is poorly calibrated, so the model is often certain about wrong findings.
- **B.** Confidence values cannot be returned in a structured field alongside each finding.
- **C.** Confidence filtering discards the highest severity findings before developers see them.
- **D.** Confidence values change the sampling temperature and make the output less deterministic.

<details>
<summary>Reveal answer</summary>

**A. Self-reported confidence is poorly calibrated, so the model is often certain about wrong findings.**

Large language model self-reported confidence is poorly calibrated, so filtering on it removes good findings and keeps bad ones.

- **B:** Findings can carry confidence fields; the problem is the quality of the value, not whether it can be emitted.
- **C:** Severity and confidence are independent, and the failure is not severity-specific.
- **D:** Asking for confidence does not alter sampling parameters.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](None)

### 287. Confidence scores are valid for routing uncertain findings to human review, not for defini

`claude-4-1-10`

Where do confidence scores legitimately earn their place in a review pipeline?

- **A.** As the primary filter deciding which findings the model produces in the first place.
- **B.** As a replacement for categorical criteria once precision reaches an acceptable level.
- **C.** As a routing signal that sends uncertain findings to human review once criteria exist.
- **D.** As a substitute for severity levels, since both express how serious a finding is.

<details>
<summary>Reveal answer</summary>

**C. As a routing signal that sends uncertain findings to human review once criteria exist.**

Confidence scores are useful for routing uncertain findings to human review, but only after explicit criteria define what counts as a finding.

- **A:** The lesson explicitly rejects confidence as the mechanism that defines a valid finding.
- **B:** Criteria are never replaced by confidence; they remain the first step.
- **D:** Confidence expresses certainty, not impact, so it cannot stand in for severity.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](None)

### 288. Hierarchy: explicit criteria first, confidence-based routing second

`claude-4-1-11`

Precision on one review category is poor. What order of work does the lesson require?

- **A.** Tune a confidence threshold first, then write criteria for whatever still slips through.
- **B.** Write explicit criteria first, and only then layer confidence-based routing on top.
- **C.** Introduce routing and criteria simultaneously so their effects can be compared directly.
- **D.** Skip criteria altogether if the routing threshold already keeps finding volume low.

<details>
<summary>Reveal answer</summary>

**B. Write explicit criteria first, and only then layer confidence-based routing on top.**

The hierarchy is explicit criteria first, confidence-based routing second, and the first step is never skipped.

- **A:** This inverts the hierarchy; a threshold applied to undefined findings has nothing reliable to filter.
- **C:** The lesson does not treat these as competing options to A/B test; criteria are a prerequisite.
- **D:** Low volume is not precision, and skipping the first step is the error the lesson warns against.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](None)

### 289. Flag comments only when claimed behaviour contradicts actual code behaviour

`claude-4-1-12`

The lesson's example review prompt allows comments to be flagged under exactly one condition. Which is it?

- **A.** When a comment is missing from a public function that has no documentation.
- **B.** When a comment uses terminology that differs from the local naming conventions.
- **C.** When a comment has not been updated since the file was last modified.
- **D.** When the behaviour a comment claims contradicts what the code actually does.

<details>
<summary>Reveal answer</summary>

**D. When the behaviour a comment claims contradicts what the code actually does.**

The example prompt permits a comment finding only when the claimed behaviour contradicts the code's actual behaviour.

- **A:** Absent documentation is not the trigger the example prompt defines.
- **B:** Local patterns and style are explicitly in the skip list.
- **C:** Staleness by timestamp is not a behavioural contradiction and is not the stated trigger.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](None)

### 290. Build exercise: disable any category whose false positive rate exceeds 25 percent and docu

`claude-4-1-13`

In the lesson's build exercise, what false positive rate triggers temporarily disabling a review category?

- **A.** Above 25 percent for that category.
- **B.** Above 50 percent for that category.
- **C.** Any category producing fewer findings than the security category.
- **D.** Any category whose findings developers dismiss more than once a week.

<details>
<summary>Reveal answer</summary>

**A. Above 25 percent for that category.**

The build exercise disables any category whose false positive rate exceeds 25 percent until its criteria are refined.

- **B:** This is looser than the exercise specifies and leaves badly performing categories running.
- **C:** Finding volume is unrelated to the precision threshold in the exercise.
- **D:** Dismissal frequency is not the metric the exercise defines for this decision.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](None)

### 291. Disabling a category prioritises system-wide trust over category completeness; it is re-en

`claude-4-1-14`

You have switched off a noisy review category while you rework it. What does the lesson say this decision represents?

- **A.** The category is permanently retired because its precision cannot be recovered.
- **B.** System-wide trust is being prioritised over category completeness while criteria are rebuilt.
- **C.** The remaining categories must also be paused so the comparison stays fair.
- **D.** The findings should still be generated but hidden from the report as a control group.

<details>
<summary>Reveal answer</summary>

**B. System-wide trust is being prioritised over category completeness while criteria are rebuilt.**

Disabling the category trades category completeness for system-wide trust, and it is re-enabled once its precision improves.

- **A:** The lesson is explicit that the category is not being abandoned, only paused.
- **C:** Pausing working categories would destroy the trust the manoeuvre is meant to protect.
- **D:** The lesson calls for disabling the category, not for shadow reporting.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-1-system-prompts) · [Technical reference](None)

## 4.2 — Few-Shot Prompting

### 292. Few-shot examples are the most effective first technique for consistent, well-formatted ou

`claude-4-2`

Instructions describe an output convention, but valid edge cases are formatted inconsistently. Which addition can demonstrate the convention?

- **A.** Several copies of the same easy example.
- **B.** Only examples whose outputs violate the intended convention.
- **C.** Examples of unrelated tasks with a similar word count.
- **D.** A small set of varied input/output examples, including the edge cases.

<details>
<summary>Reveal answer</summary>

**D. A small set of varied input/output examples, including the edge cases.**

Examples show how the rule applies; their effect still needs evaluation.

- **A:** Repeated easy cases do not demonstrate the troublesome boundary.
- **B:** Unexplained wrong outputs teach the wrong pattern.
- **C:** Length similarity does not show the required mapping.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](None)

### 293. Example diversity

`claude-4-2-2`

Few-shot examples cover only easy cases from the dominant class. What is missing?

- **A.** More copies of the same dominant example.
- **B.** A rule that minority classes never occur.
- **C.** Examples with their correct labels removed.
- **D.** Representative boundary and minority cases.

<details>
<summary>Reveal answer</summary>

**D. Representative boundary and minority cases.**

Examples should demonstrate the distinctions the task actually requires.

- **A:** Duplication does not add missing coverage.
- **B:** That changes the task instead of teaching it.
- **C:** The intended mapping becomes unclear.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)

### 294. Few-shot guarantees

`claude-4-2-3`

Several examples demonstrate a mandatory access rule. What still enforces the rule?

- **A.** Application authorization or permission checks.
- **B.** The count of examples alone.
- **C.** The order of the answer choices.
- **D.** A promise that the model understood every example.

<details>
<summary>Reveal answer</summary>

**A. Application authorization or permission checks.**

Examples can shape behavior but are not an execution boundary.

- **B:** No example count proves enforcement.
- **C:** Presentation order does not authorize actions.
- **D:** Understanding claims are not control mechanisms.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)

### 295. Prompt evaluation

`claude-4-2-4`

New examples improve the cases used to write the prompt. What should be checked next?

- **A.** Nothing; fitting examples proves production readiness.
- **B.** Performance on held-out cases and relevant failure slices.
- **C.** Only whether the prompt is longer.
- **D.** Whether it repeats the examples verbatim.

<details>
<summary>Reveal answer</summary>

**B. Performance on held-out cases and relevant failure slices.**

Development examples alone can overstate generalization.

- **A:** Unseen inputs may still fail.
- **C:** Length is not an evaluation result.
- **D:** Memorization does not establish transfer.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)

### 296. Use 2-4 targeted examples: fewer than 2 establishes no pattern, more than 4 wastes tokens

`claude-4-2-5`

How many targeted few-shot examples does the lesson recommend, and on what grounds?

- **A.** One, because a single clear demonstration avoids biasing the model toward it.
- **B.** Two to four, because fewer fails to establish a pattern and more wastes tokens.
- **C.** Five to ten, because covering every document type matters more than token cost.
- **D.** As many as the context window allows, because accuracy rises with example count.

<details>
<summary>Reveal answer</summary>

**B. Two to four, because fewer fails to establish a pattern and more wastes tokens.**

The lesson prescribes two to four targeted examples: fewer than two establishes no pattern, and more than four wastes tokens.

- **A:** One example does not establish a pattern for the model to follow.
- **C:** This exceeds the recommended range and buys little additional benefit.
- **D:** Accuracy does not scale with example count; targeting the failing cases matters more than volume.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](None)

### 297. Each example must show reasoning, not just an input-output pair

`claude-4-2-6`

Your few-shot examples are plain input and output pairs, and the model still mishandles ambiguous cases it has not seen. What is missing from the examples?

- **A.** A reasoning section in each example explaining why that choice beat the alternatives.
- **B.** A larger number of near-identical examples covering the same decision.
- **C.** An explicit statement that the examples are authoritative and must be followed.
- **D.** A confidence score attached to each example output so they can be weighted.

<details>
<summary>Reveal answer</summary>

**A. A reasoning section in each example explaining why that choice beat the alternatives.**

Examples must show the reasoning behind each decision, which teaches the model the general principle rather than a literal pattern to match.

- **B:** Repeating similar cases reinforces pattern matching rather than teaching the principle.
- **C:** Asserting authority does not tell the model how to decide an unseen case.
- **D:** Weighting examples by confidence is not part of the technique and does not convey reasoning.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](None)

### 298. Trigger 3: extraction returns empty or null fields for information the document does conta

`claude-4-2-7`

Which symptom is one of the three stated triggers for reaching for few-shot examples?

- **A.** The model returns malformed JSON that the parser cannot read.
- **B.** Responses stop early and truncate before the final field is written.
- **C.** Extraction returns empty fields for information the document actually contains.
- **D.** The model calls an external tool that is not available in the environment.

<details>
<summary>Reveal answer</summary>

**C. Extraction returns empty fields for information the document actually contains.**

Empty or null fields for information that is present in the document is one of the three triggers for few-shot examples.

- **A:** Malformed JSON is mapped to tool use with a JSON schema, not to few-shot examples.
- **B:** Truncation is a token budget problem, not one of the three triggers.
- **D:** Tool availability is unrelated to the triggers the lesson lists.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](None)

### 299. Few-shot examples are the most effective first technique for consistent, well-formatted ou

`claude-4-2-8`

A thorough prompt already specifies the output format, yet structure varies between runs, sometimes a table and sometimes prose. What should you try first?

- **A.** Expand the format section of the instructions with more precise wording.
- **B.** Lower the temperature so the model's formatting choices become deterministic.
- **C.** Ask the model to restate the required format before it produces the answer.
- **D.** Add two to four examples that display the exact format you want.

<details>
<summary>Reveal answer</summary>

**D. Add two to four examples that display the exact format you want.**

When detailed instructions already exist and output is still inconsistent, few-shot examples showing the exact format are the correct next step.

- **A:** If detailed instructions already exist and output is still inconsistent, more instructions do not fix it.
- **B:** Temperature is not the technique the lesson prescribes for formatting consistency.
- **C:** Restating an instruction is still an instruction and does not demonstrate the target format.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](None)

### 300. Technique mapping: malformed JSON needs tool_use with a JSON schema, not examples

`claude-4-2-9`

Your pipeline occasionally receives JSON that fails to parse. Which technique does the lesson's decision table map to this problem?

- **A.** Define the extraction as a tool and constrain it with a JSON schema.
- **B.** Add few-shot examples that show correctly formatted JSON documents.
- **C.** Run a validation-retry loop that feeds the parse error back to the model.
- **D.** Mark the optional properties in the schema as nullable rather than required.

<details>
<summary>Reveal answer</summary>

**A. Define the extraction as a tool and constrain it with a JSON schema.**

The lesson maps malformed JSON to tool use with JSON schemas, which eliminates syntax errors entirely.

- **B:** Few-shot examples address consistency and structural variety, not JSON syntax guarantees.
- **C:** Retries are mapped to semantic failures such as sums that do not match, not to syntax.
- **D:** Nullable fields address fabrication of missing values, not malformed output.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](None)

### 301. Technique mapping: fabricated values for missing fields need optional or nullable schema f

`claude-4-2-10`

The model invents plausible values for fields the source document never mentions. Which technique does the lesson map to this failure?

- **A.** More few-shot examples showing documents that omit some information.
- **B.** Optional or nullable schema fields so that absence can be reported honestly.
- **C.** A stricter instruction forbidding the model from guessing any value at all.
- **D.** A second review pass that deletes any value it is unable to confirm.

<details>
<summary>Reveal answer</summary>

**B. Optional or nullable schema fields so that absence can be reported honestly.**

Fabricated values for missing fields are a schema problem: optional or nullable fields let the model return nothing honestly.

- **A:** The lesson states explicitly that fabrication of missing data does not improve with examples.
- **C:** An instruction does not relieve the pressure a required field places on the model.
- **D:** This hides the symptom after the fact instead of removing the cause in the schema.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](None)

### 302. Technique mapping: an extraction sum that does not match the total needs a validation-retr

`claude-4-2-11`

Extracted line items do not add up to the stated total. Which technique does the lesson map to this failure?

- **A.** Few-shot examples demonstrating arithmetic over extracted line items.
- **B.** A tool schema that declares the total as a field computed from the items.
- **C.** A validation-retry loop that feeds the discrepancy back to the model.
- **D.** An enum field recording whether the model judged the total trustworthy.

<details>
<summary>Reveal answer</summary>

**C. A validation-retry loop that feeds the discrepancy back to the model.**

A sum that does not match the stated total is a semantic error, which the lesson routes to a validation-retry loop.

- **A:** Examples address structure and consistency, not verification of computed values.
- **B:** A schema constrains shape and cannot enforce cross-field arithmetic.
- **D:** A self-reported flag is not an independent check of the arithmetic.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](None)

### 303. Technique mapping: wrong tool selection needs better tool descriptions first, then few-sho

`claude-4-2-12`

An agent routes requests to the wrong tool. What does the lesson's table say to try first, and what after that?

- **A.** Few-shot routing examples first, then stricter tool schemas if the problem persists.
- **B.** A forced tool choice first, then few-shot examples if flexibility is later needed.
- **C.** A validation-retry loop first, then better tool descriptions if the problem persists.
- **D.** Better tool descriptions first, then few-shot examples if the problem persists.

<details>
<summary>Reveal answer</summary>

**D. Better tool descriptions first, then few-shot examples if the problem persists.**

For wrong tool selection the lesson prescribes improving tool descriptions first, and only then adding few-shot examples.

- **A:** This reverses the order; descriptions come before examples for tool selection.
- **B:** Forcing a tool removes selection entirely rather than improving it.
- **C:** Retry loops address extraction semantics, not routing decisions.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](None)

### 304. Trigger 2: inconsistent judgement calls on ambiguous cases

`claude-4-2-13`

A reviewer model labels variable shadowing 'critical' in one file and 'minor' in another. Why is a confidence threshold the wrong fix?

- **A.** Thresholds are poorly calibrated and leave the inconsistent judgement itself untouched.
- **B.** Thresholds can be applied to extraction tasks only, never to review tasks.
- **C.** Thresholds force the model to return text instead of structured findings.
- **D.** Thresholds increase the number of findings overall, which worsens the variance.

<details>
<summary>Reveal answer</summary>

**A. Thresholds are poorly calibrated and leave the inconsistent judgement itself untouched.**

Confidence thresholds are poorly calibrated and never address the root cause; examples demonstrating the correct judgement on ambiguous cases do.

- **B:** Thresholds can be applied anywhere; the objection is that they do not work, not that they are unavailable.
- **C:** Asking for a confidence value has no effect on whether output is structured.
- **D:** A threshold filters findings; the problem is that the surviving judgements are still inconsistent.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](None)

### 305. Few-shot examples over varied document structures reduce hallucination in extraction

`claude-4-2-14`

Why do examples drawn from several document structures reduce fabrication during extraction?

- **A.** They shorten the prompt, leaving more of the context window for the source document.
- **B.** They raise the model's self-reported confidence on unfamiliar page layouts.
- **C.** They teach the model to handle structural variety instead of inventing missing values.
- **D.** They make the model skip any section whose structure it does not recognise.

<details>
<summary>Reveal answer</summary>

**C. They teach the model to handle structural variety instead of inventing missing values.**

Examples covering varied document structures teach the model to handle structural variety, which cuts both empty fields and invented values.

- **A:** Examples lengthen the prompt; the benefit is not a context saving.
- **B:** Self-reported confidence is not the mechanism, and it is poorly calibrated in any case.
- **D:** Skipping content would produce empty fields, which is the failure the examples are meant to remove.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](None)

### 306. In review prompts, examples show both what to flag and what to ignore, cutting false posit

`claude-4-2-15`

In a code review prompt, what second job do well-chosen few-shot examples perform?

- **A.** They cap how many findings the model may report, keeping reviews short.
- **B.** They remove the need for severity levels by ranking the examples by importance.
- **C.** They let the model skip files resembling an example it has already processed.
- **D.** They show which patterns to ignore as well as which to flag, cutting false positives.

<details>
<summary>Reveal answer</summary>

**D. They show which patterns to ignore as well as which to flag, cutting false positives.**

Few-shot examples in review prompts demonstrate both what to flag and what to ignore, which reduces false positives.

- **A:** Examples shape judgement rather than impose a volume limit.
- **B:** Examples calibrate severity levels; they do not replace them.
- **C:** Nothing in the technique licenses skipping files.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-2-few-shot-prompting) · [Technical reference](None)

## 4.3 — Structured Output with Tool Use

### 307. tool_use does not prevent semantic errors: sum discrepancies, field placement errors and f

`claude-4-3`

A supported Claude API integration needs schema-constrained output. What else must the application still check?

- **A.** Domain correctness, source support and unsuccessful or incomplete responses.
- **B.** Nothing, because schema conformance proves every field is true.
- **C.** Only whether the answer contains a confident phrase.
- **D.** Only the number of fields, ignoring their values.

<details>
<summary>Reveal answer</summary>

**A. Domain correctness, source support and unsuccessful or incomplete responses.**

A valid structure does not establish factual correctness or successful completion.

- **B:** Types and shape do not prove the values are factual.
- **C:** Confidence wording is not validation.
- **D:** Field count does not establish meaning or correctness.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### 308. Missing values

`claude-4-3-2`

A document omits an optional field, but the schema requires a fabricated string to fill it. What should change?

- **A.** Copy the value from an unrelated document.
- **B.** Treat the field name itself as its value.
- **C.** Allow an explicit missing value where the domain contract permits it.
- **D.** Insert a plausible value to keep the type valid.

<details>
<summary>Reveal answer</summary>

**C. Allow an explicit missing value where the domain contract permits it.**

The schema should represent absence rather than pressure the model to invent data.

- **A:** That mixes records without evidence.
- **B:** That satisfies neither the intended meaning nor the evidence requirement.
- **D:** Plausibility is not source support.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### 309. Choice versus strictness

`claude-4-3-3`

What is the difference between forcing a tool choice and constraining its argument schema?

- **A.** Forcing a tool automatically validates every business fact.
- **B.** A schema decides whether external side effects are authorized.
- **C.** Both settings are just output styling preferences.
- **D.** Selection controls which call is requested; schema controls constrain its structure.

<details>
<summary>Reveal answer</summary>

**D. Selection controls which call is requested; schema controls constrain its structure.**

These are separate controls, and application validation still matters.

- **A:** Choosing an operation does not prove its inputs are true.
- **B:** Authorization is a separate application concern.
- **C:** They affect structured interaction, not merely appearance.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### 310. Unsuccessful generation

`claude-4-3-4`

An output-constrained request ends with refusal or truncation. What should the caller do?

- **A.** Handle that outcome explicitly before consuming a complete result.
- **B.** Assume a complete business result must exist.
- **C.** Fill missing fields with arbitrary defaults and claim success.
- **D.** Parse only the first valid-looking fragment as the final answer.

<details>
<summary>Reveal answer</summary>

**A. Handle that outcome explicitly before consuming a complete result.**

A requested format does not eliminate unsuccessful response paths.

- **B:** The completion status contradicts that assumption.
- **C:** Defaults can conceal unavailable output.
- **D:** A fragment may omit required content or meaning.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### 311. Reliability hierarchy: tool_use with JSON schemas above prompt-based JSON

`claude-4-3-5`

Which statement matches the reliability hierarchy the exam guide expects for structured output?

- **A.** Prompt-based JSON ranks higher because it avoids the token cost of tool definitions.
- **B.** Tool use with a JSON schema eliminates the syntax errors that prompt-based output still produces.
- **C.** The two approaches are equivalent once the prompt contains a formatted example.
- **D.** Prompt-based JSON is safer because the model can explain any fields it leaves empty.

<details>
<summary>Reveal answer</summary>

**B. Tool use with a JSON schema eliminates the syntax errors that prompt-based output still produces.**

The guide's hierarchy is tool use with JSON schemas above prompt-based JSON, because the schema removes syntax errors that prompting cannot.

- **A:** Token cost does not enter the hierarchy, and prompt-based output ranks below tool use.
- **C:** An example improves the odds but gives no structural guarantee.
- **D:** Commentary alongside JSON makes parsing harder rather than safer.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### 312. tool_choice auto lets the model return text instead of calling a tool, so structured outpu

`claude-4-3-6`

Incoming documents may be invoices, receipts or contracts, you have one extraction tool per type, and the type is unknown at request time. Which tool_choice setting fits?

- **A.** auto, so the model can answer in text when the document type is unclear.
- **B.** A specific named tool such as extract_invoice, so one schema always applies.
- **C.** any, so a tool call is guaranteed while the model selects the matching schema.
- **D.** none, so the model classifies the document before any tool is invoked.

<details>
<summary>Reveal answer</summary>

**C. any, so a tool call is guaranteed while the model selects the matching schema.**

tool_choice 'any' guarantees a tool call while leaving the choice of extraction schema to the model, which suits an unknown document type.

- **A:** auto permits a text-only reply, so structured output is not guaranteed.
- **B:** Forcing one schema misclassifies every document that is not of that type.
- **D:** none blocks tool calls entirely and produces no structured output.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### 313. tool_choice is the separate parameter that forces the model to call a tool at all

`claude-4-3-7`

Metadata extraction must run before any enrichment step, with no discretion left to the model. Which setting enforces that?

- **A.** tool_choice set to auto, with the metadata tool listed first in the tools array.
- **B.** tool_choice set to any, with only extraction tools defined for the request.
- **C.** tool_choice set to none until the enrichment stage begins.
- **D.** tool_choice set to the specific named metadata tool for that request.

<details>
<summary>Reveal answer</summary>

**D. tool_choice set to the specific named metadata tool for that request.**

Setting tool_choice to a specific named tool forces that exact call, which is how a mandatory first step such as metadata extraction is guaranteed.

- **A:** Ordering does not oblige the model to call anything, and auto allows a text reply.
- **B:** any guarantees a call but not which tool is called.
- **C:** none prevents tool calls, so the mandatory step never runs.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### 314. tool_choice applies per request, not per conversation; leaving a forced choice in place lo

`claude-4-3-8`

You forced a specific tool call on the first request of a multi-step flow. What must the following request do?

- **A.** Switch back to auto or omit tool_choice, or the model is obliged to call the same tool again.
- **B.** Repeat the same forced tool_choice, because the setting persists across the conversation.
- **C.** Remove the tool definition entirely, because a forced tool cannot be redefined later.
- **D.** Set tool_choice to none, because a conversation permits only a single tool call.

<details>
<summary>Reveal answer</summary>

**A. Switch back to auto or omit tool_choice, or the model is obliged to call the same tool again.**

tool_choice applies per request, so the follow-up request must relax it to auto or omit it, otherwise the forced tool is called again and the flow loops.

- **B:** The parameter is per request, not per conversation, so nothing persists.
- **C:** Tools may be redefined freely; removing them is unnecessary.
- **D:** There is no such per-conversation limit, and none would block legitimate later calls.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### 315. tool_use with a JSON schema eliminates JSON syntax errors such as missing brackets, traili

`claude-4-3-9`

Your extraction runs through a tool constrained by a strict JSON schema. Which failure can still reach production?

- **A.** A trailing comma that stops the JSON parser from reading the response.
- **B.** A missing closing bracket somewhere in a nested object.
- **C.** An unquoted key appearing in the returned object.
- **D.** Line items that do not add up to the stated total on the document.

<details>
<summary>Reveal answer</summary>

**D. Line items that do not add up to the stated total on the document.**

Tool use with a JSON schema removes syntax errors only; semantic errors such as sums that do not reconcile still require validation logic.

- **A:** Trailing commas are a syntax error, which the schema-constrained tool call eliminates.
- **B:** Unbalanced brackets are a syntax error and cannot survive schema-constrained output.
- **C:** Unquoted keys are a syntax error removed by the same mechanism.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### 316. Add an 'unclear' enum value for genuinely ambiguous classifications

`claude-4-3-10`

A classification field must cope with documents whose type is genuinely ambiguous. What does the lesson recommend?

- **A.** Leave the field null whenever the classification cannot be decided confidently.
- **B.** Add an explicit 'unclear' member to the enum for genuinely ambiguous cases.
- **C.** Drop the enum and accept free text so any classification can be recorded.
- **D.** Default to the most frequent category and attach a low confidence score.

<details>
<summary>Reveal answer</summary>

**B. Add an explicit 'unclear' member to the enum for genuinely ambiguous cases.**

An explicit 'unclear' enum value lets the model report genuine ambiguity instead of forcing a classification.

- **A:** Null signals absence of data rather than a positive judgement that the evidence is ambiguous.
- **C:** Free text abandons the constraint and makes downstream handling unreliable.
- **D:** Defaulting invents a classification, and self-reported confidence is poorly calibrated.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### 317. Add an 'other' enum value paired with a freeform detail string for extensible categorisati

`claude-4-3-11`

How does the lesson keep a categorisation schema extensible for cases the predefined categories do not cover?

- **A.** An 'other' enum value paired with a freeform detail string field.
- **B.** Permission for the model to invent new enum values when none of them fit.
- **C.** A separate extraction tool for every category that might appear in future.
- **D.** An optional category field that returns null whenever the case is unknown.

<details>
<summary>Reveal answer</summary>

**A. An 'other' enum value paired with a freeform detail string field.**

An 'other' enum value combined with a freeform detail string captures edge cases without breaking the constrained field.

- **B:** Unconstrained values defeat the purpose of an enum and break downstream consumers.
- **C:** Proliferating tools does not address unforeseen categories within a single field.
- **D:** Null loses the information about what the document actually was.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### 318. Format normalisation rules live in the prompt while the schema enforces structure

`claude-4-3-12`

Dates come back in mixed formats even though the schema types the field as a string. Where does the lesson put the fix?

- **A.** In the schema, by attaching a regular expression to the string type.
- **B.** In the prompt, as explicit normalisation rules such as ISO 8601 for all dates.
- **C.** In the retry loop, by rejecting every response containing a non-ISO date.
- **D.** In the enum, by listing each acceptable date format as a member value.

<details>
<summary>Reveal answer</summary>

**B. In the prompt, as explicit normalisation rules such as ISO 8601 for all dates.**

The schema enforces structure while the prompt carries format normalisation rules such as ISO 8601 dates and unsymbolled decimal amounts.

- **A:** The lesson assigns structure to the schema and formatting consistency to the prompt.
- **C:** A retry is a downstream correction for a problem the prompt can prevent.
- **D:** An enum constrains values, not the formatting of an open-ended date field.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### 319. Optional or nullable fields are the primary defence against fabrication; required fields p

`claude-4-3-13`

Every field in your extraction schema is required, and testers report invented dates and amounts on documents that lack that information. What is the best fix?

- **A.** Add a prompt instruction telling the model never to invent a value.
- **B.** Move to prompt-based JSON so the model can omit fields it cannot find.
- **C.** Make fields optional or nullable when the source may not contain them.
- **D.** Verify every extracted value against the source in a later validation stage.

<details>
<summary>Reveal answer</summary>

**C. Make fields optional or nullable when the source may not contain them.**

Required fields pressure the model to fabricate; making them optional or nullable is the root-cause fix for invented values.

- **A:** The instruction conflicts with a required field that the model must still populate.
- **B:** This gives up structural guarantees and does not stop fabrication.
- **D:** Validation detects the fabrication afterwards rather than removing the pressure that causes it.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### 320. The exam guide names three tool_choice modes; current docs add a fourth, none, but answer 

`claude-4-3-14`

How many tool_choice modes should you answer with on the exam, and which are they?

- **A.** Three: auto, any, and a specific named tool, as the exam guide frames them.
- **B.** Two: auto and any, since a forced named tool is only a variant of any.
- **C.** Four: auto, any, a named tool, and none, matching the current API documentation.
- **D.** One: any, because the other settings do not guarantee structured output.

<details>
<summary>Reveal answer</summary>

**A. Three: auto, any, and a specific named tool, as the exam guide frames them.**

The exam guide frames tool_choice as three modes, auto, any, and a specific named tool, and that is the expected exam answer.

- **B:** A forced named tool is a distinct mode with different behaviour from any.
- **C:** The current docs do list none, but the lesson says to answer with the guide's three on the exam.
- **D:** auto and forced tool choice are real modes regardless of their guarantees.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-3-structured-output) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

## 4.4 — Validation, Retry, and Feedback Loops

### 321. Retry-with-error-feedback sends the original document, the failed extraction and the speci

`claude-4-4`

An extraction passes its JSON schema, but a business invariant fails. What makes a repair attempt useful?

- **A.** Replace every disputed value with zero without checking the source.
- **B.** Provide the source, failed extraction and specific invariant failure within a bounded repair budget.
- **C.** Resend the unchanged request indefinitely.
- **D.** Delete the validation rule so the extraction passes.

<details>
<summary>Reveal answer</summary>

**B. Provide the source, failed extraction and specific invariant failure within a bounded repair budget.**

The model needs evidence of the semantic error; retries must have limits.

- **A:** Arbitrary values are not a grounded repair.
- **C:** That neither diagnoses the failed invariant nor bounds cost.
- **D:** Weakening the rule conceals the error.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](None)

### 322. Absent source fact

`claude-4-4-2`

Several extraction retries cannot find a fact that is absent from the supplied source. What is appropriate?

- **A.** Disable source checking for this field.
- **B.** Return a supported missing-data outcome or seek the required source.
- **C.** Keep retrying until a plausible answer appears.
- **D.** Use the most common value from unrelated records.

<details>
<summary>Reveal answer</summary>

**B. Return a supported missing-data outcome or seek the required source.**

More retries cannot manufacture evidence that was never supplied.

- **A:** That conceals the reason extraction cannot succeed.
- **C:** That rewards invention rather than extraction.
- **D:** Frequency does not establish this record's fact.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 323. Numerical consistency

`claude-4-4-3`

An extraction includes line items and a stated total. What provides a useful consistency check?

- **A.** Compare only the number of line items.
- **B.** Change the stated total to match a guessed sum.
- **C.** Compute the sum deterministically and compare under a defined rounding policy.
- **D.** Trust the model's 'consistent' boolean alone.

<details>
<summary>Reveal answer</summary>

**C. Compute the sum deterministically and compare under a defined rounding policy.**

An independent calculation can expose discrepancies without trusting a generated check flag.

- **A:** Item count does not verify their sum.
- **B:** That alters source evidence without justification.
- **D:** The flag can share the extraction's error.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 324. Repair exhaustion

`claude-4-4-4`

A bounded repair loop reaches its final attempt with invalid output. What should it return?

- **A.** The invalid result labeled verified.
- **B.** An unlimited hidden retry loop.
- **C.** An empty success response without explanation.
- **D.** An explicit unresolved failure or review-required outcome.

<details>
<summary>Reveal answer</summary>

**D. An explicit unresolved failure or review-required outcome.**

Budget exhaustion should remain visible rather than turn into false success.

- **A:** Attempts do not make the output valid.
- **B:** That violates the stated budget.
- **C:** That loses the failure signal.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 325. Retries are effective for format mismatches, structural errors, misplaced values and mathe

`claude-4-4-5`

Document A's line items sum to 450 while its stated total is 500. Document B names no department anywhere in its text. What should the pipeline do?

- **A.** Retry both with their validation errors attached, since retries are inexpensive.
- **B.** Retry Document A with the discrepancy error and send Document B to human review.
- **C.** Send both to human review, because any validation failure needs a person to resolve it.
- **D.** Retry both unchanged, because extraction is non-deterministic and may succeed next time.

<details>
<summary>Reveal answer</summary>

**B. Retry Document A with the discrepancy error and send Document B to human review.**

Retries fix mathematical and structural errors such as a missed line item, but cannot create information that the source document never contained.

- **A:** Retrying Document B cannot succeed, because the value is not in the source at all.
- **C:** Document A's failure is exactly the fixable class that retry-with-error-feedback handles.
- **D:** A retry without the specific error typically reproduces the same mistake.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](None)

### 326. A naive retry without the specific error reproduces the same mistake

`claude-4-4-6`

Your retry simply resends the original prompt and document after a validation failure. Why does it usually fail?

- **A.** The model has no information about what went wrong and repeats the same mistake.
- **B.** The API rejects a second identical request inside the same session window.
- **C.** The model caches its earlier answer and returns it without re-reading the source.
- **D.** Repeated requests lower the effective temperature until the output stops varying.

<details>
<summary>Reveal answer</summary>

**A. The model has no information about what went wrong and repeats the same mistake.**

A naive retry omits the specific validation error, so the model has nothing to target and reproduces the original mistake.

- **B:** Identical requests are accepted; the problem is the absence of feedback.
- **C:** There is no such answer cache; the repetition comes from the unchanged input.
- **D:** Resending a request does not alter sampling parameters.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](None)

### 327. calculated_total alongside stated_total gives an automatic discrepancy flag without extern

`claude-4-4-7`

Which schema design lets a total discrepancy be detected without any external validation code?

- **A.** A single total field whose description tells the model to double-check the arithmetic.
- **B.** An array of line items plus a boolean the model sets when it feels confident.
- **C.** Separate calculated_total and stated_total fields that can be compared directly.
- **D.** A required total field carrying a minimum value constraint in the schema.

<details>
<summary>Reveal answer</summary>

**C. Separate calculated_total and stated_total fields that can be compared directly.**

Extracting calculated_total alongside stated_total gives an automatic discrepancy flag without external logic.

- **A:** A description cannot be verified and leaves nothing to compare.
- **B:** A self-reported confidence flag is not an independent discrepancy check.
- **D:** A minimum bound says nothing about whether the total matches the line items.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](None)

### 328. conflict_detected booleans surface contradictory information in the source instead of sile

`claude-4-4-8`

A document says 'payment due: 30 days' in one section and 'payment terms: net 60' in another. What does the lesson's schema pattern ask the model to do?

- **A.** Choose the value printed closest to the document's total line.
- **B.** Return the first value it encounters and drop the second silently.
- **C.** Return null for payment terms because the source contradicts itself.
- **D.** Extract both values and set a conflict_detected boolean on the result.

<details>
<summary>Reveal answer</summary>

**D. Extract both values and set a conflict_detected boolean on the result.**

A conflict_detected boolean lets the model surface contradictory source content instead of silently choosing one value.

- **A:** Proximity is not evidence, and silently picking one hides the conflict.
- **B:** Silently picking one value is the behaviour the pattern is designed to prevent.
- **C:** Null discards both values instead of surfacing the contradiction for review.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](None)

### 329. detected_pattern fields let dismissal rates be analysed per triggering construct to priori

`claude-4-4-9`

Why do structured review findings carry a detected_pattern field?

- **A.** It lets dismissal rates be grouped by the construct that triggered each finding.
- **B.** It tells the retry loop which validation rule to re-run after a failure.
- **C.** It replaces the severity field once enough dismissal data has accumulated.
- **D.** It gives the model somewhere to record its confidence in the finding.

<details>
<summary>Reveal answer</summary>

**A. It lets dismissal rates be grouped by the construct that triggered each finding.**

detected_pattern records which code construct triggered a finding, so dismissal rates can be analysed per pattern and prompts refined accordingly.

- **B:** The retry loop is driven by validation errors, not by the pattern label.
- **C:** Severity and detected_pattern record different things and both remain.
- **D:** Confidence is a separate field; detected_pattern names the triggering construct.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](None)

### 330. Schema syntax errors are eliminated by tool_use; semantic validation errors need validatio

`claude-4-4-10`

Which statement correctly separates the two error categories this lesson distinguishes?

- **A.** Syntax errors need retry loops, while semantic errors are removed by tool use schemas.
- **B.** Syntax errors are removed by tool use schemas, while semantic errors need validation logic and retries.
- **C.** Both categories disappear once every field in the schema is marked required.
- **D.** Both categories require human review, because neither can be detected automatically.

<details>
<summary>Reveal answer</summary>

**B. Syntax errors are removed by tool use schemas, while semantic errors need validation logic and retries.**

Tool use with a JSON schema eliminates schema syntax errors, while semantic errors need validation logic and retry loops.

- **A:** This reverses the two: schemas remove syntax errors and retries address semantics.
- **C:** Required fields increase fabrication and do nothing for semantic correctness.
- **D:** Both are detectable automatically, one by the schema and one by validators.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](None)

### 331. Pydantic parsing enforces structure while validators enforce semantics, both surfacing as 

`claude-4-4-11`

Your tool definition already enforces a JSON schema. What does a Pydantic model still contribute?

- **A.** It guarantees that the model calls the extraction tool on every request.
- **B.** It removes the need to include the original document in a retry request.
- **C.** It encodes cross-field rules such as sums matching and dates being ordered.
- **D.** It converts the response into text so the retry prompt stays small.

<details>
<summary>Reveal answer</summary>

**C. It encodes cross-field rules such as sums matching and dates being ordered.**

A schema cannot express cross-field semantics, so Pydantic validators carry rules such as totals matching and dates being correctly ordered.

- **A:** Forcing a call is the job of tool_choice, not of a validation library.
- **B:** The retry pattern still requires the source document as one of its three ingredients.
- **D:** Serialisation is incidental; the value is in the semantic rules and their error messages.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](None)

### 332. Retry-with-error-feedback sends the original document, the failed extraction and the speci

`claude-4-4-12`

In a Python pipeline, what does the ValidationError raised during parsing contribute to the retry message?

- **A.** The original document text the model needs in order to re-examine the source.
- **B.** The failed extraction object that the model produced on the first attempt.
- **C.** A fresh model instance free of the reasoning from the first attempt.
- **D.** The specific per-field error naming the field and the rule that was broken.

<details>
<summary>Reveal answer</summary>

**D. The specific per-field error naming the field and the rule that was broken.**

Pydantic's ValidationError supplies the specific per-field error message, the third ingredient of the retry-with-error-feedback pattern.

- **A:** The document comes from your own pipeline state, not from the exception.
- **B:** The failed extraction is the tool input you already hold, not something the error supplies.
- **C:** Independent instances belong to multi-pass review, not to this exception.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](None)

### 333. Validation messages must state what was expected versus what was found, not merely that va

`claude-4-4-13`

What distinguishes a useful validation error message in this lesson's build exercise?

- **A.** It names the rule that failed and states what was expected against what was found.
- **B.** It reports only that validation failed, which keeps the retry prompt short.
- **C.** It includes the model's own confidence score for the field that failed.
- **D.** It lists every field in the schema so the model can re-check all of them.

<details>
<summary>Reveal answer</summary>

**A. It names the rule that failed and states what was expected against what was found.**

Validation errors must be specific and actionable, stating what was expected versus what was found rather than that validation failed.

- **B:** A bare failure gives the model nothing to target and reproduces the mistake.
- **C:** Self-reported confidence is not part of the validation output the exercise describes.
- **D:** Listing everything buries the actual error and undermines targeted correction.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](None)

### 334. Server-side strict schemas and SDK parsing do not remove the semantic validation layer

`claude-4-4-14`

Strict tool definitions now guarantee schema-conformant tool input server-side. What follows for your own validators?

- **A.** They can be removed, because the platform now enforces the same rules.
- **B.** They still carry the business rules that a schema cannot express.
- **C.** They should be rewritten as natural language instructions inside the prompt.
- **D.** They apply only when the SDK's parse helper is not being used.

<details>
<summary>Reveal answer</summary>

**B. They still carry the business rules that a schema cannot express.**

Server-side strict schemas remove syntax errors only, so validators keep carrying the semantic business rules that feed the retry loop.

- **A:** The platform enforces the schema only; business rules are not covered.
- **C:** Prompt text is not enforcement and produces no machine-readable error for a retry.
- **D:** The parse helper returns validated instances and runs your validators rather than replacing them.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](None)

### 335. Retries cannot recover data that exists only in an external document not supplied to the m

`claude-4-4-15`

An extraction needs a purchase order number that exists only in a separate system never sent to the model. Is retry-with-error-feedback appropriate?

- **A.** Yes, provided the retry prompt states that the field is mandatory.
- **B.** Yes, because a retry recovers any field the first attempt happened to miss.
- **C.** No, the value lies outside the supplied source, so the case needs human review or a null.
- **D.** No, but calling the model three more times usually surfaces the value anyway.

<details>
<summary>Reveal answer</summary>

**C. No, the value lies outside the supplied source, so the case needs human review or a null.**

Retries cannot supply data that lives only in an external document the model never received, so the case goes to human review or returns null.

- **A:** Insisting on a mandatory field invites fabrication rather than recovery.
- **B:** Retries only recover values that are present in the supplied source.
- **D:** Repetition cannot produce information the model was never given.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-4-validation-retry-loops) · [Technical reference](None)

## 4.5 — Batch Processing Strategies

### 336. custom_id correlates each request with its response regardless of arrival order

`claude-4-5`

Batch results arrive in a different order from the submitted requests. How should the application associate them?

- **A.** Match by whichever output text looks most similar.
- **B.** Assume missing results are successful empty answers.
- **C.** Match each result using its custom_id.
- **D.** Zip results with requests by their array positions.

<details>
<summary>Reveal answer</summary>

**C. Match each result using its custom_id.**

An explicit request identifier supports correlation independently of arrival order.

- **A:** Similarity is not a reliable request identifier.
- **B:** Missing output is not evidence of successful processing.
- **D:** Arrival order is not a safe identity mapping.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 337. Latency fit

`claude-4-5-2`

A user is waiting for a response within seconds. Is an asynchronous batch interface automatically a good fit?

- **A.** No; choose an interaction path compatible with the latency requirement.
- **B.** Yes; lower unit cost guarantees lower latency.
- **C.** Yes; every batch result arrives in submission order immediately.
- **D.** No; batching can never be useful for any AI workload.

<details>
<summary>Reveal answer</summary>

**A. No; choose an interaction path compatible with the latency requirement.**

Batch processing trades immediate response behavior for deferred work.

- **B:** Cost and latency are distinct properties.
- **C:** Neither assumption defines the batch contract.
- **D:** Latency-tolerant workloads can benefit from batching.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 338. Partial batch recovery

`claude-4-5-3`

Most batch items succeed but a few fail. What should recovery preserve?

- **A.** Match retries by output position instead of stable identity.
- **B.** Successful results and item identities, retrying only eligible unresolved items.
- **C.** Discard every success and blindly repeat the batch.
- **D.** Mark all failed items successful because most passed.

<details>
<summary>Reveal answer</summary>

**B. Successful results and item identities, retrying only eligible unresolved items.**

Recovery should avoid unnecessarily repeating completed work.

- **A:** Positions may not preserve request-result correspondence.
- **C:** That increases work and can duplicate downstream effects.
- **D:** Aggregate success does not resolve individual failures.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 339. Client tool orchestration

`claude-4-5-4`

A batch response requests a client-side tool. What should the application not assume?

- **A.** That responses require inspection.
- **B.** That a larger workflow can use batches for suitable independent steps.
- **C.** That the batch service executed that client tool and completed the whole workflow.
- **D.** That the response has a request identity.

<details>
<summary>Reveal answer</summary>

**C. That the batch service executed that client tool and completed the whole workflow.**

Requested client operations still need application-side execution and continuation.

- **A:** Inspection is necessary to classify outcomes.
- **B:** Application orchestration can combine batch and other processing.
- **D:** Request identity is useful batch metadata.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 340. The Message Batches API gives 50 percent cost savings

`claude-4-5-5`

Which statement about the Message Batches API matches the lesson's facts?

- **A.** It halves the cost and guarantees that results arrive within one hour of submission.
- **B.** It halves the cost, with a processing window of up to 24 hours and no latency guarantee.
- **C.** It costs the same as synchronous calls but raises the per-request rate limit.
- **D.** It halves the cost and returns results in the order the requests were submitted.

<details>
<summary>Reveal answer</summary>

**B. It halves the cost, with a processing window of up to 24 hours and no latency guarantee.**

The Message Batches API offers 50 percent cost savings with an up-to-24-hour processing window and no guaranteed latency.

- **A:** There is no delivery guarantee of any kind, let alone an hourly one.
- **C:** The defining benefit is the 50 percent cost reduction, not a rate limit change.
- **D:** Ordering is not guaranteed, which is why each request carries a custom_id.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 341. Matching rule: blocking workflows stay synchronous, latency-tolerant workflows move to bat

`claude-4-5-6`

You run a blocking pre-merge review and an overnight technical debt report. Your manager wants both moved to the Batches API for the 50 percent saving. What do you advise?

- **A.** Move both, adding a synchronous fallback whenever a batch runs long.
- **B.** Keep both synchronous, because batch results can arrive out of order.
- **C.** Move both and poll the batch status so the pipeline knows when to continue.
- **D.** Move the overnight report to batch and keep the pre-merge check synchronous.

<details>
<summary>Reveal answer</summary>

**D. Move the overnight report to batch and keep the pre-merge check synchronous.**

Blocking workflows stay synchronous while latency-tolerant work such as an overnight report moves to batch for the cost saving.

- **A:** A fallback pays for both paths and still exposes developers to unbounded waits.
- **B:** Ordering is solved by custom_id, and the overnight report loses a legitimate saving.
- **C:** Polling does not shorten a window that can run to 24 hours while developers wait.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 342. SLA calculation: a 30-hour SLA leaves 6 hours of buffer, so submit every 4 hours

`claude-4-5-7`

A report carries a 30-hour service level agreement and the batch window runs to 24 hours. What submission cadence does the lesson give?

- **A.** Every 4 hours, so a fresh batch is always in flight inside the 6-hour buffer.
- **B.** Every 6 hours, which consumes exactly the buffer the agreement allows.
- **C.** Every 24 hours, submitted immediately after the previous batch returns.
- **D.** Every 30 hours, aligned with the deadline the agreement specifies.

<details>
<summary>Reveal answer</summary>

**A. Every 4 hours, so a fresh batch is always in flight inside the 6-hour buffer.**

A 30-hour agreement minus the 24-hour worst case leaves 6 hours of buffer, and batches go in every 4 hours so one is always in flight.

- **B:** A 6-hour cadence uses the whole buffer and leaves no margin at all.
- **C:** Waiting for the previous batch to return can push delivery past the deadline.
- **D:** Submitting on the deadline itself guarantees a breach.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 343. The 24-hour window is a maximum, not a guarantee; an overrunning batch returns expired and

`claude-4-5-8`

A batch fails to finish inside the 24-hour window. What comes back, and how should the pipeline treat it?

- **A.** The batch continues running and eventually returns, so no action is needed.
- **B.** Partially complete results return and the missing items can safely be ignored.
- **C.** The batch comes back expired, which counts as a failure and is resubmitted.
- **D.** The service retries the batch automatically at no additional cost.

<details>
<summary>Reveal answer</summary>

**C. The batch comes back expired, which counts as a failure and is resubmitted.**

A batch that overruns the window returns expired, which the failure handler treats like an error and resubmits.

- **A:** The window is a maximum, not an extension; unfinished work does not simply continue.
- **B:** Ignoring missing items silently drops documents from the output.
- **D:** No automatic retry is described; resubmission is your responsibility.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 344. Refining prompts on a sample set before the batch is the proactive step that maximises fir

`claude-4-5-9`

Which step does the lesson single out as the proactive one that maximises first-pass success?

- **A.** Identifying failed items by their custom_id once the batch has ended.
- **B.** Resubmitting only the failures with targeted modifications.
- **C.** Raising max_tokens on every request in the initial submission.
- **D.** Refining prompts against a representative sample before the full batch runs.

<details>
<summary>Reveal answer</summary>

**D. Refining prompts against a representative sample before the full batch runs.**

Refining prompts on a representative sample before submitting the full batch is the proactive step that maximises first-pass success.

- **A:** This is reactive failure handling, performed after the batch has run.
- **B:** Also reactive; it reduces waste but does not raise the first-pass rate.
- **C:** A blanket token increase costs more and does not address prompt quality.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 345. The sample set is 5 to 10 documents covering the range of formats and edge cases

`claude-4-5-10`

How large a sample does the lesson suggest for pre-batch prompt refinement, and what should it contain?

- **A.** Five to ten documents spanning the formats and edge cases present in the batch.
- **B.** A single representative document drawn from the most common format.
- **C.** Half the batch, so that the measured success rate is statistically sound.
- **D.** Fifty to a hundred documents selected at random from the full batch.

<details>
<summary>Reveal answer</summary>

**A. Five to ten documents spanning the formats and edge cases present in the batch.**

A sample of 5 to 10 documents covering the range of formats and edge cases is what the lesson uses for pre-batch prompt refinement.

- **B:** One document cannot expose the structural variety that causes batch failures.
- **C:** Processing half the batch twice defeats the cost saving the exercise is protecting.
- **D:** This is far larger than the lesson prescribes and delays the refinement loop.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 346. First-pass success drives cost: 90 percent on 1,000 documents means 100 retries, 60 percen

`claude-4-5-11`

Why does the lesson treat first-pass success rate as the main cost lever in batch work?

- **A.** A failed item is billed at the synchronous rate rather than the batch rate.
- **B.** A 60 percent first-pass rate means four times the retries that a 90 percent rate does.
- **C.** Each failure consumes part of the 24-hour window reserved for the whole batch.
- **D.** The service charges a penalty for every resubmitted request in a retry batch.

<details>
<summary>Reveal answer</summary>

**B. A 60 percent first-pass rate means four times the retries that a 90 percent rate does.**

First-pass success drives resubmission volume: 90 percent on 1,000 documents leaves 100 retries, while 60 percent leaves 400.

- **A:** Failures are not repriced; the cost comes from the volume of resubmitted work.
- **C:** The window is not a shared budget that failures deplete.
- **D:** No penalty pricing is described anywhere in the lesson.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 347. No multi-turn tool calling within a single batch request; such steps run synchronously

`claude-4-5-12`

A nightly job must call your internal pricing service partway through its analysis and use the result to continue. How should it run, per the exam guide?

- **A.** As a batch, because the batch service executes your client tools on your behalf.
- **B.** As a batch, with the tool results supplied up front in the request body.
- **C.** As a batch, retrying the tool call until the pricing service responds in time.
- **D.** Synchronously, because a batch request cannot complete a multi-turn tool loop.

<details>
<summary>Reveal answer</summary>

**D. Synchronously, because a batch request cannot complete a multi-turn tool loop.**

The exam guide's rule is that a batch request cannot complete a multi-turn tool loop, so a step needing mid-processing tool execution runs synchronously.

- **A:** The batch service never runs your own code; a client tool call comes back for you to execute.
- **B:** Results that depend on the model's mid-request decisions cannot be known in advance.
- **C:** There is no tool call inside the batch item to retry.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 348. Poll until processing_status is ended, then iterate results, treating errored and expired 

`claude-4-5-13`

How does your code read the outcome of a submitted batch?

- **A.** Await the create call, which resolves once every request in the batch has finished.
- **B.** Read the results array the create call returns alongside the batch identifier.
- **C.** Poll until processing_status is ended, then iterate the results stream.
- **D.** Wait for a webhook, which is the only supported way to learn a batch outcome.

<details>
<summary>Reveal answer</summary>

**C. Poll until processing_status is ended, then iterate the results stream.**

You poll the batch until processing_status is 'ended', then iterate the results, which arrive as a JSONL stream rather than an array.

- **A:** The create call returns as soon as the batch is accepted, not when it completes.
- **B:** No results array is returned at creation time.
- **D:** The lesson's example uses polling, so a webhook is not the only route.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 349. Failure handling: identify failures by custom_id, resubmit only failures with modification

`claude-4-5-14`

One batch item failed because the document exceeded the request's limits. What belongs in the resubmission?

- **A.** Chunk the oversized document and raise max_tokens on the retry request.
- **B.** Resubmit the entire original batch so that result ordering stays consistent.
- **C.** Reuse the same custom_id so the retry overwrites the earlier failed result.
- **D.** Remove the schema constraints so the model has more freedom in its response.

<details>
<summary>Reveal answer</summary>

**A. Chunk the oversized document and raise max_tokens on the retry request.**

Only the failed items are resubmitted, with targeted modifications such as chunking oversized documents and increasing max_tokens.

- **B:** Resubmitting successes wastes the cost saving that motivated batching.
- **C:** Identifiers must stay unique so retries can be correlated and tracked separately.
- **D:** Loosening the schema reintroduces syntax errors without addressing document size.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

### 350. Matching rule: blocking workflows stay synchronous, latency-tolerant workflows move to bat

`claude-4-5-15`

Which workflow is the clearest candidate for the Message Batches API?

- **A.** A pre-merge check that gates whether developers may merge a pull request.
- **B.** An assistant answering questions interactively inside the code editor.
- **C.** A weekly code audit summary the team reads on Monday morning.
- **D.** A deploy-time policy check that holds the release until it returns.

<details>
<summary>Reveal answer</summary>

**C. A weekly code audit summary the team reads on Monday morning.**

Latency-tolerant work whose results are consumed later, such as a weekly audit summary, is what the batch API is for.

- **A:** Developers are blocked on the result, so this is a blocking workflow.
- **B:** A person is waiting in real time, which rules batch out.
- **D:** The release pipeline waits on the answer, so it must stay synchronous.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-5-batch-processing) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

## 4.6 — Multi-Instance and Multi-Pass Review

### 351. An independent instance without prior context reviews the output fresh

`claude-4-6`

You want a second pass to challenge a generated solution with less dependence on its drafting conversation. Which setup fits?

- **A.** Ask the original conversation to confirm that its answer is correct.
- **B.** Send the reviewer only a statement that the first answer passed.
- **C.** Treat agreement between two runs as proof and omit tests.
- **D.** Use a fresh reviewer invocation with the requirements, evidence and candidate solution.

<details>
<summary>Reveal answer</summary>

**D. Use a fresh reviewer invocation with the requirements, evidence and candidate solution.**

A separate review context avoids carrying the drafting conversation, but does not guarantee correctness.

- **A:** A confirmation request invites agreement rather than scrutiny.
- **B:** The reviewer lacks the material required to verify that claim.
- **C:** Models can share errors; independent checks remain useful.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](None)

### 352. Review versus testing

`claude-4-6-2`

A fresh reviewer approves generated code. What does that approval establish?

- **A.** Proof that all runtime behaviors are correct.
- **B.** Proof that tests are now unnecessary.
- **C.** Proof that all requirements were supplied to the reviewer.
- **D.** A review result to consider alongside tests and other evidence.

<details>
<summary>Reveal answer</summary>

**D. A review result to consider alongside tests and other evidence.**

An independent model review remains fallible.

- **A:** Review alone cannot establish every execution path.
- **B:** Different checks catch different failures.
- **C:** Approval does not show what context the reviewer received.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 353. Reviewer disagreement

`claude-4-6-3`

Two review passes disagree about a suspected bug. What is a useful next step?

- **A.** Inspect the cited code and construct a discriminating test or counterexample.
- **B.** Choose the more confident review automatically.
- **C.** Average the reviewers' severity words.
- **D.** Delete the finding because disagreement occurred.

<details>
<summary>Reveal answer</summary>

**A. Inspect the cited code and construct a discriminating test or counterexample.**

Concrete evidence can resolve competing claims.

- **B:** Confidence is not the disputed runtime behavior.
- **C:** Averaging labels does not determine whether the bug exists.
- **D:** Disagreement does not establish absence of a defect.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 354. Shared blind spots

`claude-4-6-4`

Several reviewers using the same assumptions agree. Why might the defect still be missed?

- **A.** The number of review messages replaces execution evidence.
- **B.** Their errors can be correlated.
- **C.** Agreement mathematically excludes any defect.
- **D.** Only reviewers with different names can disagree.

<details>
<summary>Reveal answer</summary>

**B. Their errors can be correlated.**

Repeated agreement is weaker when the same missing evidence or assumptions affect every reviewer.

- **A:** Message volume is not a test result.
- **C:** Consensus does not prove correctness.
- **D:** Names do not determine independence.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 355. Self-review in the same session retains the generating reasoning chain and confirms rather

`claude-4-6-5`

Why is asking Claude to review its own output later in the same conversation weaker than a fresh review?

- **A.** The session's remaining token budget leaves no room for a careful second look.
- **B.** It still carries the reasoning that produced the output and tends to confirm it.
- **C.** The API blocks a model from evaluating content that it generated itself.
- **D.** Review quality degrades whenever a conversation runs past two turns.

<details>
<summary>Reveal answer</summary>

**B. It still carries the reasoning that produced the output and tends to confirm it.**

Self-review in the same session retains the original reasoning chain, so the model confirms its decisions instead of questioning them.

- **A:** The limitation is about retained reasoning, not about available tokens.
- **C:** No such restriction exists; the problem is behavioural, not a platform rule.
- **D:** Turn count is not the mechanism the lesson describes.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](None)

### 356. Attention dilution in single-pass multi-file review causes uneven depth, missed bugs and c

`claude-4-6-6`

A single-pass review of a 14-file pull request gives deep comments on some files, shallow ones on others, and flags a pattern in one file that it approves in another. What is happening?

- **A.** A tokenisation problem caused by mixed programming languages across the files.
- **B.** Non-determinism that a lower temperature setting would eliminate.
- **C.** Attention dilution, the known failure mode of single-pass multi-file review.
- **D.** A schema problem, since the findings carry no consistent severity field.

<details>
<summary>Reveal answer</summary>

**C. Attention dilution, the known failure mode of single-pass multi-file review.**

Inconsistent depth, missed bugs and contradictory findings across files are the three symptoms of attention dilution in single-pass review.

- **A:** Language mixing is not the cause the lesson identifies.
- **B:** Sampling settings do not distribute attention evenly across files.
- **D:** Output shape is unrelated to the uneven depth being described.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](None)

### 357. Pass 1 is per-file local analysis, which gives every file consistent depth

`claude-4-6-7`

How should that 14-file review be restructured?

- **A.** Require developers to split the pull request into batches of three or four files.
- **B.** Run three full reviews of the whole pull request and keep findings two of them share.
- **C.** Move to a model with a much larger context window and keep a single pass.
- **D.** Review each file in its own focused pass, then run a separate cross-file integration pass.

<details>
<summary>Reveal answer</summary>

**D. Review each file in its own focused pass, then run a separate cross-file integration pass.**

The fix is per-file local analysis for consistent depth followed by a separate cross-file integration pass.

- **A:** This shifts the burden to developers instead of fixing the review architecture.
- **B:** Repeating a diluted review multiplies cost without giving any file focused attention.
- **C:** A larger window does not improve how attention is distributed across files.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](None)

### 358. Pass 2 is a cross-file integration pass over the per-file findings

`claude-4-6-8`

What does the cross-file integration pass receive, and what is it looking for?

- **A.** The raw diff again, checking each file a second time for local bugs that were missed.
- **B.** The per-file findings, checking data flow, API contracts and contradictions between them.
- **C.** Only the findings marked critical, checking whether their severity was justified.
- **D.** The repository history, checking whether these files have changed together before.

<details>
<summary>Reveal answer</summary>

**B. The per-file findings, checking data flow, API contracts and contradictions between them.**

The integration pass takes all per-file findings and checks data flow between modules, API consistency and contradictions among the findings.

- **A:** Repeating local analysis duplicates pass one instead of adding cross-file coverage.
- **C:** Severity triage is not the purpose, and filtering hides cross-file signals.
- **D:** Historical co-change is not part of the architecture the lesson describes.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](None)

### 359. A larger context window does not fix attention dilution because the problem is attention q

`claude-4-6-9`

Why does moving to a model with a much larger context window fail to fix uneven multi-file review?

- **A.** The larger model reports fewer findings because it is tuned for conversation.
- **B.** Larger windows slow the review down, so fewer files are examined in practice.
- **C.** The problem is attention quality across files, not how much text fits in the request.
- **D.** Context windows apply to natural language documents rather than to source code.

<details>
<summary>Reveal answer</summary>

**C. The problem is attention quality across files, not how much text fits in the request.**

Attention dilution is a question of attention quality, not context size, so a larger window leaves the uneven depth unchanged.

- **A:** Model tuning is not the mechanism, and the claim is not made in the lesson.
- **B:** Throughput is not the issue; every file is still in the request.
- **D:** Context windows apply to all input, so this is simply untrue.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](None)

### 360. Confidence routing sends high-confidence findings to developers and low-confidence finding

`claude-4-6-10`

Each finding now carries a confidence score. How does the lesson route them?

- **A.** High-confidence findings go to developers and low-confidence ones to human review.
- **B.** Low-confidence findings are discarded and only high-confidence ones are reported.
- **C.** Every finding goes to human review until the model reports perfect confidence.
- **D.** Findings are ranked by confidence and only the top few are ever reported.

<details>
<summary>Reveal answer</summary>

**A. High-confidence findings go to developers and low-confidence ones to human review.**

High-confidence findings go straight to developers while low-confidence findings are routed to human review for validation.

- **B:** Discarding uncertain findings throws away exactly the cases that need a human.
- **C:** This defeats the purpose of routing and floods the human queue.
- **D:** A fixed cut-off by rank is not the routing rule the lesson describes.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](None)

### 361. Thresholds are calibrated with labelled validation sets measuring how confidence tracks ac

`claude-4-6-11`

How do you arrive at a defensible routing threshold for confidence scores?

- **A.** Ask the model to propose the threshold that best matches its own certainty.
- **B.** Run labelled examples through the system and measure how confidence tracks accuracy.
- **C.** Use the median confidence of the last month's findings as the cut-off point.
- **D.** Set the threshold at 0.5, the midpoint of the confidence scale.

<details>
<summary>Reveal answer</summary>

**B. Run labelled examples through the system and measure how confidence tracks accuracy.**

Thresholds are calibrated by running labelled examples through the system and measuring how reported confidence tracks actual accuracy.

- **A:** The model's self-assessment is the very thing that needs calibrating.
- **C:** A median splits volume evenly but says nothing about accuracy.
- **D:** An arbitrary midpoint is not calibrated against any evidence.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](None)

### 362. Uncalibrated raw confidence driving automated decisions is an anti-pattern

`claude-4-6-12`

Which practice does the lesson label an anti-pattern in confidence-based routing?

- **A.** Collecting a confidence value alongside the reasoning behind each finding.
- **B.** Routing low-confidence findings to a human queue rather than to developers.
- **C.** Recalibrating thresholds after a labelled validation run shifts the data.
- **D.** Driving automated decisions from raw, uncalibrated self-reported confidence.

<details>
<summary>Reveal answer</summary>

**D. Driving automated decisions from raw, uncalibrated self-reported confidence.**

Using uncalibrated self-reported confidence to drive automated decisions is the anti-pattern; thresholds must be validated against labelled sets first.

- **A:** Recording confidence with its reasoning is part of the recommended design.
- **B:** This is the routing strategy the lesson endorses.
- **C:** Continuous recalibration is part of the architecture, not an anti-pattern.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](None)

### 363. A confidence score is the model's read on its own certainty, not a measured accuracy

`claude-4-6-13`

What does a model's reported confidence on a finding actually express?

- **A.** Its read on its own certainty, which needs calibration before it can be trusted.
- **B.** A measured accuracy rate derived from the model's previous findings.
- **C.** The proportion of training examples that matched the flagged pattern.
- **D.** The severity of the finding expressed on a normalised numeric scale.

<details>
<summary>Reveal answer</summary>

**A. Its read on its own certainty, which needs calibration before it can be trusted.**

A confidence score is the model's read on its own certainty, which is why it must be calibrated against labelled data before it drives routing.

- **B:** No historical accuracy is being computed when the model emits the score.
- **C:** The model has no access to such a statistic at inference time.
- **D:** Severity measures impact, which is independent of certainty.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](None)

### 364. The extra cost of multi-pass review is justified when review quality affects production re

`claude-4-6-14`

The multi-pass review architecture costs more than a single pass. When does the lesson say the trade-off is worth it?

- **A.** Whenever the codebase grows beyond a few thousand lines of source.
- **B.** Whenever spare budget remains within the current billing period.
- **C.** When review quality directly drives production reliability, as in compliance work.
- **D.** When the model's context window cannot hold the entire pull request.

<details>
<summary>Reveal answer</summary>

**C. When review quality directly drives production reliability, as in compliance work.**

The extra cost is justified where review quality drives production reliability, such as delivery pipelines, financial extraction and compliance analysis.

- **A:** Size alone is not the criterion the lesson gives.
- **B:** Spare budget is not a reason the lesson offers.
- **D:** Context capacity is a separate concern and is not what justifies the architecture.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](None)

### 365. Pass 1 is per-file local analysis, which gives every file consistent depth

`claude-4-6-15`

What does reviewing one file per invocation buy you?

- **A.** Consistent depth, because each invocation gives a single file its full attention.
- **B.** A shorter total runtime, since each individual request processes less text.
- **C.** Fewer findings overall, because local context limits what can be flagged.
- **D.** Cheaper reviews, because per-file prompts make the integration pass unnecessary.

<details>
<summary>Reveal answer</summary>

**A. Consistent depth, because each invocation gives a single file its full attention.**

Per-file passes give every file the model's full attention, producing consistent review depth across the whole change.

- **B:** Many parallel calls do not necessarily shorten wall-clock time, and speed is not the point.
- **C:** The goal is catching more real issues, not suppressing findings.
- **D:** The architecture is more expensive, and the integration pass remains essential.

</details>

[Lesson material](https://claudecertificationguide.com/learn/4-prompt-engineering/4-6-multi-pass-review) · [Technical reference](None)

## 5.1 — Context Window Management

### 366. Progressive summarisation systematically destroys numerical values, dates, percentages and

`claude-5-1`

Repeated summaries have rounded a critical quantity and lost a deadline. How should durable conversation state preserve these facts?

- **A.** Keep exact typed facts with source references and use summaries for surrounding narrative.
- **B.** Generate increasingly shorter summaries until the values stabilize.
- **C.** Ask the model to reconstruct the numbers from context.
- **D.** Keep only the latest message regardless of unresolved constraints.

<details>
<summary>Reveal answer</summary>

**A. Keep exact typed facts with source references and use summaries for surrounding narrative.**

Critical values need explicit preservation and checking across summaries.

- **B:** Further compression cannot restore information already lost.
- **C:** Reconstruction can invent precise-looking values.
- **D:** Recent text may omit still-active requirements.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 367. Tool-result trimming

`claude-5-1-2`

A tool returns many fields, but the task needs only a few. What should trimming preserve?

- **A.** The longest fields regardless of relevance.
- **B.** No error metadata, even if execution failed.
- **C.** Decision-relevant values, identifiers and provenance.
- **D.** Only a statement that the operation looked successful.

<details>
<summary>Reveal answer</summary>

**C. Decision-relevant values, identifiers and provenance.**

Context reduction should remove noise without erasing required evidence.

- **A:** Length does not determine usefulness.
- **B:** Removing failure context can create false success.
- **D:** That loses the facts needed for reasoning.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 368. Multiple issues

`claude-5-1-3`

A conversation concerns two orders with different amounts. What reduces cross-contamination?

- **A.** One unlabelled amount updated by the latest message.
- **B.** A blended summary that averages both amounts.
- **C.** Assume every new detail applies to both orders.
- **D.** Separate structured records keyed by stable order identifiers.

<details>
<summary>Reveal answer</summary>

**D. Separate structured records keyed by stable order identifiers.**

Identity keeps each amount and status attached to the correct issue.

- **A:** That can overwrite another active issue.
- **B:** An average is not either order's value.
- **C:** Scope must be determined rather than duplicated automatically.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 369. Persistent facts

`claude-5-1-4`

A stored case fact conflicts with a newly verified correction. What should state management do?

- **A.** Update the fact with provenance while preserving an appropriate audit trail.
- **B.** Keep the old value solely because it was saved first.
- **C.** Keep both as current without describing the conflict.
- **D.** Erase all related evidence before choosing a value.

<details>
<summary>Reveal answer</summary>

**A. Update the fact with provenance while preserving an appropriate audit trail.**

Persistence must support correction, not freeze a known error.

- **B:** Age does not establish correctness.
- **C:** That leaves downstream users with ambiguous state.
- **D:** Evidence is needed to justify and audit the correction.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 370. The fix is a persistent case facts block of transactional facts included in every prompt a

`claude-5-1-5`

A billing agent compresses older turns each time the conversation grows. Where should the customer's order numbers and refund amounts live?

- **A.** Inside the running summary, with an instruction to copy every figure across verbatim.
- **B.** Only in the tool results already sitting in the conversation history.
- **C.** In a structured facts block rebuilt into every prompt and excluded from summarisation.
- **D.** In the final assistant turn, refreshed whenever the model restates the case details.

<details>
<summary>Reveal answer</summary>

**C. In a structured facts block rebuilt into every prompt and excluded from summarisation.**

Transactional facts belong in a persistent case facts block that sits outside the summarised history and is included in every prompt.

- **A:** Summarisation is precisely what destroys these values, and an instruction to preserve them is not a reliable safeguard.
- **B:** Tool results are part of the history and get compressed along with everything else.
- **D:** This depends on the model re-emitting the values, which is the behaviour that fails after summarisation.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 371. Lost in the middle: models process the beginning and end of long inputs reliably; middle c

`claude-5-1-6`

A synthesis agent reliably reports details from the opening and closing of a long aggregated input but misses several findings placed between them. What explains this?

- **A.** The input exceeded the token limit, so the middle portion was silently discarded.
- **B.** Models attend most reliably to the start and end of long inputs, so middle content carries less weight.
- **C.** Section headers placed mid-input override the model's attention to the text around them.
- **D.** Content in the middle of a prompt is processed last and is therefore treated as stale.

<details>
<summary>Reveal answer</summary>

**B. Models attend most reliably to the start and end of long inputs, so middle content carries less weight.**

This is the lost-in-the-middle effect: information at the beginning and end of a long input is processed more reliably than material buried in the middle.

- **A:** The effect shows up well before any limit is reached and is not caused by dropped tokens.
- **C:** Headers help navigation; they do not suppress the content that follows them.
- **D:** Position in the prompt does not change processing order in that way.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 372. The lost-in-the-middle fix is structural (key findings summary first, explicit section hea

`claude-5-1-7`

You are combining the outputs of three research subagents into one prompt. Which change best protects their findings from the lost-in-the-middle effect?

- **A.** Add a line telling the model to weigh every part of the supplied input equally.
- **B.** Sort the detailed sections alphabetically so their ordering is predictable to readers.
- **C.** Merge the three outputs into one continuous block of text with no headings.
- **D.** Open with a key findings summary, then give the detailed outputs under explicit section headers.

<details>
<summary>Reveal answer</summary>

**D. Open with a key findings summary, then give the detailed outputs under explicit section headers.**

The mitigation is structural: place a key findings summary at the beginning of the aggregated input and organise the detailed results under explicit section headers.

- **A:** Prompt-based reminders are unreliable against position effects; the fix has to be structural.
- **B:** Ordering by name does nothing about the model's sensitivity to position.
- **C:** Removing structure makes specific findings harder still to locate.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 373. Verbose tool results (40+ fields) are a silent context budget killer across turns; trim to

`claude-5-1-8`

Your order lookup tool returns more than forty fields and only five matter for the task. At what point should the extra fields be removed?

- **A.** Before the result enters conversation history, in a PostToolUse hook or in the tool itself.
- **B.** During the next summarisation pass, once the history has grown large enough to need one.
- **C.** In the final response, by asking the model to quote only the fields it actually used.
- **D.** Never, because a later turn in the conversation might turn out to need another field.

<details>
<summary>Reveal answer</summary>

**A. Before the result enters conversation history, in a PostToolUse hook or in the tool itself.**

Trimming must happen before the result enters conversation history, in a PostToolUse hook or in the tool implementation, since verbose data persists across every subsequent turn.

- **B:** By then the verbose result has already consumed tokens on every intervening turn.
- **C:** The raw result stays in the conversation history no matter what the model quotes.
- **D:** That is exactly the reasoning that lets stale tool output drown a multi-turn system's budget.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 374. The Claude API is stateless; every request must include the complete conversation history

`claude-5-1-9`

An engineer assumes the Claude API keeps each conversation on the server, so their client sends only the newest user message. What goes wrong?

- **A.** The request is rejected because the server cannot locate the stored session identifier.
- **B.** The earlier turns are restored from the cache breakpoint attached to the previous request.
- **C.** The model has no access to the earlier turns and loses conversational coherence.
- **D.** Only tool results are retained on the server, so text turns are the ones that must be resent.

<details>
<summary>Reveal answer</summary>

**C. The model has no access to the earlier turns and loses conversational coherence.**

The Claude API is stateless, so each request must carry the complete conversation history; sending only the newest message strips the context the model needs.

- **A:** There is no session to look up and no such error; the request succeeds and answers without context.
- **B:** Caching reduces the cost of reprocessing a prefix; it does not store conversational state.
- **D:** Nothing at all is retained server-side, tool results included.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 375. Selective truncation of history breaks coherence; use case facts blocks plus summarisation

`claude-5-1-10`

To stay under budget, a team plans to drop whichever earlier messages look least important on each turn. How should you assess this plan?

- **A.** Sound, because the model can infer the content of missing turns from those that remain.
- **B.** Risky, because removing turns breaks coherence; summarise the narrative and keep a facts block instead.
- **C.** Sound, provided the dropped turns are all assistant messages rather than user messages.
- **D.** Risky only past four turns, below which selective truncation is entirely safe.

<details>
<summary>Reveal answer</summary>

**B. Risky, because removing turns breaks coherence; summarise the narrative and keep a facts block instead.**

Selective truncation breaks conversational coherence; the remedy is summarising the narrative while a persistent case facts block holds the critical details.

- **A:** The model cannot reconstruct turns that were never sent.
- **C:** Coherence depends on both sides of the exchange, so dropping either side causes the same damage.
- **D:** No such threshold exists; the problem is the loss of context, not the turn count.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 376. Upstream agents should return structured data (key facts, citations, relevance scores) rat

`claude-5-1-11`

A research subagent hands its full reasoning trace and raw page text to a synthesis agent with a tight context budget. What should change upstream?

- **A.** Have the synthesis agent summarise the reasoning trace before it uses any of the findings.
- **B.** Raise the synthesis agent's context budget so the reasoning trace fits comfortably alongside it.
- **C.** Remove the subagent layer and let the synthesis agent gather all the sources itself.
- **D.** Have the subagent return structured findings such as claims, citations and relevance scores.

<details>
<summary>Reveal answer</summary>

**D. Have the subagent return structured findings such as claims, citations and relevance scores.**

Upstream agents should return structured data rather than verbose reasoning chains, which saves budget and lets downstream agents use findings directly.

- **A:** The tokens are already spent getting the trace into the downstream context.
- **B:** This pays to carry reasoning the downstream agent cannot use.
- **C:** That moves the verbose exploration into the very context you were protecting.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 377. Subagents must include metadata (dates, source locations, methodological context) in struc

`claude-5-1-12`

Beyond the claims themselves, what must research subagents include in their structured output so downstream synthesis stays accurate?

- **A.** Metadata such as dates, source locations and methodological context.
- **B.** The full transcript of every tool call the subagent issued during its work.
- **C.** A self-reported confidence score standing in place of the source details.
- **D.** The prompt that the coordinator used when it spawned the subagent.

<details>
<summary>Reveal answer</summary>

**A. Metadata such as dates, source locations and methodological context.**

Subagents must include metadata such as dates, source locations and methodological context in their structured outputs so the synthesis agent can interpret findings accurately.

- **B:** Raw call logs are the verbose content that structured output is meant to replace.
- **C:** A score is not a substitute for provenance and is poorly calibrated besides.
- **D:** The spawning prompt tells the synthesis agent nothing about the findings themselves.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 378. Prompt caching exists: a cache_control breakpoint stores a processed prefix, reused at a f

`claude-5-1-13`

What does placing a cache_control breakpoint in a request actually buy you?

- **A.** The prompt below the breakpoint is compressed, so fewer input tokens are billed.
- **B.** The processed prefix is stored and reused on later requests at a fraction of the input cost.
- **C.** Earlier conversation turns are stored server-side so later requests can omit them.
- **D.** Responses to identical prompts are returned from storage without another model call.

<details>
<summary>Reveal answer</summary>

**B. The processed prefix is stored and reused on later requests at a fraction of the input cost.**

A cache breakpoint stores the processed static prefix so subsequent requests reuse it and pay only a fraction of the input cost for those tokens.

- **A:** Caching does not compress anything; it avoids reprocessing an unchanged prefix.
- **C:** This confuses caching with session state; the API remains stateless.
- **D:** It caches the processed input prefix, not the generated output.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-1-context-window-management) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

## 5.2 — Escalation & Ambiguity Resolution

### 379. An explicit request for a human is honoured immediately, with no attempt to resolve first;

`claude-5-2`

Support policy requires human escalation when a customer asks for a person. The customer does so. What should the agent do?

- **A.** Claim a transfer succeeded without invoking or verifying the handoff mechanism.
- **B.** Initiate the supported handoff and include the relevant case context.
- **C.** Continue automated troubleshooting until the customer asks three times.
- **D.** Close the case because automation cannot continue.

<details>
<summary>Reveal answer</summary>

**B. Initiate the supported handoff and include the relevant case context.**

The policy and explicit request establish the handoff; context prevents unnecessary repetition.

- **A:** A promise is not evidence of a completed transfer.
- **C:** That contradicts the stated escalation condition.
- **D:** A requested handoff is not a resolved case.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](None)

### 380. Sentiment

`claude-5-2-2`

An upset customer has a straightforward issue that policy allows automation to resolve, and has not requested a person. What should guide the decision?

- **A.** A fixed rule that upset customers must be ignored.
- **B.** The issue, policy and customer preference, while acknowledging the frustration.
- **C.** Negative wording alone, regardless of the actual task.
- **D.** The length of the customer's message alone.

<details>
<summary>Reveal answer</summary>

**B. The issue, policy and customer preference, while acknowledging the frustration.**

Sentiment alone does not establish that human judgment is required.

- **A:** That fails the support task.
- **C:** Emotion and case complexity are different signals.
- **D:** Length is not a policy criterion.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 381. Policy gap

`claude-5-2-3`

A requested exception is outside documented policy and requires discretion. What should the agent do?

- **A.** Apply an unrelated policy because its wording is similar.
- **B.** Approve the exception whenever the model sounds certain.
- **C.** Seek authorized clarification or human judgment rather than invent policy.
- **D.** Create a new policy that makes the case easy.

<details>
<summary>Reveal answer</summary>

**C. Seek authorized clarification or human judgment rather than invent policy.**

Missing authority should not be replaced with a generated rule.

- **A:** Similarity does not establish applicability.
- **B:** Confidence does not create discretionary authority.
- **D:** The agent lacks authority to do that.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 382. Confidence limits

`claude-5-2-4`

An agent reports high confidence but lacks evidence required to resolve the case. What should happen?

- **A.** Treat the confidence number as the missing evidence.
- **B.** Close the case because a number was returned.
- **C.** Raise the confidence threshold until the fact appears.
- **D.** Obtain the evidence or use the applicable unresolved-case path.

<details>
<summary>Reveal answer</summary>

**D. Obtain the evidence or use the applicable unresolved-case path.**

Self-reported certainty cannot substitute for missing facts.

- **A:** A score is not the required source data.
- **B:** Producing metadata is not resolution.
- **C:** Threshold tuning cannot retrieve absent information.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](https://www.anthropic.com/engineering/building-effective-agents)

### 383. There are exactly three valid escalation triggers: explicit human request, policy exceptio

`claude-5-2-5`

Which set names the escalation triggers the lesson treats as valid for a support agent?

- **A.** Explicit human request, detected customer frustration, and low self-reported confidence.
- **B.** Explicit human request, a policy exception or gap, and inability to make meaningful progress.
- **C.** Repeated customer messages, a refund above a fixed amount, and any failed tool call.
- **D.** Long conversation length, a documented policy violation, and an unrecognised customer record.

<details>
<summary>Reveal answer</summary>

**B. Explicit human request, a policy exception or gap, and inability to make meaningful progress.**

The three valid escalation triggers are an explicit request for a human, a policy exception or gap, and an inability to make meaningful progress.

- **A:** Frustration detection and self-reported confidence are the two triggers the lesson calls unreliable.
- **C:** None of these appear among the valid triggers; a single failed call is handled by local recovery.
- **D:** A violation has a documented answer and conversation length is not a trigger at all.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](None)

### 384. Policy gaps (policy silent) require escalation; policy violations have a documented answer

`claude-5-2-6`

One customer asks for a refund two weeks after the return window closed. Another asks the company to match a competitor's price when policy covers only its own site. How should each be handled?

- **A.** Escalate both, because each asks for an outcome that documented policy does not grant.
- **B.** Resolve both autonomously, since the policy documents already cover returns and pricing.
- **C.** Resolve the late refund from documented policy and escalate the price match as a policy gap.
- **D.** Escalate the late refund and resolve the price match using the closest related pricing rule.

<details>
<summary>Reveal answer</summary>

**C. Resolve the late refund from documented policy and escalate the price match as a policy gap.**

A policy violation has a documented answer the agent can give, whereas a policy gap means the policy is silent and requires escalation.

- **A:** The late refund already has a documented answer, so it does not need human judgement.
- **B:** Competitor matching is a gap the policy is silent on, not a documented case.
- **D:** This inverts the distinction and invents policy from an unrelated rule.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](None)

### 385. Inability to make progress is a catch-all trigger only after a genuine attempt, not antici

`claude-5-2-7`

An agent escalates at the very start of a case, stating that it may not be able to handle the request. Does this satisfy the third valid trigger?

- **A.** No, because the trigger applies only after a genuine attempt that could not advance.
- **B.** Yes, because anticipating difficulty is equivalent to being unable to make progress.
- **C.** Yes, provided the agent records its reasoning in the handoff notes for the reviewer.
- **D.** No, because inability to make progress is never a valid reason to bring in a human.

<details>
<summary>Reveal answer</summary>

**A. No, because the trigger applies only after a genuine attempt that could not advance.**

Inability to make meaningful progress is a valid trigger only after the agent has genuinely attempted resolution and could not advance.

- **B:** Anticipating difficulty is not the same as attempting resolution and failing.
- **C:** Documenting the reasoning does not substitute for making an attempt.
- **D:** It is one of the three valid triggers, just not before a genuine attempt.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](None)

### 386. Self-reported confidence scores are poorly calibrated: confident on hard cases, uncertain 

`claude-5-2-8`

A team proposes routing any case to a human when the model's self-scored confidence drops below seven out of ten. What is the flaw?

- **A.** Confidence scores are reliable, but a ten-point scale is too coarse to route on.
- **B.** The threshold is set too high, so nearly every contact would reach a human reviewer.
- **C.** Scores become reliable only when the model is also asked to justify each one.
- **D.** Self-reported confidence is poorly calibrated, so hard cases pass through and easy ones escalate.

<details>
<summary>Reveal answer</summary>

**D. Self-reported confidence is poorly calibrated, so hard cases pass through and easy ones escalate.**

LLM self-reported confidence is poorly calibrated, leaving the model overconfident on hard cases and unnecessarily uncertain on easy ones.

- **A:** The granularity of the scale is not what makes the signal unreliable.
- **B:** The failure mode is misdirected escalation, not simply escalation volume.
- **C:** Adding an explanation does not calibrate the underlying number.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](None)

### 387. A frustrated customer with a straightforward in-policy issue gets acknowledgement plus res

`claude-5-2-9`

A customer writes angrily about a delivery that arrived damaged. Policy clearly allows a replacement and they have not asked for a person. What should the agent do?

- **A.** Escalate, because the strength of the language shows the case needs human judgement.
- **B.** Acknowledge the frustration and offer the replacement directly.
- **C.** Ask the customer to confirm they are willing to continue with an automated agent.
- **D.** Resolve the case without making any reference to the customer's tone.

<details>
<summary>Reveal answer</summary>

**B. Acknowledge the frustration and offer the replacement directly.**

When the issue is straightforward and within policy, the agent should acknowledge the frustration and offer the resolution rather than escalate.

- **A:** Sentiment measures emotional state, not case difficulty, so it is an unreliable trigger.
- **C:** This adds a step when the issue can simply be resolved now.
- **D:** The lesson calls for acknowledging the frustration alongside the resolution.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](None)

### 388. A customer who reiterates a preference for a human after being offered help is escalated a

`claude-5-2-10`

After the agent offers to process a replacement, the customer repeats that they would rather deal with a person. What should happen now?

- **A.** Offer the replacement a second time, since the customer may not have read the message.
- **B.** Continue automated handling while noting the request in the case record for later.
- **C.** Escalate, since the customer has been offered agent resolution and declined it.
- **D.** Ask the customer to explain why the automated resolution is unsatisfactory to them.

<details>
<summary>Reveal answer</summary>

**C. Escalate, since the customer has been offered agent resolution and declined it.**

Once a customer reiterates their preference for a human after being offered agent resolution, the case escalates.

- **A:** The preference has now been stated twice and should be honoured.
- **B:** Recording the request is not the same as honouring it.
- **D:** This delays a handoff that is now clearly warranted.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](None)

### 389. Ambiguous customer matches are resolved by asking for an additional identifier (email, pho

`claude-5-2-11`

A name search returns three customer records that all match the query. What is the only safe next step?

- **A.** Ask the customer for a disambiguating identifier such as an email, phone number or order number.
- **B.** Work with whichever record shows the most recent activity on the account.
- **C.** Work with whichever record shows the highest lifetime order volume.
- **D.** Merge the three records so the case can proceed against one single account.

<details>
<summary>Reveal answer</summary>

**A. Ask the customer for a disambiguating identifier such as an email, phone number or order number.**

Multiple customer matches must be resolved by asking for an additional identifier; no selection heuristic is acceptable.

- **B:** A recency heuristic can easily select the wrong person.
- **C:** Activity level is another unsafe selection heuristic the lesson rules out.
- **D:** Merging genuinely distinct customers is worse than guessing between them.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](None)

### 390. Heuristic selection among matches (most recent, most active) risks privacy violations and 

`claude-5-2-12`

Why does the lesson forbid picking a record heuristically when several customers match a search?

- **A.** Because the search tool would have to be rewritten to return a single result.
- **B.** Because the wrong record can expose one customer's data to another or act on the wrong account.
- **C.** Because applying a heuristic takes longer than simply asking the customer would.
- **D.** Because the model cannot hold more than one customer record in a single turn.

<details>
<summary>Reveal answer</summary>

**B. Because the wrong record can expose one customer's data to another or act on the wrong account.**

Selecting the wrong customer risks privacy violations and incorrect actions, which is why disambiguation must be requested instead.

- **A:** The tool's behaviour is not the concern; the agent's response to it is.
- **C:** The objection is about safety, not about latency.
- **D:** There is no such limitation on reading multiple records.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](None)

### 391. Explicit escalation criteria with few-shot examples in the system prompt is the proportion

`claude-5-2-13`

An agent resolves only 55% of contacts on first touch, escalating simple replacements while attempting complex policy exceptions itself. What should you try first?

- **A.** Train a classifier on historical tickets to predict which contacts require a human.
- **B.** Add sentiment scoring and escalate automatically whenever negativity passes a threshold.
- **C.** Write explicit escalation criteria into the system prompt with few-shot examples of each decision.
- **D.** Route every contact to a human for a month and rebuild the agent from those transcripts.

<details>
<summary>Reveal answer</summary>

**C. Write explicit escalation criteria into the system prompt with few-shot examples of each decision.**

Explicit escalation criteria with few-shot examples in the system prompt are the proportionate first fix, since prompt optimisation should precede architectural changes.

- **A:** Adding infrastructure before optimising the prompt is a disproportionate first response.
- **B:** Sentiment is one of the two unreliable triggers and does not track case complexity.
- **D:** This abandons automation rather than calibrating the escalation decision.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](None)

### 392. Escalation format is a structured handoff carrying customer ID, root cause and recommended

`claude-5-2-14`

When an agent does escalate, what should the handoff to the human contain?

- **A.** The complete verbatim transcript, with no summary and no recommendation attached.
- **B.** Only the customer's most recent message, so the human can form an independent view.
- **C.** The model's confidence score plus a note that it chose not to continue the case.
- **D.** A structured handoff giving the customer ID, the root cause and a recommended action.

<details>
<summary>Reveal answer</summary>

**D. A structured handoff giving the customer ID, the root cause and a recommended action.**

Escalations should use a structured handoff carrying the customer ID, the root cause and a recommended action.

- **A:** This hands the reviewer raw material instead of a usable case assessment.
- **B:** Stripping the context forces the customer to repeat everything they have already said.
- **C:** A self-reported score is not case context and is poorly calibrated anyway.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-2-escalation-ambiguity) · [Technical reference](None)

## 5.3 — Error Propagation in Multi-Agent Systems

### 393. Access failure means the query did not execute and retry should be considered; valid empty

`claude-5-3`

One research worker cannot access a source; another successfully finds no matches. How should the coordinator receive these outcomes?

- **A.** As two successful searches because neither returned documents.
- **B.** As two permanent system failures.
- **C.** As distinct results: an access failure and a successful empty search.
- **D.** As two empty lists with no status information.

<details>
<summary>Reveal answer</summary>

**C. As distinct results: an access failure and a successful empty search.**

These outcomes have different meanings and require different recovery decisions.

- **A:** The inaccessible source was not successfully searched.
- **B:** A valid empty search need not be a failure.
- **D:** That makes unavailable evidence indistinguishable from searched evidence.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](None)

### 394. Partial results

`claude-5-3-2`

A worker succeeds on some sources and fails on another. What should its return include?

- **A.** Usable partial findings, their provenance and the specific failure context.
- **B.** Only a generic failure that discards every useful finding.
- **C.** Only successful findings with no missing-source notice.
- **D.** A fabricated result for the unavailable source.

<details>
<summary>Reveal answer</summary>

**A. Usable partial findings, their provenance and the specific failure context.**

The coordinator needs both progress and limits to choose recovery.

- **B:** That loses completed work unnecessarily when partial progress is allowed.
- **C:** That conceals incomplete coverage.
- **D:** Invented evidence is not recovery.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](https://modelcontextprotocol.io/specification/2025-06-18/server/tools)

### 395. Recovery ownership

`claude-5-3-3`

A worker has exhausted its local retries. What should it pass to the coordinator?

- **A.** A success flag to avoid burdening the coordinator.
- **B.** The attempted action, failure type, partial results and remaining recovery options.
- **C.** A request to restart all successful workers automatically.
- **D.** The word 'failed' without any context.

<details>
<summary>Reveal answer</summary>

**B. The attempted action, failure type, partial results and remaining recovery options.**

Explicit state enables a higher-level decision without blind repetition.

- **A:** False status prevents informed handling.
- **C:** That needlessly discards or repeats unrelated progress.
- **D:** A generic label gives little basis for recovery.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](https://modelcontextprotocol.io/specification/2025-06-18/server/tools)

### 396. Permission failure

`claude-5-3-4`

One source rejects access. Which fallback is acceptable?

- **A.** Claim the denied source confirms another result.
- **B.** Keep retrying identical denied access without any change.
- **C.** Use an authorized alternative and report the resulting coverage limit.
- **D.** Bypass the denial using another person's credentials.

<details>
<summary>Reveal answer</summary>

**C. Use an authorized alternative and report the resulting coverage limit.**

Recovery must preserve the access boundary and the evidence limits.

- **A:** The inaccessible source supplied no such evidence.
- **B:** Repetition does not establish permission.
- **D:** That is not authorized recovery.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](https://modelcontextprotocol.io/specification/2025-06-18/server/tools)

### 397. The four failure categories are transient, validation, business and permission

`claude-5-3-5`

Which grouping matches the failure categories a subagent should use when reporting an error?

- **A.** Transient, validation, business and permission.
- **B.** Fatal, warning, informational and debug.
- **C.** Network, disk, memory and CPU.
- **D.** Retryable, unknown, user error and silent.

<details>
<summary>Reveal answer</summary>

**A. Transient, validation, business and permission.**

The four failure categories are transient, validation, business and permission, each pointing to a different recovery path.

- **B:** These are log severities and say nothing about how to recover.
- **C:** Resource classes do not tell the coordinator whether a retry can succeed.
- **D:** This mixes one recovery hint with placeholders and omits the documented categories.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](None)

### 398. Permission failures cannot be retried without an authorisation change

`claude-5-3-6`

A subagent is refused access to a licensed database. How should its report classify and frame the failure?

- **A.** As transient, since access may be restored if the call is repeated for long enough.
- **B.** As validation, since the query must have been malformed for the source to reject it.
- **C.** As permission, noting that a retry cannot succeed without an authorisation change.
- **D.** As a business rule violation that the coordinator should escalate to the customer.

<details>
<summary>Reveal answer</summary>

**C. As permission, noting that a retry cannot succeed without an authorisation change.**

Access denial is a permission failure, and permission failures cannot be retried without a change to authorisation.

- **A:** A denial is not resolved by repetition; transient covers timeouts and rate limits.
- **B:** The query was well formed; what was missing was authorisation.
- **D:** A business failure is a rule violation, which is a different category from access denial.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](None)

### 399. Silent suppression (empty results marked success) is the worst anti-pattern because it blo

`claude-5-3-7`

A search subagent catches its own timeout and returns an empty result list with status success. Why is this the worst outcome?

- **A.** Because the coordinator will retry the query indefinitely once it sees no results returned.
- **B.** Because the coordinator reads it as a genuine empty answer, so no recovery is ever attempted at all.
- **C.** Because empty result lists cannot be merged into the final synthesis output.
- **D.** Because the status field is reserved for the coordinator to set rather than the subagent.

<details>
<summary>Reveal answer</summary>

**B. Because the coordinator reads it as a genuine empty answer, so no recovery is ever attempted at all.**

Silent suppression makes the coordinator treat a failure as a genuine empty answer, so it never retries or tries alternatives and the output carries undetectable gaps.

- **A:** It will not retry at all, and that absence of recovery is the actual problem.
- **C:** They merge without difficulty, which is precisely why the gap goes undetected.
- **D:** No such protocol rule exists; subagents report their own status.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](None)

### 400. Silent suppression in support means telling a customer they have no orders when the lookup

`claude-5-3-8`

An order lookup service is down and the tool wrapper returns no records as a successful result. What does the customer experience?

- **A.** A timeout message suggesting that they try their request again a little later.
- **B.** A request for additional identifiers so the agent can narrow its search.
- **C.** An escalation to a human reviewer, because the tool reported that it had failed.
- **D.** An agent confidently telling them there are no orders on their account.

<details>
<summary>Reveal answer</summary>

**D. An agent confidently telling them there are no orders on their account.**

Silent suppression in a support context turns an outage into a confident false statement that the customer has no orders.

- **A:** The failure was hidden, so no such message is ever produced.
- **B:** The agent has no reason to ask, because it believes the lookup succeeded.
- **C:** Nothing was reported as a failure, so no escalation trigger fires.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](None)

### 401. Workflow termination on a single subagent failure discards other subagents' completed work

`claude-5-3-9`

One of five research subagents times out and the pipeline's top-level handler aborts the entire run. What is wrong with this design?

- **A.** It discards four completed results and leaves no path to partial recovery.
- **B.** It hides the failure from the coordinator in the same way a success status would.
- **C.** It breaks the requirement that transient failures be retried at the coordinator level.
- **D.** It prevents the coordinator from categorising the failure as transient or permanent.

<details>
<summary>Reveal answer</summary>

**A. It discards four completed results and leaves no path to partial recovery.**

Workflow termination throws away the results other subagents completed and offers no recovery path, which is disproportionate to a single failure.

- **B:** The failure is fully visible here; it is the response to it that is wrong.
- **C:** Local retry for transient failures belongs in the subagent, not the coordinator.
- **D:** Categorisation remains possible; the run simply ends before recovery can happen.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](None)

### 402. Access failure means the query did not execute and retry should be considered; valid empty

`claude-5-3-10`

A database query executes normally and matches no records. What should the subagent report?

- **A.** An error with failure type transient and the retry flag set to true.
- **B.** A partial failure carrying an empty array of partial results.
- **C.** Success with an empty results array and the retry flag set to false.
- **D.** Success with the retry flag set to true, so the coordinator can confirm the result.

<details>
<summary>Reveal answer</summary>

**C. Success with an empty results array and the retry flag set to false.**

A valid empty result means the query executed and found no matches, so it is reported as a success that needs no retry.

- **A:** Nothing failed, so classifying it as an error invites a pointless retry.
- **B:** The operation completed in full, so partial failure misdescribes it.
- **D:** A confirming retry will return the same nothing and waste resources.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](None)

### 403. Retrying a valid empty result wastes time and resources on a query that will always return

`claude-5-3-11`

A coordinator reruns every query that comes back with no rows, on the assumption that emptiness signals a problem. What is the consequence?

- **A.** Access failures get caught sooner, at the cost of some additional latency.
- **B.** Time and quota are spent on queries that will keep returning nothing.
- **C.** Partial results from earlier subagents are overwritten on each successive rerun.
- **D.** The coordinator loses its ability to tell the four failure types apart.

<details>
<summary>Reveal answer</summary>

**B. Time and quota are spent on queries that will keep returning nothing.**

Retrying a valid empty result burns time and resources on a query that will always return nothing.

- **A:** Access failures are a separate case that is already reported as an error.
- **C:** Rerunning a query does not overwrite another agent's collected output.
- **D:** The type information remains present in each structured report.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](None)

### 404. A generic status after retry exhaustion hides the query, partial results and alternatives 

`claude-5-3-12`

After three backoff attempts fail, a subagent returns the single status 'search unavailable'. What does the coordinator lose?

- **A.** Nothing significant, because the coordinator only needs to know whether to retry.
- **B.** Its ability to run retries of its own, which the subagent has already consumed.
- **C.** The failure type, which can no longer be determined once retries are exhausted.
- **D.** The attempted query, any partial results and the alternative approaches worth trying.

<details>
<summary>Reveal answer</summary>

**D. The attempted query, any partial results and the alternative approaches worth trying.**

A generic status hides the attempted query, the partial results and the suggested alternatives, preventing any informed recovery decision.

- **A:** It also has to choose among alternatives and decide what to do with partial results.
- **B:** Local retries do not forbid a further coordinator-level attempt.
- **C:** The type is perfectly knowable; the generic message simply omits it.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](None)

### 405. Coverage annotations in synthesis output state which topics are well supported and which h

`claude-5-3-13`

One subagent could not reach the journals covering geothermal energy. How should the synthesis report handle that topic?

- **A.** Note that the geothermal section is limited because journal access was unavailable during research.
- **B.** Omit the geothermal section entirely, since no sources were retrieved for it.
- **C.** Fill the section from the model's background knowledge and mark it as provisional.
- **D.** Mark the whole report unreliable until the missing journals can be reached.

<details>
<summary>Reveal answer</summary>

**A. Note that the geothermal section is limited because journal access was unavailable during research.**

Coverage annotations state which topics are well supported and which are limited, so a gap is not mistaken for an irrelevant topic.

- **B:** A silent omission reads as irrelevance rather than as a known limitation.
- **C:** This substitutes unsourced content for what should be a documented gap.
- **D:** That is disproportionate when only one section is affected.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](None)

### 406. Local recovery for transient failures belongs in the subagent; only unresolved failures pr

`claude-5-3-14`

Where should retry logic for timeouts and rate limits live in a coordinator-and-subagent system?

- **A.** In the coordinator, so one consistent retry policy governs every subagent uniformly.
- **B.** In each subagent, which escalates only the failures it cannot resolve locally.
- **C.** In neither, since transient failures should be reported immediately for a human decision.
- **D.** In the synthesis step, so that retries happen once all subagent results are in.

<details>
<summary>Reveal answer</summary>

**B. In each subagent, which escalates only the failures it cannot resolve locally.**

Subagents implement local retry and fallback for transient failures and propagate only what they cannot resolve, which reduces coordinator complexity.

- **A:** This forces the coordinator to model every transient failure mode of every subagent.
- **C:** Transient failures are exactly the class that local recovery is meant to absorb.
- **D:** By synthesis time the opportunity to recover the missing data has passed.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-3-error-propagation) · [Technical reference](None)

## 5.4 — Codebase Exploration & Context Degradation

### 407. Context degradation shows up as generic 'typical pattern' language replacing specific clas

`claude-5-4`

After lengthy exploration, an agent describes generic patterns instead of the code it inspected. What is the most useful context repair?

- **A.** Replace the findings with a generic architecture tutorial.
- **B.** Append the entire repository to every subsequent prompt.
- **C.** Treat fluent explanations as proof that earlier findings remain accurate.
- **D.** Maintain compact findings linked to paths, symbols and revisions, then re-read evidence as needed.

<details>
<summary>Reveal answer</summary>

**D. Maintain compact findings linked to paths, symbols and revisions, then re-read evidence as needed.**

Concrete references support verification without carrying every raw tool output.

- **A:** That removes the repository-specific evidence.
- **B:** Indiscriminate context can add noise and cost.
- **C:** Fluency does not establish source fidelity.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 408. Efficient discovery

`claude-5-4-2`

You need the call path for one endpoint in a large repository. What is a focused approach?

- **A.** Read every file before identifying the endpoint.
- **B.** Infer the path from a generic framework tutorial.
- **C.** Change unrelated modules to see what breaks.
- **D.** Locate the entry point, trace relevant symbols and inspect their actual dependencies.

<details>
<summary>Reveal answer</summary>

**D. Locate the entry point, trace relevant symbols and inspect their actual dependencies.**

Targeted exploration builds evidence for the requested path.

- **A:** That adds large unrelated context without a dependency plan.
- **B:** Framework patterns do not prove this repository's implementation.
- **C:** Discovery should not require speculative mutation.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 409. Scratchpad freshness

`claude-5-4-3`

A persistent exploration note points to code that changed. What should you do?

- **A.** Revalidate the affected claims against the current files.
- **B.** Treat the note as immune to source changes.
- **C.** Trust the note whenever it has more detail than the code.
- **D.** Delete all tests to make the note match.

<details>
<summary>Reveal answer</summary>

**A. Revalidate the affected claims against the current files.**

Stored notes retain findings, not a guarantee of continuing accuracy.

- **B:** Persistence does not prevent staleness.
- **C:** Length is not a source-of-truth rule.
- **D:** Changing evidence to fit a claim is not verification.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 410. Investigation return

`claude-5-4-4`

A delegated code search produces many raw reads. What should the parent ideally receive?

- **A.** A claim that unseen modules behave identically.
- **B.** A focused answer with file or symbol references and unresolved uncertainties.
- **C.** Every raw read with no answer to the task.
- **D.** A generic architecture claim without source references.

<details>
<summary>Reveal answer</summary>

**B. A focused answer with file or symbol references and unresolved uncertainties.**

The parent needs usable findings and a way to inspect their support.

- **A:** Inspection of one area does not establish another.
- **C:** Volume does not supply a clear conclusion.
- **D:** The finding would be difficult to verify.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 411. Context degradation is not a token limit problem; a larger context window does not fix it

`claude-5-4-5`

An exploration agent begins describing generic patterns instead of the classes it read, and a teammate suggests switching to a model with a larger context window. How should you respond?

- **A.** Agree, since the specific findings were evicted once the window filled up.
- **B.** Agree, but only if the session is also restarted so the window begins empty.
- **C.** Disagree, because a larger window still fills with verbose output and the detail is still lost.
- **D.** Disagree, because context degradation only affects sessions that delegate to subagents.

<details>
<summary>Reveal answer</summary>

**C. Disagree, because a larger window still fills with verbose output and the detail is still lost.**

Context degradation is not about running out of tokens, so enlarging the context window leaves the underlying attention problem untouched.

- **A:** Nothing was evicted; the earlier findings are still present in the context.
- **B:** Restarting without saving state discards every finding accumulated so far.
- **D:** It affects any extended exploration session, delegated or not.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 412. The mechanism is verbose output accumulating and pushing earlier precise findings back, sh

`claude-5-4-6`

What causes an agent's specific discoveries to fade during a long codebase exploration session?

- **A.** The model discards older messages from the session once it has answered the question that raised them.
- **B.** Directory listings and file contents are retained in a lower-fidelity form than ordinary prose turns are.
- **C.** Each tool call resets the model's working memory to only the details of the step currently in progress.
- **D.** Verbose output accumulates each step, pushing earlier precise findings back and shifting attention to recent material.

<details>
<summary>Reveal answer</summary>

**D. Verbose output accumulates each step, pushing earlier precise findings back and shifting attention to recent material.**

Every exploration step adds verbose output that pushes earlier precise discoveries further back, so the model's attention drifts to recent material.

- **A:** The model does not drop earlier turns; they remain in the request.
- **B:** No such distinction exists between kinds of content in the context.
- **C:** Prior context is still supplied on every call; nothing is reset.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 413. Scratchpad files are the primary mitigation, persisting findings outside the conversation 

`claude-5-4-7`

When should an exploration agent start writing key findings to a scratchpad file?

- **A.** From the start of the session, as a deliberate strategy rather than a rescue move.
- **B.** Once the model first refers to a typical pattern instead of a real class name.
- **C.** Only once the session begins to approach its context limit.
- **D.** After the exploration finishes, as a record for whoever picks it up next.

<details>
<summary>Reveal answer</summary>

**A. From the start of the session, as a deliberate strategy rather than a rescue move.**

Scratchpad files should be maintained from the start of an extended exploration session, not adopted after degradation has already appeared.

- **B:** By that point the specific details are already hard to recover.
- **C:** Degradation is not tied to the limit, so waiting for it misses the problem.
- **D:** That misses the purpose of protecting the current session's findings.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 414. Scratchpad files are the primary mitigation, persisting findings outside the conversation 

`claude-5-4-8`

Which scratchpad entry best serves an agent that will face follow-up questions about a refund flow?

- **A.** A note that the service follows a conventional layered design built around repositories.
- **B.** Named classes with their file paths, the dependency chain between them, and the concrete gaps found.
- **C.** The full text of every source file the agent opened during its exploration.
- **D.** A list of the search queries the agent ran, recorded without their outcomes.

<details>
<summary>Reveal answer</summary>

**B. Named classes with their file paths, the dependency chain between them, and the concrete gaps found.**

A useful scratchpad records specific class names, file paths, dependency chains and concrete findings rather than generic descriptions or raw dumps.

- **A:** Generic description is exactly the degraded output the scratchpad exists to prevent.
- **C:** Copying raw content simply moves the verbosity problem into a file.
- **D:** Queries without findings cannot answer a later question about the flow.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 415. Subagent delegation's primary benefit is context isolation, not parallelisation

`claude-5-4-9`

A reviewer says delegating exploration to subagents is worthwhile only when the investigations can run at the same time. What is the better justification?

- **A.** Subagents are allocated larger context windows than the coordinating agent is.
- **B.** Subagents can open files that the coordinating agent is not permitted to read.
- **C.** Each subagent explores in its own context, keeping verbose output out of the coordinator's.
- **D.** Subagents keep their context between sessions, so findings persist automatically.

<details>
<summary>Reveal answer</summary>

**C. Each subagent explores in its own context, keeping verbose output out of the coordinator's.**

The primary benefit of subagent delegation here is context isolation: verbose exploration stays in the subagent and only a structured summary returns.

- **A:** Window size is not what delegation changes.
- **B:** Permissions are not the reason the lesson recommends delegation.
- **D:** Persistence comes from scratchpad files and state manifests, not from subagents.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 416. Summary injection between phases prevents the cold start where later subagents duplicate e

`claude-5-4-10`

Phase one mapped the architecture of a service. What keeps phase two subagents from rediscovering the same structure?

- **A.** Injecting a phase one findings summary into each phase two subagent's initial prompt.
- **B.** Giving phase two subagents read access to the full phase one conversation transcript.
- **C.** Running phase two with the same subagents that carried out phase one.
- **D.** Telling phase two subagents to skip any file that phase one has already opened.

<details>
<summary>Reveal answer</summary>

**A. Injecting a phase one findings summary into each phase two subagent's initial prompt.**

Summarising phase one findings and injecting them into phase two prompts prevents the cold start that causes duplicated exploration.

- **B:** That reintroduces the verbose output that delegation was meant to keep out.
- **C:** Each invocation still begins without the earlier context.
- **D:** A skip list is not the architectural understanding phase two needs.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 417. /compact reduces context usage in Claude Code and should be used proactively, not only at 

`claude-5-4-11`

How should the /compact command be used during a long Claude Code exploration session?

- **A.** Only after the session reports that its context has been exhausted.
- **B.** Proactively during the session, to protect context quality rather than only capacity.
- **C.** Before any exploration begins, in order to clear project instructions from context.
- **D.** Instead of scratchpad files, since compaction already preserves the specific findings.

<details>
<summary>Reveal answer</summary>

**B. Proactively during the session, to protect context quality rather than only capacity.**

/compact should be used proactively during extended sessions because it protects context quality, not merely free space.

- **A:** The lesson calls for proactive use rather than last-resort use.
- **C:** That is not what the command is for.
- **D:** Compaction summarises the conversation; scratchpads are what hold the specifics.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 418. Crash recovery manifests record explored paths, key findings, current phase and next steps

`claude-5-4-12`

What belongs in the state manifest an exploration agent writes for crash recovery?

- **A.** The raw contents of every file read, so that nothing needs rereading on resume.
- **B.** Only a session identifier and a timestamp, with the findings rebuilt on resume.
- **C.** The coordinator's prompt template together with the model settings in use.
- **D.** Explored paths, key findings, the current phase and the next steps.

<details>
<summary>Reveal answer</summary>

**D. Explored paths, key findings, the current phase and the next steps.**

The manifest records explored paths, key findings, the current phase and the next steps, so a resumed session continues instead of restarting.

- **A:** That recreates the verbose context the manifest is meant to avoid.
- **B:** Rebuilding the findings is exactly the loss the manifest prevents.
- **C:** Configuration is not a record of exploration progress.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 419. Restarting a degraded session without persisting state loses all accumulated knowledge

`claude-5-4-13`

An agent's context has degraded and the developer plans to restart the session immediately. What is missing from that plan?

- **A.** Persisting findings to a scratchpad or manifest first, then injecting them into the new session.
- **B.** Raising the context limit before the replacement session is started.
- **C.** Disabling subagents in the new session so that its context stays simpler.
- **D.** Repeating the same exploration steps so the new session matches the old one.

<details>
<summary>Reveal answer</summary>

**A. Persisting findings to a scratchpad or manifest first, then injecting them into the new session.**

Findings must be written to a scratchpad or state manifest and injected into the fresh session, otherwise the restart discards all accumulated knowledge.

- **B:** The limit was never the constraint; degradation is an attention problem.
- **C:** Subagents reduce context pressure rather than adding to it.
- **D:** Repeating the work is the cost that saving state is supposed to avoid.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 420. On resume the coordinator loads the manifest and injects it so the agent continues rather 

`claude-5-4-14`

A coordinator resumes an interrupted exploration and loads the saved manifest. What should happen next?

- **A.** The agent re-reads every path listed as explored in order to confirm the manifest.
- **B.** The coordinator starts a fresh manifest and treats the saved one as history.
- **C.** The manifest is injected into the agent's prompt so it continues from the recorded next steps.
- **D.** The coordinator asks the user to restate the original exploration objective.

<details>
<summary>Reveal answer</summary>

**C. The manifest is injected into the agent's prompt so it continues from the recorded next steps.**

On resume the coordinator loads the manifest and injects it into the agent's prompt so exploration continues from the recorded next steps.

- **A:** That repeats the very work the manifest was written to save.
- **B:** The point of the manifest is to continue from the recorded state.
- **D:** The objective and the next steps are already captured in the manifest.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration) · [Technical reference](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

## 5.5 — Human Review & Confidence Calibration

### 421. Aggregate accuracy can hide catastrophic per-type failure rates (97% overall alongside 45%

`claude-5-5`

Overall extraction accuracy is high, but scanned forms often fail. What should guide the review policy?

- **A.** Measure performance by document slice and calibrate review decisions against labeled cases.
- **B.** Use overall accuracy to exempt every document type from review.
- **C.** Use only the model's self-reported confidence without checking it.
- **D.** Review only the document type that already performs best.

<details>
<summary>Reveal answer</summary>

**A. Measure performance by document slice and calibrate review decisions against labeled cases.**

Aggregate accuracy can conceal weak subgroups; observed errors should inform review allocation.

- **B:** A strong aggregate does not establish quality on the failing slice.
- **C:** Uncalibrated confidence is not demonstrated reliability.
- **D:** That can neglect the known failure concentration.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 422. Audit sampling

`claude-5-5-2`

Only low-confidence outputs receive human review. What blind spot remains?

- **A.** All low-confidence outputs must actually be correct.
- **B.** The number of reviewers determines every model prediction.
- **C.** Confident errors in the automatically accepted population.
- **D.** There can be no blind spot above the threshold.

<details>
<summary>Reveal answer</summary>

**C. Confident errors in the automatically accepted population.**

Sampling accepted outputs can reveal mistakes confidence failed to flag.

- **A:** Review selection does not establish their outcome.
- **B:** Review staffing does not control the model's original correctness.
- **D:** An unverified threshold does not guarantee accuracy.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 423. Calibration

`claude-5-5-3`

Among outputs assigned confidence 0.9, about 60% are correct on representative labeled cases. What does this suggest?

- **A.** The system is perfectly calibrated because the score is high.
- **B.** Every individual output is exactly 60% correct.
- **C.** The labels can be ignored because the model supplied a number.
- **D.** The confidence is overestimated for that evaluated population.

<details>
<summary>Reveal answer</summary>

**D. The confidence is overestimated for that evaluated population.**

The score exceeds its observed correctness frequency.

- **A:** Calibration compares scores with outcomes.
- **B:** A group frequency is not a per-output fractional truth score.
- **C:** Calibration requires comparison against trustworthy outcomes.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 424. Distribution change

`claude-5-5-4`

A new document format enters production after review thresholds were calibrated. What should happen?

- **A.** Evaluate the new slice and adjust review routing using evidence.
- **B.** Assume the previous aggregate covers the new format.
- **C.** Automatically exempt the format from review.
- **D.** Choose a threshold based only on filename length.

<details>
<summary>Reveal answer</summary>

**A. Evaluate the new slice and adjust review routing using evidence.**

Old calibration may not transfer to a changed input distribution.

- **B:** The new slice may behave differently.
- **C:** There is no supporting quality evidence yet.
- **D:** That has no established relationship to error risk.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 425. The aggregate looks good because high-volume standard invoices dominate the volume-weighte

`claude-5-5-5`

An extraction system reports 97% aggregate date accuracy while international documents sit near 45%. How can both figures be true?

- **A.** The aggregate is computed from the best-performing document type only.
- **B.** Standard invoices dominate the volume, so the volume-weighted average hides the weak segments.
- **C.** Rare document types are excluded from the aggregate until enough samples accumulate.
- **D.** The aggregate measures whether a field was populated rather than whether it was correct.

<details>
<summary>Reveal answer</summary>

**B. Standard invoices dominate the volume, so the volume-weighted average hides the weak segments.**

The aggregate is volume-weighted, so a dominant high-accuracy document type conceals segments with unacceptable error rates.

- **A:** The aggregate covers all types, which is why it is misleading rather than wrong.
- **C:** The weak types are included in the figure and still masked by volume.
- **D:** It is an accuracy figure over the same fields, not a completeness measure.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 426. Validate accuracy by document type AND field segment before automating anything

`claude-5-5-6`

What must be validated before any part of an extraction pipeline is automated?

- **A.** The aggregate accuracy measured across all documents processed last quarter.
- **B.** The average of the per-field confidence scores that the model reports.
- **C.** The throughput each reviewer sustains at the current review volume.
- **D.** Accuracy broken down by document type and by field segment.

<details>
<summary>Reveal answer</summary>

**D. Accuracy broken down by document type and by field segment.**

Automation decisions require accuracy validated by document type and by field segment, never aggregate metrics alone.

- **A:** Aggregate figures are exactly what hide the risky segments.
- **B:** Raw confidence scores are uncalibrated and cannot stand in for measured accuracy.
- **C:** Reviewer capacity is a staffing question, not an accuracy validation.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 427. Stratified random sampling draws from each stratum: document type, confidence band and fie

`claude-5-5-7`

You are designing ongoing verification sampling for an extraction system. What defines the strata you sample from?

- **A.** Document type, confidence band and field type.
- **B.** The calendar week in which each document arrived for processing.
- **C.** The reviewer who happens to be available to check the item.
- **D.** The order in which the extractions were written to the database.

<details>
<summary>Reveal answer</summary>

**A. Document type, confidence band and field type.**

Stratified sampling draws a representative sample from each stratum: document type, confidence band and field type.

- **B:** Arrival time does not track where errors actually concentrate.
- **C:** Staffing does not define a stratum of the data.
- **D:** Insertion order carries no signal about accuracy.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 428. Stratified sampling serves ongoing accuracy measurement and novel error pattern detection

`claude-5-5-8`

Beyond confirming that each segment still meets its validated accuracy, what does stratified sampling provide?

- **A.** A replacement for the labelled validation set used during calibration.
- **B.** A way to reduce how many documents need to be extracted at all.
- **C.** Detection of novel error patterns that were absent from the original validation set.
- **D.** Proof that reviewer capacity is spread evenly across all document types.

<details>
<summary>Reveal answer</summary>

**C. Detection of novel error patterns that were absent from the original validation set.**

Stratified sampling both measures ongoing accuracy per segment and detects novel failure modes that the original validation set never contained.

- **A:** Calibration still requires ground truth labels; sampling does not replace them.
- **B:** Sampling verifies output; it does not reduce the input volume.
- **D:** Even distribution of reviewers is the anti-pattern, not a goal to demonstrate.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 429. Confidence can be reported per field, but raw scores are relative and not calibrated acros

`claude-5-5-9`

A model reports 0.90 confidence on a date field and 0.90 on an amount field. What can you conclude?

- **A.** The two fields are equally likely to be correct, since the reported scores match.
- **B.** Nothing yet, because the same score maps to different real accuracy per field and document type.
- **C.** Both fields are correct roughly 90% of the time, which is what the score states.
- **D.** The amount field is the more trustworthy of the two, since numeric fields are easier to read.

<details>
<summary>Reveal answer</summary>

**B. Nothing yet, because the same score maps to different real accuracy per field and document type.**

Raw confidence is relative, so 0.90 on dates and 0.90 on amounts can correspond to very different actual accuracy rates.

- **A:** Identical scores can correspond to quite different observed accuracy.
- **C:** Raw scores are not probabilities of correctness.
- **D:** In the lesson's data amount fields calibrate worse than dates, not better.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 430. Calibration requires a labelled validation set compared against reported confidence to bui

`claude-5-5-10`

What is required to turn raw confidence scores into thresholds you can route on?

- **A.** A larger sample of production extractions with no ground truth attached to them.
- **B.** Instructions telling the model to report its confidence more conservatively.
- **C.** A second model that scores the first model's outputs for agreement with it.
- **D.** A labelled validation set used to compare reported confidence against actual accuracy.

<details>
<summary>Reveal answer</summary>

**D. A labelled validation set used to compare reported confidence against actual accuracy.**

Calibration compares reported confidence against known-correct extractions from a labelled validation set to build a calibration curve.

- **A:** Without labels there is nothing to compare the reported scores against.
- **B:** Rewording the prompt does not calibrate the resulting number.
- **C:** Agreement between models is not the same as measured accuracy.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 431. Calibrated thresholds route above-threshold to automation with sampling, below-threshold t

`claude-5-5-11`

Once thresholds have been calibrated, how should extracted fields be routed?

- **A.** Above threshold to automation with stratified sampling, below to review, ambiguous zone to prioritised review.
- **B.** Above threshold to automation with no further checking at all, and every other field to review.
- **C.** All fields to human review regardless of score, with the thresholds used only for reporting.
- **D.** Above threshold to prioritised human review, below threshold to automation, ambiguous zone to sampling.

<details>
<summary>Reveal answer</summary>

**A. Above threshold to automation with stratified sampling, below to review, ambiguous zone to prioritised review.**

Calibrated thresholds send high-confidence fields to automation with stratified sampling, low-confidence fields to human review, and the ambiguous band to prioritised review.

- **B:** Automated output still needs stratified sampling to catch novel errors.
- **C:** That abandons the routing the calibration work exists to enable.
- **D:** This inverts the routing and automates exactly the fields that need judgement.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 432. Reviewer capacity goes to the highest-uncertainty items; spreading it evenly is the anti-p

`claude-5-5-12`

A review team currently checks a fixed percentage of every extraction type. What should change?

- **A.** Nothing, because uniform coverage is the fairest way to use a limited team.
- **B.** Review should be split evenly by reviewer rather than evenly by document type.
- **C.** Capacity should concentrate on the highest-uncertainty items where judgement adds most value.
- **D.** Review should follow arrival order so that no document waits longer than another.

<details>
<summary>Reveal answer</summary>

**C. Capacity should concentrate on the highest-uncertainty items where judgement adds most value.**

Spreading reviewers evenly wastes effort on items the model already handles well, so capacity should go to the most uncertain items first.

- **A:** Even distribution is the anti-pattern the lesson names.
- **B:** That is still an even spread and still wastes capacity on easy items.
- **D:** Chronological service ignores uncertainty entirely.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 433. Prioritisation must be dynamic, reordering the queue by uncertainty rather than serving ch

`claude-5-5-13`

How should the pending human review queue behave as new extractions keep arriving?

- **A.** It should stay fixed once built, so reviewers can finish the batch they started.
- **B.** It should reorder so each reviewer next receives the highest-uncertainty item remaining.
- **C.** It should serve items in arrival order so that waiting times stay predictable.
- **D.** It should alternate between high- and low-confidence items so both get sampled.

<details>
<summary>Reveal answer</summary>

**B. It should reorder so each reviewer next receives the highest-uncertainty item remaining.**

Prioritisation must be dynamic: the queue reorders by uncertainty so the next item served is always the most uncertain one remaining.

- **A:** A static order ignores newly arrived items that are more uncertain.
- **C:** Chronological ordering is explicitly rejected by the lesson.
- **D:** Sampling of automated output is a separate mechanism from the review queue.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

### 434. The validation-before-automation sequence ends with reducing review, only on segments with

`claude-5-5-14`

Which ordering matches the validation-before-automation sequence the lesson prescribes?

- **A.** Reduce review on strong segments, then calibrate confidence, then measure per-segment accuracy, then sample.
- **B.** Calibrate confidence, reduce human review, then measure per-segment accuracy, then add stratified sampling.
- **C.** Add stratified sampling, reduce human review, then measure per-segment accuracy, then calibrate confidence.
- **D.** Measure per-segment accuracy, calibrate confidence, set thresholds, add stratified sampling, then reduce review.

<details>
<summary>Reveal answer</summary>

**D. Measure per-segment accuracy, calibrate confidence, set thresholds, add stratified sampling, then reduce review.**

The sequence measures per-segment accuracy, calibrates confidence, sets thresholds, adds stratified sampling, and only then reduces human review.

- **A:** Reducing review first is exactly the trap; it precedes any evidence.
- **B:** Per-segment measurement has to come before any reduction in review.
- **C:** Calibration cannot come last, since thresholds depend on it.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-5-human-review-calibration) · [Technical reference](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)

## 5.6 — Information Provenance & Multi-Source Synthesis

### 435. Core concept

`claude-5-6`

Two sources report different values for the same metric in different months. How should a synthesis preserve accuracy?

- **A.** Present both values as simultaneous facts without qualification.
- **B.** Retain each value's date, definition and source before deciding whether they conflict.
- **C.** Average the values and discard their dates.
- **D.** Select the longer source without considering measurement periods.

<details>
<summary>Reveal answer</summary>

**B. Retain each value's date, definition and source before deciding whether they conflict.**

Different time periods or definitions can explain an apparent contradiction.

- **A:** That hides the temporal distinction needed to interpret them.
- **C:** Averaging can create a claim supported by neither source.
- **D:** Length does not establish comparability or truth.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 436. Unresolved conflict

`claude-5-6-2`

Two credible sources disagree on the same definition and period. What should the report preserve?

- **A.** A certainty statement with no source discussion.
- **B.** Both attributed claims and the unresolved disagreement.
- **C.** Their arithmetic average labeled as a quoted source fact.
- **D.** Only the claim with the more polished prose.

<details>
<summary>Reveal answer</summary>

**B. Both attributed claims and the unresolved disagreement.**

Do not silently manufacture a consensus the evidence does not support.

- **A:** That hides the unresolved evidence.
- **C:** The average may appear in neither source.
- **D:** Style does not resolve a factual conflict.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/citations)

### 437. Citation validity

`claude-5-6-3`

A citation points to a real document. Does that prove it supports the attached claim?

- **A.** Yes; adding two more unrelated links completes verification.
- **B.** No; citations can never help verification.
- **C.** No; the relevant passage must support the claim's actual meaning.
- **D.** Yes; a valid URL makes every attached statement grounded.

<details>
<summary>Reveal answer</summary>

**C. No; the relevant passage must support the claim's actual meaning.**

Existence and entailment are different checks.

- **A:** Link count does not establish support.
- **B:** Relevant source references are useful when checked.
- **D:** The page may say something else.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/citations)

### 438. Broken attribution

`claude-5-6-4`

A summary contains a factual claim whose original source mapping was lost. What should happen before treating it as verified?

- **A.** Assign the nearest-looking source title without reading it.
- **B.** Treat the summary's confidence as the missing citation.
- **C.** Copy the claim into another summary to make it authoritative.
- **D.** Recover supporting evidence or mark the claim unsupported.

<details>
<summary>Reveal answer</summary>

**D. Recover supporting evidence or mark the claim unsupported.**

The attribution chain must be restored rather than guessed.

- **A:** Similarity is not evidence of support.
- **B:** Confidence does not locate a source.
- **C:** Repetition does not create provenance.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](https://platform.claude.com/docs/en/build-with-claude/citations)

### 439. Each finding carries claim, source URL, document name, relevant excerpt and publication da

`claude-5-6-5`

Which set of fields makes up the structured claim-source mapping that each finding must carry?

- **A.** Claim, source URL, document name, relevant excerpt and publication date.
- **B.** Claim, author, word count, retrieval time and reported confidence score.
- **C.** Claim, summary, subagent name, token cost and assigned topic label.
- **D.** Claim, source URL, reading level, sentiment and total citation count.

<details>
<summary>Reveal answer</summary>

**A. Claim, source URL, document name, relevant excerpt and publication date.**

A finding's provenance record is the claim plus source URL, document name, the supporting excerpt and the publication date.

- **B:** None of these let a reader check that the source supports the claim.
- **C:** This is pipeline metadata rather than provenance.
- **D:** This mixes one provenance field with attributes irrelevant to verification.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 440. The pipeline is research, analysis, synthesis, report, and synthesis is the most common at

`claude-5-6-6`

In a research, analysis, synthesis and report pipeline, where is attribution most often lost?

- **A.** At collection, because subagents rarely record the source URL of a finding.
- **B.** At the analysis step, because assessments replace the original findings.
- **C.** At synthesis, where findings are combined and paraphrased without carrying mappings forward.
- **D.** At report generation, because inline citations cannot represent multiple sources.

<details>
<summary>Reveal answer</summary>

**C. At synthesis, where findings are combined and paraphrased without carrying mappings forward.**

Synthesis is the most common failure point, because combining and paraphrasing drops source mappings unless the prompt requires them to survive.

- **A:** The structured claim-source format is applied at the collection step.
- **B:** Analysis adds its assessment while preserving the original mappings.
- **D:** Inline citations handle multiple sources without difficulty.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 441. Attribution dies during summarisation unless mappings are explicitly preserved and merged

`claude-5-6-7`

How do you stop a synthesis agent from producing vague claims such as 'investment has grown significantly'?

- **A.** Limit the synthesis agent's output length so that it has no room to generalise.
- **B.** Require in its prompt that every claim in its output trace to a specific source.
- **C.** Have the synthesis agent quote whole source documents rather than summarising them.
- **D.** Run the synthesis twice and keep whichever output happens to name more sources.

<details>
<summary>Reveal answer</summary>

**B. Require in its prompt that every claim in its output trace to a specific source.**

The synthesis agent's prompt must explicitly require that every claim it produces remains traceable to a specific source.

- **A:** Brevity does not force the agent to attribute anything.
- **C:** That abandons synthesis instead of making it attributable.
- **D:** A selection heuristic is not a structural guarantee of traceability.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 442. Without temporal context a real trend can be misread as a data quality problem and wrongly

`claude-5-6-8`

Two subagent outputs about the same metric arrive without publication dates. What risk does that create for the synthesis agent?

- **A.** It will merge the two values into a single figure that cannot later be separated.
- **B.** It will refuse to include either of the two values in the final report.
- **C.** It will treat the newer of the two sources as authoritative by default.
- **D.** It may read a genuine trend as a contradiction and flag or suppress consistent findings.

<details>
<summary>Reveal answer</summary>

**D. It may read a genuine trend as a contradiction and flag or suppress consistent findings.**

Without publication or collection dates, an accelerating trend looks like a contradiction, and the synthesis may wrongly flag or suppress valid findings.

- **A:** The risk described is misinterpretation, not irreversible merging.
- **B:** It may well include them, but with the wrong interpretation attached.
- **C:** Without dates it has no way to tell which source is newer.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 443. Financial data renders as tables, news and current events as prose, technical findings as 

`claude-5-6-9`

A report section compares investment totals and growth rates across three consecutive years. What presentation fits?

- **A.** A table, so that values and trends can be compared row by row.
- **B.** Flowing prose, so that each figure gains surrounding narrative context.
- **C.** A bulleted list, matching the format used for technical findings elsewhere.
- **D.** A single sentence summarising the overall direction of the change.

<details>
<summary>Reveal answer</summary>

**A. A table, so that values and trends can be compared row by row.**

Financial data belongs in tables, where values and trends across periods are easiest to compare.

- **B:** Prose makes numeric comparison harder and obscures patterns.
- **C:** Lists suit technical detail rather than numeric comparison across periods.
- **D:** This discards the very values the section exists to present.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 444. Financial data renders as tables, news and current events as prose, technical findings as 

`claude-5-6-10`

A synthesis covers market figures, recent regulatory developments and an API's configuration options. How should it be rendered?

- **A.** As tables throughout, so every section of the report shares one consistent structure.
- **B.** As flowing prose throughout, since one narrative voice reads best across a report.
- **C.** Figures as a table, developments as prose, and configuration options as a structured list.
- **D.** As structured lists throughout, so that no single section dominates the report layout.

<details>
<summary>Reveal answer</summary>

**C. Figures as a table, developments as prose, and configuration options as a structured list.**

Content-appropriate rendering means financial data as tables, news and events as prose, and technical findings as structured lists.

- **A:** Forcing all content into a single format degrades readability.
- **B:** Numbers and configuration options are hard to compare when buried in prose.
- **D:** Uniform formatting is precisely what the lesson warns against.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 445. Reports separate well-established findings from contested ones and preserve original sourc

`claude-5-6-11`

One finding is backed by three independent sources and another rests on a single report. How should the output present them?

- **A.** Identically throughout the report, so that the reader is not steered toward either of the two findings.
- **B.** In sections that separate well-established findings from contested ones, keeping each source's characterisation.
- **C.** By dropping the single-source finding from the report until a second source can corroborate it.
- **D.** By merging all four sources into one combined confidence figure presented to the reader.

<details>
<summary>Reveal answer</summary>

**B. In sections that separate well-established findings from contested ones, keeping each source's characterisation.**

Reports should include explicit sections distinguishing well-established findings from contested ones and preserve each source's own characterisation.

- **A:** Equal presentation hides a real difference in evidentiary support.
- **C:** This discards information instead of qualifying it.
- **D:** A single number erases the source characterisations and methodological context.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 446. Conflicting sources are annotated with both values and full attribution, never resolved by

`claude-5-6-12`

A document analysis agent finds two different annual revenue figures for the same company. What should it do?

- **A.** Stop the analysis and return an error describing the inconsistency it encountered.
- **B.** Select the audited figure, on the grounds that audited statements outrank filings.
- **C.** Report the average of the two figures with both sources listed beneath it.
- **D.** Finish the analysis with both values annotated as a detected conflict.

<details>
<summary>Reveal answer</summary>

**D. Finish the analysis with both values annotated as a detected conflict.**

The analysis agent completes its work with the conflict included and explicitly annotated, since resolution belongs to the coordinator or the consumer.

- **A:** The analysis should be completed rather than abandoned at the conflict.
- **B:** Resolving the conflict is not the analysis agent's decision to make.
- **C:** Averaging manufactures a value that neither source actually states.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 447. A conflict record carries a conflict flag, per-value source and context, and a possible ex

`claude-5-6-13`

What should a recorded field-level conflict contain besides the competing values themselves?

- **A.** A conflict flag, the source and context for each value, and a possible explanation for the difference.
- **B.** A ranking of the two sources ordered by the reputation of each publisher.
- **C.** The analysing agent's confidence that one of the two values is the correct one.
- **D.** A note instructing downstream agents to adopt the more recently published value.

<details>
<summary>Reveal answer</summary>

**A. A conflict flag, the source and context for each value, and a possible explanation for the difference.**

A conflict record marks the conflict, attaches a source and context to each value, and offers a possible explanation such as audited versus preliminary figures.

- **B:** Ranking edges toward resolving the conflict, which is not the analysis agent's role.
- **C:** A confidence score is not source context and does not explain the difference.
- **D:** That imposes the arbitrary selection the lesson explicitly rejects.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 448. Resolution of an annotated conflict belongs to the coordinator or the consumer, who may pr

`claude-5-6-14`

Once a conflict has been annotated and passed upward, who decides what happens to it?

- **A.** The subagent that first retrieved the lower value, since it holds the most context.
- **B.** The report generator, which picks whichever value fits the surrounding narrative best.
- **C.** The coordinator or the consumer, who may present both, investigate further or escalate.
- **D.** Nobody, because an annotated conflict is already the final form of the finding.

<details>
<summary>Reveal answer</summary>

**C. The coordinator or the consumer, who may present both, investigate further or escalate.**

Resolution belongs to the coordinator or the consumer, who can present both values, investigate further or escalate to a human analyst.

- **A:** Retrieval order confers no authority over the resolution.
- **B:** Fitting the narrative is exactly the arbitrary selection the lesson forbids.
- **D:** Annotation preserves the choice for someone else; it does not remove the choice.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 449. Trap: selecting the most recent source when credible sources conflict is arbitrary selecti

`claude-5-6-15`

Two credible reports give different growth rates for the same market, each drawn from a different year of data. The synthesis agent currently keeps whichever report is newer. What should it do instead?

- **A.** Average the two rates and attach a footnote recording the variance between them.
- **B.** Present both rates with their source attribution and the publication date behind each.
- **C.** Hold the finding back and escalate to a human analyst before either rate is included.
- **D.** Keep the newer rate in the body and record the older one in an appendix instead.

<details>
<summary>Reveal answer</summary>

**B. Present both rates with their source attribution and the publication date behind each.**

Arbitrarily selecting one value destroys information, so both rates are annotated with their source attribution and publication dates and the consumer decides.

- **A:** An average is a figure neither source states, and it conceals both of the reported values.
- **C:** The synthesis should complete with both values annotated; escalation is not a precondition for reporting them.
- **D:** This is still arbitrary selection, and it presents false certainty in the part readers actually read.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 450. Trap: require publication or data collection dates in all structured outputs so temporal i

`claude-5-6-16`

What must structured subagent output always carry so that differing figures can be interpreted correctly?

- **A.** The number of sources the subagent consulted before settling on the figure.
- **B.** A note ranking each source by how authoritative its publisher appears to be.
- **C.** The subagent's own verdict on whether the figures genuinely conflict at all.
- **D.** The publication or data collection date attached to every reported figure.

<details>
<summary>Reveal answer</summary>

**D. The publication or data collection date attached to every reported figure.**

Publication and data collection dates must be required in all structured outputs, because they are what make correct temporal interpretation possible.

- **A:** A source count says nothing about when the figure was measured or published.
- **B:** Publisher ranking invites exactly the arbitrary selection the lesson forbids.
- **C:** That judgement belongs downstream, and it cannot be made without the dates in the first place.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 451. Build task: subagents must emit the structured format from the start, since unstructured p

`claude-5-6-17`

A research subagent returns its findings as flowing prose, and the synthesis agent is instructed to preserve attribution. Why does attribution still fail?

- **A.** The mappings were never created, so attribution was already lost before synthesis began.
- **B.** Prose inputs push the synthesis agent past the context budget it has available.
- **C.** The synthesis agent can only merge mappings drawn from more than one subagent.
- **D.** Preservation instructions bind only the report step, never the synthesis step.

<details>
<summary>Reveal answer</summary>

**A. The mappings were never created, so attribution was already lost before synthesis began.**

Subagents must output the structured format from the start; if they return unstructured prose, attribution is gone before synthesis has a chance to preserve it.

- **B:** The failure here is missing provenance, not context pressure.
- **C:** No such constraint exists; a single subagent's mappings merge without difficulty.
- **D:** The synthesis prompt is precisely where preservation has to be required.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 452. Trap: the synthesis agent must explicitly preserve and merge claim-source mappings, otherw

`claude-5-6-18`

What must the final report contain for every claim it makes to count as traceable?

- **A.** A statement of how confident the pipeline is in the claim as a whole.
- **B.** The name of the subagent that originally contributed the underlying finding.
- **C.** A count of how many sources were reviewed across the whole research phase.
- **D.** Inline citations, or a structured reference section tying each claim to its source.

<details>
<summary>Reveal answer</summary>

**D. Inline citations, or a structured reference section tying each claim to its source.**

The final output must make every claim traceable through inline citations or a structured reference section that ties each claim to its source.

- **A:** A confidence statement is not provenance and cannot be checked by a reader.
- **B:** This identifies a pipeline step rather than a source anyone can verify.
- **C:** A total for the phase says nothing about any individual claim.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

### 453. Build task: conflict handling detects overlapping claims reporting different values for th

`claude-5-6-19`

How does a conflict handler decide that two findings need annotating as a conflict?

- **A.** It compares the wording of the two findings and flags any that read differently.
- **B.** It finds claims that overlap on the same measure but report different values.
- **C.** It flags any two findings that were retrieved from different source documents.
- **D.** It flags findings whose publication dates fall more than a year apart.

<details>
<summary>Reveal answer</summary>

**B. It finds claims that overlap on the same measure but report different values.**

Conflict handling detects overlapping claims that report different values for the same measure, then preserves both with full attribution and a possible explanation.

- **A:** Paraphrase differences are not value conflicts and would flag agreeing findings.
- **C:** Two documents that agree are not in conflict, so this flags far too much.
- **D:** A gap between dates often explains a difference rather than creating a conflict.

</details>

[Lesson material](https://claudecertificationguide.com/learn/5-context-management/5-6-information-provenance) · [Technical reference](None)

## Reading the sources

The lesson links identify curriculum coverage. Technical references support the relevant mechanisms; scenario judgments and distractor explanations are original teaching material. No question claims that model confidence guarantees correctness, prompts enforce permissions, session restoration reverses external effects, or schema validity proves facts.
