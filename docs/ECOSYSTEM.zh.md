# 2026 年 11 月 MoonBit 黑客松选题建议

> 结论先行：**做 MoonBit 原生的 Verilog RTL 仿真器（工作名 `moonvsim`），核心是"可被 iverilog 差分验证的四态事件驱动仿真内核"，交付形态是"同一份 MoonBit 内核 = CLI + 浏览器波形调试器"。**
>
> 这是一次基于真实生态检索的选题，不是想象。全部检索记录见附录 A，证据链接见附录 B。

---

## 0. 一句话定位

> 别人在 MoonBit 里写"Verilog 检查器"，我补的是**唯一缺的那块地基：能跑起来的数字电路仿真内核**——并且因为 MoonBit 一份代码多后端，它既能进 CI 当 CLI，也能在浏览器里零安装跑波形。

---

## 1. 研究方法与判定标准

### 1.1 数据源（都可复核）

| 数据源 | 用法 | 说明 |
|---|---|---|
| `mooncakes.io` 注册表 JSON API | `GET /api/v0/search?kw=<关键词>` 全量关键词扫描 | 未登录可用，返回 name / downloads / description / repository / created_at |
| GitHub REST API | `search/repositories`、`search/issues`、`readme` | 从 github.com 页面上下文发起 fetch |
| GitLink（gitlink.org.cn） | 项目搜索 `?q=` | 中文社区/赛事项目聚集地，共 355 个 MoonBit 项目 |
| mooncakes.io 首页 | 实时"Recently updated"流 | 用来判断生态新增速度 |
| 官网/博客/文档 | 官方路线与"官方认为重要的事" | moonbitlang.com、docs.moonbitlang.com |
| SCC 作品展示墙 | `moonbitlang.cn/2026-scc/showcase/` | 30 个参赛项目 + 10 个初赛入围，反推评审口味 |

### 1.2 判定规则

1. **"搜不到"不等于没人做**：所以每个方向都用 ≥4 个同义词/中英文/缩写关键词交叉检索，并且同时查注册表 + GitHub + GitLink 三处。
2. **淘汰线**：只要公开仓库里存在**功能高度重合**的实现（哪怕 0 star、刚建一天），就淘汰该方向——因为评委会看到"撞车"，且你无法证明自己不是抄的。
3. **我额外加的一条判据（本次研究最重要的产出）**：在当前的 MoonBit 生态里，"一个包"级别的想法已经不可能新颖了。所以选题必须满足 **"一天克隆不出来"**：即交付物里含有*外部真实工具参与的一致性验证*、*系统级集成*、*可量化成绩单*。这条判据直接决定了下面的取舍。

### 1.3 必须先知道的背景数字

- 注册表：**3,618 个 module / 32,384 个 package / 11,062,200 次下载**（2026-11-07 实测）。
- 首页 "Recently updated" 流：**约每小时新增 10 个 module**（连续观察 `tlhuecdkoyg/MoonCDC` 8 分钟前、`wdgodghl/moonwren` 33 分钟前、`bzhangui/ksymoon` 1 小时前……）。
- 新增条目的形态高度一致：单作者、中文/英文一句话简介、20–100 下载、`created_at` 就是最近几天。
- 含义：**"我想实现 X"这个层级的想法已经被 AI 生成式提交淹没**。你现在能想到的任何一句话级 idea，几乎都已有 1–3 个刚发布的同名/近似包。

---

## 2. 生态现状：为什么"再想一个库"已经没戏

下面是关键词扫描得到的分领域命中（节选，括号内为下载量）。这些是**淘汰证据**，也是后面论证"必须做系统"的依据。

