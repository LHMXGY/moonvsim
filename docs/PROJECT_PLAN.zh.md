# moonvsim 项目计划书

**2026 MoonBit 黑客松 · 十一月赛（第二赛季度 11 月—次年 1 月）**

> 一句话：在 MoonBit 里补上唯一缺失的那块地基——一个能被 Icarus Verilog 逐断言差分验证的四态事件驱动 Verilog RTL 仿真内核，同一份内核同时驱动命令行与浏览器波形。

| 项 | 内容 |
| --- | --- |
| 项目名 | moonvsim |
| 方向 | 开发者工具（04）· 兼跨工具库（01） |
| 公开仓库 | <https://github.com/LHMXGY/moonvsim> |
| 在线演示 | <https://lhmxgy.github.io/moonvsim/>（国内网络可能不可达，仓库内 `web/demo.html` 为离线单文件版） |
| 许可证 | Apache-2.0 |
| 主要实现语言 | MoonBit（占比 100%，无其他语言实现核心逻辑） |
| 当前状态 | MVP 可用：40 个设计 / 113 条断言 / 0 处分歧，CI 全绿 |
| 申报日期 | 2026-11-07 |

---

## 0. 一页项目说明（用于报名表）

MoonBit 生态已经有 Verilog **检查器**（`moonbit-rtl`，两个独立实现）、VCD **读取器**（`moonbit-vcd`、`minivcd_mbt`）、模拟电路求解器（`moonbit-circuit-solver`）、Gerber 工具链、MCU HAL、EtherCAT 主站，但没有任何一个能**把数字电路跑起来**的执行内核。两个 linter 的 README 都自己写明了这一点：「not a synthesizer, simulator, or replacement for a complete IEEE Verilog implementation」。

moonvsim 补的就是这块地基：一个 MoonBit 原生的 Verilog-2001 四态（0/1/x/z）事件驱动 RTL 仿真器。它包含词法、语法、层次展开（参数覆盖、端口绑定）、分层事件调度（阻塞/非阻塞赋值、delta 环、组合逻辑不动点）、VCD 波形输出，以及一个零依赖的浏览器波形查看器。内核不依赖任何 I/O，因此同一份代码既能编译成 native CLI，也能编译成 wasm 在浏览器内仿真。

质量不靠自证，靠外部 oracle：**40 个自检式测试平台、113 条断言，与 Icarus Verilog 13.0 逐条比对，0 处分歧**，并接入 GitHub Actions 每次提交自动复验。性能如实公开：20,000 时钟周期约 0.5 秒（≈3.8 万周期/秒），比 Icarus 慢约 7 倍，下一步用字节码化消除按名解析来收敛差距。

它解决的是真实需求：想在 MoonBit 里写硬件、写 DSL、写教学材料或做 CI 里的 RTL 冒烟测试，今天只能装一套 Verilog 工具链；有了 moonvsim，`moon add moonvsim` 就能在 MoonBit 进程内跑仿真。

---

## 1. 选题依据：为什么是「数字 RTL 仿真内核」

### 1.1 生态现状

选题不是想出来的，是在 mooncakes.io（3,618 个模块 / 32,384 个包 / 1,100 万次下载）上按关键词逐个查出来的。EDA 相关的相邻能力已经齐全，唯独缺执行核心：

| 能力 | 生态现状 | 说明 |
| --- | --- | --- |
| Verilog 静态检查 | `dtzrttp/moonbit-rtl`(67)、`yzfyzf12345678/moonbit-rtl`(57) | 两者 README 明确声明「不是仿真器」 |
| VCD 波形读取 | `lqhy1234567/moonbit-vcd`(46)、`alicedhaha/minivcd_mbt`(63) | 能读能 diff，但不能产生波形 |
| 模拟电路仿真 | `hsy-bit/moonbit-circuit-solver`(41)、`pzq893/moonbit-spice`(34) | SPICE 改进节点法，模拟域 |
| Gerber / PCB | `Mgk789a/moonbit-gerberkit`(44) | 制造文件 |
| MCU / 总线 | `sbqrre/moonbit-mcu-hal`(41)、`MoonECAT`（EtherCAT 主站） | 面向真实硬件 |
| RISC-V | `MoonRV Lab`（反汇编/CFG/执行） | 指令级，不是 RTL 级 |
| **数字 RTL 仿真** | **无** | 本项目的缺口 |

