# Zi benchmarks

Deterministic, network-free measurements of the paths a user pays for on every shell start: sourcing `zi.zsh`, loading plugins, queueing turbo tasks, parsing ices, reading package manifests, and unloading. The suite exists to make a performance change visible in the pull request that causes it (#553); it does not gate merges (ADR-0009: coverage and performance are observed, not gated).

## Cases

| Case | Measured region |
| --- | --- |
| `source-cold` | `source zi.zsh` in a fresh home with no compiled files, so automatic compilation is included |
| `source-warm` | `source zi.zsh` with the compiled files from the previous sample kept |
| `light-load-10` | `zi light` of ten fixture plugins |
| `load-10` | `zi load` (tracked) of ten fixture plugins |
| `turbo-10` | ten `wait'0'` tasks queued, then `@zi-scheduler burst` |
| `ice-200` | 200 `zi ice` calls carrying 13 ices each |
| `manifest-21` | the 21 vendored package manifests through `.zi-read-package-manifest` |
| `unload-10` | `zi unload` of ten tracked plugins |

Each sample starts a fresh `zsh -f` with an isolated home and reports `EPOCHREALTIME` elapsed milliseconds of the measured region only. Cases rotate in a balanced order across rounds. Every run also records health data that costs nothing extra: function and parameter counts after source and after loading, `.zwc` presence, `zsh -n` and `zcompile` durations, and the line counts of the hot files.

## Run it

```sh
zsh benchmarks/run.zsh --checkout . --output candidate.json --label candidate
zsh benchmarks/run.zsh --checkout ../zi-at-main --output baseline.json --label baseline
zsh benchmarks/run.zsh --checkout ../zi-at-main --output control.json --label control
zsh benchmarks/compare.zsh --baseline baseline.json --candidate candidate.json \
  --control control.json --output comparison.json --markdown comparison.md
```

Defaults are 5 warmups and 30 samples; `--case NAME` selects a subset. `compare.zsh` reports median, p95, min and the sample count per variant, the median and p95 deltas, and an A/A control column from the second baseline run so the noise floor is visible next to the real comparison. A case whose median regresses over 10% or whose p95 regresses over 15% is flagged for review; flags never fail. A functional failure on either side invalidates that case and exits 1, because timing a broken behaviour is meaningless.

## Read results carefully

- Hosted runners differ in hardware and load. Compare only within one run, and only when `comparable` is true (same Zsh version, architecture, and sample count).
- The fixture plugins are tiny; the cases isolate Zi's own overhead, not a real configuration's plugin bodies.
- `source-cold` includes compilation, so it moves with file size; `source-warm` is the everyday startup cost.
- `tests/benchmark-harness.zsh` proves the runner and comparer: shape, A/A, a synthetic 30% regression flagged, a functional failure invalidated.

## Where it runs

`.github/workflows/benchmark.yml` compares every pull request into `next` with its base and the promotion pull request into `main` with `main`, writes the table to the job summary, and keeps the JSON and Markdown as an artifact for 90 days. Per-release results are committed by a maintainer under `benchmarks/results/<tag>/` after a release, never by automation.
