#!/usr/bin/env node
/**
 * Reads ../study-book/content.js and writes Resources/practice/bank.json
 * for InterviewMaster Practice (spoken questions + hints + rubric).
 */
import fs from "fs";
import path from "path";
import vm from "vm";
import { execFileSync } from "child_process";
import { fileURLToPath } from "url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "..");
const bookPath = path.resolve(repo, "../study-book/content.js");
const outPath = path.join(repo, "Resources/practice/bank.json");

function slug(text) {
  return String(text)
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function strip(html) {
  return String(html || "")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/\s+/g, " ")
    .trim();
}

const src = fs.readFileSync(bookPath, "utf8");
const ctx = { window: {} };
vm.createContext(ctx);
vm.runInContext(src, ctx);
const book = ctx.window.BOOK;
if (!book?.chapters) {
  throw new Error(`No BOOK.chapters in ${bookPath}`);
}

const groupByChapter = {};
const groups = book.groups.map((group) => {
  const id = slug(group.name);
  for (const chapterId of group.chapters || []) {
    groupByChapter[chapterId] = { id, title: group.name };
  }
  return { id, title: group.name };
});

const questions = [];
for (const [chapterId, chapter] of Object.entries(book.chapters)) {
  const group = groupByChapter[chapterId] || {
    id: slug(chapter.group || "other"),
    title: chapter.group || "Other"
  };
  let quizIndex = 0;
  let drillIndex = 0;
  for (const block of chapter.blocks || []) {
    if (block.type === "quiz" && block.q) {
      const correct = strip((block.opts || []).find((opt) => opt.correct)?.label);
      const explain = strip(block.explain);
      const answer = [correct, explain].filter(Boolean).join("\n\n");
      questions.push({
        id: `${chapterId}-quiz-${quizIndex}`,
        packId: "study-book",
        groupId: group.id,
        topicId: chapterId,
        topicTitle: chapter.title,
        text: strip(block.q),
        hints: [correct, explain].filter(Boolean),
        rubric: explain,
        answer
      });
      quizIndex += 1;
    }
    if (chapterId === "drills" && block.type === "cards") {
      for (const item of block.items || []) {
        const title = strip(item.title);
        const body = strip(item.body);
        const more = strip(item.more);
        questions.push({
          id: `${chapterId}-drill-${drillIndex}`,
          packId: "study-book",
          groupId: group.id,
          topicId: chapterId,
          topicTitle: chapter.title,
          text: `${title}. ${body}`.trim(),
          hints: more ? more.split(" → ").map((part) => part.trim()).filter(Boolean).slice(0, 5) : [],
          rubric: more,
          answer: more
        });
        drillIndex += 1;
      }
    }
  }
}

