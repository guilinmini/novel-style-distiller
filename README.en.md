# Novel Style Distiller

Distill a complete novel into a source-isolated, executable writing-style contract; create an original long-form novel from a theme; and make every later chapter, continuation, or revision load the same locked style contract and current story state.

This is neither a summarizer nor a “write like this author” prompt. It extracts observable, adjustable, testable mechanisms while separating source evidence from the runtime writing environment.

## What it does

### 1. Distill a complete novel

- Model plot causality, character arcs, timeline, setups/payoffs, information control, and scene pacing.
- Extract prose, voice, tone, dialogue, syntax, rhythm, imagery, and emotion-delivery mechanisms.
- Validate claims with cross-section evidence, counterexamples, and holdout text.
- Produce a private audit area and a source-neutral `runtime-style-pack`.

### 2. Start an original long-form project

- Create an original premise, world rules, characters, central arc, ending direction, and outline from the user's theme.
- Copy and lock a selected runtime style pack into the project.
- Create a Story Bible, current state, plot-thread ledger, timeline, and chapter records.
- Generate `.agents/skills/<project>-writer/SKILL.md`, a project-specific runtime writer.

### 3. Write continuously

Every chapter follows:

```text
load style and state → chapter blueprint → draft → continuity/style/originality review
→ deliver draft → user accepts → write back durable state
```

The contract is mandatory for every chapter, while action, dialogue, introspection, transition, and climax modes adjust its surface intensity to avoid mechanical sameness.

## Source/runtime isolation

```text
distillations/<source>/
├── audit/                 # source identity, evidence, profiles, rejected claims
└── runtime-style-pack/    # neutral writing contract copied into original projects

novel-projects/<project>/
├── style/                 # locked runtime-pack snapshot
├── bible/                 # stable setting and character truth
├── outline/               # master outline and chapter blueprints
├── state/                 # current state, threads, timeline, chapter records
├── chapters/              # manuscript
└── .agents/skills/<project>-writer/
```

Chapter writing reads only the original project, never the source novel or audit evidence. This reduces context noise and the risk of leaking source names, characters, plot, or distinctive expression.

## Install

User-level installation:

```bash
git clone https://github.com/guilinmini/novel-style-distiller ~/.agents/skills/novel-style-distiller
```

Project-level installation:

```text
<workspace>/.agents/skills/novel-style-distiller/
```

Other Agent Skills hosts can place the complete repository in their skill-discovery directory. Preserve the relative layout of `SKILL.md`, `references/`, `extractors/`, and `templates/`.

This is a Markdown-only skill. It requires no Python, database, RAG system, graph store, or third-party runtime.

## Use

### 1. Distill

Provide a complete novel you may analyze locally, preferably as UTF-8 TXT or Markdown. Extract and inspect PDF/EPUB sources first.

```text
Use $novel-style-distiller to distill /path/to/novel.txt into a runtime
style pack for original long-form fiction. Write it to distillations/my-source/.
```

The default output is `distillations/<source-slug>/`. Excerpts and short fixtures may produce experimental results only.

### 2. Create a project from a theme

```text
Use $novel-style-distiller with distillations/my-source/runtime-style-pack/
to create an original novel from this theme: “In a city that forgets one street
each day, a map restorer searches for her missing sister.”
Create novel-projects/lost-streets/.
```

The skill generates a project writer and locks the style-pack version. Later upstream changes do not silently alter the novel.

### 3. Write, continue, or revise

Inside the original project, ask naturally:

```text
Write chapter one.
```

Or invoke the generated skill explicitly:

```text
Use $lost-streets-writer to write chapter one.
```

Later requests can be:

```text
Next chapter.
Rewrite chapter two so the conflict starts earlier without changing its final fact.
Check the last three chapters for style drift.
```

A delivered chapter remains a draft. Saying “accept/finalize,” or asking for the next chapter without requesting revisions, commits the previous draft and updates current state, timeline, and plot threads.

## Repository layout

```text
novel-style-distiller/
├── SKILL.md
├── agents/openai.yaml
├── references/
├── extractors/
├── templates/
└── examples/
```

## Boundaries

- Novels only; not essays, nonfiction, screenplays, or methodology books.
- Use the supplied source text rather than model memory.
- One novel supports claims about that work and edition, not an author's entire body of work.
- Sentence-level traits in a translation must not be attributed directly to the original author.
- Do not continue the source novel or reuse its characters, world, proper nouns, distinctive expression, or plot skeleton.
- Source text, OCR files, and audit evidence never enter the project writer and should not be committed to Git.
- Style must be expressed as observable behavior rather than “write like this author.”

See [CONTRIBUTING.md](./CONTRIBUTING.md) before contributing. Commit only synthetic or clearly redistributable fixtures.

Licensed under GNU AGPL v3.0; see [LICENSE](./LICENSE). This project is a substantial rewrite of `cangjie-skill`; see [NOTICE](./NOTICE).
