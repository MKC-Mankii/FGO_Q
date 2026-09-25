import { initialData } from './constants.js';

// 应用全局响应状态
export const appState = {
    data: structuredClone(initialData),
    curGroupIdx: 0,
    curSchemeIdx: 0,
    curRoundIdx: 0,

    // 弹窗与选择临时态
    pendingAction: null,
    pendingSwapMasterId: 3,
    selectedSwapFront: 3,
    selectedSwapBack: 4,

    // 出牌配置状态
    curAttackSlot: 0,
    curAttackCards: ['7', '4', '5'],

    // 看板与选中高亮态
    selectedStepState: null,         // { waveIdx, stepIdx }
    currentEditingStepInfo: null     // { waveIdx, stepIdx, tempStep }
};

// 快照基准态（初始为预设数据，后端载入或保存后更新为最新快照）
let initialSnapshot = structuredClone(initialData);

export function setInitialSnapshot(data) {
    initialSnapshot = structuredClone(data);
}

export function getInitialSnapshot() {
    return initialSnapshot;
}

export function getCurGroup() {
    return appState.data.groups[appState.curGroupIdx];
}

export function getCurScheme() {
    const group = getCurGroup();
    return group ? group.schemes[appState.curSchemeIdx] : null;
}

export function resetStateToInitial() {
    appState.data = structuredClone(initialSnapshot || initialData);
    appState.curGroupIdx = 0;
    appState.curSchemeIdx = 0;
    appState.curRoundIdx = 0;
    appState.pendingAction = null;
    appState.selectedStepState = null;
    appState.currentEditingStepInfo = null;
}
