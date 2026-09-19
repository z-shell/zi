# Zi benchmarks

Deterministic, network-free measurements of the paths a user pays for on every shell start: sourcing `zi.zsh`, loading plugins, queueing turbo tasks, parsing ices, reading package manifests, and unloading. The suite exists to make a performance change visible in the pull request that causes it (#553); it does not gate merges (ADR-0009: coverage and performance are observed, not gated).

## Cases

| Case | Measured region |
| --- | --- |
| `source-fresh-home` | `source zi.zsh` in a home no sample has used before (directories are created, nothing is cached) |
| `source-reused-home` | `source zi.zsh` in the variant's home kept from the previous sample (prepared directories and completion state persist) |
| `light-load-10` | `zi light` of ten fixture plugins |
| `load-10` | `zi load` (tracked) of ten fixture plugins |
| `turbo-10` | ten `wait'0'` tasks queued, then `@zi-scheduler burst` |
| `ice-200` | 200 `zi ice` calls carrying 13 ices each |
| `manifest-21` | the 21 vendored package manifests through `.zi-read-package-manifest` |
| `unload-10` | `zi unload` of ten tracked plugins |

Each sample starts a fresh `zsh -f` with an isolated home and reports `EPOCHREALTIME` elapsed milliseconds of the measured region only. All variants of one invocation are measured together: within a round they alternate, and their order reverses every round, so runner drift is not correlated with a variant; cases rotate in a balanced order across rounds. Zi does not compile itself on source, so the two source cases differ by persisted home state, not by bytecode. Every run also records health data that costs nothing extra: function and parameter counts after source and after loading, `.zwc` presence, `zsh -n` and `zcompile` durations, and the line counts of the hot files.

## Run it

```sh
zsh benchmarks/run.zsh --variant baseline=../zi-at-main --variant candidate=. \
  --variant control=../zi-at-main --output-dir results
zsh benchmarks/compare.zsh --baseline results/baseline.json --candidate results/candidate.json \
  --control results/control.json --output comparison.json --markdown comparison.md
```

Defaults are 5 warmups and 30 samples; `--case NAME` selects a subset. `run.zsh` writes one JSON report per variant and exits 1, after writing every report, when a workload fails functionally. `compare.zsh` reports median, p95, min and the sample count per variant, the median and p95 deltas, and an A/A control column from the second baseline measurement so the noise floor is visible next to the real comparison. A case whose median regresses over 10% or whose p95 regresses over 15% is flagged for review; flags never fail, and they are null when the two reports are not comparable (different Zsh version, architecture, sample or warmup count). A functional failure on either side invalidates that case and exits 1, because timing a broken behaviour is meaningless. A case a checkout cannot run because it predates the API the case exercises is a different thing: `case.zsh` exits 6, `run.zsh` records the case as `unsupported` for that variant with the reason and still exits 0, and `compare.zsh` renders the row without a delta. A baseline without the API (or both sides without it) is unsupported, not failed, and does not exit 1; a candidate without an API its baseline has is recorded as a failure, because that is a removal. The manifest case is named for its inventory: `run.zsh` pins the 21 repository names and requires `tests/fixtures/package-manifests/repositories.txt` to list exactly them with a snapshot each, and each sample re-asserts the count; replacing one repository with another is rejected even though the count is unchanged. A changed inventory is a different workload and needs a renamed or versioned case and an updated pinned list, not a drifting number or a silently swapped set. Snapshot contents are not pinned, so refreshing a vendored manifest verbatim keeps the inventory.

## Read results carefully

- Hosted runners differ in hardware and load. Compare only within one run, and only when `comparable` is true (same Zsh version, architecture, and sample count).
- The fixture plugins are tiny; the cases isolate Zi's own overhead, not a real configuration's plugin bodies.
- `source-reused-home` is the everyday startup cost; `source-fresh-home` adds the first-run directory preparation.
- `tests/benchmark-harness.zsh` proves the runner and comparer: shape, A/A, a synthetic 30% regression flagged, a functional failure invalidated, a control-only failure rendered, a repeated `--case` rejected, a checkout without the manifest reader reported unsupported (and a candidate that lost it reported as a failure), a swapped manifest inventory rejected, and six cells in every table row.

## Where it runs

`.github/workflows/benchmark.yml` compares every pull request into `next` with its base and the promotion pull request into `main` with `main`, writes the table to the job summary, and keeps the JSON and Markdown as an artifact for 90 days. Per-release results are committed by a maintainer under `benchmarks/results/<tag>-<os>-<arch>/` (zpmod's naming) after a release, never by automation.