### 1.2 关键词检索证据

在 mooncakes.io 上以同义词组逐一检索（完整记录见 `docs/ECOSYSTEM.zh.md` 附录 A）：

| 关键词 | 结果 |
| --- | --- |
| `verilog` | 4 个：两个 linter、一个 tree-sitter 语法、一个 VCD 工具 |
| `vhdl` / `verilator` / `yosys` / `testbench` / `rtlsim` / `vsim` | 0 |
| `simulate` / `simulation` | 只有 DES/网络/离散事件通用仿真器，无 RTL |
| `netlist` / `circuit` | 只有 SPICE 类与电路计算类 |
| GitHub 仓库检索 `moonbit rtl simulation` / `moonbit iverilog` / `moonbit vcd simulator` | 0 |
| GitLink `moonbit 仿真` | 仅 `lqhylqhy/moonbit-vcd` |

同时按赛事要求做了「避免重复提交」的排查：GitHub 上 `moonbit verilog` 仅 2 个 lint 项目（均 2026-08-24 之后创建），GitLink 355 个 MoonBit 项目中没有 RTL 仿真器，SCC 展示墙 30 个项目 + 10 个初赛入围里也没有。

### 1.3 与相邻项目的边界

| 项目 | 做什么 | 与本项目的关系 |
| --- | --- | --- |
| `moonbit-rtl` ×2 | 语法/结构静态检查 | 上游：本项目可消费其诊断，不做重复 |
| `moonbit-vcd` | 读 VCD、四态位运算、trace diff | 互补：它是「读」，本项目是「产生」，其 diff 能力可做二次校验 |
| DigitalJS（JS 生态） | 浏览器内 RTL 仿真 | 同类先例：本项目在计划书中公开引用，差异在于 MoonBit 原生 + CLI/wasm 同源 + 差分验证 |
| `wcx789ll/moonsim` 等 | 离散事件仿真框架 | 通用框架，不含 Verilog 前端与 RTL 语义 |

### 1.4 结论

缺口不在「描述电路」（已有 linter、语法树），而在「**执行电路**」。这是一个边界清晰、可在一个月内交付并被外部工具验证的系统型软件选题，符合赛事「优先选择边界清晰、能够在一个月内交付并验证的项目」的建议。

---

## 2. 项目目标与范围

### 2.1 V1 目标（可验证）

1. 支持 Verilog-2001 可综合子集 + 常用测试平台语法的解析与执行。
2. 输出标准 VCD，任何波形查看器可打开。
3. 与 Icarus Verilog 在**全部**自检式测试设计上逐断言一致。
4. 单一内核可编译为 native / wasm / js 三后端。
5. 提供 CLI 与浏览器演示，零安装可用。

### 2.2 范围内（IN SCOPE）

- 四态位向量 1–64 bit，x/z 传播，四则/位/归约/移位/比较/拼接/复制/位选/部分选择。
- 模块、层次实例化、`parameter`/`localparam` 覆盖、命名与位置端口连接。
- `wire`/`reg`/`integer`/`logic`（作为 reg 别名），`signed`/`unsigned`，声明初始化。
- `assign` 连续赋值、`always @(...)`（含 `*`）、`initial`。
- 阻塞/非阻塞赋值、`if`/`case`/`for`/`while`/`repeat`、`#delay`、`@(posedge/negedge)`。
- `$display`/`$write`/`$finish` 与常用格式符。
- VCD 输出、CLI（`run --top --vcd --max-time`）、浏览器波形查看器。

### 2.3 范围外（明确不做，写进 README）

- SystemVerilog 语法、类、断言；UDP；`specify` 块；`fork`/`join`；`real`；`function`/`task` 的执行（语法可解析）。
- 综合、布局布线、形式验证。

### 2.4 成功判据