| 领域 | 已被占据（节选） |
|---|---|
| 测试/质量 | `f4ah6o/turtles`(889) "Mutation testing"、`erzhuzi259/moongrammata`(75) 结构感知 fuzz、`moonbitlang/moon_cove`(113) 覆盖率、`zhangbowen2006/moonbit-target-parity`(607) 跨后端行为对比、`Kaida-Amethyst/mbtsmith`(67) 随机程序生成、`moonrockz/moonspec`(14730) BDD |
| 数据引擎 | `superbigcup325/moonlake`(181) SQL-over-Parquet、`codeworm96/magpiedb`(57) OLAP、`uiwcvb/moonsql`(38)、`mizchi/parquet`(2326)、`f4ah6o/duckdb`(1503)、`shunge/arrow`(90)、`QYF795/regolith`(89) LSM、`PingGuoMiaoMiao/moonlsm`(67)、`wallll-wal6/moonkv`(62) bitcask、`moonbitstack/moonraft`(75) |
| 服务端 | `le065-tc/moonredis`(40) Redis 协议服务端、`xiewenchen/moonbit-platform`(34) Redis/PG 驱动 + HTTP 服务端、`Hhsqoo/artifactdock`(53) OCI registry 服务端、`chgttyyr/moon_dns`(33) 权威 DNS、`ChaonanShen/moonbit-mqtt-broker`、`moonbitstack/mooncat`(1097) ASGI |
| AI/数据 | `howtomakeaname/tokenizers-moonbit`(657)、`tonyfettes/tiktoken`(120)、`trkbt10/vcdb`(683) 向量库、`moonbitstack/moonmcp`(175)/`marianoguerra/mcp`(371) MCP、`moonbitlang/openseek`(595) 编码智能体 |
| 工具链 | `wuhaiting321/dwarfscope` DWARF、`moonbit-community/elf`、`oilleelssq-wq/moonlink` 链接器、`f4ah6o/hotpath`/`gywcs101/moonflame` profiler、`mizchi/lsp`、`mizchi/wit`(65208) 组件模型 |
| 电子/硬件 | `dtzrttp/moonbit-rtl`(67) + `yzfyzf12345678/moonbit-rtl`(57) **Verilog 静态检查**、`lqhy1234567/moonbit-vcd`(46) + `alicedhaha/minivcd_mbt`(63) VCD 波形分析、`hsy-bit/moonbit-circuit-solver`(41) SPICE 模拟电路、`pzq893/moonbit-spice`、`Mgk789a/moonbit-gerberkit`(44) Gerber、`sbqrre/moonbit-mcu-hal`(41) MCU HAL |

**由此得出选题策略**：不要跟"包"竞争，要跟"缺的那块地基"竞争——即**某个垂直领域里所有周边工具都已就位、唯独核心引擎缺席**的位置。

---

## 3. 已淘汰方向与证据

每个方向都做了多关键词检索（附录 A 有完整词表）。

