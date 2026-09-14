# AI Solution Engineering: 50 interview questions to rehearse

These are practice questions selected from the topics in your brief, not confirmed EPAM questions. The proposed order is **35 Essential questions first, then 15 Depth questions**. Technical sources were checked on 7 September 2026. Framework APIs evolve; explain the concept before quoting an API name.

For each question, give the short answer aloud in 45–90 seconds, then handle the follow-up. Score yourself: **0** cannot explain; **1** definition only; **2** explanation plus example; **3** tradeoff plus failure mode and verification. Repeat the lowest scores. The examples below are design proposals; replace project stories with work you actually did.

## Essential: RAG design and diagnosis

### 1. Design a RAG system end to end. — Essential

- First clarify the users, document types, freshness, permissions, latency and what counts as a correct answer.
- Offline: parse documents, preserve structure and source locations, chunk, embed and index. Online: authorize, retrieve, rerank, pack evidence, generate and attach citations.
- Evaluate retrieval and answers separately, then monitor quality, latency and cost together. RAG supplies external evidence; it does not make the generator infallible. [Original RAG paper](https://arxiv.org/abs/2005.11401)

**Follow-up / trap:** “Why not just use a larger model?” It may improve synthesis but cannot recover a private fact the system never retrieved.

### 2. How would you chunk an entire book? — Essential

- Parse chapters, headings, paragraphs, tables and page references before splitting text. Remove repeated headers without deleting meaningful content.
- Index focused passages with the book title and chapter path; keep links to larger parent sections for context expansion.
- Test factual lookups, cross-chapter questions and whole-book summaries separately. One giant vector poorly represents many unrelated topics. [Document chunking guidance](https://learn.microsoft.com/en-us/azure/search/vector-search-how-to-chunk-documents)

**Follow-up / trap:** “What about a scanned book?” Add OCR and inspect extraction quality first; changing embeddings cannot fix missing text.

### 3. How do you choose chunk size and overlap? — Essential

- Start with structure-aware chunks within the embedding model's token limit; treat any initial size as a hypothesis.
- Small chunks improve focus but can lose context. Large chunks preserve context but add irrelevant material. Overlap preserves boundaries while increasing duplication and cost.
- Compare sizes on a fixed question set, measuring evidence recall, final answer quality and token usage. [Chunking tradeoffs](https://learn.microsoft.com/en-us/azure/search/vector-search-how-to-chunk-documents)

**Follow-up / trap:** “Is 500 tokens always best?” No; contracts, code and tables have different boundaries and query patterns.

### 4. What is an embedding, and how would you select an embedding model? — Essential

- An embedding maps input into a numeric representation where a chosen similarity measure can support retrieval.
- Benchmark on your language, domain and query style, including exact identifiers and paraphrases. Compare retrieval quality, cost, latency and storage.
- Encode queries and documents with compatible model versions and the model's required query/document conventions. Equal vector dimensions do not imply compatible spaces. [Semantic retrieval implementation](https://www.sbert.net/examples/sentence_transformer/applications/retrieve_rerank/README.html)

**Follow-up / trap:** “Can we change the model without rebuilding vectors?” Usually re-embed into a separate versioned index; test and migrate it deliberately.

### 5. Why combine keyword search and vector search? — Essential

- Keywords help with error codes, names and exact terms; dense vectors help with paraphrases and conceptual similarity.
- Retrieve from both, deduplicate and combine rankings. Reciprocal rank fusion uses `score(d) = sum(1 / (c + rank(d)))` across lists containing d, with one-based ranks and a chosen positive constant c.
- Validate the hybrid result against each component baseline. Hybrid is a candidate design, not a guaranteed improvement. [Azure hybrid search](https://learn.microsoft.com/en-us/azure/search/hybrid-search-overview), [RRF scoring](https://learn.microsoft.com/en-us/azure/search/hybrid-search-ranking)

**Follow-up / trap:** “Why not average the two raw scores?” Their ranges and meanings differ; an arbitrary average can distort relevance.

### 6. What does a reranker add? — Essential

- The first retriever searches cheaply across the corpus. A cross-encoder reranker jointly examines each query–candidate pair for finer relevance judgments.
- Retrieve a broader candidate set, rerank it, then fit the best evidence into the context budget.
- Measure the improvement against added latency. A reranker cannot recover evidence absent from its candidates. [Retrieve and rerank](https://www.sbert.net/examples/sentence_transformer/applications/retrieve_rerank/README.html)

**Follow-up / trap:** “Why not run the cross-encoder over a million documents?” Pairwise scoring is too expensive for a normal interactive request.

### 7. How would you answer questions over tables in PDFs? — Essential

- Preserve row and column headers, units, captions, footnotes and page locations. A cell value alone may be meaningless.
- Retrieve a table description, then pass the relevant structured rows or cells for answering; use deterministic code for arithmetic.
- Check extraction against the original page, especially merged cells and tables split across pages. [Document layout and table extraction](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/prebuilt/layout?view=doc-intel-4.0.0)

**Follow-up / trap:** “What if revenue is in millions?” Preserve units through extraction, computation and the answer; a correct sum with wrong units is still wrong.

### 8. How do you make citations trustworthy? — Essential

- Keep stable source IDs and precise page or section locations attached to retrieved evidence.
- Require claim-level references and check that the cited passage actually supports each claim. A real URL alone proves little.
- Measure both citation correctness and coverage: unsupported extra claims can remain even when every displayed citation is valid. [ALCE citation evaluation paper](https://arxiv.org/abs/2305.14627)

**Follow-up / trap:** “It has three citations; is it grounded?” Only if those sources entail the claims and cover the answer's substantive content.

### 9. A RAG answer is wrong. How do you debug it? — Essential

- Trace the exact query and corpus version. Check whether the required evidence exists and was parsed correctly.
- Inspect the candidate set, reranked results and final prompt separately. Find the first stage where evidence disappeared or changed meaning.
- Run the generator with verified evidence to isolate synthesis problems. Fix that stage, add a regression case and compare on the unchanged evaluation set.

**Follow-up / trap:** “Should we change the prompt first?” Only after evidence shows that prompt interpretation, rather than missing retrieval, caused the failure.

### 10. How would you build the first RAG evaluation suite? — Essential

- Collect representative questions with source evidence and expected answer criteria; include unanswerable, ambiguous, stale and permission-sensitive cases.
- Freeze a held-out set and establish a simple baseline. Change one major component at a time and inspect per-category regressions.
- Track retrieval relevance, answer correctness, support, refusal quality, latency and cost. A single aggregate hides different failure modes. [RAG design and evaluation guide](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/rag/rag-solution-design-and-evaluation-guide)

**Follow-up / trap:** “Can we generate all the questions from our chunks?” Useful for coverage, but keep independently written real questions to avoid an overly easy test set.

## Essential: agents and controlled execution

### 11. When do you need an agent instead of a fixed workflow? — Essential

- Use a fixed workflow when the steps and branches are known. Use an agent when the model must choose subsequent actions dynamically and a predefined workflow is insufficient.
- Start with the simplest design that meets the task: one model call, retrieval, then tools if needed.
- Agent flexibility brings extra cost, variable latency and more failure paths, so require measurable task-success improvement. [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents)

**Follow-up / trap:** “Is every chatbot an agent?” A chatbot may only generate text; an agent selects actions that affect its workflow or environment.

### 12. Explain ReAct. — Essential

- ReAct interleaves reasoning about the task, taking an action and observing its result, then uses that result to choose the next step.
- In a tool-based implementation, the application executes an allowed tool and feeds the observation back to the model.
- Add explicit stopping criteria and operational budgets; the reasoning pattern itself provides no reliability guarantee. [ReAct paper](https://arxiv.org/abs/2210.03629)

**Follow-up / trap:** “What do you log?” Tool selections, validated arguments, results and concise decision summaries; private model reasoning is not a required observability contract.

### 13. How do LangChain and LangGraph differ? — Essential

- LangChain provides higher-level model, tool and agent abstractions. LangGraph provides lower-level stateful orchestration with nodes, transitions, persistence and interruption.
- Current LangChain agents build on LangGraph; describing them as unrelated competitors or “chains versus any loops” is incomplete.
- Choose based on how much explicit control the workflow needs, not familiarity with a brand. [LangChain overview](https://docs.langchain.com/oss/python/langchain/overview), [LangGraph overview](https://docs.langchain.com/oss/python/langgraph/overview)

**Follow-up / trap:** “Must a LangGraph node call an LLM?” No; a node can perform deterministic validation, retrieval or other code.

### 14. What are state, nodes, edges and reducers in LangGraph? — Essential

- State carries the workflow's data; nodes perform work and return updates; edges choose what runs next.
- Reducers define how an update combines with an existing state field. Replacement, appending and merging by ID have different semantics.
- Parallel writers need an appropriate merge policy or separate fields; appending everything can duplicate results. [Graph API and reducers](https://docs.langchain.com/oss/python/langgraph/graph-api)

**Follow-up / trap:** “Does returning an empty list clear an append-reduced field?” No; appending an empty list leaves the accumulated data unchanged.

### 15. How do you implement safe tool calling? — Essential

- The model proposes a tool and arguments; application code validates the schema, authorizes the caller and executes the allowed operation.
- Give tools narrow names and contracts, bounded outputs, timeouts and clear error results.
- Enforce permissions outside the model. Tool output is untrusted input; it cannot authorize a new action. [Tool design guidance](https://www.anthropic.com/engineering/building-effective-agents), [OWASP prompt injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)

**Follow-up / trap:** “The model produced valid JSON; can we execute it?” Schema validity says nothing about authorization or whether the action makes sense.

### 16. How do you add human-in-the-loop approval? — Essential

- Persist a proposed action with its exact arguments and pause before executing it. Let the reviewer approve, edit or reject that proposal.
- In LangGraph, an interrupt needs checkpointing and a thread identifier. Resume with the review result and revalidate current permissions and state.
- A resumed node can execute again from its beginning, so side effects before the interrupt must be idempotent. [LangGraph interrupts](https://docs.langchain.com/oss/python/langgraph/interrupts)

**Follow-up / trap:** “The payment happened before the pause; what goes wrong on resume?” Re-execution can charge again unless the operation is safely deduplicated.

### 17. How do you prevent an agent from looping forever? — Essential

- Set limits for steps, wall-clock time, tokens, tool calls and retries. A step count alone does not bound a slow tool.
- Detect repeated actions with unchanged observations and stop with a useful explanation or an escalation path.
- Record the termination reason and partial progress so failures can be diagnosed and resumed deliberately. [LangGraph recursion controls](https://docs.langchain.com/oss/python/langgraph/graph-api)

**Follow-up / trap:** “Could a high recursion limit solve failures?” It can hide a faulty loop while increasing cost; inspect the repeated transition first.

## Essential: evaluation that explains failure

### 18. Explain precision@k and recall@k with an example. — Essential

- Precision@k is relevant retrieved items divided by k. Recall@k is retrieved relevant items divided by all labeled relevant items.
- If three documents are relevant and the top five contain two, precision@5 is 2/5 and recall@5 is 2/3.
- Define the relevance unit and annotation policy: document, chunk or evidence fact. Deduplicate IDs before scoring. [Information retrieval evaluation](https://nlp.stanford.edu/IR-book/html/htmledition/evaluation-of-ranked-retrieval-results-1.html)

**Follow-up / trap:** “Can recall be trusted with incomplete labels?” It measures recall against the known labels; unjudged relevant evidence can distort the result.

### 19. What is MRR, and when is it insufficient? — Essential

- Reciprocal rank is 1 divided by the rank of the first relevant hit; use zero if none appears within the cutoff. MRR averages that value across queries.
- It rewards bringing the first useful item near the top. A relevant result at rank four contributes 0.25.
- For multi-hop answers, one early hit can look excellent while a second necessary source is missing. Also measure coverage of all required evidence. [Retrieval evaluator metrics](https://www.sbert.net/docs/package_reference/sentence_transformer/evaluation.html)

**Follow-up / trap:** “MRR is 1, so the answer has enough context?” Only the first relevant hit is guaranteed to be first; completeness is a separate question.

### 20. How do faithfulness, correctness and relevance differ? — Essential

- Faithfulness asks whether the answer's claims follow from the supplied evidence. Correctness asks whether it satisfies the expected facts or answer criteria.
- Relevance asks whether it addresses the user's question. A supported answer to a different question is still unhelpful.
- An answer can faithfully repeat a stale source and be factually wrong; assess source quality and freshness too. [Ragas faithfulness definition](https://docs.ragas.io/en/stable/concepts/metrics/available_metrics/faithfulness/)

**Follow-up / trap:** “Is grounding just a cosine similarity?” Similarity is not entailment; define grounding operationally and check claim support.

### 21. Would you use an LLM as a judge? — Essential

- Yes, for scalable rubric-based judgments that are hard to express in exact matching, with human-labeled examples for calibration.
- Freeze the rubric and judge version; review disagreements and test order sensitivity, verbosity preference and adversarial examples.
- Keep deterministic checks for schemas, citation IDs and arithmetic. A judge score is a measurement with error, not ground truth. [LangSmith evaluation methods](https://docs.langchain.com/langsmith/evaluation)

**Follow-up / trap:** “Can the same model generate answers and grade itself?” It can share the generator's blind spots; compare with independent human judgments.

### 22. How do you avoid misleading evaluation results? — Essential

- Separate development and held-out examples; prevent near-duplicates and source leakage across splits.
- Report sample counts, categories, failed requests and uncertainty, rather than silently dropping difficult cases.
- Distinguish a system outage from a completed but incorrect answer. Keep reliability visible and avoid claiming a quality comparison from missing outputs.

**Follow-up / trap:** “The new prompt wins on six questions; ship it?” First check representativeness, effect size and regressions; six favorable examples may not generalize.

### 23. What belongs in offline evaluation versus production monitoring? — Essential

- Offline: repeatable datasets, controlled comparisons and targeted regressions before release.
- Online: real task outcomes, user feedback, latency, errors, costs and sampled quality checks, segmented by user and query type.
- Use production failures to propose new labeled cases without tuning on the held-out test set. [Offline and online evaluation](https://docs.langchain.com/langsmith/evaluation)

**Follow-up / trap:** “Users clicked thumbs up, so it is accurate?” Feedback measures perceived usefulness and is selection-biased; verify factual quality separately.

## Essential: Python, FastAPI and reliability

### 24. When should a FastAPI endpoint use `async def`? — Essential

- Use it when you await nonblocking database or HTTP clients, allowing other requests to progress during I/O waits.
- A blocking SDK called directly inside `async def` still blocks the event loop. Use an async client or deliberately offload blocking I/O.
- FastAPI runs normal `def` path operations in its thread pool; ordinary helper functions you call directly are not automatically offloaded. [FastAPI concurrency](https://fastapi.tiangolo.com/async/)

**Follow-up / trap:** “Does adding `async` make CPU-heavy embedding computation parallel?” No; the computation still needs a suitable worker or inference service.

### 25. What happens when you call an async function? — Essential

- Calling it creates a coroutine object; it does not by itself run that work to completion.
- `await` runs and waits for the awaitable. Scheduling tasks lets operations make progress concurrently when they yield control.
- Sequentially awaiting each HTTP call in a loop does not create concurrent requests. [Python coroutines and tasks](https://docs.python.org/3/library/asyncio-task.html)

**Follow-up / trap:** “Can a coroutine with no effective suspension starve others?” Yes; cooperative scheduling needs opportunities to yield.

### 26. Explain the GIL without oversimplifying. — Essential

- In conventional GIL-enabled CPython, only one thread executes Python bytecode at a time. Threads can still overlap I/O; some native extensions release the GIL.
- For CPU-bound Python code, consider processes or native/vectorized computation, measuring serialization overhead.
- Optional free-threaded CPython builds can disable the GIL. Check the actual interpreter and extension compatibility; do not assume every Python runtime has identical behavior. [Python free-threading support](https://docs.python.org/3/howto/free-threading-python.html)

**Follow-up / trap:** “So threads are useless in Python?” No; they are useful for many blocking I/O workloads and compatible native computations.

### 27. How would you process 10,000 reviews with bounded concurrency? — Essential

- Stream inputs through a queue with a finite `maxsize` and a fixed worker pool. A full queue makes the producer wait, providing backpressure.
- A semaphore limits active operations, but creating 10,000 tasks first still allocates 10,000 task objects.
- Bound result buffering too: persist results or emit them incrementally. Concurrency limits and provider requests-per-second limits are separate controls. [Python async queues](https://docs.python.org/3/library/asyncio-queue.html)

**Follow-up / trap:** “What if the consumer is slower than the producer?” The producer should slow down or a defined overload policy should reject work.

### 28. How should concurrent work handle failure and cancellation? — Essential

- Decide whether one failure aborts the batch or becomes a per-item error.
- `TaskGroup` cancels sibling tasks for most child exceptions; default `gather` propagates the first exception without automatically cancelling the other awaitables.
- Clean up resources and propagate cancellation. Cancellation is cooperative; an external side effect may already have happened. [Python task semantics](https://docs.python.org/3/library/asyncio-task.html)

**Follow-up / trap:** “Can we catch every exception and return an empty list?” That hides failures and may turn partial work into a false success.

### 29. What does Pydantic validation guarantee? — Essential

- It checks or converts input into declared types and constraints; configure strictness and extra-field behavior deliberately.
- Use separate request and response contracts, length limits and domain validators where appropriate.
- Schema-valid output can still contain invented facts, nonexistent citation IDs or unauthorized actions. Validate those against trusted application state. [Pydantic models](https://pydantic.dev/docs/validation/latest/concepts/models/)

**Follow-up / trap:** “If `age` is an integer, must it be sensible?” No; an integer type alone does not enforce a plausible range or business rule.

### 30. How do you design retries and timeouts for LLM calls? — Essential

- Set a total request deadline, then fit attempt timeouts and retry delays inside the remaining budget.
- Retry transient faults and eligible throttling with capped exponential backoff and jitter; honor applicable server retry guidance. Avoid retries for permanent input or authentication errors.
- Coordinate SDK and application retries to prevent multiplication. A timed-out write may already have succeeded, so use idempotency for side effects. [AWS retry behavior](https://docs.aws.amazon.com/sdkref/latest/guide/feature-retry-behavior.html), [Idempotent API design](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs//)

**Follow-up / trap:** “Three retries at each of three service layers?” That can multiply downstream attempts and overload the dependency.

## Essential: production and model fundamentals

### 31. Serverless, managed containers or AKS: how do you choose? — Essential

- Compare traffic shape, cold-start tolerance, job duration, networking, GPUs, operational skills and cost at expected utilization.
- Functions suit event-triggered tasks; managed containers can simplify service deployment; AKS offers Kubernetes-level control with more operational responsibility.
- Separate the API, durable background ingestion and inference when their scaling needs differ. Avoid choosing Kubernetes solely because the project uses AI. [Azure compute decision guide](https://learn.microsoft.com/en-us/azure/architecture/guide/technology-choices/compute-decision-tree)

**Follow-up / trap:** “Are serverless functions always cheaper?” No; include sustained load, warm capacity, execution duration and operational costs.

### 32. How would you use MLflow and LangSmith? — Essential

- MLflow supports experiment/model lifecycle work and now also GenAI tracing, evaluation and prompt workflows.
- LangSmith provides LLM application tracing and evaluation across workflows; its role extends beyond a LangChain debug console.
- Choose around the team's existing stack, retention, deployment and evaluation needs. Version the model, prompt, corpus and settings with each result. [MLflow GenAI](https://mlflow.org/docs/latest/genai/), [LangSmith evaluation](https://docs.langchain.com/langsmith/evaluation)

**Follow-up / trap:** “Should we log every prompt verbatim?” Set deliberate redaction and retention rules; collect the evidence required for diagnosis without casually copying secrets.

### 33. How do you reduce user-visible latency? — Essential

- Measure queueing, retrieval, reranking, provider wait, first useful text and completion, including p50 and p95.
- Reduce unnecessary sequential model calls, right-size context and outputs, reuse safe cached work and overlap independent I/O.
- Streaming improves time to useful output; it does not necessarily reduce completion time. Compare quality and latency together before accepting a change.

**Follow-up / trap:** “Our spinner appears instantly; are we fast?” Measure when usable answer content appears, rather than when the UI starts waiting.

### 34. Tell me about an AI system you shipped. — Essential

- Use an actual project: who needed it, what failed before, the constraints and your exact responsibility.
- Explain one design choice, a rejected alternative, a concrete failure and the evidence that the fix worked.
- State measured results and their limits. If deployment was a prototype or live measurement was unavailable, say so precisely.

**Follow-up / trap:** “What did you personally implement?” Be ready to distinguish your contribution from team work and tools you only explored.

### 35. Explain a transformer in practical terms. — Essential

- Tokens become vectors with positional information. Attention combines information across token positions; feed-forward layers transform the representations.
- Queries and keys determine attention weights; values carry the information being combined. Multiple heads can capture different relationships.
- Decoder causal masking prevents access to future tokens. Training can process known sequence positions in parallel, while autoregressive generation produces subsequent tokens step by step. [Transformer paper](https://arxiv.org/abs/1706.03762)

**Follow-up / trap:** “What is the cost of standard full attention?” Its token-pair interactions scale quadratically with sequence length; optimized implementations can reduce memory traffic without removing those interactions.

## Depth: complex retrieval and agent workflows

### 36. How would you answer a multi-hop question? — Depth

- Identify which evidence facts must be joined. Retrieve the first fact, then use the discovered entity or relationship to retrieve the next.
- Preserve provenance for each hop and verify the join, including identity, dates and units. Stop when a required fact is missing.
- Evaluate evidence completeness as well as final correctness. Finding one supporting passage does not establish the whole reasoning chain. [Context recall approaches](https://docs.ragas.io/en/stable/concepts/metrics/available_metrics/context_recall/)

**Follow-up / trap:** “Two people have the same name; what breaks?” Entity resolution; the system may join facts about different people into a plausible false answer.

### 37. What is GraphRAG, and when would you use it? — Depth

- Broadly, graph-based RAG uses entities and relationships to organize or retrieve evidence. Microsoft's GraphRAG also builds community summaries for corpus-level questions.
- It can help when questions depend on relationships or broad themes that similarity search misses.
- Compare against ordinary retrieval first: extraction errors, entity resolution, indexing cost and update complexity can outweigh the benefit. [GraphRAG paper](https://arxiv.org/abs/2404.16130)

**Follow-up / trap:** “Does adding a graph remove hallucinations?” No; extracted edges and summaries can themselves be wrong and need source provenance.

### 38. How would you summarize themes across thousands of documents? — Depth

- A few nearest-neighbor chunks may not represent the corpus. Use a coverage-aware approach, such as hierarchical summaries or community summaries linked to originals.
- Aggregate evidence without counting repeated copies as independent support. Keep uncommon but material exceptions visible.
- Evaluate completeness and source diversity, not just whether a fluent paragraph was produced. [GraphRAG global summarization approach](https://arxiv.org/abs/2404.16130)

**Follow-up / trap:** “Does a summary of summaries preserve every exception?” No; validate critical claims against original evidence and test omission cases.

### 39. Why use RAG when a model has a huge context window? — Depth

- Long context can be useful for a bounded document set; retrieval can reduce cost and focus evidence across a larger changing corpus.
- Test the actual model on your workload. A large advertised window does not guarantee uniform use of evidence throughout it.
- Long-context performance has shown position sensitivity; treat that as a reason to evaluate, not a universal claim that every current model fails. [Lost in the Middle](https://arxiv.org/abs/2307.03172)

**Follow-up / trap:** “Can we always paste the whole book?” Consider latency, cost, permissions, updates and whether the answer needs local detail or global coverage.

### 40. How would you handle index updates and embedding migrations? — Depth

- Give documents and chunks stable identities, content hashes and version metadata; explicitly handle updates and deletion.
- Build a new index for incompatible embedding changes, validate it on the same queries, then switch traffic with rollback available.
- Include corpus and permission versions in cache decisions. A cached answer can become stale even when its question is unchanged.

**Follow-up / trap:** “The source file was deleted; are we done?” Remove derived chunks and embeddings, and invalidate answers or caches that should no longer expose it.

### 41. How do you defend RAG and agents against prompt injection? — Depth

- Treat retrieved documents and tool results as data, even if they contain instructions addressed to the assistant.
- Enforce tenant access, allowed tools and argument restrictions in application code; filter unauthorized evidence before it reaches the model.
- Test malicious documents and data-exfiltration attempts. Prompt wording alone cannot establish a security boundary. [OWASP prompt injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)

**Follow-up / trap:** “A document says to email all retrieved files; what should happen?” It has no authority to expand tool permissions or the user's request.

### 42. When do multiple agents improve a system? — Depth

- Use them for independent subtasks, specialized context or distinct permissions when these yield a measured advantage.
- Define task contracts and merge criteria, isolate each worker's context and cap combined costs and parallelism.
- Compare against a single agent or deterministic fan-out. More agents can add coordination overhead and correlated mistakes. [Agent workflow patterns](https://www.anthropic.com/engineering/building-effective-agents)

**Follow-up / trap:** “Three agents agree; is that strong evidence?” Agreement is weaker when all share the same model, source error or prompt bias.

### 43. What does durable agent execution guarantee? — Depth

- Persisted checkpoints let a workflow recover recorded progress after interruption or failure.
- Recovery can replay work; isolate nondeterminism and side effects, and use stable operation IDs and idempotent external writes.
- Checkpoints alone do not create exactly-once external effects. Also plan schema migrations for workflows paused on an older application version. [LangGraph persistence](https://docs.langchain.com/oss/python/langgraph/persistence)

**Follow-up / trap:** “The tool succeeded, then the process crashed before checkpointing.” On replay, deduplicate the operation or reconcile its existing result.

### 44. When would you use nDCG instead of MRR? — Depth

- nDCG rewards placing highly relevant results early and supports graded relevance, such as essential evidence versus merely related material.
- Discount gains by rank and normalize against the ideal ranking for that query.
- MRR focuses only on the first relevant hit; nDCG evaluates more of the ranking. Neither alone proves that all multi-hop evidence was retrieved. [Ranked retrieval metrics](https://nlp.stanford.edu/IR-book/html/htmledition/evaluation-of-ranked-retrieval-results-1.html)

**Follow-up / trap:** “Can two evaluators report different nDCG values?” Yes, if they use different gains, cutoffs, judgments or handling of queries without relevant items.

## Depth: implementation and model tradeoffs

### 45. How would you stream an answer reliably? — Depth

- Define events for content, completion and failure; do not treat an interrupted stream as a successful complete answer.
- Bound buffering for slow clients and propagate disconnection or deadline cancellation to upstream work where supported.
- Decide which validation can happen incrementally and which needs the final output. Cancellation cannot undo external work already completed. [Python cancellation semantics](https://docs.python.org/3/library/asyncio-task.html)

**Follow-up / trap:** “The HTTP status is already 200 when the provider fails.” The stream needs an explicit error or incomplete termination contract.

### 46. Explain mutable defaults, assignment and shallow copies. — Depth

- A mutable default argument is created once when the function is defined and can retain changes across calls; use `None` and initialize inside.
- Assignment binds another name to an object; it does not copy it. A shallow copy duplicates the outer container but shares nested objects.
- Choose ownership deliberately for request state so one request cannot mutate another request's data. [Python programming FAQ](https://docs.python.org/3/faq/programming.html)

**Follow-up / trap:** “Does `new = old.copy()` isolate a list of dictionaries?” The new list still refers to the same dictionaries.

### 47. Why use generators and context managers in data pipelines? — Depth

- Generators produce items lazily, which helps avoid materializing a full dataset. Downstream code can still defeat that benefit by accumulating every result.
- Context managers make resource acquisition and cleanup explicit, including exception paths; use async context managers for appropriate async resources. [Python generators](https://docs.python.org/3/tutorial/classes.html#generators), [Context manager semantics](https://docs.python.org/3/reference/compound_stmts.html#the-with-statement)
- Pair streaming reads with bounded processing and bounded output storage for an end-to-end memory bound.

**Follow-up / trap:** “A generator opened a file; can we abandon it safely?” Arrange explicit ownership and cleanup rather than relying on garbage collection timing.

### 48. How do tokens, temperature and prompting affect an application? — Depth

- Tokenization divides text into model-specific units; token counts affect context limits, cost and generation length. Tokens are not the same as words. [Tokenization algorithms](https://huggingface.co/docs/transformers/en/tokenizer_summary)
- Temperature changes how concentrated the sampling distribution is; lower values do not guarantee factual answers or identical runs. [Generation configuration](https://huggingface.co/docs/transformers/en/main_classes/text_generation)
- Give a clear task, relevant evidence, a response contract and useful examples; evaluate prompt changes against the same cases rather than trusting a nicer-looking answer.

**Follow-up / trap:** “Can temperature zero fix hallucinations?” It can make a wrong preferred continuation more consistent; evidence and validation still matter.

### 49. When would you choose prompting, RAG or fine-tuning? — Depth

- Prompting is a cheap starting point for task instructions. RAG supplies changing or private information. Fine-tuning can improve a repeatable behavior or domain task using curated examples.
- LoRA freezes the base weights and trains low-rank updates, reducing the number of trainable parameters compared with full fine-tuning.
- These approaches can be combined; select them from observed failures and held-out improvements, not from a desire to train a model. [LoRA paper](https://arxiv.org/abs/2106.09685)

**Follow-up / trap:** “Should we fine-tune every time a policy changes?” Retrieval is often a better freshness mechanism; learned weights are awkward to audit and update per fact.

### 50. How would you implement a small ranked-retrieval utility? — Depth

- State the contract first: input IDs and scores, deduplication, tie-breaking, cutoff and invalid-input behavior.
- Use a dictionary or set for identity-based membership. Choose sorting for simplicity or a size-k heap when streaming a large input makes that worthwhile.
- Explain complexity and test ties, duplicates, empty inputs and k boundaries. A correct small implementation is more useful than unnecessary framework scaffolding. [Python data structures](https://docs.python.org/3/tutorial/datastructures.html)

**Follow-up / trap:** “Does keeping the first duplicate preserve the highest score?” Only if the input contract guarantees that order; otherwise update the stored best score.

## Four timeboxed coding exercises

Use fake providers and local fixtures. These are practice specifications, not a request to add production dependencies or call live APIs.

### Exercise A — FastAPI answer endpoint, 25 minutes

Build `POST /answer` with a question, bounded `top_k` and a typed response containing answer text, citation IDs and status. Use a fake async retriever and generator. Related questions: 24, 29, 30.

**Acceptance criteria:** whitespace-only questions and out-of-range `top_k` fail validation; citation IDs must come from retrieved evidence; empty evidence returns an explicit insufficient-evidence result; upstream failure returns a documented error; one total deadline covers the operation. Demonstrate success, validation failure, empty retrieval and timeout with local tests. Do not derive tenant authorization from an unverified body field.

### Exercise B — Review-processing worker pool, 25 minutes

Process an iterator of 10,000 synthetic reviews through eight workers and a queue of at most 32 waiting items. Persist each result through an injected async sink. Related questions: 25–28, 47.

**Acceptance criteria:** measured active calls never exceed eight; producer queue never exceeds 32; do not create one task per review; every admitted review produces a success or explicit per-item error under the chosen policy; cancellation shuts down producer and workers; do not retain all outputs in memory. Use a deterministic fake that can fail or pause selected items.

### Exercise C — Retrieval metrics and fusion, 20 minutes

Implement precision@k, recall@k, reciprocal rank@k and reciprocal rank fusion for two lists of document IDs. Related questions: 5, 18, 19, 50.

**Acceptance criteria:** documented duplicate and tie policies; invalid k rejected; queries with no gold relevant IDs handled explicitly; with relevant IDs `{A, B, C}` and results `[X, A, Y, B, Z]`, precision@5 = 0.4, recall@5 = 2/3 and reciprocal rank@5 = 0.5. RRF must use ranks, deduplicate the final IDs and produce deterministic ties. Explain why none of these three metrics alone measures answer faithfulness.

### Exercise D — Agent approval and replay, 20 minutes

Implement or sketch a tiny state machine: propose an action → await approval → execute fake tool → finish. Add rejection and tool-failure paths. LangGraph is optional; plain Python is sufficient. Related questions: 14–17, 43.

**Acceptance criteria:** no write before approval; the approved arguments are the ones executed; rejection reaches a terminal state; approval for modified arguments is invalidated; repeating the same operation ID does not duplicate the fake effect; an injected crash after the effect can recover through deduplication; step and time budgets are explicit. Explain what must move to durable storage for this guarantee to survive process loss.

## A 90-minute mock interview

This is a suggested rehearsal structure, not a prediction of the interviewer's agenda.

| Time | Practice | Success evidence |
| --- | --- | --- |
| 0–8 min | Introduce one real project, then explain your contribution. | Clear ownership, constraints and an honest measured outcome. |
| 8–28 min | Design RAG for a book containing tables and updated policies. | Draw ingestion and query paths; explain chunking, permissions, citations and evaluation. |
| 28–43 min | Debug a wrong answer, then add one tool and approval. | Locate the failing stage; explain state, stopping and replay behavior. |
| 43–68 min | Run Exercise A or B from an empty file. | A working core flow, meaningful edge checks and a clear explanation of limitations. |
| 68–80 min | Compare metrics, deployment choices and latency tradeoffs. | Correct definitions with examples; decisions tied to workload and evidence. |
| 80–87 min | Three Depth follow-ups chosen from your weakest scores. | You can change the design when the assumptions change. |
| 87–90 min | Ask about the team's use cases, evaluation and production ownership. | Questions that connect the role to work you can perform. |

If time is limited, prioritize questions **1–10, 13–16, 18–20, 24–30 and 34**, complete one coding exercise, and rehearse your production story twice. Use diagrams as recall prompts: redraw the flow without looking, narrate a failure at each stage, then check what you missed.