| 判据 | 目标值 | 当前 |
| --- | --- | --- |
| 差分断言数 | ≥ 100 | 113 ✅ |
| 分歧数 | 0 | 0 ✅ |
| 单元测试 | ≥ 30 | 33 ✅ |
| 三后端可编译 | native / wasm-gc / js | ✅（CI 每提交验证） |
| CI 绿 | 每提交 | ✅ 连续通过 |
| 可运行示例 | ≥ 5 | 6 ✅ |

---

## 3. 技术方案

### 3.1 架构

```text
        .v 源文件
            │
      ┌─────▼─────┐   src/lexer   记号流（含四态字面量、最长匹配运算符表）
      │   lexer   │
      └─────┬─────┘
      ┌─────▼─────┐   src/parser  递归下降 + 优先级爬升，产出 src/ast
      │  parser   │
      └─────┬─────┘
      ┌─────▼─────┐   src/elaborate  层次展开：参数覆盖、端口绑定、位宽、符号性
      │ elaborate │                  → Netlist（信号表 / 作用域 / 进程 / 连续赋值）
      └─────┬─────┘
      ┌─────▼─────┐   src/sim   分层事件调度：就绪队列 → NBA 提交 → 组合不动点 → 边沿
      │    sim    │             （内核无 I/O，可跑 native / wasm / js）
      └──┬─────┬──┘
         │     └──────────► src/vcd  VCD 写出（层次 $scope、$var、值变化）
         │
    ┌────▼─────┐
    │ src/cmd  │  CLI：run --top --vcd --max-time
    └──────────┘
```

### 3.2 四态位平面表示

一个 `Bits` 用三个 `UInt64` 平面编码 1–64 位四态值：

| 平面 | 含义 |
| --- | --- |
| `val` | 已知位的值（1 表示该位为 1） |
| `unk` | 未知位掩码（x） |
| `zed` | 高阻位掩码（z） |

好处：按位与/或/非/移位全部是单条整数指令；四态传播规则集中在 `src/value/bits.mbt`，可以用单元测试穷举验证，而不是散落在求值器里。

### 3.3 分层事件调度

每一轮 delta 依次执行：

1. `snapshot()` 保存当前值用于边沿检测；
2. 运行所有就绪进程，直到遇到等待（时间等待 / 边沿等待）；
3. 提交非阻塞赋值（NBA）；
4. `settle()`：连续赋值与组合进程迭代到不动点（`dirty` 标志驱动）；
5. `trace()` 写出变化；
6. 唤醒边沿等待者，进入下一轮 delta。

设计上的三个关键决定：

- **确定性**：进程按 lowering 顺序执行，同名设计每次运行结果逐字节一致，便于 diff。
- **防挂死**：delta 轮数上限 1000，组合环直接报错而不是把 CPU 吃满。
- **NBA 语义**：非阻塞赋值在 delta 结束时统一提交，保证 `a<=b; b<=a;` 真正交换。

### 3.4 位宽与符号性语义

严格按 IEEE 1364 实现求值上下文：

- 算术/位运算的结果位宽 = max(左, 右, 上下文位宽)，因此 `assign s[8:0] = a + b;` 的进位不会丢。
- 比较运算只产出 1 位，且只有**两侧都是 signed** 才按有符号比较（§5.1.4）。
- 移位保留左操作数位宽；拼接是自决定宽度，再按上下文截断。
- 无尺寸十进制字面量是 signed 的 32 位值（§3.5.1）。

这些规则是差分测试中被 Icarus 抓出来的地方：早期版本用 `a.signed || b.signed` 判符号性，导致 `-1 < 0` 类断言在混合符号下出错，已修正并补了回归设计。

### 3.5 可跨后端的内核

`src/sim` 不引用文件系统、时钟或进程 API，只接受 `Netlist` 并返回消息与 VCD 文本。CLI 层（`src/cmd`）负责读文件、写文件；浏览器层只需要把同一份内核编译成 wasm-gc。这条约束是刻意的：赛事方向里「解释器/运行时/开发体验工具」最容易被做成只能跑在一种后端上的脚本，而 MoonBit 的多后端是它的核心卖点，不该浪费。

