#!/usr/bin/env bash
# Fail if any tracked file contains an xpub-shaped string.
# Run locally before commit, and in CI on every push and PR.
#
# Excludes test fixtures and docs (where example xpubs may be intentional).

set -euo pipefail

# Match base58-ish strings of 100+ chars starting with xpub/ypub/zpub/Zpub.
# Word boundary on each side to avoid matching English text containing the prefix.
PATTERN='\b([xyzZ]pub)[A-HJ-NP-Za-km-z1-9]{100,}\b'

EXCLUDES=(
	':!docs/'
	':!test/fixtures/'
	':!spec/fixtures/'
	':!**/fixtures/**'
	':!*.example'
)

if git grep -nE "$PATTERN" -- "${EXCLUDES[@]}"; then
	echo ""
	echo "ERROR: xpub-shaped string found in tracked files."
	echo "Refusing to proceed. Move the value to .env (gitignored) or remove it."
	exit 1
fi

echo "OK: no xpub-shaped strings in tracked files."