| # | 方向 | 检索到的近似实现 | 判定 |
|---|---|---|---|
| 1 | Jupyter kernel / notebook | `Mr-Shi123/moonjupyter` v0.3.1（2026-10-24 创建）："Includes a pure-MoonBit ZeroMQ (ZMTP 3.1) protocol implementation" — 恰好是我原本打算做的差异化点 | ❌ 淘汰（正面撞车） |
| 2 | MoonBit → Python 扩展/绑定生成器 | GitHub `gyyyy6/MoonBridge`（2026-11-06 push）"MoonBit to Python binding generator，生成可 pip install 的 Python 包"；另有 `moonbitlang/python.mbt`(★35)、`moonbit-community/moonpython` | ❌ 淘汰（注册表 `pyo3`/`pybind`/`abi3` 均为 0，但 GitHub 上已被占，且只差一天） |
| 3 | 调试器 / DAP server | 官方博客 2025-10-31 "Announcing LLDB based debugger for MoonBit"；`Kaida-Amethyst/moondbg` 在注册表 | ❌ 淘汰（官方已有，重复=低分） |
| 4 | 浏览器自动化 / Playwright 类 | `justjavac/cdp`(5125) CDP 库、`mizchi/webdriver`(12926) BiDi 客户端、`mizchi/playwright`(364) Playwright 兼容 API | ❌ 淘汰（三层都有人做了） |
| 5 | Git 服务端 | `mizchi/bit`(104869) + `bit_pack`(2414 packfile) + `bit_protocol`(2395 线协议) + `bit_repo`/`bit_lib`/`bit_io_native` —— 一整套 gix 等价物 | ⚠️ 淘汰（做服务端会被视为对 bit_* 的薄封装） |
| 6 | 变异测试 / 模糊测试 / 覆盖率 / 差分测试 | 见第 2 节"测试/质量"整行 | ❌ 淘汰 |
| 7 | 包文档站（docs.rs 类） | 注册表本身就是"share package **and documentation**"，导航有 **Build queue**，且每个 module API 返回 `build_status` | ❌ 淘汰（官方已覆盖） |
| 8 | 私有 registry / 离线镜像 | `lillian-dot/moonchsrc`、`trail-it/moonchsrc`（镜像工具已存在） | ❌ 淘汰 |
| 9 | SQL/OLAP/列存/KV/向量库 | 见第 2 节"数据引擎"整行，同赛道 10+ 个实现 | ❌ 淘汰 |
| 10 | 通用离散事件仿真引擎 | `wcx789ll/moonsim`(44)、`walkzzz/moondes`(35)、`Ljh684/moonnet-lab`(33) | ❌ 淘汰（"仿真引擎"这个词已被占，见下方风险说明） |
| 11 | **Verilog RTL 仿真器** | 只有 2 个**静态检查器**（明确声明不含仿真）+ 2 个 VCD 波形工具 | ✅ **保留（主选）** |
| 12 | **S3 兼容对象存储服务端** | 注册表里有 6+ 个 S3 *客户端*（`mldong/moon-s3` 176、`mizchi/s3` 355、`kaashyapan/s3` 65、`hackwaly/s3` 56……），**没有任何 server** | ✅ 保留（备选 1） |
| 13 | MySQL 线协议**服务端** | 只有驱动（`moonbitstack/moonmysql` 462、`Lfan-ke/moon-mysql` 87、`Hosi121/mysql` 61），server 为 0 | ✅ 保留（备选 2） |

---

## 4. 主选方案：`moonvsim` — MoonBit 原生 Verilog RTL 仿真器

### 4.1 缺口证据（三重独立验证）

**① 注册表里只有"检查器"，而且它们自己写明不做仿真**

- `dtzrttp/moonbit-rtl`(67) README 原文："The project intentionally does **not** claim complete SystemVerilog support, synthesis, **simulation**, formal verification, or an LSP server."
- `yzfyzf12345678/moonbit-rtl`(57) README 原文："The project is a static analysis and reporting library, **not** a synthesizer, **simulator**, or replacement for a complete IEEE Verilog implementation."
- 两个项目都停在"lexer + parser + hierarchy + lint + SARIF 报告"这一层，**没有任何求值与调度**。

**② GitHub 八组关键词，命中数全为 0**
（口径说明：GitHub 仓库搜索匹配 name/description/topics，不匹配源码，因此"0 命中"只能证明没人这样**命名/描述**自己的仓库。所以这条只作为辅助证据，主证据是 ① 的注册表描述与 ③ 的 GitLink。）

`moonbit rtl simulation` = 0；`moonbit simulator verilog` = 0；`moonbit iverilog` = 0；`moonbit vcd simulator` = 0；`moonbit hardware simulation` = 0；`moonbit testbench` = 0；`moonbit eda` = 0；`moonbit waveform` = 0。
（唯一相关命中是上面两个 linter，`moonbit verilog` 总共只有 2 个仓库。）

**③ GitLink 上同样没有**

`moonbit 仿真` 的搜索结果里，硬件方向只有 `lqhylqhy/moonbit-vcd`（波形分析）；`verilog` 返回的都是非 MoonBit 的通用 HDL 仓库。

