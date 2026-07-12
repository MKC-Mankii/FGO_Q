# Runner 与配置文件说明（按键精灵）

## 1. 两个文件的关系

- `Q/battle_runner.q`：主逻辑脚本。
  - 负责战斗流程、识图点击、回合执行。
  - 启动时会扫描手机脚本目录中的 `.mq` 文件，读取配置内容并解析到 `CFG_*` 变量。
  - 不建议在这里改每次活动参数（如好友、回合 DSL、战斗次数），这些应放到配置文件。

- `Q/battle_config.q`：配置源文件。
  - 只放配置数据（`Dim PRESET = ...`、`Dim FRIEND = ...`、`Dim ACTIVITY_DSL_* = ...` 等）。
  - 你在编辑器里改的是 `.q` 源文件。
   - 真正运行时，`battle_runner.q` 读取的是按键精灵编译后同步到手机的 `.mq` 文本。

一句话：`battle_runner.q` 负责“怎么打”，`battle_config.q` 负责“打什么参数”。

---

## 2. 在按键精灵中的运行链路

1. 在电脑端编辑 `Q/battle_config.q`。
2. 在按键精灵里编译并同步到手机，生成对应 `.mq`。
3. 手机执行 `battle_runner.q`。
4. `battle_runner.q` 会先扫描脚本目录中的 `.mq`，找到候选配置文件。
5. 读取配置文本，解析 `Dim KEY = VALUE` 行。
6. 解析成功后应用：
   - `FRIEND` 决定助战识图目标。
   - `ACTION_ROUND_INDEX` / `ACTIVITY_DSL*` 决定本次战斗动作序列。
   - `BATTLE_COUNT`、`APPLE_ENABLE` 等控制流程行为。
7. 如果关键配置缺失或无效，`battle_runner.q` 会停止，不会继续跑默认战斗。

---

## 3. 当前配置字段说明（battle_config）

- `PRESET`：预设标记，主要用于日志识别。
- `FRIEND`：助战关键字（如 `aobao`、`cdai`、`taigong` 等）。
- `BATTLE_COUNT`：本次总战斗次数。
- `DEBUGE_MODULE_BATTLE`：调试模式开关（0/1）。
- `APPLE_ENABLE`：是否允许吃苹果（0/1）。
- `ACTIVITY_REWARD`：活动结算流程开关（0/1）。
- `ACTION_ROUND_INDEX`：使用第几套 DSL（1/2/3）。
- `ACTIVITY_DSL`：直接覆盖 DSL（非空时优先）。
- `ACTIVITY_DSL_1/2/3`：多套预置 DSL。

优先级规则：
- 若 `ACTIVITY_DSL` 非空：直接使用 `ACTIVITY_DSL`。
- 否则按 `ACTION_ROUND_INDEX` 选择 `ACTIVITY_DSL_1/2/3`。
- 为空则停止运行。

---

## 4. 文件命名与识别规则（重点）

当前 `battle_runner.q` 的扫描匹配主要识别这些名字特征：

- 文件路径中包含 `fgo_battle_config`
- 或命中旧规则 `.../config(...`、`.../config.`

建议：
- 配置脚本命名尽量使用 `fgo_battle_config.q`（编译后对应 `fgo_battle_config.mq`），最稳妥。
- 如果改成其他名字，务必确认能命中 `battle_runner.q` 的扫描规则，否则会出现 `CONFIG PATH NOT FOUND`。

---

## 5. 日常修改建议流程

1. 只改 `Q/battle_config.q` 中参数，不改 `Q/battle_runner.q` 战斗主流程。
2. 在按键精灵中重新编译并同步配置脚本。
3. 启动 `battle_runner.q`，先看日志是否出现：
   - `CONFIG PATH FOUND: ...`
   - `CONFIG PARSED ...`
   - `SELECTED DSL HEAD: ...`
4. 若日志出现 `CONFIG PATH NOT FOUND`：
   - 先检查配置脚本编译同步是否成功。
   - 再检查配置脚本命名是否符合匹配规则。
5. 若日志出现 `FRIEND CONFIG INVALID OR EMPTY, STOP`：
   - 检查 `FRIEND` 值是否在支持列表中。
6. 若日志出现 `CONFIG DSL EMPTY, STOP`：
   - 检查 `ACTIVITY_DSL` 或对应索引的 `ACTIVITY_DSL_N` 是否为空。

---

## 6. 建议的协作约定

- `battle_runner.q`：只做逻辑优化、识图坐标、流程修复。
- `battle_config.q`：只做活动参数、助战、回合 DSL 调整。
- 每次活动开始前，优先复制一份 DSL 到 `ACTIVITY_DSL_1/2/3` 做版本留档。

这样可以保证：逻辑只有一套，配置随活动快速切换。