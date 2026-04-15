# 🧩 Sudoku Harmony

A feature-rich Sudoku game built for **HarmonyOS** using **ArkUI** and **ETS** (Enhanced TypeScript). Supports phones, tablets, wearables, and TVs.

## ✨ Features

- **Multiple Difficulty Levels** — Easy, Medium, Hard, Expert, and Evil
- **Variant Sudoku Modes** — Standard, Diagonal (Sudoku-X), Jigsaw, and Killer
- **AI-Powered Hints** — Human-logic solving strategies via LogicSolver with step-by-step coaching
- **Hand Gesture Input** — Swipe and tap gestures for number entry, notes, and erasing
- **Undo / Redo** — Grouped history supporting both single-cell and batch operations
- **Puzzle Library** — 75 built-in puzzles across 4 difficulty tiers with progress tracking
- **Game Statistics** — Track completion times, win rates, and star ratings
- **Dark Mode** — Full theme support with light and dark color schemes
- **Internationalization** — i18n support (Chinese and English)
- **Background Generation** — Puzzle generation via Web Workers with progress callbacks
- **Offline-First** — No network requests; all data stored locally

## 📱 Supported Devices

| Phone | Tablet | Wearable | TV |
|:-----:|:------:|:--------:|:--:|
| ✅    | ✅     | ✅       | ✅ |

**Target SDK:** HarmonyOS 6.0.2

## 🏗️ Project Structure

```
├── AppScope/                  # App-level manifest and resources
├── entry/                     # Main HAP module
│   └── src/main/ets/
│       ├── entryability/      # App entry point and lifecycle
│       ├── pages/             # Screen components
│       │   ├── Index.ets              # Home screen & puzzle selection
│       │   ├── GamePage.ets           # Main game screen
│       │   └── PuzzleLibraryPage.ets  # Built-in puzzle browser
│       ├── components/        # Reusable UI components
│       │   ├── SudokuBoard.ets        # Game board renderer
│       │   ├── SudokuCell.ets         # Individual cell component
│       │   ├── GestureKey.ets         # Gesture-based number pad
│       │   ├── CoachSheet.ets         # AI coaching overlay
│       │   └── ...
│       ├── models/            # Data models
│       │   ├── CellData.ets           # Bit-flag cell state
│       │   ├── GameHistory.ets        # Undo/redo history
│       │   ├── VariantConfig.ets      # Variant type definitions
│       │   └── ...
│       ├── stores/v2/         # V2 domain-driven state management
│       ├── utils/             # Algorithms and utilities
│       │   ├── SudokuGenerator.ets    # Puzzle generation
│       │   ├── LogicSolver.ets        # Human-logic hint engine
│       │   ├── SudokuValidator.ets    # Conflict & completion checks
│       │   ├── DifficultyEvaluator.ets # Difficulty rating
│       │   ├── KillerSudoku.ets       # Killer cage generation
│       │   ├── JigsawGenerator.ets    # Jigsaw region generation
│       │   └── ...
│       ├── workers/           # Background Web Workers
│       ├── services/          # Application services (coaching)
│       └── constants/         # Colors, sizes, and game constants
├── docs/                      # Design documents (Chinese)
├── .github/workflows/         # CI/CD pipeline
├── build-profile.json5        # Build configuration
├── code-linter.json5          # Linting rules
└── oh-package.json5           # Package manifest
```

## 🚀 Getting Started

### Prerequisites

- [DevEco Studio](https://developer.huawei.com/consumer/en/deveco-studio/) with HarmonyOS SDK 6.0.2
- **ohpm** (OpenHarmony Package Manager)
- **Hvigor** build tool (bundled with DevEco Studio)

### Install Dependencies

```bash
ohpm install --all
```

### Build

```bash
# Debug build
hvigorw clean --no-daemon
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon

# Release build
hvigorw assembleHap --mode module -p product=default -p buildMode=release --no-daemon
```

Build output: `entry/build/default/outputs/default/entry-default.hap`

### Lint

```bash
hvigorw lintETS --mode module -p product=default
```

### Run Tests

Tests use the [Hypium](https://gitee.com/openharmony/testfwk_arkxtest) framework and require a HarmonyOS device or emulator:

```bash
hvigorw test --mode module -p product=default --no-daemon
```

## 🎮 Variant Modes

| Mode | Description |
|------|-------------|
| **Standard** | Classic 9×9 Sudoku with 3×3 boxes |
| **Diagonal** | Sudoku-X — both main diagonals must also contain 1–9 |
| **Jigsaw** | Irregularly shaped regions replace standard boxes |
| **Killer** | Cages with sum constraints; no repeated digits within a cage |

The app also supports multiple grid sizes (4×4, 6×6, 9×9, 12×12, 16×16) through configurable `GridConfig`.

## 🧠 Solving Engine

The **LogicSolver** provides human-style hints using techniques such as:

- Naked & Hidden Singles
- Naked & Hidden Pairs/Triples
- Pointing Pairs
- Box/Line Reduction
- Cage Sum Analysis (Killer mode)

The **DifficultyEvaluator** rates puzzles based on which techniques are required to solve them.

## 🔧 Architecture Highlights

- **State Management:** Progressive V2 domain-driven pattern — each domain (`GameSession`, `GameHistory`, `GameInteraction`, `GameUI`, `GameLoading`) manages a specific slice of state
- **Cell State:** Bit-flag encoding for cell properties (`GIVEN`, `ERROR`, `SELECTED`, `HIGHLIGHTED`) with 2-bit note encoding per digit
- **Topology:** Dynamic peer/unit relationships built from `VariantConfig`, supporting standard and custom region layouts
- **Persistence:** LocalStorage-based saves for game state, settings, statistics, and puzzle library progress

## 📦 CI/CD

Every push and pull request triggers the [GitHub Actions workflow](.github/workflows/harmonyos-ci.yml):

1. **Build** — Compiles the HAP package
2. **Test** — Compiles and validates unit tests
3. **Publish** — On version tags (`v*`), signs the HAP and creates a GitHub Release

## 📄 License

See the repository for license details.
