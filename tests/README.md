# Tests

## Fast smoke test

```sh
sh tests/smoke.sh
```

Checks source registration without copying the source, validated-pack activation, safe project scaffolding, required web-fiction memory files, project activation, `doctor`, automatic batch mode, review-checkpoint mode, pause/resume, checkpoint idempotency, and batch completion.

## 120-chapter deterministic state regression

```sh
sh tests/longform-regression.sh
```

Creates an isolated synthetic project and commits 120 synthetic chapter transactions through the real batch controller. It verifies:

- strict sequential checkpoints;
- interruption and durable resume after chapters 40 and 80;
- retention of an object change from chapter 30;
- retention of a knowledge change from chapter 60;
- retention of a relationship change from chapter 90;
- thread payoff at chapter 120;
- preservation of early chapter records and structured snapshots;
- final batch counts and resume state.

The test uses no source novel, model API, Python package, database, or network access.

## What this does not prove

The deterministic regression proves orchestration and memory invariants, not literary quality. Model-in-the-loop evaluation must separately test the opening-three-chapter promise, reward delivery, hook payoff, reader-emotion variation, natural-prose symptoms, distilled-style drift, continuity, and source isolation using the protocol in [`../references/06-evaluation.md`](../references/06-evaluation.md). Keep those generated artifacts local unless they are fully synthetic and intentionally approved for the repository.
