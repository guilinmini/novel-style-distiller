# Novel Style Distiller

Distill a complete novel into evidence-backed, reusable, and testable AI writing skills covering plot architecture, character arcs, narrative craft, prose patterns, tone, dialogue, and narrative voice.

This is not a summarizer or an author-imitation prompt. It identifies observable mechanisms in a particular work and turns the transferable ones into tools for original fiction.

## Outputs

- A whole-novel model of conflict, causality, subplots, setups/payoffs, narrative order, and character arcs.
- A prose profile covering diction, syntax, rhythm, paragraphs, imagery, sensory emphasis, and description patterns.
- A voice profile covering narrator stance, distance, emotional temperature, reliability, irony, and dialogue texture.
- Atomic skills such as delayed causal reveal, action-borne emotion, or controlled limited-POV distance.
- Evidence and evaluation records with source locators, counterexamples, holdout checks, routing cases, and originality review.

See [SKILL.md](./SKILL.md) for the full workflow.

## Install

Clone the complete repository into the user-level Agent Skills directory:

```bash
git clone https://github.com/guilinmini/novel-style-distiller ~/.agents/skills/novel-style-distiller
```

For project-level installation, use:

```text
<project>/.agents/skills/novel-style-distiller/
```

Other agent hosts may place the repository in their own skill-discovery directory. If automatic discovery is unavailable, provide the root `SKILL.md` as operating instructions while preserving the relative directory structure.

The skill consists of Markdown instructions, extractors, and templates. It has no Python or third-party runtime dependency.

## Use

Provide a complete novel that you may analyze locally, preferably as UTF-8 TXT or Markdown. Extract and inspect PDF/EPUB sources before use.

```text
Use $novel-style-distiller to distill /path/to/novel.txt
into skills for writing original fiction.
```

The default output location is `distillations/<novel-slug>/`. The source novel must not be copied into generated skills or committed to Git.

## Boundaries

- Novels only; not essays, nonfiction, screenplays, or methodology books.
- Use the supplied text rather than model memory.
- One novel supports claims about that work and edition, not the author's entire body of work.
- Sentence-level traits in a translation must not be attributed directly to the original author.
- Generated skills support original fiction and must not continue the source novel or reuse its characters, world, distinctive language, or plot skeleton.
- Style must be expressed as observable, adjustable, testable features rather than “write like this author.”

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

See [CONTRIBUTING.md](./CONTRIBUTING.md) before contributing. Commit only synthetic or clearly redistributable fixtures.

Licensed under GNU AGPL v3.0; see [LICENSE](./LICENSE). This project is a substantial rewrite of `cangjie-skill`; see [NOTICE](./NOTICE).
