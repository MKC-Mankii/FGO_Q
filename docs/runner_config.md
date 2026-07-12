# Runner 与配置文件说明（按键精灵）

## 1. 两个文件的关系

- `Q/battle_runner.q`：主逻辑脚本。
  - 负责战斗流程、识图点击、回合执行。
  - 启动时会扫描手机脚本目录中的 `.mq` 文件，读取配置内容并解析到 `CFG_*` 变量。
   - 在这里手工修改大组索引、重复挑战次数、调试开关。

- `Q/battle_config.q`：配置源文件。
   - 只放配置数据（`Dim PRESET = ...`、`Dim FRIEND_Gx_y = ...`、`Dim ACTIVITY_DSL_* = ...` 等）。
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
   - `FRIEND_Gx_y`（必要时回退 `FRIEND_Gx` / 旧字段 `FRIEND`）决定助战识图目标。
   - `ACTION_ROUND_INDEX_Gx` / `ACTIVITY_DSL*` 决定本次战斗动作序列。
   - runner 手工项（`MANUAL_BATTLE_COUNT`、`MANUAL_APPLE_ENABLE`）与配置项共同控制流程行为。
7. 如果关键配置缺失或无效，`battle_runner.q` 会停止，不会继续跑默认战斗。

---

## 3. 当前配置字段说明（battle_config）

- `PRESET`：预设标记，主要用于日志识别。
- `FRIEND_Gx_y`：按关卡（大组 x + 小组 y）配置的助战关键字（推荐使用）。
- `FRIEND_Gx`：按大组配置的助战关键字（可选兜底）。
- `FRIEND`：全局助战关键字（仅兼容兜底，当前配置文件可不定义）。
- `ACTIVITY_REWARD`：活动结算流程开关（0/1）。
- `ACTION_ROUND_GROUP_INDEX`：DSL 大组索引（仅在 `battle_runner.q` 手动切换，不在 `battle_config.q` 中配置）。
   - 1=`Campaign.q`
   - 2=`Caber Common.q`
   - 3=`Order_Saber.q`
   - 4=`ordeal.q`
- `ACTION_ROUND_INDEX_G1/G2/G3/G4`：各大组内第几套 DSL（从 1 开始，在 `battle_config.q` 配置）。
   - 建议放在各自大组注释下，便于和该组 `FRIEND_Gx_y`、`ACTIVITY_DSL_Gx_y` 一起维护。
- `ACTIVITY_DSL`：直接覆盖 DSL（非空时优先）。
- `ACTIVITY_DSL_1/2/3`：多套预置 DSL。
- `ACTIVITY_DSL_Gx_y`：按“大组 + 组内索引”管理的 DSL（例如 `ACTIVITY_DSL_G2_3`）。

优先级规则：
- 若 `ACTIVITY_DSL` 非空：直接使用 `ACTIVITY_DSL`。
- 否则按 `battle_runner.q` 中 `ACTION_ROUND_GROUP_INDEX` + `battle_config.q` 中 `ACTION_ROUND_INDEX_Gx` 选择 `ACTIVITY_DSL_Gx_y`。
- 若对应 `ACTIVITY_DSL_Gx_y` 为空：回退到旧字段 `ACTIVITY_DSL_1/2/3`（兼容老配置）。
- 为空则停止运行。

助战选择规则：
- 先按当前 `大组 + 小组` 读取 `FRIEND_Gx_y`。
- 若对应 `FRIEND_Gx_y` 为空，再回退到 `FRIEND_Gx`。
- 若 `FRIEND_Gx` 也为空，再回退到旧字段 `FRIEND`。
- 三者都无效则停止运行。

当前推荐分组：
- 大组 1（campaign）：3 套。
- 大组 2（caber）：3 套。
- 大组 3（order_saber）：3 套。
- 大组 4（ordeal）：7 套（其中 1-4 为活动组，5-7 为艺术组）。

runner 手工字段：
- `CFG_ACTION_GROUP_INDEX`：大组选择（1-4）。
- `MANUAL_BATTLE_COUNT`：重复挑战次数（必须大于 0）。
- `MANUAL_APPLE_ENABLE`：是否允许吃苹果（0/1）。
- `MANUAL_DEBUGE_MODULE_BATTLE`：调试模式（0/1）。

---

## 4. 文件命名与识别规则（重点）

当前 `battle_runner.q` 的扫描匹配主要识别这些名字特征：

- 文件路径中包含 `fgo_battle_config`
- 或命中旧规则 `.../config(...`、`.../config.`

实际编译产物（手机端）通常会出现同一基名的多文件：

- `fgo_battle_config(<GUID>).mq`
- `fgo_battle_config(<GUID>).prop`
- `fgo_battle_config(<GUID>).uis`

说明：
- 其中 runner 只读取 `.mq` 文本内容。
- 文件名中带 GUID（如 `(...)`）是正常现象。
- 只要路径中仍包含 `fgo_battle_config`（或命中旧规则），现有扫描逻辑即可识别。

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
   - 再检查手机脚本目录中是否存在 `fgo_battle_config(<GUID>).mq`（注意是 `.mq`，不是 `.prop/.uis`）。
   - 再检查配置脚本命名是否符合匹配规则。
5. 若日志出现 `FRIEND CONFIG INVALID OR EMPTY, STOP`：
   - 先检查当前 `FRIEND_Gx_y` 是否填写且值在支持列表中。
   - 若你依赖兜底，再检查 `FRIEND_Gx` / `FRIEND`。
6. 若日志出现 `CONFIG DSL EMPTY, STOP`：
   - 检查 `ACTIVITY_DSL` 或当前大组对应索引的 `ACTIVITY_DSL_Gx_y` 是否为空。
   - 若依赖旧字段兜底，再检查 `ACTIVITY_DSL_1/2/3`。

---

## 6. 建议的协作约定

- `battle_runner.q`：只做逻辑优化、识图坐标、流程修复。
- `battle_config.q`：只做活动参数、助战、回合 DSL 调整。
- 每次活动开始前，优先复制一份 DSL 到 `ACTIVITY_DSL_1/2/3` 做版本留档。

这样可以保证：逻辑只有一套，配置随活动快速切换。