### 3.6 差分验证方法学（本项目的质量核心）

自证式测试不可靠，因此所有语义断言都交给外部 oracle：

```text
conformance/t_*.v  ──┬──► moonvsim run --top <t> --max-time 5000 ──► 解析 PASS/FAIL 行 ─┐
                     │                                                              ├─► 逐断言比对
                     └──► iverilog -g2005 -o x.vvp -s <t> && vvp x.vvp ─────────────┘
```

- 每个设计打印 `PASS <name>` / `FAIL <name> <detail>` 并以 `$finish` 结束。
- 脚本比较两侧的「断言名 → 通过与否」集合，任何一侧缺项也算分歧。
- 结果写 `conformance/report.json` 与 `conformance/REPORT.md`，CI 上传为构建产物。
- 已发现的真实缺陷包括：`~&`/`~|`/`~^` 丢失取反、声明初始化被展开阶段丢弃、`wire signed` 触发解析死循环、无尺寸字面量符号性错误。

---

## 4. 当前进展（截至 2026-11-07）

### 4.1 已交付能力

| 能力 | 状态 |
| --- | --- |
| 四态位向量 1–64 位，x/z 传播 | 完成 |
| 词法：字面量、注释、转义标识符、全部运算符 | 完成 |
| 语法：模块/端口/参数/语句/实例 | 完成 |
| 展开：层次、参数覆盖、端口绑定、位宽、符号性 | 完成 |
| 分层调度：delta 环、NBA、组合不动点 | 完成 |
| 语句：阻塞/非阻塞、`if`/`case`/`for`/`while`/`repeat` | 完成 |
| 时序：`#delay`、边沿、`always @(posedge/negedge/*)` | 完成 |
| `$display`/`$write`/`$finish` 与格式符 | 完成 |
| VCD 写出（层次、id、变化） | 完成 |
| CLI | 完成 |
| 浏览器波形查看器（零依赖、离线单文件） | 完成 |
| 差分一致性套件 | 完成 |

### 4.2 质量证据

| 指标 | 数值 |
| --- | --- |
| 单元测试 | 33 / 33 通过 |
| 差分设计 | 40 |
| 差分断言 | 113，0 分歧（参考 Icarus Verilog 13.0） |
| 可运行示例 | 6（计数器、ALU、层次、交通灯 FSM、波形演示、基准） |
| CI | 每提交：`moon test` → 三后端 `moon check` → native release → 差分 → 基准 → 产物上传 |
| 提交数 | 19（含 5 次 fix/chore，全部可追溯） |

### 4.3 性能基线（如实记录）

| 仿真器 | 20,000 周期耗时 | 周期/秒 |
| --- | --- | --- |
| moonvsim（native release） | ≈ 0.5 s | ≈ 3.8 万 |
| Icarus Verilog 13.0 | ≈ 0.07 s | ≈ 27 万 |

两者最终状态完全一致（`sum=26dfe118 prod=4c9b18d7`）。差距来自求值时按名字解析标识符，已立项（issue #1）用字节码化收敛。

### 4.4 提交节奏

提交按「一个可验证能力一次提交」组织：脚手架 → AST → 词法 → 语法 → 展开 → 调度器 → VCD+CLI → 示例 → 语义修正 → 差分套件 → 波形查看器 → 文档 → 基准 → CI。评审核对时可以直接按 commit 顺序复现研发过程。

---

## 5. 里程碑与排期

### 5.1 总览

| 里程碑 | 时间 | 交付 | 验收方式 |
| --- | --- | --- | --- |
| M0 选题与生态调查 | 11/01–11/07 ✅ | 关键词调查报告、淘汰表 | `docs/ECOSYSTEM.zh.md` |
| M1 内核最小闭环 | 11/07 ✅ | 解析到 VCD 端到端 | `moonvsim run examples/counter.v` |
| M2 差分验证与可视化 | 11/07 ✅ | 40 设计 / 113 断言 / 查看器 | `conformance/REPORT.md` |
| M3 性能：字节码化 | 11/08–11/21 | 标识符在 lowering 解析为 id，基准 ≥2× | `bench/RESULTS.md` 前后对比 |
| M4 语言覆盖 | 11/22–12/12 | 存储器数组、`casez`/`casex`、`function`/`task` | 新增 ≥10 个差分设计 |
| M5 工具链集成 | 12/13–12/31 | mooncakes 发布、wasm 内核在线仿真、GitHub Action | `moon add` 可用；Action 示例 |
| M6 验收材料 | 01/01–01/20 | 演示视频、文档定稿、季度申报 | 报名表 + 仓库 |

