# 🧠 Peter Norvig 的数独解法深度解析

> 基于 [Peter Norvig](https://norvig.com/) 的 [Sudoku.ipynb](https://github.com/norvig/pytudes/blob/main/ipynb/Sudoku.ipynb)
> Norvig 是 Google Research 的前研究总监、《Artificial Intelligence: A Modern Approach》的作者，AI 领域的教父级人物。
> 这份代码最初写于 2006 年，2021 年修订，仅约 80 行 Python 就能解决任意数独。

---

## 目录

1. [核心思想：约束传播 + 搜索](#1-核心思想)
2. [数据结构设计](#2-数据结构设计)
3. [约束传播（Constraint Propagation）](#3-约束传播)
4. [深度优先搜索（Search）](#4-深度优先搜索)
5. [完整求解流程](#5-完整求解流程)
6. [性能表现](#6-性能表现)
7. [Norvig 的设计取舍与思考](#7-设计取舍)
8. [我的评价与思考](#8-我的评价与思考)
9. [对我们数独 App 的启示](#9-对数独-app-的启示)

---

## 1. 核心思想

Norvig 的数独解法本质上只有两个武器：

```
约束传播（Constraint Propagation）— 尽可能多地推导
         +
深度优先搜索（DFS）— 推导不动时，猜一个，递归下去
```

关键洞察：**不要先传播完再搜索，要交替进行**。每次猜一个数字后，立刻做一轮约束传播，
能极大减少搜索空间。这是朴素回溯和 Norvig 方法的根本区别。

---

## 2. 数据结构设计

### 2.1 Norvig 的选择

| 概念 | 表示 | 说明 |
|------|------|------|
| Digit | `str` 如 `'5'` | 字符而非数字，因为不需要做算术 |
| DigitSet | `str` 如 `'123'` | 用字符串表示候选集合，紧凑且可读 |
| Square | `str` 如 `'C2'` | 行字母(A-I) + 列数字(1-9)，调试时一眼看出位置 |
| Grid | `Dict[Square, DigitSet]` | 81 个格子各自的候选集 |

### 2.2 预计算的拓扑结构

Norvig 在程序启动时一次性算好所有关系，之后求解时直接查表：

```python
# 81 个格子
squares = cross('ABCDEFGHI', '123456789')
# → ('A1', 'A2', ..., 'I9')

# 27 个单元（9行 + 9列 + 9宫）
all_units = [cross(rows, c) for c in cols]       # 9 列
           + [cross(r, cols) for r in rows]       # 9 行
           + [cross(rs, cs) for rs in ('ABC','DEF','GHI')
                             for cs in ('123','456','789')]  # 9 宫

# 每个格子所属的 3 个单元
units = {s: tuple(u for u in all_units if s in u) for s in squares}

# 每个格子的 20 个同伴（同行 + 同列 + 同宫，去重去自己）
peers = {s: set().union(*units[s]) - {s} for s in squares}
```

**预计算的好处**：求解时永远不需要临时算"某个格子的同行/列/宫有哪些"，直接 `peers[s]` 查表，O(1)。

### 2.3 为什么是 `Dict` 而不是二维数组？

Norvig 考虑过几种方案，最终选 `Dict[str, str]`，原因：

- `grid.copy()` 是浅拷贝，够用（因为值是不可变字符串）
- 调试时 `grid['C2']` 比 `grid[2][1]` 更直观
- 不需要 `deepcopy`（如果用 `set` 表示候选集就需要）

---

## 3. 约束传播（Constraint Propagation）

这是 Norvig 代码最精妙的部分。只用两条策略，反复互相触发：

### 策略 1：Naked Single（裸单数）

> 如果某个格子只剩一个候选数，就把这个数从它所有同伴的候选中删除。

### 策略 2：Hidden Single（隐性单数）

> 如果某个单元（行/列/宫）中，某个数字只有一个格子能放，就把那个格子填上这个数字。

### 3.1 代码架构

Norvig 的精妙之处在于：**`eliminate` 是基本操作，`fill` 是用 `eliminate` 实现的**。

```
fill(grid, s, d)
  = "在 s 填入 d"
  = "把 s 的候选中除了 d 以外的数字全部 eliminate"

eliminate(grid, s, d)
  = "从 s 的候选中移除 d"
  → 如果移除后 s 只剩 1 个候选：触发 策略1 → 对所有 peers eliminate
  → 对 s 所在的每个 unit，检查 d 还能放在哪：
    → 如果只有 1 个位置：触发 策略2 → fill 那个位置
```

### 3.2 `eliminate` 的实现逻辑

```python
def eliminate(grid, s, d):
    """从 grid[s] 中移除数字 d"""

    if d not in grid[s]:
        return grid        # 已经不在了，什么都不做

    grid[s] = grid[s].replace(d, '')

    # 矛盾检测：候选数被清空了
    if not grid[s]:
        return None        # 无解！

    # ---- 策略 1: Naked Single ----
    # 如果只剩一个候选，从所有 peer 中消除它
    if len(grid[s]) == 1:
        d2 = grid[s]
        if not all(eliminate(grid, s2, d2) for s2 in peers[s]):
            return None    # 消除过程中发现矛盾

    # ---- 策略 2: Hidden Single ----
    # 对于 s 所在的每个 unit，看 d 还能放在哪
    for u in units[s]:
        dplaces = [s for s in u if d in grid[s]]
        if not dplaces:
            return None    # 这个 unit 中 d 无处可放 → 矛盾
        if len(dplaces) == 1:
            if not fill(grid, dplaces[0], d):
                return None
    return grid
```

### 3.3 连锁反应

这两个策略是**互相递归**的：

```
eliminate → 可能触发 策略1 → 调用 eliminate（对 peer）
                                 ↓
eliminate → 可能触发 策略2 → 调用 fill → 调用 eliminate（对其他数字）
                                              ↓
                                         eliminate → 可能又触发策略1 ...
```

**一次 `fill` 操作可能引发雪崩式的连锁推导**，一口气推导出大量格子。
很多简单和中等的数独，仅靠 `constrain`（对所有给定数做一遍 `fill`）就能直接解完。

### 3.4 `constrain` 的入口

```python
def constrain(grid):
    """对网格的副本进行约束传播"""
    result = {s: digits for s in squares}   # 初始化：每个格子候选都是 1-9
    for s in grid:
        if len(grid[s]) == 1:
            fill(result, s, grid[s])        # 对每个已知数字做 fill
    return result
```

---

## 4. 深度优先搜索（Search）

当约束传播推不动了（还有格子有多个候选），就需要搜索了。

### 4.1 搜索代码

```python
def search(grid):
    """深度优先搜索 + 约束传播"""

    if grid is None:
        return None   # 此路不通

    # 找候选数最少的未确定格子（MRV 启发式）
    s = min((s for s in squares if len(grid[s]) > 1),
            default=None, key=lambda s: len(grid[s]))

    if s is None:
        return grid   # 所有格子都确定了 → 解出来了！

    # 尝试该格的每个候选数字
    for d in grid[s]:
        solution = search(fill(grid.copy(), s, d))
        if solution:
            return solution

    return None       # 所有候选都试过了，都不行 → 回溯
```

### 4.2 关键设计决策

#### MRV（Minimum Remaining Values）启发式

每次选**候选数最少的格子**来猜。

```
为什么？假设格子 B3 有 7 个候选，G2 有 2 个候选：
- 猜 B3：错误概率 6/7 ≈ 85.7%
- 猜 G2：错误概率 1/2 = 50%

选候选少的格子，猜对的概率更大，搜索树更小。
```

#### 每次猜测都做一份 copy

```python
search(fill(grid.copy(), s, d))
#           ^^^^^^^^^^^
#           关键：复制一份再改
```

这样不同分支的搜索互不干扰。如果某条路走不通，原来的 `grid` 没被污染，可以直接尝试下一个候选。

#### 搜索和约束传播的交替

```
search
  → fill(copy, s, d)     ← 猜测
    → eliminate           ← 约束传播开始连锁反应
      → eliminate → ...   ← 可能推导出很多格子
  → search(result)        ← 在大幅缩减的网格上继续搜索
```

每次猜测后都会触发一轮约束传播，可能直接推导出大片区域。
这就是为什么即使 10^38 的搜索空间也能秒解。

---

## 5. 完整求解流程

```
输入: 谜题字符串 "53..7...."

  ↓  parse()

Grid: {'A1': '5', 'A2': '3', 'A3': '123456789', ...}
      （已知格只有 1 个候选，未知格有全部 9 个候选）

  ↓  constrain()

Grid: {'A1': '5', 'A2': '3', 'A3': '4', ...}
      （通过约束传播，大量格子被确定）

  ↓  search()
      （如果还有未确定的格子，用 DFS + 约束传播继续推）

  ↓

Solution: 每个格子恰好 1 个数字

  ↓  is_solution() 验证

✅ 完成
```

---

## 6. 性能表现

Norvig 的测试结果（Python，单核）：

| 测试集 | 数量 | 耗时 | 平均每题 |
|--------|------|------|---------|
| 常规题目 | 10,000 | 27.2s | ~2.7ms |
| 最难题目 | 10 | 34.3ms | ~3.4ms |
| 空棋盘 | 1 | 瞬间 | <1ms |

**对比他自己的 Java 版本**：100,000+ 题/秒（得益于多线程 + 位运算数据结构 + JVM 优化）。

关键结论：**约束传播把搜索空间从 10^38 压缩到可以秒解的程度**。

---

## 7. Norvig 的设计取舍与思考

Norvig 在文末坦诚讨论了他"没走的路"，这些思考本身就很有教学价值：

### 7.1 为什么 Digit 是 `str` 不是 `int`？

- 数独数字不需要做加减乘除，只需要唯一性
- 用 `str` 可以直接拼接成 DigitSet：`'123'` 比 `{1, 2, 3}` 更紧凑

### 7.2 为什么 DigitSet 是 `str` 不是 `set` 或 `int` 位图？

| 方案 | 优点 | 缺点 |
|------|------|------|
| `str` '123' | 紧凑可读，拷贝是 O(1)（不可变） | 集合运算不够快 |
| `set` {1,2,3} | 原生集合操作 | Grid 拷贝需要 deepcopy |
| `int` bitset | 最快，位运算 | 不直观，调试困难 |

Norvig 选了可读性。Java 版选了位图（追求性能）。

### 7.3 为什么 Grid 是 `Dict` 不是二维数组？

- `Dict` 的 `.copy()` 是浅拷贝，因为值（`str`）是不可变的
- 二维数组需要 `deepcopy`
- `grid['C2']` 比 `grid[2][1]` 更可读

### 7.4 为什么没有实现更多解题技巧？

Norvig 原文：

> 我们可以尝试加更多约束传播策略（X-Wing、Swordfish...），
> 但策略太多，每个都增加代码复杂度，
> 而且即使全部实现了，也不能**保证**解决所有谜题。
> 
> 用搜索（DFS）兜底，两条策略 + 搜索就够了。

这是工程上的极简主义：**用最少的代码覆盖 100% 的情况**。

---

## 8. 我的评价与思考

### 8.1 这份代码的精妙之处

**1. 以 `eliminate` 为核心的递归设计**

大多数人会把 `fill`（填数）作为基本操作，Norvig 反过来把 `eliminate`（消除）作为基础。
这使得两条策略可以自然地互相递归触发，代码量极少却覆盖了连锁推导的全部场景。

**2. 约束传播和搜索的交替**

不是"先传播完再搜索"，而是每次猜测立刻传播。
这把看似不可能的 10^38 搜索空间压缩到几十次猜测就能解完。

**3. 数据结构为"正确性+可读性"服务**

用 `str` 而不是位图，用 `Dict` 而不是数组。
虽然性能不是最优，但代码清晰度极高，80 行搞定一切。
这是教学代码的典范。

### 8.2 局限性

**1. 无法给出解题过程**

Norvig 的代码是面向"机器"的——只关心最终答案，不关心中间步骤。
对于一个数独 App，我们需要能告诉玩家"下一步该怎么走"，需要能识别具体使用了哪种技巧。

**2. 不区分难度**

代码不知道一道题是"简单"还是"地狱"——它用同样的方式解所有题。
我们的 App 需要评估难度，这要求记录解题过程中用了哪些技巧。

**3. 搜索（猜测）不是人类技巧**

当约束传播推不动时，Norvig 直接猜。但人类玩家不应该需要"猜"——
一道好的数独应该完全通过逻辑推导解出。
如果我们的提示系统说"这一步需要猜"，那是题目质量的问题。

**4. Python 性能有限**

2.7ms/题在 Python 中已经很快，但如果要在手机上实时生成+验证大量数独，
用位运算 + 编译型语言（或 ArkTS 中的类似优化）会更好。

### 8.3 Norvig 自己对这个项目的评价

Norvig 引用了安全专家 Ben Laurie 的话：

> "数独是对人类智力的拒绝服务攻击。"

他写这个程序的初衷是想告诉身边沉迷数独的人：看，电脑 80 行代码就能秒解，
你们不用再浪费时间了。结果——没人听他的，但至少有一个陌生人写信说因此戒了数独。

---

## 9. 对我们数独 App 的启示

### 9.1 直接可用的部分

| Norvig 的设计 | 在我们 App 中的用途 |
|--------------|-------------------|
| 预计算 peers/units | 完全照搬，用于冲突检测和候选数计算 |
| `constrain` + `search` | 作为求解器内核，用于：验证唯一解、生成题目时挖洞验证 |
| MRV 启发式 | 搜索时使用 |

### 9.2 需要扩展的部分

| 需求 | Norvig 没有 | 我们需要做 |
|------|-----------|----------|
| 提示系统 | 只有 Naked/Hidden Single | 实现更多人类技巧（Naked Pair、X-Wing 等） |
| 难度评估 | 无 | 记录解题用了哪些技巧，加权评分 |
| 解题步骤 | 只返回最终结果 | 每步记录：在哪个格子、用了什么技巧、推导出什么 |
| 数据结构 | `Dict[str, str]` | 用位运算（flags + notes 位图），适合 UI 渲染和性能 |

### 9.3 架构建议

```
我们的求解器应该分两层：

1. 逻辑求解器（给玩家看的）
   - 按难度递进尝试各种人类技巧
   - 记录每一步用了什么技巧
   - 用于：提示系统、难度评估
   - 如果所有技巧都推不动 → 说明题目太难或需要猜测

2. 暴力求解器（Norvig 风格，给机器用的）
   - 约束传播 + DFS
   - 用于：验证唯一解、生成题目、快速求解
   - 不关心过程，只关心结果和解的数量
```

这样既能给玩家提供有意义的提示和难度评估，
又能在后台高效完成生成和验证。
