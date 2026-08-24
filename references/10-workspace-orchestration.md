# Zero-configuration workspace orchestration

Use this reference when the repository itself is the working environment: first clone, source-path registration, choosing an active style pack, creating an original project, switching projects, status, or recovery.

## User experience contract

The user should be able to:

1. clone and open this repository;
2. say “蒸馏 `/path/to/book.txt`”;
3. wait for a validated runtime style pack;
4. state an original novel theme;
5. start planning or writing through normal conversation.
6. say “批量写接下来 20 章” and resume safely after an interrupted host session.

Do not require the user to install the root Skill, create directories, copy templates, or manage state files.

## First source-path request

When a source path is supplied:

1. Confirm the path is a readable file and is a novel candidate.
2. Run:

   ```sh
   sh scripts/novelctl.sh register-source "/path/to/novel"
   ```

3. Read `.novel/ACTIVE_SOURCE.md` and the generated `audit/SOURCE_REQUEST.md`.
4. Fill `SOURCE_MANIFEST.json`, `PIPELINE_STATE.json`, and `CHUNK_MANIFEST.json`; the registration script deliberately does not invent bibliographic metadata.
5. Execute Mode A completely, including source isolation, evaluation, `STYLE_FINGERPRINT.json`, and the three-file runtime interface: writing contract, reader-experience contract, and quantitative targets.
6. Update pipeline state to `complete` only after the runtime pack passes its required gates.
7. Run `sh scripts/novelctl.sh activate-pack <runtime-style-pack-path>`.
8. Report the active pack ID/version and invite the user's original theme.

Registration stores only the absolute path, file size, format, and hash. It never copies source content.

For PDF/EPUB, perform or request text extraction according to the available tools. Keep normalized working text outside Git and record it in the private audit. If extraction cannot be done safely, report that concrete blocker rather than pretending distillation completed.

## Existing source or interrupted run

Registration is idempotent for the same source hash. Before restarting:

- compare `.novel/ACTIVE_SOURCE.md`, `SOURCE_MANIFEST.json`, and `PIPELINE_STATE.json`;
- reuse completed chunks and stages whose hashes still match;
- invalidate dependent results when normalized text changes;
- never overwrite another source that happens to share a filename.

## Theme request

When the user supplies a theme:

1. Read `.novel/ACTIVE_PACK.md`. If it is absent and exactly one validated pack exists, activate that pack automatically. If multiple packs exist without an active selection, present their neutral pack IDs, versions, and suitability without exposing source text.
2. Derive a project slug and working title. Record conservative assumptions instead of forcing a setup interview.
3. Run `sh scripts/novelctl.sh scaffold-project <project-slug> <runtime-style-pack-path>` to copy the full three-file style interface, craft snapshot, project writer, calibration state, and memory skeleton without overwriting an existing project.
4. Execute Mode B and replace every scaffold placeholder with real project content.
5. Instantiate relevant initial character/entity files and the first planning horizon. Empty optional directories may remain, but all required ledgers must be valid.
6. Validate the project and run:

   ```sh
   sh scripts/novelctl.sh activate-project "novel-projects/<project-slug>"
   sh scripts/novelctl.sh doctor
   ```

7. Present the premise, central conflict, ending direction, key assumptions, first planning horizon, and the next natural request. Write prose immediately only if the user asked to start writing.

## Active project and switching

`.novel/ACTIVE_PROJECT.md` is a pointer, not story memory. When a user names a different project, validate and activate that project explicitly. Never merge state from two projects because their themes or pack IDs are similar.

If no project is active and exactly one complete project exists, it may be activated automatically after verifying its project ID. Otherwise ask which project to use.

## Batch request

When the user asks for multiple chapters in one request, read [12-batch-writing.md](12-batch-writing.md). Before creating the durable job, require `state/STYLE_CALIBRATION.md` to show an accepted sample and successful three-chapter stability review, or record an explicit user waiver. The multi-chapter request itself is not a waiver. Then create the job through `novelctl.sh`, fill its plan, and run the project writer's sequential loop. Never run dependent chapter drafts in parallel.

## Status and recovery

Use:

```sh
sh scripts/novelctl.sh status
sh scripts/novelctl.sh doctor
```

`status` reports active pointers. `doctor` checks the workbench entry files and the active project's minimum configuration. A passing doctor does not prove prose quality; it proves the expected memory and style interfaces exist.

If an active batch exists, `status` also reports its pointer. Use `batch-status` and `batch-resume` to recover its exact next chapter; do not scan chapter filenames and guess.

Recovery order:

1. repair missing or mismatched files;
2. resolve contradictions recorded in the continuity ledger;
3. rebuild the temporary context pack;
4. resume the unfinished mode from persistent state;
5. do not reconstruct canon from chat history.

## Completion boundaries

- Source registration is not distillation completion.
- A writing contract without a reader-experience contract, quantitative targets, isolation, and evaluation is not a validated v2 runtime pack.
- A directory with an outline but no memory index, knowledge ledger, continuity ledger, and writer Skill is not a configured long-form project.
- A delivered chapter is not canon until accepted.
- Canon commit does not mean Git commit.
