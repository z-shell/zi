<!-- GENERATED from knowledge/domains/quality/code-review.md. Do not edit this delivery copy.
Regenerate: python3 automation/knowledge/knowledge-delivery.py
Check: python3 automation/knowledge/knowledge-delivery.py --check -->

# Code review

Review the requested changes against the owning repository's contracts and checks. Use the following priorities and report verified failure scenarios, rather than speculation or stylistic preferences as blockers.

| Priority | Required assessment |
| --- | --- |
| CRITICAL, blocks merge | Untrusted input execution, unreviewed eval, exposed secrets and unsafe temporary files; uncontrolled global state, broken declared unload contracts and irreversible side effects; Bash-only syntax in native Zsh or non-POSIX constructs in sh; undocumented changes to loading interfaces, CLI arguments or configuration schemas |
| IMPORTANT, requires resolution before merge | Features above the declared compatibility floor without fallback; incorrect sourced-library, autoload-function or startup-file classification; missing regression or unit coverage for features and fixes; CI pinning or permission violations |
| SUGGESTION, non-blocking | Native expansions that improve relevant performance, naming, comments and formatting |

Classify the language and execution profile first. For Zsh, read [the scripting standard](https://github.com/z-shell/.github/blob/main/.github/instructions/zsh/scripting.instructions.md) and [the machine policy](https://github.com/z-shell/.github/blob/main/knowledge/domains/zsh/data/zsh-standard-policy.json). Apply the declared compatibility floor, not the reviewer's installed version alone.

Run deterministic checks applicable to the affected code before advisory critique: zsh -f -n for native Zsh, sh -n for POSIX sh, and the owning repository's relevant suites. Inspect fpath, environment variables, aliases and functions for correctly scoped state and the declared unload behavior. Check plugin source paths for implicit network activity and heavy blocking work.

For each finding, provide CRITICAL, IMPORTANT or SUGGESTION, the rule or category, path:line, concrete impact and proposed correction. Include relevant verification and its limits. Reviews do not authorize repairs, commits or external publication.
