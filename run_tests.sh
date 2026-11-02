#!/usr/bin/env bash
# Runs every GUT-independent test in tests/ and reports a single verdict.
# A test only counts as passing if it prints its PASS token AND emits no
# SCRIPT ERROR / Parse Error -- a crashed script can still print PASS.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# Cap stored output per test. A runaway test (e.g. a per-frame error loop) can
# emit tens of MB; capturing that into a shell variable makes the runner crawl
# and blows up memory. We only need the verdict and first few errors.
MAX_OUTPUT_BYTES=262144
tmp_out="$(mktemp)"
tmp_full="$(mktemp)"
trap 'rm -f "$tmp_out" "$tmp_full"' EXIT

pass=0
fail=0
failures=()

# Verify save isolation before running tests that may save progress.
timeout 60 godot --headless -s tests/test_save_isolation.gd > "$tmp_out" 2>&1
isolation_code=$?
isolation_output="$(cat "$tmp_out")"
if [ "$isolation_code" -ne 0 ] \
	|| ! printf '%s\n' "$isolation_output" | grep -q "SAVE_ISOLATION_PASS" \
	|| printf '%s\n' "$isolation_output" | grep -Eq "SCRIPT ERROR|Parse Error|Compile Error"; then
	echo "PASS=0 FAIL=1"
	printf '%s\n' "FAILURES:" "  test_save_isolation.gd :: save isolation preflight failed"
	printf '%s\n' "$isolation_output" | grep -E "SCRIPT ERROR|Parse Error|Compile Error|FAIL|ERROR" | head -5
	exit 1
fi
pass=1

for t in tests/test_*.gd; do
	name=$(basename "$t")
	[ "$name" = "test_save_isolation.gd" ] && continue
	# Stream to a file so a flood can't buffer in a shell variable; keep a
	# bounded copy for the verdict checks, plus a full copy only if asked.
	if [ -n "${KEEP_OUTPUT:-}" ]; then
		timeout 300 godot --headless -s "$t" 2>&1 | tee "$tmp_full" | head -c "$MAX_OUTPUT_BYTES" > "$tmp_out"
	else
		timeout 300 godot --headless -s "$t" 2>&1 | head -c "$MAX_OUTPUT_BYTES" > "$tmp_out"
	fi
	code=${PIPESTATUS[0]}
	out="$(cat "$tmp_out")"
	errors=$(printf '%s\n' "$out" | grep -E "SCRIPT ERROR|Parse Error|Compile Error" | head -2)
	if [ -n "$errors" ]; then
		fail=$((fail + 1))
		failures+=("$name :: $(printf '%s' "$errors" | head -1)")
		[ -n "${KEEP_OUTPUT:-}" ] && cp "$tmp_full" "/tmp/opencode/$name.log"
	elif printf '%s\n' "$out" | grep -q "_PASS"; then
		pass=$((pass + 1))
	elif [ $code -eq 0 ]; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		failures+=("$name :: exit $code")
		[ -n "${KEEP_OUTPUT:-}" ] && cp "$tmp_full" "/tmp/opencode/$name.log"
	fi
done

echo "PASS=$pass FAIL=$fail"
if [ ${#failures[@]} -gt 0 ]; then
	printf 'FAILURES:\n'
	printf '  %s\n' "${failures[@]}"
	exit 1
fi
