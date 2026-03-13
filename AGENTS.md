# AGENTS.md

## Project Overview

Soduku-Harmony is a feature-rich Sudoku game built for **HarmonyOS** using **ArkUI** and **ETS** (Enhanced TypeScript). The app targets HarmonyOS 6.0.2 and supports phones, tablets, wearables, and TVs.

**Key features:**

- Puzzle generation with configurable difficulty levels
- AI-powered solving hints using human-logic strategies (LogicSolver)
- Undo/redo with grouped history (single-cell and batch operations)
- Hand gesture detection for input
- Variant Sudoku support (custom topology)
- Game statistics tracking and history
- Internationalization (i18n) support
- Dark mode / theme support
- Background puzzle generation via Web Workers

**Bundle name:** `com.bytemain.soduku`
**Version:** 1.0.0

## Repository Structure

```
├── AppScope/                  # App-level manifest and resources (icons, strings)
├── entry/                     # Main HAP module (all application code)
│   └── src/main/ets/
│       ├── entryability/      # App entry point and lifecycle (EntryAbility.ets)
│       ├── pages/             # Screen components (GamePage, Index, StatsPage)
│       ├── components/        # Reusable UI components (SudokuBoard, SudokuCell, etc.)
│       ├── models/            # Data models (CellData, GameState, GameHistory, etc.)
│       ├── stores/v2/         # V2 domain-driven state management
│       ├── utils/             # Algorithms and utilities (generator, solver, validator, storage)
│       ├── workers/           # Background Web Workers (PuzzleWorker)
│       ├── services/          # Application services (CoachService)
│       └── constants/         # Game-wide constants, colors, and theme definitions
├── docs/                      # Design documents and research notes (Chinese)
├── .github/workflows/         # CI/CD pipeline (GitHub Actions)
├── build-profile.json5        # Build configuration (SDK version, build modes)
├── code-linter.json5          # Linting rules (ESLint + security rules)
├── oh-package.json5           # Root package manifest
└── hvigorfile.ts              # Root build script
```

## Build and Test Commands

This project uses **Hvigor** (HarmonyOS build system) and **ohpm** (OpenHarmony Package Manager).

```bash
# Install all dependencies
ohpm install --all

# Clean build artifacts
hvigorw clean --no-daemon

# Build HAP (debug)
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon

# Build HAP (release)
hvigorw assembleHap --mode module -p product=default -p buildMode=release --no-daemon

# Run the linter
hvigorw lintETS --mode module -p product=default
```

Build output is located at `entry/build/default/outputs/default/entry-default.hap`.

**Testing framework:** Hypium (`@ohos/hypium`) with Hamock (`@ohos/hamock`) for mocking.
Test files are in `entry/src/ohosTest/ets/test/`.

## Code Style Guidelines

- **Language:** ETS (Enhanced TypeScript for ArkUI). All source files use the `.ets` extension.
- **Naming:** PascalCase for classes, components, and interfaces; camelCase for functions, variables, and properties.
- **UI Components:** Use ArkUI decorators (`@Entry`, `@Component`, `@State`, `@Prop`, `@Link`).
  - Use `@Prop` for simple types (number, boolean, string) that need one-way sync from parent.
  - Properties without `@Prop` are initialization-only and do **not** update when the parent re-renders.
- **State management:** Progressive V2 domain-driven pattern in `stores/v2/`. Each domain manages a specific slice of state.
- **Constants:** All grid-size-dependent values must use constants from `GameConstants.ets` (`GRID_SIZE`, `BOX_SIZE`, `TOTAL_CELLS`, `DIGITS`, etc.). Never hardcode grid dimensions.
- **Bit flags:** Cell state uses bit manipulation (`GIVEN`, `ERROR`, `SELECTED`, `HIGHLIGHTED`, etc.) defined in `CellData.ets`. Notes use 2-bit encoding per digit.
- **History:** Use `GameHistory.push()` for single-cell operations and `pushBatch()` for multi-cell operations (e.g., auto-notes) to enable atomic undo/redo.
- **Documentation:** Code comments are primarily in Chinese. Follow existing comment style.
- **Linting rules** (`code-linter.json5`):
  - `plugin:@performance/recommended`
  - `plugin:@typescript-eslint/recommended`
  - Strict security rules — cryptographic operations (AES, Hash, RSA, DSA, DH, ECDSA, 3DES) are errors; MAC is a warning.
- **Lint scope:** All `**/*.ets` files except test, mock, node_modules, oh_modules, build, and preview directories.

## Testing Instructions

- Tests use the **Hypium** framework (`@ohos/hypium`).
- Test files live in `entry/src/ohosTest/ets/test/`.
- Mock data is in `entry/src/mock/`.
- Assertions include `.assertContain()`, `.assertEqual()`, and the standard Hypium assertion library.
- Tests require the HarmonyOS runtime/emulator; they cannot be run in a plain Node.js environment.

## Security Considerations

- **Offline-first:** The app makes no network requests and stores all data locally using HarmonyOS LocalStorage.
- **No secrets in code:** Never commit credentials, API keys, or signing certificates. HAP signing credentials are managed via GitHub Secrets in CI.
- **Linting enforces cryptographic safety:** Unsafe crypto operations (AES, Hash, RSA, DSA, DH, ECDSA, 3DES) trigger lint errors. See `code-linter.json5`.
- **Permissions:** The app declares `ohos.permission.ACTIVITY_MOTION` and `ohos.permission.DETECT_GESTURE` for hand gesture detection. Only request permissions that are strictly necessary.
- **HAP signing:** Release builds are signed using `SHA256withECDSA` via `hap-sign-tool.jar` in CI. Key passwords come from GitHub Secrets (`KEY_PASSWORD`, `KEYSTORE_PASSWORD`).

## Commit and PR Guidelines

- **Branch protection:** The `main` and `openharmony_master` branches require passing CI builds.
- **CI pipeline:** Every push and PR triggers a build in the GitHub Actions workflow (`.github/workflows/harmonyos-ci.yml`). Ensure your changes build successfully.
- **Releases:** Tag with `v*` (e.g., `v1.0.0`) to trigger automatic HAP signing and GitHub Release creation.
- Write clear, descriptive commit messages. Reference issue numbers when applicable.

## Key Architecture Notes

| Area | Key Files | Notes |
|------|-----------|-------|
| App entry | `EntryAbility.ets` | Lifecycle, theme init, hand detection setup |
| Game UI | `GamePage.ets` | Main game screen — largest file (~52 KB) |
| Home screen | `Index.ets` | Puzzle selection, game initialization |
| Cell model | `CellData.ets` | Bit-flag state, 2-bit note encoding |
| Puzzle generation | `SudokuGenerator.ets`, `PuzzleWorker.ets` | Background worker with progress callbacks |
| Solving / Hints | `LogicSolver.ets`, `SudokuSolver.ets` | Human-logic hints + brute-force solver |
| Validation | `SudokuValidator.ets` | Conflict detection, completion checks |
| Difficulty | `DifficultyEvaluator.ets` | Rates puzzle difficulty by technique complexity |
| Topology | `Topology.ets`, `VariantTopology.ets` | Standard and variant Sudoku peer relationships |
| Persistence | `GameStorage.ets`, `SettingsStorage.ets`, `StatsStorage.ets` | LocalStorage-based saves |
| State management | `stores/v2/*.ets` | Domain-driven V2 reactive state |
