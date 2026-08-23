# Layered long-form memory system

Use this reference when initializing an original project, preparing chapter context, accepting a chapter, compacting old material, switching arcs/volumes, or revising accepted canon.

## Why memory is layered

Long novels cannot safely rely on a single growing summary or the conversation window. Store information by stability and access pattern:

| Layer | Purpose | Files |
|---|---|---|
| stable truth | world rules, identities, baseline facts | `bible/STORY_BIBLE.md` |
| plan | ending direction, arcs, future chapter functions | `outline/` |
| working state | next-chapter situation and active pressure | `state/CURRENT_STATE.md` |
| entity state | current character, object, location, faction state | `state/characters/`, `state/entities/` |
| relational/information state | trust, leverage, secrets, knowledge | relationship and knowledge ledgers |
| chronological state | accepted events and constraints | timeline and continuity ledger |
| promise state | open questions, setups and payoffs | plot-thread ledger |
| episodic memory | accepted per-chapter changes | `state/chapter-records/` |
| compressed history | act/volume causal summaries | `state/summaries/` |
| decision memory | user decisions and material assumptions | decision log |
| temporary context | selected inputs for one chapter | `state/context/` |

## Required project memory layout

```text
state/
├── MEMORY_INDEX.md
├── CURRENT_STATE.md
├── RELATIONSHIP_LEDGER.md
├── KNOWLEDGE_LEDGER.md
├── PLOT_THREADS.md
├── TIMELINE.md
├── CONTINUITY_LEDGER.md
├── DECISION_LOG.md
├── characters/<character-id>.md
├── entities/<entity-id>.md
├── chapter-records/<chapter-id>.md
├── summaries/<scope-id>.md
├── context/<chapter-id>.md
└── revisions/<revision-id>.md
```

Use stable lowercase IDs. Renaming a display name must not create a new entity ID.

## Memory index

`MEMORY_INDEX.md` routes questions to files and records freshness. Read it before selecting extended context. It should not become another full summary.

Update it when:

- a new entity file is created;
- an arc or volume summary replaces older detail in routine context;
- a continuity review changes authority or freshness;
- the active chapter or scope changes.

## Preparing a chapter context pack

Build `state/context/<chapter-id>.md` from the template before the blueprint is finalized. It is temporary and never establishes canon.

Always include:

- locked style contract/version;
- current chapter goal and hard constraints;
- `MEMORY_INDEX.md` and `CURRENT_STATE.md`;
- previous accepted chapter record and necessary tail reference;
- POV character state and knowledge;
- due/high-priority threads;
- relevant timeline and continuity constraints.

Conditionally include:

- other character/entity files present in the scene;
- relationship entries that the scene can change;
- older arc summary when a distant consequence returns;
- only the relevant craft modules from the project's `craft/INDEX.md` snapshot.

Do not include complete old chapters, the full audit, all entity files, or every craft module.

## Accepted chapter writeback

After acceptance, update in causal order:

1. accepted chapter and chapter record;
2. timeline events;
3. character and entity state;
4. knowledge and relationship changes;
5. plot threads and reader promises;
6. continuity constraints/conflicts;
7. compact `CURRENT_STATE.md`;
8. outline status and project progress;
9. `MEMORY_INDEX.md` freshness and routes.

All changed facts should be traceable to a chapter/event ID. Rebuild the next context pack after writeback; never patch an old pack and assume it is current.

## Compaction

Compaction reduces routine context without deleting history.

At an act/volume boundary or when working files become unwieldy:

1. create a causal summary from accepted chapter records;
2. preserve choices, costs, knowledge changes, relationship changes, open threads, and durable constraints;
3. move resolved transient details out of `CURRENT_STATE.md`;
4. keep original chapter records and timeline events;
5. register the summary in `MEMORY_INDEX.md`;
6. test retrieval by preparing a chapter that depends on an early consequence.

A summary that only recounts events is insufficient; it must preserve why later options changed.

## Knowledge discipline

For each important fact, maintain:

```text
author truth
≠ character knowledge/belief
≠ reader knowledge/hypothesis
```

Log acquisition paths. When a character infers a fact, distinguish the inference from confirmation. When an accepted revision changes a reveal, propagate its knowledge consequences.

## Revision memory

Use `REVISION_IMPACT.md.template` before changing accepted canon. Classify the revision, list downstream dependencies, obtain user confirmation for canon/structural changes, and apply in chronological order.

Prose-only revisions do not alter state. Canon revisions update every affected ledger and keep supersession history. Never make the current state correct by erasing evidence of the old version.

## Memory quality gates

- No active character acts on unacquired knowledge.
- Current locations, injuries, objects, resources, and deadlines agree across files.
- Accepted prose and chapter records agree on every critical change.
- Open promises have last-touched and due windows.
- Current state contains only next-chapter-relevant information.
- Old causal dependencies remain retrievable through summaries and records.
- Temporary context packs are labeled non-canon and rebuilt when inputs change.
