import { appState, getCurGroup, getCurScheme, getInitialSnapshot } from './state.js';
import { DEFAULT_ROUND_ATTACK } from './constants.js';

// 创建标准空回合结构（统一新建方案与新建wave的默认出牌和动作配置）
export function createDefaultRound() {
    return {
        steps: [],
        attack: [...DEFAULT_ROUND_ATTACK]
    };
}

// 从可能包含代码/变量声明/引号的外部文本中智能识别并提取纯净的 DSL 字符串
export function extractDslFromText(text) {
    if (!text || typeof text !== 'string') return '';
    let str = text.trim();
    if (!str) return '';

    // 1. 如果包含 Q 脚本变量赋值语句或 JSON 字段 (如 SCHEME_G0_1 = "..." 或 "dsl": "...")
    const schemeMatch = str.match(/SCHEME_[A-Za-z0-9_]+\s*=\s*["']([^"']+)["']/i);
    if (schemeMatch && schemeMatch[1]) {
        str = schemeMatch[1].trim();
    } else {
        const jsonMatch = str.match(/["']?dsl["']?\s*[:=]\s*["']([^"']+)["']/i);
        if (jsonMatch && jsonMatch[1]) {
            str = jsonMatch[1].trim();
        }
    }

    // 2. 如果首尾包裹着双引号或单引号，予以剥离
    if ((str.startsWith('"') && str.endsWith('"')) || (str.startsWith("'") && str.endsWith("'"))) {
        str = str.slice(1, -1).trim();
    }

    // 3. 校验是否符合 DSL 特征：
    // 分割回合校验，每一回合通常包含形如 s10, m20, t1, a1,2,3 或带有管道符 '|'
    const roundParts = str.replace(/[\r\n]+/g, ';').split(';').map(s => s.trim()).filter(Boolean);
    if (!roundParts.length) return '';

    const dslPattern = /\b[smt]\d{1,5}\b|\||\ba[\s,]*[1-8baq]/i;
    const hasDslSignature = roundParts.some(part => dslPattern.test(part));

    return hasDslSignature ? str : '';
}

// 将单回合 DSL 字符串 (如 "s20, 30 | m22 | a7, 8, 5") 解析为结构化对象:
// { steps: [ {type:'skill', code:20}, ...], attack: ['7','4','5'] }
export function parseRoundDsl(roundDslStr) {
    const res = createDefaultRound();
    if (!roundDslStr) return res;

    const groups = roundDslStr.split('|').map(s => s.trim()).filter(Boolean);
    groups.forEach(groupStr => {
        const parts = groupStr.split(',').map(s => s.trim()).filter(Boolean);
        if (!parts.length) return;

        const first = parts[0];
        const prefix = first[0]?.toLowerCase();

        if (prefix === 'a') {
            // 出牌阶段 (例如 a1,2,3 或 a 1, 2, 3 或 a, 1, 2, 3)
            const normCard = c => (['b', 'a', 'q'].includes(c.toLowerCase()) ? c.toUpperCase() : c);
            let cards = [];
            const firstVal = first.slice(1).trim();
            if (firstVal) {
                cards = [firstVal, ...parts.slice(1)];
            } else {
                cards = [...parts.slice(1)];
            }
            cards = cards.map(normCard);
            res.attack = [cards[0] || '7', cards[1] || 'B', cards[2] || 'B'];
        } else if (prefix === 't') {
            // 选敌目标
            const targetNum = first.slice(1).trim() || (parts[1] ? parts[1].trim() : '1');
            res.steps.push({ type: 'target', target: targetNum });
        } else if (prefix === 's') {
            // 从者技能组
            const firstCode = first.slice(1).trim();
            if (firstCode) res.steps.push({ type: 'skill', code: firstCode });
            for (let i = 1; i < parts.length; i++) {
                const code = parts[i].trim();
                if (code) res.steps.push({ type: 'skill', code });
            }
        } else if (prefix === 'm') {
            // 御主技能组与换人
            const firstCode = first.slice(1).trim();
            if (firstCode) res.steps.push({ type: 'master', code: firstCode });
            for (let i = 1; i < parts.length; i++) {
                const code = parts[i].trim();
                if (code) res.steps.push({ type: 'master', code });
            }
        }
    });
    return res;
}

// 将方案的回合结构数组编译回标准 DSL 字符串
export function compileSchemeDsl(roundsData) {
    return roundsData.map(r => {
        const groupSegments = [];
        let curType = null;
        let curList = [];

        r.steps.forEach(st => {
            if (st.type === 'target') {
                if (curList.length) {
                    groupSegments.push(curType === 'skill' ? `s${curList.join(', ')}` : `m${curList.join(', ')}`);
                    curList = [];
                    curType = null;
                }
                groupSegments.push(`t${st.target}`);
            } else if (st.type === 'skill') {
                if (curType !== 'skill' && curList.length) {
                    groupSegments.push(`m${curList.join(', ')}`);
                    curList = [];
                }
                curType = 'skill';
                curList.push(st.code);
            } else if (st.type === 'master') {
                if (curType !== 'master' && curList.length) {
                    groupSegments.push(`s${curList.join(', ')}`);
                    curList = [];
                }
                curType = 'master';
                curList.push(st.code);
            }
        });
        if (curList.length) {
            groupSegments.push(curType === 'skill' ? `s${curList.join(', ')}` : `m${curList.join(', ')}`);
        }

        // 加上 attack
        if (r.attack && r.attack.length) {
            groupSegments.push(`a${r.attack.join(', ')}`);
        }
        return groupSegments.join(' | ');
    }).join(';');
}

// 获取当前激活方案的所有回合结构化数据
export function getCurSchemeRounds() {
    const scheme = getCurScheme();
    if (!scheme) return [];
    if (!scheme._parsedRounds) {
        const roundDsls = (scheme.dsl || "").split(';').map(s => s.trim()).filter(Boolean);
        if (!roundDsls.length) roundDsls.push(compileSchemeDsl([createDefaultRound()]));
        scheme._parsedRounds = roundDsls.map(parseRoundDsl);
    }
    return scheme._parsedRounds;
}

// 同步回合数据并更新 DSL
export function commitChanges() {
    const scheme = getCurScheme();
    if (scheme && scheme._parsedRounds) {
        scheme.dsl = compileSchemeDsl(scheme._parsedRounds);
    }
}

// 重置当前方案所有回合状态到配置文件/初始快照状态
export function resetCurSchemeRoundsToInitial() {
    const curGroup = getCurGroup();
    const curScheme = getCurScheme();
    if (!curGroup || !curScheme) return;

    const snapshot = getInitialSnapshot();
    const snapGroup = snapshot?.groups?.find(g => g.groupId === curGroup.groupId)
                   || snapshot?.groups?.[appState.curGroupIdx];
    const snapScheme = snapGroup?.schemes?.[appState.curSchemeIdx];

    const initialDsl = snapScheme ? (snapScheme.dsl ?? "") : compileSchemeDsl([createDefaultRound()]);
    curScheme.dsl = initialDsl;
    curScheme._parsedRounds = null;

    appState.selectedStepState = null;
    appState.currentEditingStepInfo = null;

    const rounds = getCurSchemeRounds();
    if (appState.curRoundIdx >= rounds.length) {
        appState.curRoundIdx = Math.max(0, rounds.length - 1);
    }

    commitChanges();
}


// 生成完整的按键精灵 Q 配置文件文本
export function generateConfigText(stateData) {
    const out = [
        "' battle_v3_config.q",
        "' 配置源文件：只保存配置，不保存战斗逻辑",
        "' 按键精灵编译后会把它下发成 .mq，逻辑主脚本读取这个 mq 文件内容",
        "",
        "' 好友关键字填写在下面按关卡配置的 FRIEND_Gx_y 中；不区分大小写。",
        "' 支持：aobao, aobaoshan, cdai, daoman, cba, rba, rbashan,",
        "'       shahu, shahushan, princess, princess120, taigong, sparrow, mary, keli",
        "' 优先级：FRIEND_Gx_y > FRIEND_Gx > friend（全局字段，目前未在此文件配置）。",
        "",
        "' USER CONFIG",
        "Dim ACTIVITY_REWARD = 0",
        "",
        "' BATTLE CONFIG",
        "' DSL 大组在 battle_v3_runner.q 里手动改（CFG_ACTION_GROUP_INDEX）",
        "' 0=test, 1=campaign, 2=caber, 3=grand, 4=ordeal"
    ];

    stateData.groups.forEach(g => {
        const gNum = g.groupId;
        out.push("");
        out.push("' -----------------------------");
        let groupDesc = `' 大组 ${gNum}: ${g.name}`;
        if (g.hint) groupDesc += `（${g.hint}）`;
        out.push(groupDesc);
        out.push(`Dim ACTIVITY_REWARD_G${gNum} = ${g.activityReward ?? 0}`);
        out.push(`Dim ACTION_ROUND_INDEX_G${gNum} = ${g.defaultScheme}`);
        if (g.defaultFriend) {
            out.push(`Dim FRIEND_G${gNum} = "${g.defaultFriend}"`);
        }
        g.schemes.forEach((s, sIdx) => {
            const sNum = sIdx + 1;
            const dsl = s.dsl || '';
            const sName = s.name || s.friend || '';
            if (sName) {
                out.push(`' 方案 ${sNum}: ${sName}`);
            }
            out.push(`Dim FRIEND_G${gNum}_${sNum} = "${s.friend || ''}"`);
            out.push(`Dim DSL_G${gNum}_${sNum} = "${dsl}"`);
        });
    });

    out.push("");
    out.push("' 预设说明：");
    out.push("' test     = 测试配置");
    out.push("' campaign = 活动关卡配置");
    out.push("' caber    = 术呆常用配置");
    out.push("' grand    = 戴冠战关卡配置");
    out.push("' ordeal   = 白纸化地球 Ordeal Call 配置");
    out.push("' custom   = 手工逐项修改上面字段");
    out.push("");

    return out.join('\n');
}

// 解析从磁盘读取的 Q 配置文件文本并同步至状态树
export function parseConfigFileText(text, stateData) {
    const getVal = key => {
        const m = text.match(new RegExp('^\\s*(?:Dim\\s+)?' + key.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&') + '\\s*=\\s*(?:"([^"\\r\\n]*)"|([^\\r\\n]+))', 'im'));
        return m ? (m[1] ?? m[2]).trim() : '';
    };

    stateData.groups.forEach(g => {
        const gNum = g.groupId;
        const def = getVal(`ACTION_ROUND_INDEX_G${gNum}`);
        if (def) g.defaultScheme = Number(def);

        const rew = getVal(`ACTIVITY_REWARD_G${gNum}`);
        if (rew !== '') {
            g.activityReward = Number(rew);
        } else {
            g.activityReward = 0;
        }

        const friendG = getVal(`FRIEND_G${gNum}`);
        if (friendG) g.defaultFriend = friendG;

        const parsedSchemes = [];
        for (let sNum = 1; sNum <= 20; sNum++) {
            const fr = getVal(`FRIEND_G${gNum}_${sNum}`) || (gNum === 0 && sNum === 1 ? friendG : '') || friendG || '';
            const dsl = getVal(`DSL_G${gNum}_${sNum}`) || getVal(`TEST_DSL_G${gNum}_${sNum}`) || (gNum === 0 ? getVal(`TEST_DSL_${sNum}`) : '');
            const nameMatch = text.match(new RegExp(`'\\s*(?:方案|Scheme)\\s*${sNum}\\s*[:：]\\s*([^\\r\\n]+)[\\r\\n]+(?:Dim\\s+FRIEND_G${gNum}_${sNum}|Dim\\s+DSL_G${gNum}_${sNum})`, 'i'));
            const schemeName = nameMatch ? nameMatch[1].trim() : '';
            if (dsl || (gNum === 0 && sNum <= 3) || sNum <= g.schemes.length) {
                if (dsl) {
                    parsedSchemes.push({
                        name: schemeName || fr || '',
                        friend: fr,
                        dsl: dsl
                    });
                }
            } else {
                break;
            }
        }

        if (parsedSchemes.length) {
            g.schemes = parsedSchemes;
        }
    });
}
