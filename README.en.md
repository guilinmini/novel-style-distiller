# Novel Style Distiller

An agent-native long-form fiction workbench that can be cloned and used directly. It distills a complete user-provided novel into a source-isolated style contract, creates an original long-form project from a theme, and makes every later chapter load the same locked style plus current layered memory.

It is not an author-imitation prompt, and the user does not manually maintain dozens of files. The repository ships the distillation workflow, long-form craft library, memory system, project templates, chapter state machine, and configuration checks.

## Fastest workflow

### 1. Clone and open

```bash
git clone https://github.com/guilinmini/novel-style-distiller.git
cd novel-style-distiller
```

Open the directory in an Agent-capable environment that reads project `AGENTS.md` and local files. The repository does not need to be copied to a Skills directory.

### 2. Give the source path in chat

```text
Distill this novel: /path/to/novel.txt
```

The Agent registers the path and hash without copying the book, models the whole novel, validates extracted mechanisms, builds the private audit, and compiles a source-neutral `runtime-style-pack`.

TXT/Markdown can be processed directly. PDF/EPUB requires extraction support in the active Agent environment; extracted text remains a local ignored artifact.

### 3. State the original theme

```text
I want to write a novel about a city that forgets one street every day and a map restorer searching for her missing sister.
```

With one eligible style pack, the Agent selects it automatically and creates:

- an original premise, characters, world rules, ending direction, and long-range outline;
- a locked style-pack snapshot;
- a Story Bible, chapter plans, and layered durable memory;
- a project-local long-form craft library;
- `.agents/skills/<project>-writer/SKILL.md`;
- active-project routing and a configuration health check.

### 4. Write through normal conversation

```text
Write chapter one.
Accept it and continue with the next chapter.
Rewrite chapter two so the conflict begins earlier without changing its ending fact.
Review the last five chapters for style drift and overdue promises.
```

The project writer always loads its locked `WRITING_STYLE_CONTRACT.md`; the user does not repeatedly name the source or style.

## Layered long-form memory

Durable state is separated into stable Bible facts, future plans, compact current state, character/entity state, relationships, knowledge, timeline, continuity constraints, plot threads, accepted chapter deltas, arc/volume summaries, decisions, and revision impacts.

Before drafting, the writer builds a temporary chapter context pack containing only relevant memory and craft modules. It does not stuff the entire manuscript, every entity, or all previous chapters into context.

## Built-in craft

[`knowledge/INDEX.md`](knowledge/INDEX.md) routes to practical modules for story architecture, characters and relationships, worldbuilding and exposition, scene/chapter design, pacing and tension, POV and information, dialogue and subtext, foreshadowing and payoff, genre/serialization promises, continuity and revision, and distilled-style integration.

General craft never outranks the user's request, accepted canon, POV, current chapter contract, or locked distilled style.

## Chapter lifecycle

```text
PREPARE → PLAN → DRAFT → REVIEW → DELIVER → ACCEPT / COMMIT
```

The draft does not change canon. After acceptance, the writer updates chapter records, timeline, characters/entities, knowledge, relationships, threads, continuity, current state, and the memory index. `COMMIT` here means committing story canon, not running Git commit.

## Repository layout

```text
novel-style-distiller/
├── AGENTS.md
├── SKILL.md
├── scripts/novelctl.sh
├── knowledge/
├── references/
├── extractors/
├── templates/
├── tests/
├── distillations/          # generated and ignored
├── novel-projects/         # generated and ignored
└── .novel/                 # active pointers, generated and ignored
```

## Optional maintenance commands

The Agent normally runs these for the user:

```bash
sh scripts/novelctl.sh register-source "/path/to/novel.txt"
sh scripts/novelctl.sh activate-pack "distillations/my-source/runtime-style-pack"
sh scripts/novelctl.sh scaffold-project "my-project" "distillations/my-source/runtime-style-pack"
sh scripts/novelctl.sh activate-project "novel-projects/my-project"
sh scripts/novelctl.sh status
sh scripts/novelctl.sh doctor
sh tests/smoke.sh
```

`novelctl.sh` uses POSIX Shell and has no Python, database, RAG, graph-store, or third-party package dependency. An Agent without Shell can instantiate the same templates directly.

## Optional standalone Skill installation

```bash
git clone https://github.com/guilinmini/novel-style-distiller ~/.agents/skills/novel-style-distiller
```

The `$novel-style-distiller` Skill remains usable in this mode, while root `AGENTS.md` routing and active workspace pointers belong to the complete-repository workflow.

## Boundaries

- Novels only, using text actually supplied by the user.
- One novel supports conclusions about that work, edition, and translation—not an author's full body of work.
- Do not continue the source or reuse its characters, world, proper nouns, distinctive expression, or plot skeleton.
- Source books, OCR files, audit evidence, and generated projects are ignored local artifacts.
- Original chapter writing never reopens the source novel or audit.
- Excerpts may produce experimental output only, not a validated whole-novel style pack.

See [CONTRIBUTING.md](CONTRIBUTING.md). Licensed under GNU AGPL v3.0; see [LICENSE](LICENSE) and [NOTICE](NOTICE).
