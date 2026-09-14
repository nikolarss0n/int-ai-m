# Collected interview questions

Collected 14 September 2026: **120 general interview prompts**, including 50 recommended starting selections. The separate Claude Architect deck contains another 120 cards.

This general inventory is separate from the [120 Claude Architect cards](/Users/nklars0/Projects/int-ai-m/notes/interview-cards/claude-certification-cards.md). The general prompts still need authored choices; the Claude deck has four options, correct answers and explanations for every card. App integration is pending. Narrow follow-up drills link to parent questions; they are not counted as new independent topics. Exact repeated prompts were merged.

The source column links each prompt to a reviewed conversation or saved guide. `practiced` means a question and user response are visible; `discussed` means explanation/clarification is visible; `prepared` means it appeared in a suggested list or guide; `mentioned_only` means the topic was named but not taught; `asked_not_answered` records an unanswered prompt. None is a claim about current mastery.

## Source key

- **voice-ai**: [AI Engineer Interview Prep](codex://threads/01a0589c-bb51-7230-873c-a37393dbdfdd) — 34 turns; all available pages reviewed.
- **voice-ts**: [TypeScript Mock Interview](codex://threads/01a06bcf-ac72-70f2-a0c5-179d0ae4ffe9) — 3 turns; all available pages reviewed.
- **epam-chat**: [Prepare EPAM AI interview](codex://threads/01a0693c-cc62-7190-8ece-512dfecfbf64) — 2 turns; all available pages reviewed.
- **gil-chat**: [Python и GIL async limitations](https://chatgpt.com/c/6a94261c-9188-83ed-b3c1-4c67771af947) — 8 turns; all available pages reviewed.
- **epam-bg**: [Търсене на чат за EPAM](https://chatgpt.com/c/6a9ace2d-f570-83eb-8f28-492ea2787dbd) — 51 turns; all available pages reviewed.
- **guide-50**: [AI Solution Engineering: 50 interview questions to rehearse](/Users/nklars0/Projects/int-ai-m/notes/ai-solution-engineering-top-50.md).
- **epam-guide**: [EPAM AI Solution Engineering interview prep](/Users/nklars0/Documents/Codex/2026-09-04/he/outputs/epam-ai-interview-prep.md).

## Proposed first 50

Ordered from the concepts revisited in voice practice toward applied AI scenarios. This deliberately differs from the earlier broad top-50 guide.

`ai-026`, `py-gil-scheduling`, `py-threads-useful`, `py-io`, `py-execution-models`, `ai-025`, `ai-024`, `ai-027`, `ai-028`, `py-collections`, `py-hashable`, `py-copy`, `py-yield`, `py-generator-memory`, `py-decorator`, `py-context-manager`, `ai-046`, `py-type-hints`, `py-async-race`, `oop-protocol`, `oop-composition`, `oop-models`, `oop-lifetimes`, `api-endpoint`, `ai-029`, `ai-030`, `api-idempotency`, `api-jobs`, `api-workers`, `api-testing`, `ai-001`, `ai-002`, `ai-003`, `ai-004`, `ai-005`, `ai-006`, `ai-007`, `ai-008`, `ai-009`, `rag-sql`, `ai-018`, `ai-019`, `ai-020`, `ai-021`, `ai-010`, `ai-011`, `ai-014`, `ai-016`, `llm-softmax`, `ai-035`

## Questions by topic

### RAG (16)

| ID | Question | Evidence | Source |
| --- | --- | --- | --- |
| ai-001 ★ | Design a RAG system end to end. | discussed | guide-50 · question:1; epam-bg · turn:09964d8c-984e-45ea-be4a-7eac3a7545c1 |
| ai-002 ★ | How would you chunk an entire book? | prepared | guide-50 · question:2 |
| ai-003 ★ | How do you choose chunk size and overlap? | prepared | guide-50 · question:3 |
| ai-004 ★ | What is an embedding, and how would you select an embedding model? | discussed | guide-50 · question:4; epam-bg · turn:f9b72e6a-be8d-4d14-9f87-c3823d8668ea |
| ai-005 ★ | Why combine keyword search and vector search? | prepared | guide-50 · question:5 |
| ai-006 ★ | What does a reranker add? | prepared | guide-50 · question:6 |
| ai-007 ★ | How would you answer questions over tables in PDFs? | prepared | guide-50 · question:7 |
| ai-008 ★ | How do you make citations trustworthy? | prepared | guide-50 · question:8 |
| ai-009 ★ | A RAG answer is wrong. How do you debug it? | prepared | guide-50 · question:9 |
| ai-036 | How would you answer a multi-hop question? | prepared | guide-50 · question:36 |
| ai-037 | What is GraphRAG, and when would you use it? | prepared | guide-50 · question:37 |
| ai-038 | How would you summarize themes across thousands of documents? | prepared | guide-50 · question:38 |
| ai-039 | Why use RAG when a model has a huge context window? | prepared | guide-50 · question:39 |
| ai-040 | How would you handle index updates and embedding migrations? | prepared | guide-50 · question:40 |
| ai-041 | How do you defend RAG and agents against prompt injection? | prepared | guide-50 · question:41 |
| rag-sql ★ | Can SQL store and search embeddings, and what does a vector index add? | discussed | epam-bg · turn:704a7797-5347-4eb9-ade8-8b4b15057622 |

### Evaluation (8)

| ID | Question | Evidence | Source |
| --- | --- | --- | --- |
| ai-010 ★ | How would you build the first RAG evaluation suite? | prepared | guide-50 · question:10 |
| ai-018 ★ | Explain precision@k and recall@k with an example. | discussed | guide-50 · question:18; epam-bg · turn:3225cfa2-711b-47ec-95b5-2531b3a974f5 |
| ai-019 ★ | What is MRR, and when is it insufficient? | prepared | guide-50 · question:19 |
| ai-020 ★ | How do faithfulness, correctness and relevance differ? | discussed | guide-50 · question:20; epam-bg · turn:4bcc0002-e32d-4e81-a981-f7d539ba3fce |
| ai-021 ★ | Would you use an LLM as a judge? | discussed | guide-50 · question:21; epam-bg · turn:da2f53c8-5c7c-403d-b364-be781654c3f5 |
| ai-022 | How do you avoid misleading evaluation results? | prepared | guide-50 · question:22 |
| ai-023 | What belongs in offline evaluation versus production monitoring? | prepared | guide-50 · question:23 |
| ai-044 | When would you use nDCG instead of MRR? | prepared | guide-50 · question:44 |

### Agents (9)

| ID | Question | Evidence | Source |
| --- | --- | --- | --- |
| ai-011 ★ | When do you need an agent instead of a fixed workflow? | prepared | guide-50 · question:11 |
| ai-012 | Explain ReAct. | prepared | guide-50 · question:12 |
| ai-013 | How do LangChain and LangGraph differ? | prepared | guide-50 · question:13 |
| ai-014 ★ | What are state, nodes, edges and reducers in LangGraph? | prepared | guide-50 · question:14 |
| ai-015 | How do you implement safe tool calling? | prepared | guide-50 · question:15 |
| ai-016 ★ | How do you add human-in-the-loop approval? | prepared | guide-50 · question:16 |
| ai-017 | How do you prevent an agent from looping forever? | prepared | guide-50 · question:17 |
| ai-042 | When do multiple agents improve a system? | prepared | guide-50 · question:42 |
| ai-043 | What does durable agent execution guarantee? | prepared | guide-50 · question:43 |

### FastAPI and production (16)

| ID | Question | Evidence | Source |
| --- | --- | --- | --- |
| ai-024 ★ | When should a FastAPI endpoint use `async def`? | practiced | guide-50 · question:24; voice-ai · turn:01a058ab-ecc6-7d40-ae03-82d87952e63d |
| ai-029 ★ | What does Pydantic validation guarantee? | prepared | guide-50 · question:29 |
| ai-030 ★ | How do you design retries and timeouts for LLM calls? | prepared | guide-50 · question:30 |
| ai-031 | Serverless, managed containers or AKS: how do you choose? | prepared | guide-50 · question:31 |
| ai-032 | How would you use MLflow and LangSmith? | prepared | guide-50 · question:32 |
| ai-033 | How do you reduce user-visible latency? | prepared | guide-50 · question:33 |
| ai-034 | Tell me about an AI system you shipped. | prepared | guide-50 · question:34 |
| ai-045 | How would you stream an answer reliably? | prepared | guide-50 · question:45 |
| api-endpoint ★ | What belongs in a production LLM endpoint beyond calling the model? | prepared | voice-ai · turn:01a058ac-9c8b-7852-bc41-c77c9ff141d1;backend:1 |
| api-pool | What is a connection pool, and why must it be bounded? | prepared | voice-ai · turn:01a058ac-9c8b-7852-bc41-c77c9ff141d1;backend:4 |
| api-idempotency ★ | How do idempotency keys prevent duplicate effects during retries? | prepared | voice-ai · turn:01a058ac-9c8b-7852-bc41-c77c9ff141d1;backend:5 |
| api-jobs ★ | Why should a large document-embedding batch use a durable background job? | asked_not_answered | voice-ai · turn:01a058ad-9db9-7de0-a8f0-d06bf62365fd |
| api-workers ★ | What changes for models, caches and concurrency limits with multiple Uvicorn workers? | prepared | epam-guide · heading:What changes with several Uvicorn workers? |
| api-testing ★ | How would you test an async service using fakes, stubs and mocks without live model calls? | prepared | epam-guide · section:Short Python coding drills they may use;testing answer |
| api-security | How do authentication, authorization, rate limits and safe logging protect an AI API? | prepared | voice-ai · turn:01a058ad-cebc-7361-9e66-41c6af9dced5;cheat-sheet:20 |
| api-cache | What can an AI service cache, and what invalidates cached answers? | prepared | voice-ai · turn:01a058ad-cebc-7361-9e66-41c6af9dced5;cheat-sheet:21 |

### Python runtime (24)

| ID | Question | Evidence | Source |
| --- | --- | --- | --- |
| ai-025 ★ | What happens when you call an async function? | prepared | guide-50 · question:25 |
| ai-026 ★ | Explain the GIL without oversimplifying. | practiced | guide-50 · question:26; voice-ai · turn:01a058a2-386e-7b41-9c53-442200cf17ce; gil-chat · turn:4da9f4e7-62b4-48e0-b602-1a80713fb97a |
| ai-027 ★ | How would you process 10,000 reviews with bounded concurrency? | prepared | guide-50 · question:27 |
| ai-028 ★ | How should concurrent work handle failure and cancellation? | prepared | guide-50 · question:28 |
| ai-046 ★ | Explain mutable defaults, assignment and shallow copies. | prepared | guide-50 · question:46 |
| ai-047 | Why use generators and context managers in data pipelines? | prepared | guide-50 · question:47 |
| py-io ★ | What is I/O-bound work versus CPU-bound work, including local and remote model calls? | discussed | voice-ai · turn:01a0589f-ddb3-73f3-911b-02748199bf2d |
| py-gil-scheduling ★ | Does the GIL queue database requests or decide which CPU and I/O tasks run first? | practiced | voice-ai · turn:01a058a2-386e-7b41-9c53-442200cf17ce |
| py-threads-useful ★ | Why are Python threads useful even when the GIL is enabled? | practiced | epam-bg · turn:80dd6fe7-445d-4931-91b6-18caaac83c5c |
| py-execution-models ★ | How do a process, thread and coroutine differ? | discussed | epam-bg · turn:82f54c26-7f52-4183-b05a-6a92d3d21c54 |
| py-collections ★ | When would you use a list, tuple, set or dictionary? | practiced | voice-ai · turn:01a058a4-644f-7383-9723-2d9fac3d9a3d |
| py-hashable ★ | What makes an object hashable, and why must dictionary keys and set members be hashable? | practiced | voice-ai · turn:01a058a5-0543-7da2-9e40-dee891d45951 |
| py-copy ★ | Which nested objects are shared after a shallow copy versus a deep copy? | practiced | voice-ai · turn:01a058a5-fced-7051-95bf-41e2f5170669 |
| py-yield ★ | What does yield preserve, and how does it differ from return or await? | discussed | voice-ai · turn:01a058a9-4068-7562-8033-55bb795ea230 |
| py-generator-memory ★ | Why can a generator reduce memory use, and is a normal for loop the problem? | discussed | voice-ai · turn:01a058a8-bc1f-7981-99e2-82cecad7cbae |
| py-decorator ★ | What is a decorator, and where would you use it in an AI service? | practiced | voice-ai · turn:01a058aa-0d19-7651-91c1-b7f0c7c91ede |
| py-context-manager ★ | What does with do, and who implements resource cleanup on exceptions? | practiced | voice-ai · turn:01a058aa-f8d4-7d00-9b27-1fb03dcd7a11 |
| py-type-hints ★ | Do Python type hints enforce types at runtime? | prepared | voice-ai · turn:01a058ad-cebc-7361-9e66-41c6af9dced5;cheat-sheet:11 |
| py-venv | What does a virtual environment isolate? | prepared | voice-ai · turn:01a058ad-cebc-7361-9e66-41c6af9dced5;cheat-sheet:12 |
| py-task-future | How do a coroutine, Task and Future differ? | prepared | epam-guide · heading:Coroutine, Task, and Future? |
| py-async-race ★ | How can a single-threaded asyncio program have a race condition? | prepared | epam-guide · heading:What is a race condition if asyncio is single-threaded? |
| py-argument-sharing | How do mutation and rebinding differ when passing an object to a Python function? | prepared | epam-guide · heading:How does Python pass arguments? |
| py-memory | How do reference counting and cyclic garbage collection work, and what does del remove? | prepared | epam-guide · heading:How is memory managed in CPython? |
| py-retry-decorator | What must a retry decorator preserve for async calls, cancellation and function metadata? | prepared | epam-guide · heading:What should a retry decorator preserve? |

### LLM foundations (5)

| ID | Question | Evidence | Source |
| --- | --- | --- | --- |
| ai-035 ★ | Explain a transformer in practical terms. | prepared | guide-50 · question:35 |
| ai-048 | How do tokens, temperature and prompting affect an application? | prepared | guide-50 · question:48 |
| ai-049 | When would you choose prompting, RAG or fine-tuning? | prepared | guide-50 · question:49 |
| llm-softmax ★ | What are logits and softmax, and where are they used in next-token generation? | discussed | epam-bg · turn:735b8623-f499-4b12-ad48-feb32a262e1d |
| llm-sampling | How do temperature, top-k and top-p differ? | mentioned_only | epam-bg · turn:37b8d2f6-4edf-4dbe-98e5-3fc9e68daada |

### Coding (1)

| ID | Question | Evidence | Source |
| --- | --- | --- | --- |
| ai-050 | How would you implement a small ranked-retrieval utility? | prepared | guide-50 · question:50 |

### Python OOP (9)

| ID | Question | Evidence | Source |
| --- | --- | --- | --- |
| oop-composition ★ | Why choose composition over inheritance for an AI pipeline? | prepared | epam-guide · heading:Why composition over inheritance for an AI pipeline? |
| oop-protocol ★ | When would you use Protocol rather than ABC for an LLM client? | prepared | epam-guide · heading:`ABC` versus `Protocol` for `ModelClient`? |
| oop-solid | How do SOLID principles apply to a route, use case and provider adapter? | prepared | epam-guide · heading:Explain SOLID using this service |
| oop-lifetimes ★ | Which dependencies belong to application lifespan versus individual requests? | prepared | epam-guide · heading:How should dependency lifetimes work? |
| oop-models ★ | When would you use a dataclass versus a Pydantic model? | prepared | epam-guide · heading:Dataclass versus Pydantic model? |
| oop-methods | How do classmethod, staticmethod and property differ? | prepared | epam-guide · heading:`classmethod`, `staticmethod`, and `property`? |
| oop-mro | How do MRO and super work in multiple inheritance? | prepared | epam-guide · heading:How do MRO and `super()` work? |
| oop-exceptions | How should provider errors become domain exceptions and HTTP responses? | prepared | epam-guide · heading:How would you design exceptions? |
| oop-thread-safety | Does the GIL make a shared model or SDK client thread-safe? | prepared | epam-guide · heading:Is a shared model object thread-safe because of the GIL? |

### Submitted project (12)

| ID | Question | Evidence | Source |
| --- | --- | --- | --- |
| project-classifier | Why use an LLM instead of a fixed classifier for review themes? | prepared | epam-guide · heading:Why an LLM instead of a classifier? |
| project-rag | Is summarizing all reviews supplied in a request actually RAG? | prepared | epam-guide · heading:Is this RAG? |
| project-schema | Why derive the model's JSON Schema from the Zod output contract? | prepared | epam-guide · heading:Why JSON Schema and Zod? |
| project-injection | Why inject LlmClient instead of constructing an SDK inside the summarizer? | prepared | epam-guide · heading:Why inject `LlmClient`? |
| project-retry | How can SDK retries multiply application retries? | prepared | epam-guide · heading:What does `MAX_RETRIES=2` mean? |
| project-invalid-output | Should schema-invalid model output be retried unchanged? | prepared | epam-guide · heading:Should schema-invalid output be retried? |
| project-health | What does a health endpoint prove, and how is readiness different? | prepared | epam-guide · heading:What does `/health` prove? |
| project-field | How would you add mentionCount or a category and keep schema, prompt, tests and stub aligned? | prepared | epam-guide · heading:1. Add a field or category |
| project-theme-limit | How would you add maxThemesPerCategory and enforce the limit consistently? | prepared | epam-guide · heading:2. Add `maxThemesPerCategory` |
| project-citations | How would you add review IDs and verify that returned quotes belong to those reviews? | prepared | epam-guide · heading:4. Add review IDs and citations |
| project-batch | How would you add a bounded batch endpoint with an explicit partial-failure policy? | prepared | epam-guide · heading:5. Add a batch endpoint |
| project-size-limits | Why are HTTP body bytes, string length and model token budgets different limits? | prepared | epam-guide · section:Real weaknesses you should be ready to volunteer;items:2,6 |

### TypeScript (20)

| ID | Question | Evidence | Source |
| --- | --- | --- | --- |
| ts-01 | How does TypeScript differ from JavaScript? | practiced | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:1; voice-ts · turn:01a06bd1-51c7-7101-8b55-7bbf7f0db589;transcript_tail |
| ts-02 | What is the difference between `any`, `unknown`, and `never`? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:2 |
| ts-03 | How do `type` aliases and `interface`s differ? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:3 |
| ts-04 | What are union and intersection types? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:4 |
| ts-05 | How does type narrowing work? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:5 |
| ts-06 | What are type guards? Give examples. | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:6 |
| ts-07 | What are generics, and why are they useful? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:7 |
| ts-08 | What do `keyof`, `typeof`, and indexed-access types do? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:8 |
| ts-09 | What are optional properties and optional chaining? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:9 |
| ts-10 | What is the difference between `null` and `undefined`? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:10 |
| ts-11 | What do TypeScript enums compile to? What alternatives exist? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:11 |
| ts-12 | What are tuples, and how do they differ from arrays? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:12 |
| ts-13 | What are function overloads? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:13 |
| ts-14 | What are literal types and discriminated unions? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:14 |
| ts-15 | What are mapped and conditional types? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:15 |
| ts-16 | Explain `Partial`, `Required`, `Pick`, `Omit`, and `Record`. | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:16 |
| ts-17 | What does `as const` do? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:17 |
| ts-18 | What is the difference between a type assertion and the `satisfies` operator? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:18 |
| ts-19 | How would you safely type an API response? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:19 |
| ts-20 | How would you type reusable React component props and events? | prepared | voice-ts · turn:01a06bd0-9aac-7f91-8fc2-8a05cf91ecc0;list:20 |

## Observed revisit signals

These are specific moments from earlier sessions, not a current ability assessment.

- **py-gil-scheduling**: Asked whether the GIL queues database work or chooses CPU versus I/O tasks; clarify lock versus scheduler.
- **ai-026**: Repeated requests for a concrete GIL explanation across voice and Bulgarian sessions; prioritize a visual/concept card.
- **py-hashable**: Explicitly asked what hashable means during collection-type practice.
- **py-copy**: Initially described copying hashes rather than sharing or copying nested objects.
- **py-yield**: Asked whether yield waits for a chunk and how it differs from a normal loop.
- **py-generator-memory**: Requested a real-world example and revisited the difference between the data source and for loop.
- **py-decorator**: Compared decorators with labels/marking functions and asked for the correct explanation.
- **py-context-manager**: Explicitly said the reason for using with was unknown in that session.
- **ai-024**: Initially described async versus def as response ordering/waiting; correction discussed in the next response.
- **py-threads-useful**: Asked for the question to be repeated and for an example answer before rehearsal.
- **ai-021**: Asked whether evaluation must mainly be manual; make automatic metrics versus fallible LLM judges explicit.
- **ts-01**: Voice transcript says subset; the intended distinction is TypeScript adding a type system to JavaScript. Only this TS question has an observed answer.

## Collection limits

Five conversations were read through their final available page (98 turns). Voice evidence comes from saved transcript/handoff text, not raw audio. The TypeScript session contains a 20-question outline but only the opening question has an observed answer. The June EPAM/S&P chats were mentioned by an older assistant, but their originals were not retrieved. Unrelated personal chats were not used.

The JSON includes up to three lexical candidates from the existing app bank per question. These are explicitly unverified mapping suggestions: overlap in words does not prove equivalence or coverage. No app question IDs or progress have been changed.
