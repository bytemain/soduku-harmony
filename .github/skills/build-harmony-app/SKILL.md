---
name: Build HarmonyOS App
description: Build, verify, and locate the packaged HarmonyOS app for this repository using Hvigor from DevEco Studio.
---

# Build HarmonyOS App

Use this skill when the user asks to build, package, verify, or locate the output of the HarmonyOS app in this repository.

## Repository facts

- Root package file: `oh-package.json5`
- Root model version: `6.0.2`
- App module: `entry`
- Verified successful task: `assembleApp`

## Build command

Run from the current repo root:

```zsh
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [[ -n "${HVIGORW:-}" ]]; then
	:
elif command -v hvigorw >/dev/null 2>&1; then
	HVIGORW="$(command -v hvigorw)"
else
	echo "hvigorw not found; export HVIGORW=/path/to/hvigorw or put it in PATH" >&2
	exit 1
fi

cd "$REPO_ROOT"
"$HVIGORW" --mode project assembleApp
```

## What this does

- Builds the `entry` module
- Compiles ArkTS resources and code
- Packages and signs the HAPs
- Produces the app packaging artifacts for the project

## Expected success signal

Look for output similar to:

```text
> hvigor Finished ::assembleApp...
> hvigor BUILD SUCCESSFUL
```

## Output locations

After a successful build, check:

- Signed default HAP: `entry/build/default/outputs/default/entry-default-signed.hap`
- Unsigned default HAP: `entry/build/default/outputs/default/entry-default-unsigned.hap`
- App output dir: `entry/build/default/outputs/default/app/`
- Mapping dir: `entry/build/default/outputs/default/mapping/`
- Symbols dir: `entry/build/default/outputs/default/symbol/`
- Test HAPs: `entry/build/default/outputs/ohosTest/`

## Common checks

Before building, confirm the tool exists:

```zsh
[[ -n "${HVIGORW:-}" ]] || command -v hvigorw
```

To inspect tasks:

```zsh
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

if [[ -n "${HVIGORW:-}" ]]; then
	:
elif command -v hvigorw >/dev/null 2>&1; then
	HVIGORW="$(command -v hvigorw)"
else
	echo "hvigorw not found; export HVIGORW=/path/to/hvigorw or put it in PATH" >&2
	exit 1
fi

"$HVIGORW" tasks
```

## Troubleshooting

### ArkTS component root node errors

If you see an error like:

```text
In an '@Entry' decorated component, the 'build' method can have only one root node
```

Make sure the component's `build()` returns exactly one root container such as `Column`, `Row`, or `Stack`.

### Unexpected token while compiling `.ets`

This often means the ArkTS parser encountered invalid component structure, usually from:

- Multiple sibling root nodes in `build()`
- Broken braces after refactoring
- Invalid interpolation or builder placement

### Build warnings

This repo currently may emit non-blocking warnings such as:

- deprecated API usage
- `Function may throw exceptions`
- system capability warnings

If `BUILD SUCCESSFUL` appears, those warnings do not block packaging.

## When responding to the user

- Prefer repo-relative commands and detect `hvigorw` from the current environment first
- Report whether build passed or failed
- If it passed, include the signed HAP path
- If it failed, quote the first blocking error and fix that root cause first
