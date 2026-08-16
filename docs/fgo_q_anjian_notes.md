# FGO_Q 按键精灵相关记录

- 按键精灵手机助手里，`Import` 只验证过能导入插件 `zm.luae`，没有找到可直接执行 `.q` 逻辑文件的可靠用法。
- `File.Read` 能读写 `/sdcard/` 普通文件，但不能把 `.atc` 里的文本附件当作普通文件读出来。
- 当前脚本分离实验的新探针文件：`Q/mq_core_logic.mq` 和 `Q/mq_config_runner.q`。

- `AWARD_TIE` 在战斗中可能误识别，导致 `WaitRoundReadyOrBattleEnd` 提前结束；已在 `Q/battle_runner.q` 增加回合检测宽限、连续稳定确认与领奖等待超时兜底。
- 战斗结束判定触发条件（当前实现）：只在上一组确实完成了 attack 后，下一组开始前的 `WaitRoundReadyOrBattleEnd` 才会进入提前结束检测；纯 skill/master 组本身不负责等待或结束判定。
- 当前 battle_runner 控制流：`WaitRoundReadyOrBattleEnd` 已上提到 `DoBattle -> DoGroupActions` 之前；`DoSkillActions` / `DoMasterActions` / `DoAttackActions` 只负责执行动作，不再各自等待战斗继续。