### 4.2 为什么这是"真缺口"而不是我随便找的空位

MoonBit 的硬件/电子方向已经**长出了完整的周边，唯独缺核心**：

- 前端：两个 Verilog-2001 前端（词法/语法/层级/位宽）
- 波形：两个 VCD 解析器（还带 trace diff、边沿统计、四态运算）
- 模拟电路：`moonbit-circuit-solver`（MNA 求解）、`moonbit-spice`
- 制造数据：`moonbit-gerberkit`（Gerber/Excellon）
- 嵌入式：`moonbit-mcu-hal`（MCU HAL + 仿真套件）
- 工业：`CXREN/jtt808`、`dgmlbtttt/iec104`、SCC 入围作品 `MoonECAT`（EtherCAT 主站）、`MoonRV Lab`（RISC-V 反汇编/CFG/执行）

也就是说：**这个垂直领域的所有"读"工具都有了，唯独没有"跑"的工具**。这正好是评审最容易认可的那种缺口——不是又一个工具，而是让已有工具能互相咬合的那一块。

同时，SCC 作品墙页面明确写着赛事偏好："**赛事更偏好具备长期演进空间的系统型软件**"。仿真器天然是系统型，且演进路径清晰（见 4.10）。

### 4.3 差异化定位（写进 README 第一屏）

| 对比对象 | 它的定位 | 我的差异 |
|---|---|---|
| `moonbit-rtl` ×2 | 静态分析/lint，明确不做仿真 | 我做**求值 + 调度 + 波形**；甚至可以把它们当"前端"来复用/对照 |
| `moonbit-vcd` ×2 | 波形**读**与统计 | 我**生产**波形；一致性对比直接复用它的 trace diff |
| `moonsim` / `moondes` | 通用离散事件引擎，不懂 Verilog 语义 | 我做**语言语义**：四态、NBA/阻塞赋值、delta cycle、位宽截断/符号扩展 |
| iverilog / Verilator | C++ 实现，重量级工具链 | MoonBit 一份内核**多后端**：CLI 进 CI，wasm 进浏览器零安装 |
| DigitalJS（JS 生态） | 浏览器可视化仿真 | 同类体验，但 MoonBit 侧从 0 到 1；且我们是"内核 + 一致性成绩单"，不是演示品 |

> 注意 DigitalJS 的存在：申报文案里**主动引用它**并说明"这是 JS 生态已有的能力，MoonBit 侧缺失，我们补的是 MoonBit 侧的从 0 到 1 与一致性验证"。主动引用参照物 = 显得专业，且符合赛事"移植需注明出处"的要求。

### 4.4 一个月可交付范围（把边界钉死）

**IN SCOPE（v0.1 必须做完）**

1. **前端**：Verilog-2001 可综合子集 + 测试平台子集
   `module/endmodule`、ANSI 端口、`parameter/localparam`、`wire/reg/integer`、位宽与位选/部分选择/拼接/复制、运算符全集（含 `>>>`、归约、三元）、`assign`、`always @(...)`（`posedge/negedge/*`）、`begin/end`、`if/else`、`case/casez`、`for`（常量边界）、`function`（简版）、实例化与端口连接（含命名连接）、`generate`（for/if）。
2. **语义核心**
   四态值模型（`0/1/X/Z`，2 bit 编码）、位宽推导与截断/扩展规则、阻塞赋值与 NBA 的双区域调度、delta cycle、`initial` 块、`#delay`、`$display/$write/$monitor/$finish/$stop/$time`、`$dumpfile/$dumpvars`。
