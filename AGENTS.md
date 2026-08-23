# Novel Style Distiller Workbench

This repository is an interactive Chinese serial web-fiction workbench. Users should be able to clone it, open it in an Agent-capable coding environment, distill a source novel's transferable style, and write a long-running original 网文爽文 through natural-language requests without installing the root Skill elsewhere.

## Conversation routing

Read [`SKILL.md`](SKILL.md) when the request concerns novel distillation, project creation, chapter planning, drafting, revision, or long-form memory.

- **A source-novel path is supplied**: validate the path, run `sh scripts/novelctl.sh register-source <path>`, then execute Mode A in `SKILL.md` through runtime-pack validation. Registration alone is not completion.
- **An original-fiction theme is supplied**: use the single active validated runtime pack. If several packs are eligible and none is active, ask the user to choose. Derive a slug, run `scaffold-project`, execute Mode B by replacing every scaffold placeholder with real project content, then activate it with `activate-project`.
- **A chapter, continuation, or revision is requested**: use the active project's generated writer Skill and Mode C. Load the locked style contract, reward/hook ledgers, and durable memory before drafting.
- **A batch such as “批量写接下来 20 章” is requested**: read `references/12-batch-writing.md`, create a durable batch job, and run chapters sequentially with per-chapter review, canon writeback, and checkpointing. Never generate dependent chapters in parallel.
- **Status or recovery is requested**: run `sh scripts/novelctl.sh status` or `doctor`, then resume from recorded files rather than chat memory.

When the user supplies both a source path and a theme, complete distillation first, initialize the original project second, and write only if the request also asks for prose.

## Zero-configuration behavior

Do not ask the user to create directories, copy templates, install Python, or invoke `$novel-style-distiller`. Create and fill all required files within this repository. Make conservative assumptions for missing project metadata and record them; ask only when a choice would materially change the user's story.

The definition of configured is:

1. the source is registered without copying it into the repository;
2. the private audit and source-isolated runtime pack are complete, validated, and recorded in `.novel/ACTIVE_PACK.md`;
3. the original project has a locked style snapshot, Story Bible, outline, layered memory, and project-specific writer Skill;
4. `.novel/ACTIVE_PROJECT.md` points to that project;
5. `sh scripts/novelctl.sh doctor` passes.

## Durable memory and craft

- Treat project files, not the conversation, as durable truth.
- Use [`knowledge/INDEX.md`](knowledge/INDEX.md) to load only the craft modules relevant to the current planning or writing problem.
- Treat web-fiction positioning, earned gratification, hook/payoff discipline, reader-emotion movement, and natural-prose diagnostics as core project behavior rather than optional decoration.
- Keep stable canon in the Bible, current working state in `state/CURRENT_STATE.md`, entity state in `state/characters/`, chronological facts in the timeline, promises in the thread ledger, and accepted deltas in chapter records.
- Never update canon from an unaccepted single-chapter draft. An explicit bounded batch request may authorize per-chapter `AUTO_COMMIT` after every chapter independently passes its gates and writes a structured changes record.
- Never load the source novel or `audit/` while writing the original project.

## Repository safety

User source books and generated workspaces are local, ignored artifacts. Do not add, commit, publish, or push them. Do not run Git commit or push unless the user explicitly asks for that version-control operation.
