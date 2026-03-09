# 🧠 Norvig 数独解法深度解析

> 基于 [Peter Norvig](https://norvig.com/) 的 [Sudoku.ipynb](https://github.com/norvig/pytudes/blob/main/ipynb/Sudoku.ipynb)。
> 约 80 行 Python 解决任意数独。本文逐层拆解其设计思路，理解**为什么**这么写，而不只是**怎么**写。

---

## 一、Norvig 方法的核心直觉

朴素回溯是"盲猜 + 错了就退"，Norvig 的方法是"尽量不猜，逼不得已再猜"：

```
约束传播（Constraint Propagation）— 像人一样推导，能确定的先确定
         +
深度优先搜索（DFS）           — 推不动了，挑一个格子猜，递归下去
```

**关键洞察**：这两者不是分阶段的，而是**交替进行**的——

1. 先把已知数字的约束传播完
2. 遇到传播不动了，选一个格子猜一个数
3. 猜完以后**立刻再做一轮约束传播**
4. 新一轮传播可能又推导出一大片
5. 又推不动了？再猜一个……

这就是 Norvig 方法和朴素回溯的**根本区别**。朴素回溯每次只填一个数然后检查合法性，而 Norvig 的每次"猜"都会触发一场**雪崩式的连锁推导**，一个数字确定了可能导致十几个格子跟着确定。大多数简单/中等题，只需要初始传播一轮就直接解完，搜索树深度为 0。

---

## 二、数据结构——极简但精妙

### 2.1 格子命名

```python
rows = 'ABCDEFGHI'
cols = '123456789'
squares = cross(rows, cols)  # ['A1', 'A2', ... 'I9']，共81个字符串
```

用**字符串** `'C2'` 表示一个格子，不用 `(2, 1)` 这样的坐标。看起来是个小选择，但后面你会发现它让代码极其可读——`grid['C2']` 比 `grid[2][1]` 直观得多。

### 2.2 候选集也是字符串

```python
grid['C2'] = '139'    # C2 的候选数是 1、3、9
grid['A1'] = '7'      # A1 已确定是 7
```

为什么用字符串不用集合、不用位图？三个理由：

**① 不可变性 → 浅拷贝就够用**

Python 的 `str` 是不可变的。`eliminate` 中的 `grid[s] = grid[s].replace(d, '')` 其实是创建了一个**新字符串**并重新绑定到 `grid[s]`，原字符串不受影响。这意味着 `grid.copy()` 做的浅拷贝就完全安全——不需要 `deepcopy`。这一点在搜索回溯时至关重要（第五节详述）。

**② 可读性极强**

```python
'7' in grid['C2']        # C2 的候选中有没有 7？
grid['C2'].replace('7', '')  # 从候选中移除 7
len(grid['C2'])          # 还有几个候选？
len(grid['C2']) == 1     # 是否已确定？
```

直接 `print(grid)` 就能看到每个格的候选，调试极方便。对比位图版本 `(candidates >> 7) & 1`——正确但不直观。

**③ 语法天然契合**

`d in grid[s]`、`grid[s].replace(d, '')`、`len(grid[s])` 都是一行搞定，不需要辅助函数。

> **代价**：字符串操作比位运算慢得多。但 Norvig 的目标是 80 行解数独，不是写最快的解法。追求极致性能时才换位图（如 Java 版可达 10 万题/秒）。

### 2.3 拓扑结构——预计算一次，查表无数次

```python
# 27 个单元（unit）：9行 + 9列 + 9宫
all_units = (
    [cross(r, cols) for r in rows] +        # 9 行
    [cross(rows, c) for c in cols] +        # 9 列
    [cross(rs, cs) for rs in ('ABC','DEF','GHI')
                    for cs in ('123','456','789')]  # 9 宫
)

# 每个格子属于哪 3 个单元
units = {s: [u for u in all_units if s in u] for s in squares}

# 每个格子的 20 个同伴（同行+同列+同宫，去重去自己）
peers = {s: set(sum(units[s], [])) - {s} for s in squares}
```

这些在程序启动时算一次就好。之后求解时 `peers['C2']` 直接查表，O(1)。

**为什么是 20 个 peers？** 同行 8 个 + 同列 8 个 + 同宫 8 个 = 24，但同行同宫有 2 个重叠、同列同宫有 2 个重叠，去重后 24 - 4 = **20** 个。你可以自己数一下 C2 的 peers：

```
同行: C1 C3 C4 C5 C6 C7 C8 C9        (8个)
同列: A2 B2 D2 E2 F2 G2 H2 I2        (8个)
同宫: A1 A2 A3 B1 B2 B3 C1 C3        (8个，但 A2,B2 已在同列，C1,C3 已在同行)
去重去自己 → 20个
```

---

## 三、约束传播——两条简单规则引发连锁反应

整个约束传播只用了两条策略：

| # | 策略名 | 人话 | 形式化 |
|---|-------|------|--------|
| 1 | **Naked Single**（裸单数）| 一个格子只剩一个候选了，那它就是这个数 | `len(grid[s]) == 1` → 从所有 peers 消除该数 |
| 2 | **Hidden Single**（隐性单数）| 一个单元里某个数字只有一个格子能放了 | `len(dplaces) == 1` → 把该数填入该格 |

就这两条。但它们**互相触发**，形成连锁反应：

```
填入 C2=7
  → Naked Single：从 C2 的 20 个 peers 中消除 7
    → 其中 C5 本来候选是 '37'，消除 7 后变成 '3'
      → C5 确定了！又触发 Naked Single，从 C5 的 peers 中消除 3
        → A5 本来候选是 '13'，消除 3 后变成 '1'
          → A5 确定了！继续传播……
    → 同时，第2列 unit 中，数字 7 只剩一个位置能放了
      → Hidden Single 触发，把 7 填入那个位置
        → 又触发新的 Naked Single……
```

一次 `fill` 操作可能**连锁出几十步推导**。这就是为什么很多简单题只需要初始一轮传播就直接解完。

### 3.1 `eliminate` 是一切的基石

Norvig 没有分别实现 `nakedSingle()` 和 `hiddenSingle()` 两个函数。他只写了一个 `eliminate()`，在里面**同时检查两条策略**：

```python
def eliminate(grid, s, d):
    """从格子 s 的候选中移除数字 d，并传播所有后果"""

    # 前置检查：d 已经不在候选中了，不用做什么
    if d not in grid[s]:
        return grid

    # 移除候选
    grid[s] = grid[s].replace(d, '')
    remaining = grid[s]

    # ❌ 候选清空 → 走进死胡同，矛盾了
    if len(remaining) == 0:
        return None

    # --- 策略 1：Naked Single ---
    # 这个格子只剩一个候选了 → 确定了 → 从所有 peers 中消除
    if len(remaining) == 1:
        d2 = remaining  # 确定的数字
        for s2 in peers[s]:
            if not eliminate(grid, s2, d2):  # 递归！消除可能引发新的确定
                return None                   # 传播过程中发现矛盾

    # --- 策略 2：Hidden Single ---
    # 检查 s 所在的每个 unit：d 还有哪些格子能放？
    for u in units[s]:
        dplaces = [sq for sq in u if d in grid[sq]]
        if len(dplaces) == 0:
            return None                      # ❌ 这个 unit 里 d 无处可放
        if len(dplaces) == 1:
            # d 在这个 unit 里只有一个位置能放 → 填进去
            if not fill(grid, dplaces[0], d):  # fill 又会触发一轮 eliminate
                return None

    return grid  # ✅ 传播成功，没有矛盾
```

仔细看这段代码——**策略 1 调用 `eliminate`（递归），策略 2 调用 `fill`，而 `fill` 又会调用 `eliminate`**。这形成了一个精密的递归网络，所有连锁反应都在这里面自动展开。

### 3.2 `fill` 只是 `eliminate` 的马甲

```python
def fill(grid, s, d):
    """在格子 s 填入数字 d = 把 s 的候选中除了 d 以外的全部 eliminate"""
    other_digits = grid[s].replace(d, '')
    if all(eliminate(grid, s, d2) for d2 in other_digits):
        return grid
    return None
```

这个视角翻转非常优雅——`fill` 不是"写入"一个数，而是"**消除其他所有候选**"。一切操作都归结为 `eliminate`，一个函数搞定所有传播逻辑。

### 3.3 连锁反应的递归树

```
eliminate(C2, '7')
├── C2 候选 '37' → '3'，只剩1个 → Naked Single 触发
│   ├── eliminate(A2, '3')
│   │   ├── A2 候选 '1389' → '189'，还有3个 → 不触发 Naked Single
│   │   ├── 行A unit: '3' 还有 A4, A7 能放 → 不触发 Hidden Single
│   │   ├── 列2 unit: '3' 只剩 F2 → fill(F2, '3') ← Hidden Single!
│   │   │   ├── eliminate(F2, '1')
│   │   │   ├── eliminate(F2, '5')
│   │   │   │   └── 宫5 unit: '5' 只剩 E4 → fill(E4, '5') → ...
│   │   │   └── eliminate(F2, '8')
│   │   └── 宫1 unit: '3' 还有 B1, B3 → 不触发
│   ├── eliminate(C1, '3') → ...
│   ├── eliminate(C3, '3') → ...
│   └── ... (C2 的所有 20 个 peers)
├── 行C unit: '7' 还有 C4, C7, C9 → 多于1个，不触发 Hidden Single
├── 列2 unit: '7' 还有 E2, G2 → 不触发
└── 宫1 unit: '7' 还有 A1, B3 → 不触发
```

**这棵树可以非常深**——一个 `eliminate` 可能引发十几层递归。这正是约束传播的威力所在。

### 3.4 矛盾检测是传播的副产品

注意 `eliminate` 在两个地方返回 `None`：
- 候选清空了（`len(remaining) == 0`）——这个格子没数可填了
- 某个 unit 里某个数字无处可放了（`len(dplaces) == 0`）——违反数独规则

不需要单独写一个 `validate()` 函数——**矛盾检测是传播过程的天然副产品**。搜索时猜错了一个数，传播过程中自然会发现矛盾并一路返回 `None`。

---

## 四、初始化——从题目字符串到约束传播后的 grid

```python
def constrain(grid_string):
    """把 81 字符的题目字符串转化为约束传播后的 grid"""
    # 一开始每个格都有全部候选
    grid = {s: '123456789' for s in squares}

    # 逐个填入已知数字（. 或 0 表示空格）
    for s, d in zip(squares, grid_string):
        if d in '123456789':
            if not fill(grid, s, d):     # 填入 + 传播
                return None               # 题目本身就矛盾

    return grid
```

注意返回的 grid **已经经过了一轮完整的约束传播**。对于简单题，这一步就直接解完了——所有 81 个格子都只剩 1 个候选。

---

## 五、深度优先搜索——推不动时的最后手段

```python
def search(grid):
    """约束传播解不完的，搜索来兜底"""
    if grid is None:
        return None                          # 此前传播时发现矛盾

    if all(len(grid[s]) == 1 for s in squares):
        return grid                          # 🎉 全部确定，解出来了！

    # MRV 启发式：选候选最少的未确定格
    s = min((s for s in squares if len(grid[s]) > 1),
            key=lambda s: len(grid[s]))

    # 逐个尝试这个格子的每个候选
    for d in grid[s]:
        result = search(fill(grid.copy(), s, d))  # copy！
        if result:
            return result                    # 找到解了
    return None                              # 所有候选都试过了，此路不通
```

只有 10 行，但每一行都值得细看。

### 5.1 MRV 启发式——看似小技巧，效果巨大

MRV = Minimum Remaining Values，选候选数最少的格来猜。

直觉很简单：
- 一个格有 2 个候选？猜对概率 **50%**
- 一个格有 7 个候选？猜对概率 **14%**

但搜索树的大小差异远不止概率——假设要猜 10 个格子：

| 每格候选数 | 搜索树节点数 | 量级 |
|-----------|------------|------|
| 2 | 2¹⁰ = 1,024 | 一千 |
| 3 | 3¹⁰ = 59,049 | 六万 |
| 7 | 7¹⁰ = 282,475,249 | **两亿八** |

选候选少的格先猜，搜索树规模差了**几十万倍**。

实践中，经过约束传播后，大多数未确定格只有 2-3 个候选，加上传播的剪枝效果，最难的数独通常也只需要几十次猜测。

### 5.2 `grid.copy()` 的精妙之处

```python
result = search(fill(grid.copy(), s, d))
```

这里 `grid.copy()` 是整个搜索能正确回溯的关键。

**为什么要复制？** `fill` → `eliminate` 会原地修改 grid（`grid[s] = ...`）。如果我们猜 `d='3'` 猜错了，grid 已经被传播过程改得面目全非了。没有备份就没法退回去试 `d='5'`。

**为什么浅拷贝够用？** 因为 grid 的值是 `str`（不可变的）。`grid.copy()` 复制的是 dict 结构——key 和 value 的引用。之后 `eliminate` 中 `grid[s] = grid[s].replace(d, '')` 创建了**新字符串**并绑定到新 dict 上，原 dict 里的旧字符串不受影响。

```
原 grid:   {'C2': '139', 'A1': '7', ...}
copy grid: {'C2': '139', 'A1': '7', ...}   ← 指向同一批 str 对象

fill(copy_grid, 'C2', '1'):
  copy_grid['C2'] = '1'    ← copy_grid 指向新 str '1'
  原 grid['C2'] 仍然是 '139'  ← 不受影响！
```

如果值是可变的（比如 `list` 或 `set`），浅拷贝后两个 dict 会**共享同一个 list 对象**，修改一个另一个也变了。就得用 `deepcopy`，性能差很多。

> 这也是 Norvig 选 `str` 作为候选集的一个**隐藏理由**——不只是为了可读性，更是为了让搜索回溯的成本最低。

### 5.3 搜索的实际代价

| 测试集 | 平均耗时（Python）| 说明 |
|-------|-----------------|------|
| 简单/中等题 | < 1ms | `constrain` 一步就解完，搜索深度 = 0 |
| 常规题库 | ~2.7ms/题 | 少量搜索 |
| 最难题目（如 Arto Inkala） | ~3.4ms/题 | 几十次猜测 |
| Java 位图版 | 10μs/题 | 10 万+题/秒，性能上限 |

约束传播把理论上 $9^{81} ≈ 10^{77}$ 的搜索空间压缩到几十次猜测就能解完。

---

## 六、为什么只用两条策略？

你可能会问：人类玩家会用 Naked Pair、X-Wing、Swordfish、Coloring 等高级技巧，为什么 Norvig 一条都不加？

**答案是极简主义**：

1. **两条策略 + DFS 就能 100% 解所有数独**——DFS 是万能兜底
2. 加更多策略只能**减少搜索量**（已经很少了），不能增加**覆盖面**
3. 代码从 80 行膨胀到几百行，复杂度急剧上升
4. 对于 Norvig 的目标（证明约束传播+搜索的威力），这已经是最优解

但对于我们的 App，情况完全不同：

| 需求 | Norvig 能给的 | 我们需要的 |
|------|-------------|-----------|
| 验证解是否存在 | ✅ 直接用 `search` | ✅ |
| 验证唯一解 | ✅ 跑两次看有没有第二个解 | ✅ |
| 给玩家提示 | ❌ "电脑猜出来的" | "这里用了 X-Wing 技巧" |
| 评估难度 | ❌ 没有难度概念 | 记录用了哪些技巧 → 加权评分 |
| 教学功能 | ❌ 机器视角 | 按人类思路逐步推导 |

所以我们需要**两层求解器**（详见 Doc 01 §6）：

| 层 | 角色 | 风格 | 来源 |
|---|------|------|------|
| 暴力求解器 | 给机器用 | Norvig 风格，只要结果 | 直接移植 |
| 逻辑求解器 | 给玩家用 | 按技巧递进，记录每步 | 需要额外开发 |

---

## 七、从 Python 到 ArkTS：关键转译

把 Norvig 的 Python 代码移植到我们的 ArkTS App 时，核心转换如下：

### 数据结构转换

| Python (Norvig) | ArkTS (我们) | 为什么变 |
|-----------------|-------------|---------|
| `grid: Dict[str, str]` | `candidates: number[]` (长度81) | ArkTS 无 dict 语法糖，数组+下标更自然 |
| 候选集 `'139'` (str) | `0b1000001010` (9位位图) | 位运算更快，无 str.replace |
| 格子 `'C2'` (str) | `index = row*9+col` (number) | 数组下标访问 |
| `peers['C2']` → set | `PEERS[19]` → `number[]` | 预计算数组 |

### 操作转换

| 操作 | Python | ArkTS |
|------|--------|-------|
| d 在候选中？ | `d in grid[s]` | `(cands[i] >> d) & 1` |
| 从候选移除 d | `grid[s] = grid[s].replace(d, '')` | `cands[i] &= ~(1 << d)` |
| 只剩1个候选？ | `len(grid[s]) == 1` | `popcount(cands[i]) === 1` |
| 候选清空？ | `len(grid[s]) == 0` | `cands[i] === 0` |
| 复制 grid | `grid.copy()` | `cands.slice()` (值是 number，浅拷贝够) |
| 表示矛盾 | `return None` | `return false` |

> 有意思的是，Norvig 选 `str` 的理由（不可变→浅拷贝安全）在我们这里也成立——`number` 是值类型，`cands.slice()` 就是安全的浅拷贝。

---

## 八、总结——80 行代码里的五个深刻设计

1. **一切归结为 `eliminate`**：不分别实现两条策略，所有传播逻辑在一个递归函数里自然展开
2. **不可变值 + 浅拷贝**：用 `str` 而非 `set`，让回溯几乎零成本
3. **约束传播和搜索交替进行**：不是"先传播完再搜索"，而是"猜一步传播一步"，极大压缩搜索空间
4. **MRV 启发式**：一个 `min()` 调用，搜索树规模从亿级降到千级
5. **极简策略 + DFS 兜底**：只用两条规则就能 100% 覆盖所有数独

理解了这些设计背后的**为什么**，我们就知道在 App 里该继承什么（拓扑预计算、暴力求解器、MRV、浅拷贝策略），该扩展什么（人类技巧库、步骤记录、位图数据结构、难度评分系统）。
