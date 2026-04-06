---
name: Run Unit Tests
description: Build and run local unit tests for the HarmonyOS Sudoku app using Hvigor from DevEco Studio.
---

# Run Unit Tests

Use this skill when the user asks to run tests, verify test results, or check if code changes break existing tests.

## Repository facts

- Test framework: Hypium (`@ohos/hypium`) with Hamock (`@ohos/hamock`) for mocking
- Test entry: `entry/src/test/List.test.ets` (registers all test suites)
- Test files: `entry/src/test/*.test.ets`
- Mock data: `entry/src/mock/`

## Test command

Run from the repo root:

```zsh
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  test
```

Or, if `hvigorw` is already in PATH (e.g. via `export PATH="/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin:$PATH"`):

```zsh
hvigorw test
```

## What this does

1. Compiles the `entry` module in unit-test mode
2. Builds and executes all local unit tests registered in `List.test.ets`
3. Generates an HTML test report
4. Prints `BUILD SUCCESSFUL` on success

## Expected success signal

```text
> hvigor Finished :entry:default@GenerateUnitTestResult...
> hvigor Finished :entry:test...
> hvigor BUILD SUCCESSFUL
```

## Common warnings (non-blocking)

The build may emit warnings that do **not** block tests:

- `The system capacity of this api 'motion' is not supported on all devices` — hand detection API
- `'px2vp' has been deprecated` — legacy API usage
- `Function may throw exceptions` — SettingsStorage

If `BUILD SUCCESSFUL` appears, all tests passed.

## Adding new tests

1. Create `entry/src/test/YourFeature.test.ets` following existing patterns
2. Register it in `entry/src/test/List.test.ets`:
   ```typescript
   import yourFeatureTest from './YourFeature.test'
   // ...
   export default function testsuite() {
     // ...
     yourFeatureTest()
   }
   ```
3. Run the test command above to verify

## When responding to the user

- Run the test command and check for `BUILD SUCCESSFUL`
- If tests fail, quote the first error from the output
- Non-blocking warnings can be ignored