3. **输出**：标准 VCD（含层次 scope、向量、`$dumpvars`）。
4. **形态**：`moon run cmd/main -- sim tb.v` CLI；同内核编译到 wasm 的浏览器 demo（拖入 `.v` → 跑 → canvas 波形）。
5. **一致性成绩单**：对 **≥40 个设计**（自建 30 + 开源 10：FIFO/UART/SPI/ALU/分频/状态机/简易 CPU 子集）跑 iverilog 差分，输出 pass/fail 表 + 首个失配时刻 + 波形 diff。
6. **工程**：README（含 quickstart、支持矩阵、局限声明）、`moon test` 单测（词法/求值/调度/VCD）、GitHub Actions 矩阵（js + wasm + native）、MIT/Apache 双许可。

**OUT OF SCOPE（README 里明确写"不支持"，反而加分）**

SystemVerilog（class/interface/assertion）、UDP、`specify` 时序检查、实数/字符串完整语义、`fork/join`、force/release、SDF 反标、综合。

> 这个 in/out 划分刚好对应黑客松页面自己的建议："拿不准时，优先选边界清晰、一个月内可交付可验证的题目"。

### 4.5 技术路线（模块与依赖）

```
moonvsim/
  core/        # 纯函数式、无 I/O：值、位宽、表达式求值、语句执行
  sched/       # 事件队列 + 活跃/非活跃/NBA 三区域 + delta cycle 上限
  frontend/    # 词法/语法/AST（可参考 moonbit-rtl 的 AST 形状，但不直接依赖）
  elaborate/   # 参数求值、generate 展开、实例树、层次名、位宽绑定
  vcd/         # VCD writer（结构化，流式）
  sim/         # 顶层 API：load → elaborate → run(until) → trace
  cmd/main/    # native CLI（文件 I/O 用 moonbitlang/async 的 fs）
  web/         # js/wasm 适配 + 波形 canvas
  conformance/ # 差分脚本：跑 iverilog 与 moonvsim，比对 VCD
```

设计原则：**core/sched/vcd 不碰 I/O**（纯 MoonBit，多后端通吃），I/O 全部放适配层——这是 MoonBit 生态里 `bit_core` / `bit_io_native`、`moonbitstack` 系列已经在用的成熟分层法，照抄即可，评委会觉得"懂行"。

依赖尽量少：`moonbitlang/core` + `moonbitlang/async`（CLI 的文件/进程）；对比阶段可用 `lqhy1234567/moonbit-vcd` 做 VCD diff（或自己写 30 行 diff，更稳）。

### 4.6 外部验收 oracle（这是本项目最硬的护城河）

为什么一天克隆不出来：**克隆者可以抄代码，但抄不走"对 40 个设计与 iverilog 逐拍一致"这件事**。

1. **基准仿真器**：iverilog（Windows 有官方安装包，或 WSL/Verilator 二选一）。
2. **差分方法**：同一 testbench，两边各出 VCD → 规范化（去注释、按时间戳对齐）→ 逐信号逐拍比对 → 输出首个失配 `(time, signal, expected, got)`。
3. **成绩单**：README 顶部放一张实时表 —— `designs: 42 · pass: 39 · known-diff: 3`，每个 known-diff 链到 issue 并说明是"我们错"还是"iverilog 的扩展行为"。
4. **反向产出**：差分过程中必然发现自己的 X 传播/NBA 顺序 bug，这些 issue + commit 就是黑客松要的"可追溯开发记录"。
5. **额外可信度**：拿 `moonbit-rtl` 仓库里的 examples 当输入语料（真实第三方用例），并给它们提 issue/PR。

### 4.7 四周排期（每周都有可演示物）

