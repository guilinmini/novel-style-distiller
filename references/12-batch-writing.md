# Sequential batch writing and recovery

Use this reference when the user asks to write multiple chapters in one request, resume an interrupted batch, inspect batch progress, or deliver chapters in groups.

## Product contract

Batch writing is a first-class workflow for Chinese serialized web fiction. It does not mean drafting many dependent chapters from one stale context. It means repeatedly running the complete chapter state machine without requiring a new user message between chapters:

```text
authorize bounded batch
→ schedule batch functions and rolling detailed horizon
→ PREPARE one chapter from latest canon
→ PLAN → DRAFT → REVIEW
→ commit that chapter and every state delta
→ durable batch checkpoint
→ rebuild context for the next chapter
```

Never parallelize dependent chapter prose. Planning analyses may be independent, but chapter N+1 cannot start until chapter N's accepted files and checkpoints agree.

## Authorization modes

| Mode | Meaning | Pause behavior |
|---|---|---|
| `AUTO_COMMIT` | The explicit bounded batch request authorizes each chapter to become canon after its own gates pass | Continue until completion or a hard stop |
| `REVIEW_CHECKPOINTS` | The user authorizes work in groups | Pause after the configured number of committed chapters |

If the user says only “批量写接下来 N 章”, use `AUTO_COMMIT`. If the user says “每 5 章给我看”, use `REVIEW_CHECKPOINTS` with interval 5. A batch request never authorizes changing the approved ending, central arc, or explicit project constraints.

## Create the job

Resolve the active project and run:

```sh
sh scripts/novelctl.sh batch-create "novel-projects/<project>" <count> <checkpoint-interval> auto
```

Use `review` instead of `auto` for review checkpoints. One job accepts 1–200 chapters; split larger runs at an arc or volume boundary so compaction and re-outline checks happen naturally.

The command creates:

```text
state/
├── ACTIVE_BATCH.md
├── BATCH_INDEX.md
└── batches/<batch-id>/
    ├── BATCH_JOB.md
    └── BATCH_PLAN.md
```

Fill every placeholder in `BATCH_PLAN.md`. Plan the entire batch at function level: arc movement, pressure/reward sequence, emotion wave, hook obligations, and thread schedule. Detail only the next 3–8 chapters; extend that horizon after each checkpoint.

Start or resume with:

```sh
sh scripts/novelctl.sh batch-resume "novel-projects/<project>" <batch-id>
```

The command rejects an unresolved plan and reports the single authoritative `RESUME_FROM` chapter.

## Per-chapter batch loop

For the reported chapter:

1. Read the latest style contract, memory index, current state, reward ledger, serial rhythm, batch plan, previous chapter record/changes, and relevant extended memory.
2. Rebuild the temporary context pack.
3. Create or update the chapter blueprint. State the chapter's present reward, emotion movement, hook family, promised payoff, and observable canon change.
4. Draft with the locked style contract.
5. Run task, continuity, POV/knowledge, style, serial-reward, natural-prose, repetition, and source-isolation gates.
6. Allow one focused rewrite for a failed prose/shape gate. A canon contradiction or pack mismatch is not repaired by improvisation.
7. Save the accepted chapter at `chapters/<chapter-id>.md`.
8. Write both:
   - `state/chapter-records/<chapter-id>.md`;
   - `state/chapter-records/<chapter-id>.changes.json` conforming to `schemas/chapter-changes.schema.json`.
9. Apply the changes in causal order to every durable ledger, including reward and serial-rhythm state.
10. Refresh `CURRENT_STATE.md`, `MEMORY_INDEX.md`, the outline, and `NOVEL_PROJECT.md` so all three say they are accepted through this chapter.
11. Checkpoint the job:

   ```sh
   sh scripts/novelctl.sh batch-checkpoint \
     "novel-projects/<project>" <batch-id> <committed-chapter-id> <next-chapter-id-or-none>
   ```

The final batch chapter uses `none`; the project's own `Next planned chapter` still points to the first chapter beyond the batch.

`batch-checkpoint` refuses to advance unless the accepted chapter, chapter record, structured changes, and three core checkpoint files exist and agree. It is safe to repeat the exact same checkpoint after an uncertain tool response.

## Fifteen-field snapshot and twelve change types

Every accepted `.changes.json` stores a post-chapter snapshot of:

1. story time;
2. locations;
3. POV state;
4. characters;
5. relationships;
6. character knowledge;
7. reader knowledge;
8. objects;
9. resources;
10. conditions/injuries/obligations;
11. world rules;
12. factions/authority;
13. plot threads;
14. deadlines;
15. immediate next pressure.

Its change entries use only the applicable types from: `plot`, `character`, `relationship`, `knowledge`, `location`, `object`, `resource`, `condition`, `timeline`, `thread`, `world-rule`, and `reader-promise`. Do not create empty fake changes merely to use all twelve types.

The snapshot is a compact active checkpoint keyed by stable IDs, not a duplicate of the whole Bible or every historical entity. Durable ledgers and chapter records remain the full history; the snapshot makes resume validation and recent-state comparison deterministic.

## Checkpoint review

At the configured interval:

- compare hook families and unpaid promises;
- compare reward families and intensity;
- inspect suppression/payoff debt;
- inspect reader-emotion activation and recovery;
- compare openings, endings, paragraph cadence, metaphor domains, and dialogue voices;
- check style-contract drift and source isolation;
- refresh the detailed planning horizon;
- create an arc/volume summary when crossing a boundary.

Replan only uncommitted chapters. Accepted chapters require the revision-impact workflow.

## Pause and resume

Pause deliberately when work cannot continue safely:

```sh
sh scripts/novelctl.sh batch-pause "novel-projects/<project>" <batch-id> "<reason>"
```

Hard stops include:

- missing or mismatched style contract;
- unresolved canon contradiction;
- failure of a hard quality gate after one focused rewrite;
- required structural change outside batch authorization;
- incomplete or conflicting state writeback;
- unavailable host capacity that prevents the next complete chapter transaction.

After interruption, run `batch-status`, repair the recorded issue, then `batch-resume`. Never infer completed chapters from the conversation or from prose files alone.

## Delivery

`AUTO_COMMIT` may write chapter files throughout the run and return a combined delivery or checkpoint summaries according to `BATCH_PLAN.md`. On completion report:

- chapter range and files;
- accepted/committed count;
- major reward and plot movement;
- open hooks and next pressure;
- any automatic replan inside the authorized scope;
- batch job status.

Batch completion commits story canon only. Do not run Git commit or push unless the user separately requests version-control operations.
