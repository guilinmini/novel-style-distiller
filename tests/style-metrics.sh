#!/bin/sh

set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -r "$test_root"' EXIT HUP INT TERM

prose="$test_root/prose.md"
targets_pass="$test_root/targets-pass.json"
targets_fail="$test_root/targets-fail.json"

printf '%s\n' '# Heading excluded' '“你要走？”' '她的手指一紧。' > "$prose"
printf '%s\n' '{"schema_version":"1.0","metrics":{"mean_paragraph_chars":{"target":[1,20],"hard":[1,40]}},"lexical_signals":{"body":{"terms":["手指"],"target_per_10000_chars":[1,10000],"hard_per_10000_chars":[1,10000]}}}' > "$targets_pass"
printf '%s\n' '{"schema_version":"1.0","metrics":{"mean_paragraph_chars":{"target":[100,110],"hard":[90,120]}}}' > "$targets_fail"

python3 "$repo_root/scripts/style_metrics.py" profile "$prose" > "$test_root/profile.json"
grep -F '"paragraphs": 2' "$test_root/profile.json" >/dev/null

python3 "$repo_root/scripts/style_metrics.py" compare --targets "$targets_pass" "$prose" > "$test_root/pass.json"
grep -F '"overall": "PASS"' "$test_root/pass.json" >/dev/null

set +e
python3 "$repo_root/scripts/style_metrics.py" compare --targets "$targets_fail" "$prose" > "$test_root/fail.json"
status=$?
set -e
test "$status" -eq 2
grep -F '"overall": "FAIL"' "$test_root/fail.json" >/dev/null

printf '%s\n' 'style metrics regression: PASS'