| 周 | 目标 | 周末可演示 |
|---|---|---|
| W1 | 词法/语法/AST + 表达式求值与位宽规则；`assign` + 组合逻辑；VCD writer | `counter.v` 组合逻辑版跑出波形，CLI 打印信号表 |
| W2 | 时序逻辑：`always @(posedge)`、阻塞/NBA、delta cycle、`initial`、`#delay`；事件调度器 | 时钟分频 + 简单 FSM 的波形与手算逐拍一致 |
| W3 | 层次化：实例化、参数、`generate`、层次名、`$dumpvars` 全层次；测试平台 `$display/$finish` | 一个含 3 层例化和 generate 的 UART 发送器跑通 |
| W4 | 一致性工程：40 设计语料 + iverilog 差分 + 成绩单；浏览器 demo；CI 矩阵；文档与申报材料 | 打开浏览器拖入 `.v` 看波形；README 成绩单；演示视频 |

里程碑建议：**W2 结束就发 v0.1.0 到 mooncakes**（早发布 = 早锁定"首个"，也符合黑客松"持续可追溯提交"的要求）。

### 4.8 交付物清单（对照赛事验收标准）

- [x] 公开 GitHub 仓库，逐日提交（MoonBit 为主实现语言）
- [x] README：定位、支持矩阵、局限、quickstart、成绩单
- [x] 可运行示例：`examples/` 下 5 个 .v + 期望输出
- [x] 测试：`moon test`（词法/求值/调度/VCD 快照）+ CI 矩阵
- [x] 在线 demo（wasm，可直接给评委点）
- [x] 开发复盘：AI 如何参与、哪些决策是人做的（赛事明确要求）
- [x] 开源许可 + 对 iverilog/DigitalJS/moonbit-rtl 的出处说明

### 4.9 风险与预案

| 风险 | 概率 | 预案 |
|---|---|---|
| Verilog 语法太杂，parser 吃时间 | 中高 | **降级路径**：先只支持我列出的子集，用"解析失败清单"把不支持语法显式报错；必要时把 `moonbit-rtl` 的 AST 作为参考甚至依赖（它有 span 与 hierarchy，正好省一半工） |
| 四态 X 传播语义做不对 | 高 | 只保证"与 iverilog 在语料上一致"，不追求 IEEE 全集；把不一致项显式记为 known-diff |
| NBA/delta cycle 调度写错 | 中 | W2 就用"手算逐拍表"做单测（先写测试再写调度器） |
| 性能被吐槽 | 低 | 语料都是小设计；README 给吞吐数字即可，不承诺大规模 |
| 撞上"通用离散事件引擎"叙事（moonsim/moondes 已有） | 中 | 文案上**不要**自称"离散事件仿真框架"，要自称"**Verilog 语义仿真器**"——差异在语言语义，不在调度器 |
| 有人在你之后一周发同类 | 中 | 这正是要抢 11 月的原因；且成绩单/语料是时间护城河 |

### 4.10 长期演进（季度奖/半年奖叙事）

v0.1 仿真内核 → v0.2 覆盖率（行/翻转/FSM）+ 断言子集 → v0.3 与 `moonbdd`/`cvc5.mbt` 对接做**有界模型检验**（正好呼应 MoonBit 官方 0.9 "First-Class Formal Verification" 的品牌）→ v0.4 简易综合到网表 + `moonbit-rtl` lint 联动 → 最终形态："MoonBit 的芯片前端工具链"。

这个演进线是**顺着 MoonBit 官方叙事走的**（形式化验证 + 多后端 + 硬件生态），答辩时非常好讲。

---

## 5. 备选方案

### 备选 1：S3 兼容对象存储服务端（`moonstore`）

- **缺口证据**：注册表 S3 相关全是**客户端或抽象层**（`mldong/moon-s3` 176、`mizchi/s3` 355、`kaashyapan/s3` 65、`hackwaly/s3` 56、`kaashyapan/sigv4` 108；`marianoguerra/sos`(64) 经查是 "one storage interface, many backends"，即 **OpenDAL 式抽象库**，不是服务端）；GitHub `moonbit s3 server` / `moonbit minio` / `moonbit object storage server` 均 0，GitLink 无。
  > 顺带排除一个子方向：**"统一存储接口层"已经被 `sos` 占了**（对标 Apache OpenDAL），不要做这个。
