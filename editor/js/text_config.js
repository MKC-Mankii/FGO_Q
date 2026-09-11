/**
 * FGO Q Battle Config Editor - 页面全量文本与文案统一配置
 * 
 * ==============================================================================
 * 【使用说明 / Guide】
 * 本文件集中管理编辑器页面中的全部显示文本，包括：
 * 1. 顶部标题与导航栏操作按钮文案
 * 2. 大组选项卡与活动领奖标签
 * 3. 侧边栏方案列表与排序文案
 * 4. 方案详情栏（助战选择、方案重命名、DSL复制导入）
 * 5. 战斗动作时序看板（Wave 标题、按钮、空提示、卡片文字）
 * 6. 动作录入控制台（锁定目标、从者技能、御主礼装、出牌选择）
 * 7. 弹窗提示与交互文案（选敌、修改动作、礼装换人、DSL导入）
 * 8. 助战从者名称与出牌卡片标签
 * 9. 所有操作反馈与 Toast 消息通知
 * 
 * 方便您直接在此文件中手动修改任意文本，保存后在浏览器中刷新即可生效！
 * ==============================================================================
 */

export const TEXT_CONFIG = {
    // 1. 顶部导航区 (Masthead)
    masthead: {
        eyebrow: "FGO_Q V3",
        title: "Battle Config Editor",
        subtitle: "可视化配置各关卡技能、换人与出牌时序。",
        syncReading: "正在自动读取本地配置...",
        syncSuccess: "✅ 已同步: {path}",
        syncLocalFallback: "⚠️ 本地服务未响应，使用内存初始配置",
        syncSavedDisk: "✅ 已保存到磁盘: Q/battle_v3_config.q",
        syncSaveError: "❌ 保存出错: {error}",
        btnReload: "📂 重新读取",
        btnReloadTitle: "重新从本地磁盘读取配置文件",
        btnCopy: "📋 复制配置",
        btnSave: "💾 保存配置",
        btnSaving: "💾 正在保存...",
        btnShutdown: "🛑 退出服务",
        btnShutdownTitle: "关闭后台服务进程并安全退出",
        shutdownConfirm: "确定要关闭后台配置编辑器服务吗？\n\n服务关闭后，此网页无法继续保存修改。下次使用可通过快捷方式再次启动。",
        shutdownDone: "🛑 服务已安全停止，您可以关闭此标签页。"
    },

    // 2. 战场选项卡与设置 (Group Tabs & Info)
    groups: {
        schemeCountBadge: "{count} 方案",
        rewardActiveBadge: " · 🎁",
        rewardLabel: "活动点数",
        rewardTitle: "当前战场结算时是否自动执行活动点数领取确认点击（默认关）",
        hintPrefix: "说明: ",
        rewardOpenedToast: "🎁 已开启【{label}】活动点数领取流程",
        rewardClosedToast: "ℹ️ 已关闭【{label}】活动点数领取流程",
        // 战场预设提示文案
        defaultHints: {
            test: "测试战场",
            campaign: "活动关卡",
            caber: "术呆通用",
            grand: "戴冠战关卡",
            ordeal: "白纸化地球 Ordeal Call"
        }
    },

    // 3. 侧边栏方案列表 (Sidebar)
    sidebar: {
        title: "方案列表",
        btnAddScheme: "+ 加方案",
        btnReset: "🔄 重置配置",
        dragHandleTitle: "按住拖拽排序",
        schemeItemTitle: "按住拖拽调整排序 · 方案 {index}: {name} {defaultTag}",
        defaultTag: "(默认方案)",
        defaultBadge: "⭐",
        friendPrefix: "助战: ",
        noFriend: "无助战",
        defaultSchemeName: "方案 {index}",
        sortAdjustedToast: "↕️ 已调整方案排序：原方案 {oldIndex} 移动至方案 {newIndex}",
        schemeAddedToast: "已新建方案 {count}",
        resetDoneToast: "已恢复初始预设"
    },

    // 4. 方案详情属性栏 (Scheme Header Bar)
    schemeBar: {
        curSchemeLabel: "当前方案:",
        schemePrefix: "方案 {index}:",
        viewTitle: "点击直接修改方案名称",
        editIconTitle: "点击修改名称",
        inputPlaceholder: "输入方案名称",
        btnSaveNameTitle: "保存方案名称",
        btnCancelNameTitle: "取消修改",
        saveNameToast: "✅ 方案名称已保存：{name}",
        friendLabel: "助战:",
        customFriendSuffix: " (自定义)",
        rewardCheckboxLabel: "点数奖励",
        rewardCheckboxTitle: "当前方案结算时是否自动执行活动点数领取确认点击（默认关）",
        rewardOpenedToast: "🎁 方案 {index} 已开启活动点数领取流程",
        rewardClosedToast: "ℹ️ 方案 {index} 已关闭活动点数领取流程",
        defaultTagActive: "⭐ 默认方案",
        defaultTagActiveTitle: "当前方案是该战场的默认运行方案",
        defaultTagInactive: "☆ 设为默认",
        defaultTagInactiveTitle: "点击将当前方案设为该战场的默认运行方案",
        setDefaultSuccessToast: "✅ 已将方案 {index} 设为战场默认方案",
        alreadyDefaultToast: "ℹ️ 当前方案已是该战场的默认运行方案",
        btnCopyDsl: "📋 复制 DSL",
        btnCopyDslTitle: "直接复制当前方案的动作 DSL 脚本到剪贴板",
        copyDslSuccessToast: "📋 方案 {index} 的 DSL 已直接复制到剪贴板！",
        copyDslFailToast: "❌ 复制 DSL 失败，请重试",
        btnImportDsl: "📥 导入 DSL",
        btnImportDslTitle: "通过动作 DSL 脚本导入方案"
    },

    // 5. 战斗动作时序看板 (Action Timeline Board - 左栏)
    timeline: {
        title: "🎬 时序 (Timeline)",
        btnAddWave: "+ 添加回合",
        btnAddWaveTitle: "在当前选中的回合后插入一个新回合",
        btnResetScheme: "🔄 重置方案",
        btnResetSchemeTitle: "将当前方案所有回合恢复为配置文件状态",
        resetSchemeToast: "已将当前方案所有回合恢复为配置文件状态",
        btnClearScheme: "🗑️ 清空方案",
        btnClearSchemeTitle: "清空当前方案所有回合动作",
        clearSchemeToast: "已清空当前方案所有动作",
        waveDragTitle: "按住拖拽调整 Wave {wave} 前后顺序",
        waveBadge: "Wave {wave}",
        waveActiveIndicator: "🎯 正在添加动作",
        btnClearWave: "🗑️ 清空动作",
        btnClearWaveTitle: "清空本回合所有动作",
        btnDeleteWave: "✕ 删除此回合",
        btnDeleteWaveTitle: "删除此回合",
        emptyWaveHint: "本回合暂无动作，点击右侧控制台按钮添加技能或出牌",
        addWaveToast: "已在 Wave {insertIndex} 后插入新回合 (当前 Wave {curIndex})",
        deleteWaveToast: "已删除第 {wave} 回合",
        deleteWaveMinWarnToast: "⚠️ 至少需要保留 1 个回合",
        clearWaveToast: "已清空 Wave {wave} 的所有动作",
        waveOrderAdjustedToast: "↕️ 已调整回合顺序：原 Wave {oldIndex} 移动至 Wave {newIndex}",
        chipDragTitle: "点击选中并修改此动作；按住拖拽可调整先后顺序",
        chipRemoveTitle: "删除此动作",
        chipAttackTitle: "🗡️ 出牌:",
        chipAttackEditTitle: "点击重新配置出牌",
        chipAttackRemoveTitle: "清除此出牌",
        removeAttackToast: "已清除 Wave {wave} 的出牌配置",
        setAttackToast: "✅ 已为 Wave {wave} 设置出牌: a{cards}",
        chipOrderAdjustedToast: "↔️ 已调整动作卡片顺序"
    },

    // 6. 动作录入控制台 (Visual Action Palette - 右栏)
    palette: {
        hintDefault: "💡 点击右侧技能、锁定与出牌按钮直接加入此回合；点击左侧各回合可切换目标。",
        hintSelected: "✏️ 已选中 <strong>Wave {wave}</strong> 动作【<strong style=\"color:#ffffff;\">{label}</strong>】。点击右侧任意技能、锁定目标或换人直接修改替换；点击空白处或再次点击卡片取消选中。",

        // 选敌
        targetTitle: "🎯 锁定目标",
        targetSubtitle: "t1~t6",
        targetBtn1: "目标 1",
        targetBtn2: "目标 2",
        targetBtn3: "目标 3",
        targetBtn4: "目标 4",
        targetBtn5: "目标 5",
        targetBtn6: "目标 6",
        targetDesc: "目标 {target}",

        // 御主礼装技能
        masterTitle: "👔 御主技能",
        masterSubtitle: "m1~m3",
        masterMainBtn: "技能 {id}",
        masterMainBtnTitle: "点击直接添加 技能 {id} (自身/无目标)",
        masterTargetBtnTitle: "技能 {id} → 给从者 {target}",
        masterSwapBtn: "⇄ 换人",
        masterSwapBtnTitle: "点击配置 技能 {id} 换人 (前排⇄替补)",
        masterDescSelf: "御主技能 {id}",
        masterDescTarget: "御主技能 {id} → 从者 {target}",

        // 从者 1 ~ 3 技能
        servant1Title: "⚔️ 从者 1",
        servant1Subtitle: "s1~s3",
        servant2Title: "⚔️ 从者 2",
        servant2Subtitle: "s4~s6",
        servant3Title: "⚔️ 从者 3",
        servant3Subtitle: "s7~s9",
        skillMainBtn: "技能 {id}",
        skillMainBtnTitle: "点击直接添加 技能 {id} (自身/无目标)",
        skillTargetBtnTitle: "技能 {id} → 给从者 {target}",
        skillDescSelf: "从者技能 {id}",
        skillDescTarget: "从者技能 {id} → 从者 {target}",

        // 回合出牌
        attackTitle: "🗡️ 回合出牌 (Attack)",
        attackSubtitle: "",
        btnResetAttack: "✕ 清空",
        btnResetAttackTitle: "清空当前出牌重选",
        resetAttackToast: "已清空当前选卡",
        categoryNp: "👑 宝具",
        categoryColor: "🎨 色卡",
        categoryNormal: "🃏 普攻",

        np1Btn: "👑 宝具 1",
        np1BtnTitle: "从者 1 宝具 (6)",
        np2Btn: "👑 宝具 2",
        np2BtnTitle: "从者 2 宝具 (7)",
        np3Btn: "👑 宝具 3",
        np3BtnTitle: "从者 3 宝具 (8)",

        colorBusterBtn: "🔴 红卡 (B)",
        colorBusterBtnTitle: "智能优先选择红卡 (Buster · 可多次连选)",
        colorArtsBtn: "🔵 蓝卡 (A)",
        colorArtsBtnTitle: "智能优先选择蓝卡 (Arts · 可多次连选)",
        colorQuickBtn: "🟢 绿卡 (Q)",
        colorQuickBtnTitle: "智能优先选择绿卡 (Quick · 可多次连选)",

        normalCardBtn: "第 {num} 张",
        normalCardBtnTitle: "发牌第 {num} 张",

        seqLabel1: "一",
        seqLabel2: "二",
        seqLabel3: "三",
        cancelCardTagTitle: "点击取消顺位【{seq}】({card})",
        cancelCardToast: "已取消顺位【{seq}】({cardName})",
        attackFullWarnToast: "⚠️ 已选满 3 张牌，请先取消某张牌再更换",
        attackUpdatedToast: "⚡ Wave {wave} 出牌已更新：{cards}",
        editAttackHintToast: "💡 已定位到 Wave {wave}。在右侧控制台点击任意 3 张卡牌即可更新出牌。",

        // 操作反馈
        actionModifiedToast: "✏️ Wave {wave} 第 {step} 步已修改为：{desc}",
        actionAddedToast: "➕ Wave {wave} 已添加：{desc}"
    },

    // 7. 弹窗系统文案 (Modals)
    modals: {
        btnCancel: "取消",
        btnClose: "✕",

        // 技能目标选择弹窗 (#targetModal)
        targetModal: {
            title: "选择技能作用目标",
            optSelf: "⚡ 无目标 / 自身",
            optServant1: "👤 从者 1",
            optServant2: "👤 从者 2",
            optServant3: "👤 从者 3",
            addSkillToast: "⚔️ Wave {wave} 已添加从者技能",
            addMasterToast: "👔 Wave {wave} 已添加御主技能"
        },

        // 动作修改弹窗 (#editStepModal)
        editStepModal: {
            titleTarget: "🎯 修改选敌目标 (Wave {wave} 第 {step} 步)",
            titleSkill: "⚔️ 修改从者技能 (Wave {wave} 第 {step} 步)",
            titleMaster: "👔 修改御主礼装技能 (Wave {wave} 第 {step} 步)",
            titleSwap: "👔 修改礼装换人动作 (Wave {wave} 第 {step} 步)",
            labelLockTarget: "选择锁定目标 (上排 1~3 | 下排 4~6)：",
            targetBtn: "目标 {target}",
            labelSkillSeq: "选择技能序号 (从者 1: 1~3 | 从者 2: 4~6 | 从者 3: 7~9)：",
            skillOptBtn: "从者{servant} 技{skill} (s{code}x)",
            labelTarget: "选择作用目标：",
            targetSelf: "⚡ 无/自身",
            targetNone: "⚡ 无目标",
            targetServant: "👤 从者 {target}",
            labelMasterSkill: "选择御主技能：",
            masterSkillBtn: "👔 技能 {id}",
            labelSwapMasterSkill: "触发换人的御主技能：",
            labelSwapFront: "前排互换从者：",
            swapFrontBtn: "前排 {num} 号从者",
            labelSwapBack: "后排替补从者：",
            swapBackBtn: "后排 {num} 号替补",
            btnDeleteStep: "🗑️ 删除此动作",
            btnSaveStep: "保存修改",
            stepUpdatedToast: "✏️ 已更新 Wave {wave} 的动作",
            stepDeletedToast: "🗑️ 已删除该动作"
        },

        // 换人专属弹窗 (#swapModal)
        swapModal: {
            titleDefault: "御主技能：换人 (Order Change)",
            instruction: "请选择需要互换的前排从者与后排替补：",
            frontBtn: "前排 {num} 号从者",
            backBtn: "后排 {num} 号替补",
            btnConfirm: "确定换人",
            swapDesc: "换人: 前排{f} ⇄ 替补{b}"
        },

        // DSL 导入弹窗 (#importDslModal)
        importDslModal: {
            title: "📥 导入方案 DSL 脚本",
            helpLine1: "支持单回合或多回合 DSL 指令（回合间用分号 <code>;</code> 或换行分隔）：",
            helpLine2: "例如：",
            example1: "s10 | a1, 2, 3",
            helpOr: " 或 ",
            example2: "s20, 30 | a7, 8, 5; s10 | a6, 4, 5",
            placeholder: "在此粘贴 DSL 动作脚本，例如：\ns10 | a1, 2, 3\n或 s20, 30, 40 | a7, 8, 5; s10 | a6, 4, 5; s92, 50 | m22 | a7, 4, 5",
            errorEmpty: "⚠️ 请先输入或粘贴 DSL 脚本字符串！",
            errorInvalid: "⚠️ 未能解析出有效的回合指令！",
            errorParseFailed: "❌ 解析出错：{error}",
            btnImportNew: "➕ 导入为新方案",
            btnImportNewTitle: "基于导入的 DSL 新建为一个全新方案",
            btnOverwrite: "⚡ 覆盖当前方案",
            btnOverwriteTitle: "用导入的 DSL 覆盖当前方案的所有回合",
            btnPasteClipboard: "📋 识别剪贴板",
            btnPasteClipboardTitle: "读取系统剪贴板并自动识别 DSL 脚本填入",
            clipboardDetectedToast: "📋 已自动识别并填入剪贴板中的 DSL",
            clipboardEmptyOrInvalid: "⚠️ 剪贴板中未检测到有效的 DSL 动作脚本",
            importNewSuccessToast: "✅ 已将 DSL 导入为新方案 {count}（共 {rounds} 个回合）",
            overwriteSuccessToast: "✅ 已成功覆盖方案 {index}（共 {rounds} 个回合）"
        }
    },

    // 8. 看板时序动作芯片标签 (Timeline Chip Labels)
    stepLabels: {
        target: "🎯 锁定目标 {target}",
        servantSkillTarget: "⚔️ 从者技能 {skillId} → 从者 {targetId}",
        servantSkillSelf: "⚔️ 从者技能 {skillId}",
        swap: "👔 换人: 前排{front} ⇄ 替补{back}",
        masterSkillTarget: "👔 御主技能 {masterId} → 从者 {targetId}",
        masterSkillSelf: "👔 御主技能 {masterId}",
        defaultStepName: "第 {step} 步"
    },

    // 9. 出牌卡片文案与标签 (Attack Cards Display)
    cards: {
        np1Badge: "👑 宝1",
        np2Badge: "👑 宝2",
        np3Badge: "👑 宝3",
        np1Plain: "宝1",
        np2Plain: "宝2",
        np3Plain: "宝3",
        busterBadge: "🔴 红卡",
        artsBadge: "🔵 蓝卡",
        quickBadge: "🟢 绿卡",
        busterPlain: "红卡",
        artsPlain: "蓝卡",
        quickPlain: "绿卡",
        normalBadge: "🃏 普{num}",
        normalPlain: "普{num}",
        cardInfoLabels: {
            '6': { label: '👑 宝具 1 (6)', color: 'var(--gold)' },
            '7': { label: '👑 宝具 2 (7)', color: 'var(--gold)' },
            '8': { label: '👑 宝具 3 (8)', color: 'var(--gold)' },
            'B': { label: '🔴 红卡 (B)', color: '#f87171' },
            'A': { label: '🔵 蓝卡 (A)', color: '#60a5fa' },
            'Q': { label: '🟢 绿卡 (Q)', color: 'var(--quick)' },
            '1': { label: '🃏 普 1 (1)', color: 'var(--text-main)' },
            '2': { label: '🃏 普 2 (2)', color: 'var(--text-main)' },
            '3': { label: '🃏 普 3 (3)', color: 'var(--text-main)' },
            '4': { label: '🃏 普 4 (4)', color: 'var(--text-main)' },
            '5': { label: '🃏 普 5 (5)', color: 'var(--text-main)' }
        }
    },

    // 10. 常用助战列表 (Supported Friends)
    supportedFriends: [
        { key: "", label: "-- 留空 / 无助战 --", shortLabel: "无助战" },
        { key: "aobao", label: "奥伯龙 (aobao)", shortLabel: "奥伯龙" },
        { key: "aobaoshan", label: "奥伯龙+善 (aobaoshan)", shortLabel: "奥伯龙+善" },
        { key: "cdai", label: "术呆 / C呆 (cdai)", shortLabel: "术呆" },
        { key: "daoman", label: "道满 (daoman)", shortLabel: "道满" },
        { key: "cba", label: "术斯卡蒂 (cba)", shortLabel: "术斯卡蒂" },
        { key: "rba", label: "尺斯卡蒂 (rba)", shortLabel: "尺斯卡蒂" },
        { key: "rbashan", label: "尺斯卡蒂+善 (rbashan)", shortLabel: "尺斯卡蒂+善" },
        { key: "shahu", label: "杀狐 (shahu)", shortLabel: "杀狐" },
        { key: "shahushan", label: "杀狐+善 (shahushan)", shortLabel: "杀狐+善" },
        { key: "princess", label: "爱尔奎特·公主 (princess)", shortLabel: "公主" },
        { key: "princess120", label: "公主120级 (princess120)", shortLabel: "公主120" },
        { key: "taigong", label: "太公望 (taigong)", shortLabel: "太公望" },
        { key: "sparrow", label: "红阎魔 (sparrow)", shortLabel: "红阎魔" },
        { key: "mary", label: "奥尔加玛丽 (mary)", shortLabel: "奥尔加玛丽" },
        { key: "keli", label: "水飞嫂 (keli)", shortLabel: "水飞嫂" },
        { key: "bdai", label: "狂呆 / 呆呆 (bdai)", shortLabel: "狂呆" }
    ],

    // 11. 全局通知与操作提示 (Messages & Toast Notifications)
    messages: {
        copySuccess: "📋 完整配置代码已复制到剪贴板！",
        copyFail: "❌ 复制失败，请重试",
        saveSuccess: "✅ 配置已直接保存至 Q/battle_v3_config.q",
        backupSuffix: " (已生成备份: {backup})",
        saveError: "❌ 保存出错: {error}",
        autoLoadSuccess: "✅ 已自动读取 {path}",
        autoLoadFailWarn: "Auto-load config failed:"
    }
};

/**
 * 格式化模板字符串：将文本中的 `{paramName}` 替换为对应的真实值
 * @param {string} template 包含占位符的模板字符串，如 "已删除第 {wave} 回合"
 * @param {Record<string, any>} params 参数键值对象，如 { wave: 2 }
 * @returns {string} 替换后的字符串
 */
export function formatText(template, params = {}) {
    if (!template || typeof template !== 'string') return '';
    return template.replace(/\{(\w+)\}/g, (match, key) => {
        return params[key] !== undefined ? String(params[key]) : match;
    });
}
