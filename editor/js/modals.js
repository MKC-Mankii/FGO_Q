import { appState, getCurGroup, getCurScheme } from './state.js';
import { CARD_INFO } from './constants.js';
import { getCurSchemeRounds, commitChanges, parseRoundDsl, compileSchemeDsl, extractDslFromText } from './dsl.js';
import { $, toast } from './api.js';
import { TEXT_CONFIG, formatText } from './text_config.js';

const escapeHtml = str => String(str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

let updateCallback = null;


export function registerUpdateCallback(fn) {
    updateCallback = fn;
}

function triggerUpdate(opts) {
    if (typeof updateCallback === 'function') {
        updateCallback(opts);
    }
}

export function closeModal() {
    const targetModal = $('targetModal');
    if (targetModal) targetModal.classList.remove('show');

    const swapModal = $('swapModal');
    if (swapModal) swapModal.classList.remove('show');

    const attM = $('attackModal');
    if (attM) attM.classList.remove('show');

    const impM = $('importDslModal');
    if (impM) impM.classList.remove('show');

    const editM = $('editStepModal');
    if (editM) editM.classList.remove('show');

    appState.pendingAction = null;
    appState.currentEditingStepInfo = null;
}

// 格式化出牌卡片文案 (文本纯字符串格式)
export function formatAttackCards(cards) {
    if (!cards || !cards.length) return '';
    return cards.map(c => {
        const str = String(c).trim().toUpperCase();
        if (str === '6') return TEXT_CONFIG.cards.np1Plain;
        if (str === '7') return TEXT_CONFIG.cards.np2Plain;
        if (str === '8') return TEXT_CONFIG.cards.np3Plain;
        if (str === 'B') return TEXT_CONFIG.cards.busterPlain;
        if (str === 'A') return TEXT_CONFIG.cards.artsPlain;
        if (str === 'Q') return TEXT_CONFIG.cards.quickPlain;
        return formatText(TEXT_CONFIG.cards.normalPlain, { num: str });
    }).join(' + ');
}

// 生成左侧已选出牌小组件内部的 3 张牌独立框体 HTML（带独立色系与位置卡基础色）
export function formatAttackCardsBadgesHtml(cards) {
    if (!cards || !cards.length) return '';
    return cards.map(c => {
        const str = String(c).trim().toUpperCase();
        let label = str;
        let typeCls = 'normal';
        if (str === '6') { label = TEXT_CONFIG.cards.np1Badge; typeCls = 'np'; }
        else if (str === '7') { label = TEXT_CONFIG.cards.np2Badge; typeCls = 'np'; }
        else if (str === '8') { label = TEXT_CONFIG.cards.np3Badge; typeCls = 'np'; }
        else if (str === 'B') { label = TEXT_CONFIG.cards.busterBadge; typeCls = 'buster'; }
        else if (str === 'A') { label = TEXT_CONFIG.cards.artsBadge; typeCls = 'arts'; }
        else if (str === 'Q') { label = TEXT_CONFIG.cards.quickBadge; typeCls = 'quick'; }
        else {
            label = formatText(TEXT_CONFIG.cards.normalBadge, { num: str });
            typeCls = 'normal'; // 位置卡使用基础色
        }
        return `<span class="attack-mini-card ${typeCls}">${label}</span>`;
    }).join('');
}

// 点击时序中的出牌卡片：切换当前回合，引导用户通过右侧直接点选3张卡牌更新
export function editRoundAttack(waveIdx, event) {
    if (event) event.stopPropagation();
    appState.curRoundIdx = waveIdx;
    if (typeof window.setActiveWave === 'function') {
        window.setActiveWave(waveIdx);
    }
    toast(formatText(TEXT_CONFIG.palette.editAttackHintToast, { wave: waveIdx + 1 }));
}


// 打开动作修改弹窗
export function openEditStepModal(waveIdx, stepIdx) {
    const rounds = getCurSchemeRounds();
    const step = rounds[waveIdx]?.steps?.[stepIdx];
    if (!step) return;

    appState.currentEditingStepInfo = {
        waveIdx,
        stepIdx,
        tempStep: JSON.parse(JSON.stringify(step))
    };

    const body = $('editStepModalBody');
    if (!body) return;

    const cfg = TEXT_CONFIG.modals.editStepModal;

    if (step.type === 'target') {
        $('editStepModalTitle').textContent = formatText(cfg.titleTarget, { wave: waveIdx + 1, step: stepIdx + 1 });
        const curT = Number(step.target) || 1;
        let targetBtnsHtml = '';
        for (let i = 1; i <= 6; i++) {
            targetBtnsHtml += `<button class="edit-step-opt-btn ${curT === i ? 'active' : ''}" onclick="window.setEditStepTarget(${i})">${escapeHtml(formatText(cfg.targetBtn, { target: i }))}</button>`;
        }
        body.innerHTML = `
            <div class="edit-step-group">
                <span class="edit-step-label">${escapeHtml(cfg.labelLockTarget)}</span>
                <div class="edit-step-grid" style="grid-template-columns: repeat(3, 1fr);">
                    ${targetBtnsHtml}
                </div>
            </div>
        `;
    } else if (step.type === 'skill') {
        const code = String(step.code || '10');
        const sId = Number(code[0]) || 1;
        const tId = Number(code[1]) || 0;

        $('editStepModalTitle').textContent = formatText(cfg.titleSkill, { wave: waveIdx + 1, step: stepIdx + 1 });
        
        let skillBtnsHtml = '';
        for (let i = 1; i <= 9; i++) {
            const servantNum = Math.ceil(i / 3);
            const skillNum = i;
            const btnText = formatText(cfg.skillOptBtn, { servant: servantNum, skill: skillNum, code: i });
            skillBtnsHtml += `<button class="edit-step-opt-btn ${sId === i ? 'active' : ''}" onclick="window.setEditStepSkillId(${i})">${escapeHtml(btnText)}</button>`;
        }

        body.innerHTML = `
            <div class="edit-step-group">
                <span class="edit-step-label">${escapeHtml(cfg.labelSkillSeq)}</span>
                <div class="edit-step-grid">
                    ${skillBtnsHtml}
                </div>
            </div>
            <div class="edit-step-group">
                <span class="edit-step-label">${escapeHtml(cfg.labelTarget)}</span>
                <div class="edit-step-grid" style="grid-template-columns: repeat(4, 1fr);">
                    <button class="edit-step-opt-btn ${tId === 0 ? 'active' : ''}" onclick="window.setEditStepSkillTarget(0)">${escapeHtml(cfg.targetSelf)}</button>
                    <button class="edit-step-opt-btn ${tId === 1 ? 'active' : ''}" onclick="window.setEditStepSkillTarget(1)">${escapeHtml(formatText(cfg.targetServant, { target: 1 }))}</button>
                    <button class="edit-step-opt-btn ${tId === 2 ? 'active' : ''}" onclick="window.setEditStepSkillTarget(2)">${escapeHtml(formatText(cfg.targetServant, { target: 2 }))}</button>
                    <button class="edit-step-opt-btn ${tId === 3 ? 'active' : ''}" onclick="window.setEditStepSkillTarget(3)">${escapeHtml(formatText(cfg.targetServant, { target: 3 }))}</button>
                </div>
            </div>
        `;
    } else if (step.type === 'master') {
        const code = String(step.code || '10');
        const isSwap = code.length === 5 && code.substring(1, 3) === '00';
        if (isSwap) {
            const f = Number(code[3]) || 3;
            const b = Number(code[4]) || 4;
            $('editStepModalTitle').textContent = formatText(cfg.titleSwap, { wave: waveIdx + 1, step: stepIdx + 1 });
            body.innerHTML = `
                <div class="edit-step-group">
                    <span class="edit-step-label">${escapeHtml(cfg.labelSwapFront)}</span>
                    <div class="edit-step-grid">
                        <button class="edit-step-opt-btn ${f === 1 ? 'active' : ''}" onclick="window.setEditStepSwapFront(1)">${escapeHtml(formatText(cfg.swapFrontBtn, { num: 1 }))}</button>
                        <button class="edit-step-opt-btn ${f === 2 ? 'active' : ''}" onclick="window.setEditStepSwapFront(2)">${escapeHtml(formatText(cfg.swapFrontBtn, { num: 2 }))}</button>
                        <button class="edit-step-opt-btn ${f === 3 ? 'active' : ''}" onclick="window.setEditStepSwapFront(3)">${escapeHtml(formatText(cfg.swapFrontBtn, { num: 3 }))}</button>
                    </div>
                </div>
                <div class="edit-step-group">
                    <span class="edit-step-label">${escapeHtml(cfg.labelSwapBack)}</span>
                    <div class="edit-step-grid">
                        <button class="edit-step-opt-btn ${b === 4 ? 'active' : ''}" onclick="window.setEditStepSwapBack(4)">${escapeHtml(formatText(cfg.swapBackBtn, { num: 4 }))}</button>
                        <button class="edit-step-opt-btn ${b === 5 ? 'active' : ''}" onclick="window.setEditStepSwapBack(5)">${escapeHtml(formatText(cfg.swapBackBtn, { num: 5 }))}</button>
                        <button class="edit-step-opt-btn ${b === 6 ? 'active' : ''}" onclick="window.setEditStepSwapBack(6)">${escapeHtml(formatText(cfg.swapBackBtn, { num: 6 }))}</button>
                    </div>
                </div>
            `;
        } else {
            const mId = Number(code[0]) || 1;
            const tId = Number(code[1]) || 0;
            $('editStepModalTitle').textContent = formatText(cfg.titleMaster, { wave: waveIdx + 1, step: stepIdx + 1 });
            body.innerHTML = `
                <div class="edit-step-group">
                    <span class="edit-step-label">${escapeHtml(cfg.labelMasterSkill)}</span>
                    <div class="edit-step-grid">
                        <button class="edit-step-opt-btn ${mId === 1 ? 'active' : ''}" onclick="window.setEditStepMasterId(1)">${escapeHtml(formatText(cfg.masterSkillBtn, { id: 1 }))}</button>
                        <button class="edit-step-opt-btn ${mId === 2 ? 'active' : ''}" onclick="window.setEditStepMasterId(2)">${escapeHtml(formatText(cfg.masterSkillBtn, { id: 2 }))}</button>
                        <button class="edit-step-opt-btn ${mId === 3 ? 'active' : ''}" onclick="window.setEditStepMasterId(3)">${escapeHtml(formatText(cfg.masterSkillBtn, { id: 3 }))}</button>
                    </div>
                </div>
                <div class="edit-step-group">
                    <span class="edit-step-label">${escapeHtml(cfg.labelTarget)}</span>
                    <div class="edit-step-grid" style="grid-template-columns: repeat(4, 1fr);">
                        <button class="edit-step-opt-btn ${tId === 0 ? 'active' : ''}" onclick="window.setEditStepMasterTarget(0)">${escapeHtml(cfg.targetNone)}</button>
                        <button class="edit-step-opt-btn ${tId === 1 ? 'active' : ''}" onclick="window.setEditStepMasterTarget(1)">${escapeHtml(formatText(cfg.targetServant, { target: 1 }))}</button>
                        <button class="edit-step-opt-btn ${tId === 2 ? 'active' : ''}" onclick="window.setEditStepMasterTarget(2)">${escapeHtml(formatText(cfg.targetServant, { target: 2 }))}</button>
                        <button class="edit-step-opt-btn ${tId === 3 ? 'active' : ''}" onclick="window.setEditStepMasterTarget(3)">${escapeHtml(formatText(cfg.targetServant, { target: 3 }))}</button>
                    </div>
                </div>
            `;
        }
    }

    $('editStepModal').classList.add('show');
}

export function setEditStepTarget(tVal) {
    if (!appState.currentEditingStepInfo) return;
    appState.currentEditingStepInfo.tempStep.target = String(tVal);
    openEditStepModal(appState.currentEditingStepInfo.waveIdx, appState.currentEditingStepInfo.stepIdx);
}

export function setEditStepSkillId(sId) {
    if (!appState.currentEditingStepInfo) return;
    const oldCode = String(appState.currentEditingStepInfo.tempStep.code || '10');
    const target = oldCode[1] || '0';
    appState.currentEditingStepInfo.tempStep.code = `${sId}${target}`;
    openEditStepModal(appState.currentEditingStepInfo.waveIdx, appState.currentEditingStepInfo.stepIdx);
}

export function setEditStepSkillTarget(tId) {
    if (!appState.currentEditingStepInfo) return;
    const oldCode = String(appState.currentEditingStepInfo.tempStep.code || '10');
    const sId = oldCode[0] || '1';
    appState.currentEditingStepInfo.tempStep.code = `${sId}${tId}`;
    openEditStepModal(appState.currentEditingStepInfo.waveIdx, appState.currentEditingStepInfo.stepIdx);
}

export function setEditStepMasterId(mId) {
    if (!appState.currentEditingStepInfo) return;
    const oldCode = String(appState.currentEditingStepInfo.tempStep.code || '10');
    const target = oldCode[1] || '0';
    appState.currentEditingStepInfo.tempStep.code = `${mId}${target}`;
    openEditStepModal(appState.currentEditingStepInfo.waveIdx, appState.currentEditingStepInfo.stepIdx);
}

export function setEditStepMasterTarget(tId) {
    if (!appState.currentEditingStepInfo) return;
    const oldCode = String(appState.currentEditingStepInfo.tempStep.code || '10');
    const mId = oldCode[0] || '1';
    appState.currentEditingStepInfo.tempStep.code = `${mId}${tId}`;
    openEditStepModal(appState.currentEditingStepInfo.waveIdx, appState.currentEditingStepInfo.stepIdx);
}

export function setEditStepSwapMasterId(mId) {
    if (!appState.currentEditingStepInfo) return;
    const oldCode = String(appState.currentEditingStepInfo.tempStep.code || '30034');
    const f = oldCode[3] || '3';
    const b = oldCode[4] || '4';
    appState.currentEditingStepInfo.tempStep.code = `${mId}00${f}${b}`;
    openEditStepModal(appState.currentEditingStepInfo.waveIdx, appState.currentEditingStepInfo.stepIdx);
}

export function setEditStepSwapFront(fVal) {
    if (!appState.currentEditingStepInfo) return;
    const oldCode = String(appState.currentEditingStepInfo.tempStep.code || '30034');
    const mId = oldCode[0] || '3';
    const b = oldCode[4] || '4';
    appState.currentEditingStepInfo.tempStep.code = `${mId}00${fVal}${b}`;
    openEditStepModal(appState.currentEditingStepInfo.waveIdx, appState.currentEditingStepInfo.stepIdx);
}

export function setEditStepSwapBack(bVal) {
    if (!appState.currentEditingStepInfo) return;
    const oldCode = String(appState.currentEditingStepInfo.tempStep.code || '30034');
    const mId = oldCode[0] || '3';
    const f = oldCode[3] || '3';
    appState.currentEditingStepInfo.tempStep.code = `${mId}00${f}${bVal}`;
    openEditStepModal(appState.currentEditingStepInfo.waveIdx, appState.currentEditingStepInfo.stepIdx);
}

export function saveEditingStep() {
    if (!appState.currentEditingStepInfo) return;
    const { waveIdx, stepIdx, tempStep } = appState.currentEditingStepInfo;
    const rounds = getCurSchemeRounds();
    if (rounds[waveIdx]?.steps?.[stepIdx]) {
        rounds[waveIdx].steps[stepIdx] = tempStep;
        commitChanges();
        appState.selectedStepState = { waveIdx, stepIdx };
        triggerUpdate({ renderBoardOnly: true });
        toast(formatText(TEXT_CONFIG.modals.editStepModal.stepUpdatedToast, { wave: waveIdx + 1 }));
    }
    closeModal();
}

export function deleteCurrentEditingStep() {
    if (!appState.currentEditingStepInfo) return;
    const { waveIdx, stepIdx } = appState.currentEditingStepInfo;
    closeModal();
    const rounds = getCurSchemeRounds();
    if (rounds[waveIdx]?.steps) {
        rounds[waveIdx].steps.splice(stepIdx, 1);
        commitChanges();
    }
    appState.selectedStepState = null;
    triggerUpdate({ renderBoardOnly: true });
    toast(TEXT_CONFIG.modals.editStepModal.stepDeletedToast);
}

// 导入 DSL 逻辑
export function doImportDsl(isNewScheme) {
    let rawText = $('importDslText').value.trim();
    const errorEl = $('importDslError');
    const importCfg = TEXT_CONFIG.modals.importDslModal;
    if (!rawText) {
        errorEl.textContent = importCfg.errorEmpty;
        errorEl.style.display = 'block';
        return;
    }

    const candidate = extractDslFromText(rawText);
    if (candidate) {
        rawText = candidate;
    }

    const roundStrings = rawText
        .replace(/[\r\n]+/g, ';')
        .split(';')
        .map(s => s.trim())
        .filter(Boolean);

    if (!roundStrings.length) {
        errorEl.textContent = importCfg.errorInvalid;
        errorEl.style.display = 'block';
        return;
    }

    try {
        const parsedRounds = roundStrings.map(rStr => parseRoundDsl(rStr));
        const compiledDsl = compileSchemeDsl(parsedRounds);
        const group = getCurGroup();

        if (isNewScheme) {
            const newScheme = {
                friend: group.schemes[appState.curSchemeIdx]?.friend || group.defaultFriend || '',
                dsl: compiledDsl,
                _parsedRounds: parsedRounds
            };
            group.schemes.push(newScheme);
            appState.curSchemeIdx = group.schemes.length - 1;
            appState.curRoundIdx = 0;
            closeModal();
            triggerUpdate({ fullRender: true });
            toast(formatText(importCfg.importNewSuccessToast, { count: group.schemes.length, rounds: parsedRounds.length }));
        } else {
            const scheme = group.schemes[appState.curSchemeIdx];
            scheme._parsedRounds = parsedRounds;
            scheme.dsl = compiledDsl;
            appState.curRoundIdx = 0;
            closeModal();
            triggerUpdate({ fullRender: true });
            toast(formatText(importCfg.overwriteSuccessToast, { index: appState.curSchemeIdx + 1, rounds: parsedRounds.length }));
        }
    } catch (e) {
        errorEl.textContent = formatText(importCfg.errorParseFailed, { error: e.message || e });
        errorEl.style.display = 'block';
    }
}