- **为什么成立**：`aws cli` / `rclone` / `boto3` 就是天然 oracle，还能跑 ceph 的 `s3-tests` 子集；SigV4 已经有人写好（`kaashyapan/sigv4`），HTTP 服务端也有一堆现成件 → **一个月能出高完成度**。
- **为什么排第二**：完成度容易高，但"惊艳度"低于仿真器，且 MinIO 的存在让它看起来像"再写一个 MinIO"；差异化只能落在"wasm 边缘部署 + 单二进制"。
- **如果主选在 W2 结束时明显跑不动，立刻切这个**（切换成本最低，因为两者都还没写代码时就开始）。

### 备选 2：MySQL 线协议服务端（`moonsqld`）

- **缺口证据**：驱动很多（`moonbitstack/moonmysql` 462、`Lfan-ke/moon-mysql` 87、`Hosi121/mysql` 61），**服务端 0**；GitHub `moonbit mysql server` = 0。
- **风险**：要自己写 SQL 执行层（现有的 `uiwcvb/moonsql`(38) 太薄，不宜作为基座）→ 实际工作量接近"存储引擎 + 协议"，一个月偏紧。
- **适合作为**：如果你更想走"数据基础设施"叙事，且愿意把 SQL 子集砍到 `CREATE/INSERT/SELECT(单表, 索引)`。

### 备选 3（备而不用）：用户态 TCP/IP 栈

- **缺口证据**：`smoltcp` 0 命中、`netstack` 0 命中，只有报文头解析 `chensuiyi/packet`(44)；`mizchi/moonix` 是 POSIX 虚拟层。
- **不推荐原因**：需要 TUN/root 权限，Windows 开发体验差，demo 门槛高，一个月风险最大。

---

## 6. 提交前 48 小时 checklist

1. 仓库名/public、README 第一屏就写清"是什么/不是什么/和谁不同"。
2. 成绩单数字真实可复现（给出 `make conformance` 一条命令）。
3. 在线 demo 链接可用（wasm 版，别依赖本地原生工具链）。
4. 明确列出 OUT OF SCOPE（评委最怕的是"声称全支持但一跑就崩"）。
5. 出处与许可：iverilog（GPL，仅作对照工具，不链接其代码）、DigitalJS、`moonbit-rtl`、`moonbit-vcd` 全部注明。
6. 复盘文档：AI 生成占比、人工决策点（赛事明文要求）。

---

## 附录 A：检索关键词全记录

**注册表（mooncakes.io `/api/v0/search`）**
`jupyter` `notebook` `repl` `zeromq` `zmtp` `nanomsg` `pty` `cpython` `pybind` `abi3` `xunit` `vscode` `dap` `junit` `static site` `playground` `sandbox` `hot reload` `incremental` `cache` `reproducible` `lockfile` `vendor` `offline` `mirror` `git server` `packfile` `smart http` `receive-pack` `git http` `gitea` `forge` `code hosting` `git daemon` `clone` `playwright` `puppeteer` `cdp` `devtools protocol` `webdriver` `selenium` `headless browser` `browser automation` `mysql server` `wire protocol` `postgres server` `verilog` `vhdl` `rtl` `emulator` `nes` `gameboy` `chip8` `minio` `object storage` `s3 compatible` `presigned` `bucket` `multipart upload` `storage server` `smoltcp` `tcp/ip` `tun` `netstack` `verilator` `synthesis` `yosys` `hdl` `testbench` `event driven` `digital logic` `circuit` `moonwave` `moonveri` `rtlsim` `vsim` `moonhdl` `cycle accurate` `simulate` `simulation` `netlist` `gate level` `hdl simulator` `waveform viewer` `soap` `pyo3` `vcpkg` `zookeeper` `libfuzzer` `mutation` `fuzz` `coverage` `parquet` `arrow` `duckdb` `sqlite` `postgres` `redis` `kafka` `mqtt` `dns` `smtp` `tokenizer` `agent` `mcp` `rag` `vector` `btree` `lsm` `raft` `oci` `kubernetes` `hcl` `sbom`

