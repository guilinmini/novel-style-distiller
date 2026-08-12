# Novel Style Distiller

Distill a complete novel into evidence-backed, reusable, and testable AI writing skills covering plot architecture, character arcs, narrative craft, prose patterns, tone, dialogue, and narrative voice.

This is not a summarizer or an author-roleplay prompt. It turns observable mechanisms in a source novel into tools for writing **original fiction**.

## Outputs

- A whole-novel model: conflict, causal plot chain, setups/payoffs, narrative order, and character arcs.
- A prose profile: diction, syntax, rhythm, paragraphs, imagery, sensory emphasis, and description patterns.
- A voice profile: narrator stance, distance, emotional temperature, reliability, humor/irony, and dialogue texture.
- Installable atomic skills such as delayed causal reveal, action-borne emotion, or close-limited narrative distance.
- Evidence and evaluations: source locators, counterexamples, holdout checks, routing tests, and overlap checks.

See [SKILL.md](./SKILL.md) for the complete workflow.

## Install

Clone it into the user-level Agent Skills directory:

```bash
git clone https://github.com/guilinmini/novel-style-distiller ~/.agents/skills/novel-style-distiller
```

Full pack validation requires Python 3.11+ and `jsonschema`. Install it in the Python environment used by your agent:

```bash
python3 -m pip install -r ~/.agents/skills/novel-style-distiller/requirements.txt
```

For project-level installation, use `<project>/.agents/skills/novel-style-distiller/`. Preserve the full repository; do not copy `SKILL.md` alone.

Invoke it with a request such as:

```text
Use $novel-style-distiller to distill /path/to/novel.txt into fiction-writing skills.
```

For another agent host, place the full repository in a directory where the host discovers `SKILL.md`. If automatic skill discovery is unavailable, provide `SKILL.md` to the agent as its operating procedure and preserve the repository's relative paths.

## Requirements and boundaries

- Provide a complete novel plus title, author, edition, original language, and translator information. TXT/Markdown can be used directly; EPUB/PDF must first be completely extracted and checked as normalized TXT/Markdown.
- Use a source file you are allowed to analyze locally.
- Do not commit or redistribute the source novel.
- A single novel supports claims about that work and edition, not the author's entire body of work.
- A translation's sentence-level style cannot be attributed directly to the original author.
- Generated skills must support original fiction; they must not continue the source novel or reuse its characters, world, distinctive language, or plot skeleton.

## Repository layout

```text
novel-style-distiller/
├── SKILL.md
├── agents/openai.yaml
├── references/
├── extractors/
├── templates/
├── schemas/
├── scripts/
└── examples/
```

See [CONTRIBUTING.md](./CONTRIBUTING.md) before contributing. Only commit synthetic or lawfully redistributable fixtures.

## License

GNU Affero General Public License v3.0. See [LICENSE](./LICENSE). This project is a substantial rewrite of `cangjie-skill`; see [NOTICE](./NOTICE).
