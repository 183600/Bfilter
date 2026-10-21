#!/usr/bin/env bash
# Fail if throwaway agent/probe files were committed to the repository.
set -euo pipefail

bad="$(
  git ls-files |
    grep -E '(^|/)(zz_|tmp_|_scratch_|dbg_)' || true
)"
if [[ -n "$bad" ]]; then
  echo "error: scratch/probe files must not be committed:" >&2
  echo "$bad" >&2
  echo "Use descriptive test names, or keep throwaway scripts in /tmp." >&2
  exit 1
fi

# The old README promised unimplemented features; keep the new README from
# silently regressing to that state.
if grep -q 'Core features are not yet implemented' README.md; then
  echo "error: README contains the obsolete 'not implemented' status block" >&2
  exit 1
fi

echo "repository hygiene: ok"