**GitHub（`search/repositories`，均带 `moonbit` 前缀）**
`moonbit verilog` `moonbit rtl simulation` `moonbit simulator verilog` `moonbit iverilog` `moonbit vcd simulator` `moonbit hardware simulation` `moonbit testbench` `moonbit eda` `moonbit waveform` `moonbit moonsim` `moonbit fpga` `moonbit simulation` `moonbit s3 server` `moonbit minio` `moonbit object storage server` `moonbit s3 compatible` `moonbit mysql server` `moonbit protocol server` `moonbit python binding`

**GitLink（`gitlink.org.cn/search`）**
`moonbit`（355 个项目）`verilog` `moonbit 仿真`

---

## 附录 C：可直接粘贴的申报文案（约 350 字）

> **项目名**：moonvsim —— MoonBit 原生 Verilog RTL 仿真器
>
> **一句话**：用 MoonBit 实现一个可被 iverilog 逐拍差分验证的 Verilog-2001 四态事件驱动仿真内核，同一份代码编译为 CLI 与浏览器波形调试器。
>
> **要解决的问题**：MoonBit 生态在硬件方向已有 Verilog 前端/静态检查（`moonbit-rtl` ×2）、VCD 波形分析（`moonbit-vcd` ×2）、模拟电路求解（`moonbit-circuit-solver`）、MCU HAL、EtherCAT 主站，唯独缺少"把 RTL 跑起来"的仿真内核——所有工具都缺一个共同的执行底座。
>
> **目标用户**：MoonBit 硬件/嵌入式开发者、FPGA 教学与课程作业批改、CI 中的 RTL 回归、以及想在浏览器里零安装看波形的工程师。
>
> **架构**：`core`（四态值与位宽语义）/ `sched`（活跃-非活跃-NBA 三区域 + delta cycle）/ `frontend`（Verilog-2001 子集）/ `elaborate`（参数、generate、层次）/ `vcd`（波形输出）全部为无 I/O 纯 MoonBit；I/O 只在 `cmd`（native CLI）与 `web`（wasm）两个适配层，因此天然多后端。
>
> **可行性**：解析层可参考已有前端，语义层是本项目主攻；对照工具 iverilog 现成可用；语料从 FIFO/UART/SPI/ALU/简易 CPU 起步，逐周可演示。
>
> **验收**：≥40 个设计与 iverilog 差分，README 公示 pass/known-diff 成绩单；`moon test` 覆盖求值与调度；CI 矩阵 js/wasm/native。
>
> **边界（明确不做）**：SystemVerilog、UDP、时序检查、综合、`fork/join`、实数完整语义。

---

## 附录 B：证据链接

- 注册表：https://mooncakes.io/
- 黑客松官网：https://moonbitlang.github.io/Hackathon2026/
- SCC 作品展示墙（评审口味依据）：https://moonbitlang.cn/2026-scc/showcase/
- 官方博客（LLDB 调试器、形式化验证、多后端）：https://www.moonbitlang.com/blog/
- FFI/多后端文档：https://docs.moonbitlang.com/en/latest/language/ffi.html
- Verilog 静态检查器 1：https://github.com/dtzrttp/moonbit-rtl
- Verilog 静态检查器 2：https://github.com/yzfyzf12345678/moonbit-rtl
- VCD 波形工具：https://github.com/lqhy1234567/moonbit-vcd
- 模拟电路求解器：`hsy-bit/moonbit-circuit-solver`（mooncakes）
- iverilog（对照 oracle）：https://github.com/steveicarus/iverilog
- Verilator：https://github.com/verilator/verilator
- DigitalJS（JS 生态同类，需在 README 注明参照）：https://github.com/tgedr/digitaljs