### 5.2 月度节奏与奖金节点

| 月份 | 目标 | 对应赛事节点 |
| --- | --- | --- |
| 11 月 | M3 + M4 前半：性能翻倍、存储器支持 | 十一月赛启动支持（150）+ 完成支持（350） |
| 12 月 | M4 后半 + M5：语言覆盖补齐、发布到 mooncakes、Action | 第二赛季度评审材料 |
| 1 月 | M6：验收、演示视频、季度评选申报 | 季度评选（一等 12,000 / 二等 6,000 / 三等 3,000） |

### 5.3 M3 工作包拆解（示例，按天）

| 日 | 工作 | 产物 |
| --- | --- | --- |
| D1–D2 | 设计指令集：`(op, dst, src_a, src_b, width, signed)` | `docs/BYTECODE.md` |
| D3–D5 | lowering：表达式树 → 指令数组，标识符解析成 signal id | `src/sim/code.mbt` |
| D6–D7 | 求值器改走指令数组，保留 AST 路径做对照 | 单测覆盖两条路径一致 |
| D8 | 差分套件全量回归 | 113 断言仍为 0 分歧 |
| D9 | 基准复测、写入 `bench/RESULTS.md` | 数据表 + 结论 |
| D10 | 文档与 issue 关闭 | README 性能章节更新 |

---

## 6. 验收对标：赛事六条标准 → 本项目证据

| 赛事标准 | 本项目对应证据 |
| --- | --- |
| 01 以 MoonBit 为主要实现语言 | 核心逻辑 100% MoonBit；仅测试脚本用 Python 编排外部 oracle |
| 02 仓库公开、提交连续可追踪 | 公开仓库，19 次提交按能力递进，4 个 issue 记录后续计划 |
| 03 能运行：README、示例、测试 | README 含快速开始与 6 个示例；33 个单测 + 113 条差分断言；一条命令复现 |
| 04 已有项目须有本期实质新增 | 本期从零构建（首个提交 2026-11-07） |
| 05 开源合规、说明移植来源 | Apache-2.0；README 明确引用 DigitalJS 等先例与 Icarus 作为 oracle |
| 06 AI 可解释 | 见第 10 节：AI 用于 API 侦察与样板，架构决策、语义修正、质量把关由参赛者负责，每个修正都有差分断言佐证 |

---

## 7. 交付物清单

| 类别 | 交付物 | 状态 |
| --- | --- | --- |
| 代码 | 8 个 MoonBit 包（value/ast/lexer/parser/elaborate/sim/vcd/cmd） | 完成 |
| 测试 | 33 个单元测试 + 40 个差分设计 | 完成 |
| 工具 | `conformance/run_conformance.py`、`bench/run_bench.py` | 完成 |
| 演示 | 浏览器波形查看器（在线 + 离线单文件）、6 个示例 | 完成 |
| 文档 | README、ARCHITECTURE、ECOSYSTEM（缺口调查）、本计划书 | 完成 |
| CI | GitHub Actions：测试 + 三后端 + 差分 + 基准 + 产物 | 完成 |
| 视频 | 3 分钟演示脚本（见下） | 待录制（M6） |
| 发布 | mooncakes 包 | 待发布（M5） |

**演示视频脚本（3 分钟）**