const extraPacks = [
  {
    id: "aws",
    title: "AWS",
    blurb: "IAM, networking, storage, and compute trade-offs",
    groups: [{ id: "aws", title: "AWS" }],
    questions: [
      ["aws-iam", "What is the difference between an IAM user and an IAM role?", "An IAM user is a long-lived identity with its own keys. An IAM role is assumed temporarily via STS and has no permanent password or access keys — prefer roles for apps, EC2, and cross-account access."],
      ["aws-s3", "When would you choose S3 Intelligent-Tiering over S3 Standard?", "Use Intelligent-Tiering when access patterns are unknown or change over time. It moves objects between frequent and infrequent tiers automatically; Standard is cheaper only if you know the data stays hot."],
      ["aws-sqs-sns", "How does SQS differ from SNS, and when would you use both?", "SQS is a pull queue (competing consumers, buffering). SNS is push pub/sub (fan-out). Use SNS → SQS when one event must fan out to several independent workers that can retry at their own pace."],
      ["aws-vpc", "How does VPC peering differ from Transit Gateway?", "Peering is a 1:1 non-transitive link. Transit Gateway is a hub that routes between many VPCs and on-prem without a full mesh of peerings."],
      ["aws-lambda-ecs", "When would you run a workload on Lambda instead of ECS?", "Lambda for short, spiky, event-driven work with no always-on cost. ECS when you need long-running processes, custom runtimes, or predictable concurrency without Lambda timeouts and cold starts."],
      ["aws-dynamo", "Explain eventual consistency in DynamoDB and when it is acceptable.", "A replica may lag after a write, so a read might miss the latest value unless you request strongly consistent reads. Eventual consistency is fine for caches, feeds, and high-read paths that can tolerate a brief stale view."],
      ["aws-multi-az", "How would you design a multi-AZ architecture for a public API on AWS?", "Put ALB across AZs, run compute in at least two AZs, use Multi-AZ data stores (RDS/Aurora, DynamoDB global tables as needed), and fail over without a single-AZ dependency."]
    ]
  },
  {
    id: "models",
    title: "Models",
    blurb: "Transformers, sampling, RAG, and serving trade-offs",
    groups: [{ id: "models", title: "Models" }],
    questions: [
      ["models-encoder-decoder", "What is the difference between a transformer encoder and a decoder?", "Encoders see the whole sequence (bidirectional). Decoders are causal: each token can only attend left, which is what generation needs. Encoder-decoder models (T5) encode the input then decode the output."],
      ["models-sampling", "Explain temperature versus top-p when sampling from an LLM.", "Temperature scales logits before softmax: low → peaked/deterministic, high → more random. Top-p samples from the smallest set of tokens whose cumulative probability ≥ p. Use both: temperature for overall randomness, top-p to cut the long tail."],
      ["models-rag", "What is RAG, and when would you use it instead of fine-tuning?", "RAG retrieves documents at query time and conditions the LLM on those chunks. Prefer RAG when knowledge changes, must be cited, or is private. Fine-tune for style, format, or a skill that prompting cannot lock in."],
      ["models-embeddings", "How do embeddings enable semantic search?", "Text is mapped to a vector so similar meaning is nearby in space. At query time you embed the question and nearest-neighbor search the index — that is semantic search, not keyword match."],
      ["models-context", "What is a context window, and what breaks when you exceed it?", "The context window is the token budget for prompt + history + retrieved text + output. Exceed it and the model truncates or errors — usually dropping the oldest or middle context, so answers lose facts."],
      ["models-quant", "What is weight quantization, and what do you trade away for speed?", "Weights stored in fewer bits (INT8/INT4) shrink memory and speed up inference. You trade a small accuracy drop and possible instability on edge cases; measure with your eval set before shipping."],
      ["models-eval", "How would you evaluate whether a smaller model is good enough for a production assistant?", "Hold a golden set of real tasks, score correctness/faithfulness/latency/cost against the current model, and only switch if quality is within the bar and p95 latency/cost improve."]
    ]
  },
  {
    id: "angular",
    title: "Angular",
    blurb: "Components, change detection, forms, and routing",
    groups: [{ id: "angular", title: "Angular" }],
    questions: [
      ["angular-component-directive", "What is the difference between an Angular component and a directive?", "A component is a directive with a template. Directives attach behavior to existing elements; components render their own view."],
      ["angular-change-detection", "How does Angular change detection work, and what does OnPush change?", "Default CD walks the tree on every event. OnPush only checks when inputs change by reference, an event fires in the component, or you mark it dirty — fewer checks, you must keep inputs immutable."],
      ["angular-signals", "What are Angular signals, and why were they added?", "Signals are fine-grained reactive values. They let Angular update only what depends on the changed signal instead of scanning the whole component tree."],
      ["angular-state", "When would you share state with a service versus NgRx?", "A service (or signals in a service) is enough for local/feature state. NgRx when many features need a single event log, time-travel, or strict unidirectional flow."],
      ["angular-forms", "What is the difference between template-driven and reactive forms?", "Template-driven: ngModel in the template, implicit FormControl. Reactive: FormGroup/FormControl in code, better for validation, tests, and dynamic fields."],
      ["angular-router", "How does the Angular router lazy-load a feature module?", "Use loadChildren (or loadComponent) on a route so the feature chunk is fetched only when that URL is visited, not in the main bundle."],
      ["angular-pipes", "When should a pipe be pure, and what goes wrong if it is not?", "Pure pipes run only when the input reference changes — the default and cheaper. Impure pipes run every CD cycle; easy to tank performance if they do real work."]
    ]
  }
].map((pack) => ({
  ...pack,
  questions: pack.questions.map(([id, text, answer]) => ({
    id,
    packId: pack.id,
    groupId: pack.id,
    topicId: pack.id,
    topicTitle: pack.title,
    text,
    hints: [],
    rubric: answer,
    answer
  }))
}));

const studyPack = {
  id: "study-book",
  title: "ML & AI Engineer",
  blurb: "Questions and whiteboard drills from the study book, grouped by topic",
  groups,
  questions
};

const positions = [
  {
    id: "study-book-all",
    title: "ML & AI Engineer — all topics",
    packId: "study-book",
    groupIds: []
  },
  {
    id: "senior-ai-python",
    title: "Senior AI Python",
    packId: "study-book",
    groupIds: [
      "python-engineering",
      "genai-and-llm",
      "ml-in-production",
      "engineering-practice",
      "interview-prep",
      "system-design"
    ]
  },
  ...groups.map((group) => ({
    id: `study-book-${group.id}`,
    title: group.title,
    packId: "study-book",
    groupIds: [group.id]
  })),
  ...extraPacks.map((pack) => ({
    id: pack.id,
    title: pack.title,
    packId: pack.id,
    groupIds: []
  }))
];

const bank = { packs: [studyPack, ...extraPacks], positions };
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(bank, null, 2) + "\n");
execFileSync("python3", [path.join(here, "polish-practice-language.py")], {
  cwd: repo,
  stdio: "inherit"
});

const byGroup = {};
for (const q of questions) {
  byGroup[q.groupId] = (byGroup[q.groupId] || 0) + 1;
}
console.log(`Wrote ${outPath}`);
console.log(`study-book questions: ${questions.length}`);
console.log(Object.entries(byGroup).map(([id, n]) => `${id}: ${n}`).join("\n"));
console.log(`positions: ${positions.length}`);