1. 0:00–0:30 问题：MoonBit 有 linter 没有仿真器，展示两个 linter 的自述。
2. 0:30–1:10 `moonvsim run examples/traffic.v --vcd out.vcd`，命令行直接出结果。
3. 1:10–2:00 浏览器打开波形，看到时钟、计数器、FSM 状态迁移。
4. 2:00–2:40 跑差分套件：40 设计 / 113 断言 / 0 分歧，与 Icarus 同屏对比。
5. 2:40–3:00 路线图：字节码化、存储器、mooncakes 发布。

---

## 8. 风险与应对

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| 性能优化达不到 2× | 叙事变弱 | 先做可测量的两档目标（1.5×/2×），达不到就如实记录并转为「正确性优先」叙事 |
| 存储器/`casez` 语义复杂 | M4 延期 | 每个特性独立成 issue + 独立差分设计，允许单独延后 |
| Windows 环境不稳定（沙箱、DLL、证书） | 阻塞开发 | 已把 iverilog 本地安装与 CI（Ubuntu）双轨；CI 是最终裁判 |
| 单人时间不足 | 里程碑滑坡 | 每月只承诺一个可验收目标；范围外清单写在 README 里，防止蔓延 |
| 被质疑「AI 写的」 | 评审风险 | 提交粒度=能力粒度，每个 bug 有差分断言；AI 使用说明单列一节 |
| 与已有项目撞题 | 不计分 | 已完成关键词 + GitHub + GitLink + SCC 展示墙四重排查，并公开调查记录 |

---

## 9. 长期演进（赛后 6–12 个月）

1. **性能**：字节码化 + 事件队列分层，目标进入 Icarus 同量级。
2. **综合前端**：从「能跑」到「能映射」，先做门级网表导出（BLIF/Verilog netlist）。
3. **形式化**：结合 MoonBit 的 `verification` 能力，对小型设计做等价性检查。
4. **生态集成**：发布到 mooncakes；提供 `moon test` 插件式的 RTL 冒烟测试；VS Code 波形预览。
5. **在线 IDE**：wasm 内核 + 编辑器，浏览器内写 Verilog 即仿真，用于教学。

---

## 10. AI 使用说明

- **AI 参与的部分**：MoonBit 标准库 API 侦察、错误信息解读、样板代码与测试设计草稿、文档初稿。
- **由参赛者掌握的部分**：选题与范围界定、架构分层、四态位平面与调度器设计、IEEE 1364 语义判断、以及每一次与 Icarus 分歧的归因（是测试写错还是仿真器错）。
- **可验证性**：所有语义修正都有对应的差分断言；所有性能数字都可用 `bench/run_bench.py` 复现；所有提交可按序复现研发路径。

---

## 附录 A 关键词检索记录（摘要）

| 关键词 | 命中数 | 结论 |
| --- | --- | --- |
| `verilog` | 4 | 仅 linter / 语法 / VCD |
| `vhdl` `verilator` `yosys` `testbench` `rtlsim` `vsim` `hdl` | 0–1 | 无仿真器 |
| `simulate` `simulation` | 20+ | 均为通用离散事件/网络仿真 |
| `netlist` `circuit` | 数个 | SPICE/电路计算，非数字 RTL |
| `waveform viewer` | 0 | 无 |

平台侧交叉验证：GitHub 仓库检索 `moonbit rtl simulation` / `moonbit iverilog` / `moonbit vcd simulator` / `moonbit eda` 均为 0；GitLink 355 个 MoonBit 项目无 RTL 仿真器；SCC 2026 展示墙 40 个项目无同类。

## 附录 B 关键链接

- 仓库：<https://github.com/LHMXGY/moonvsim>
- 差分报告：<https://github.com/LHMXGY/moonvsim/blob/main/conformance/REPORT.md>
- 缺口调查：<https://github.com/LHMXGY/moonvsim/blob/main/docs/ECOSYSTEM.zh.md>
- 架构说明：<https://github.com/LHMXGY/moonvsim/blob/main/docs/ARCHITECTURE.md>
- 基准数据：<https://github.com/LHMXGY/moonvsim/blob/main/bench/RESULTS.md>
- 路线图 issue：#1 字节码化 · #2 存储器 · #3 casez/casex · #4 CI 产物
- 赛事主页：<https://moonbitlang.github.io/Hackathon2026/>
