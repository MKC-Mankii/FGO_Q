import { appState, getCurGroup, getCurScheme } from './state.js';
import { SUPPORTED_FRIENDS, CARD_INFO } from './constants.js';
import { getCurSchemeRounds, commitChanges, generateConfigText, createDefaultRound } from './dsl.js';
import { openEditStepModal, formatAttackCards, formatAttackCardsBadgesHtml, registerUpdateCallback } from './modals.js';
import { $, toast } from './api.js';
import { TEXT_CONFIG, formatText } from './text_config.js';

export const escapeHtml = str => String(str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

export function getFriendLabel(key) {
    if (!key) return TEXT_CONFIG.sidebar.noFriend;
    const f = (TEXT_CONFIG.supportedFriends || SUPPORTED_FRIENDS).find(item => item.key.toLowerCase() === key.toLowerCase());
    return f ? (f.shortLabel || f.label.split(' ')[0]) : key;
}

export function getSchemeDisplayName(s, idx) {
    return s.name || s.friend || formatText(TEXT_CONFIG.sidebar.defaultSchemeName, { index: idx + 1 });
}

export function getStepLabel(st) {
    if (st.type === 'target') {
        return formatText(TEXT_CONFIG.stepLabels.target, { target: st.target });
    }
    if (st.type === 'skill') {
        const code = String(st.code);
        const sId = code[0] || '1';
        const tId = code[1] || '0';
        if (tId && tId !== '0') {
            return formatText(TEXT_CONFIG.stepLabels.servantSkillTarget, { skillId: sId, targetId: tId });
        }
        return formatText(TEXT_CONFIG.stepLabels.servantSkillSelf, { skillId: sId });
    }
    if (st.type === 'master') {
        const code = String(st.code);
        if (code.length === 5 && code.substring(1, 3) === '00') {
            const mId = code[0] || '3';
            const f = code[3] || '2';
            const b = code[4] || '4';
            return formatText(TEXT_CONFIG.stepLabels.swap, { masterId: mId, front: f, back: b });
        }
        const mId = code[0] || '1';
        const tId = code[1] || '0';
        if (tId && tId !== '0') {
            return formatText(TEXT_CONFIG.stepLabels.masterSkillTarget, { masterId: mId, targetId: tId });
        }
        return formatText(TEXT_CONFIG.stepLabels.masterSkillSelf, { masterId: mId });
    }
    return st.code || '';
}

// 渲染顶部大组 Tabs
export function renderGroupTabs() {
    const tabsContainer = $('groupTabs');
    if (!tabsContainer) return;

    tabsContainer.innerHTML = appState.data.groups.map((g, idx) => {
        const isActive = (idx === appState.curGroupIdx);
        const hasReward = Boolean(g.activityReward);
        const badgeCount = formatText(TEXT_CONFIG.groups.schemeCountBadge, { count: g.schemes.length });
        const rewardBadge = hasReward ? TEXT_CONFIG.groups.rewardActiveBadge : '';
        return `
            <div class="group-tab ${isActive ? 'active' : ''}" onclick="window.selectGroup(${idx})">
                <span>${escapeHtml(g.label)}</span>
                <span class="group-badge">${badgeCount}${rewardBadge}</span>
            </div>
        `;
    }).join('');

    const curGroup = getCurGroup();
    const hintEl = $('groupHint');
    if (hintEl) {
        hintEl.textContent = curGroup ? (curGroup.hint ? `${TEXT_CONFIG.groups.hintPrefix}${curGroup.hint}` : '') : '';
    }

    const rewardCheckbox = $('groupRewardCheckbox');
    const rewardItem = $('groupRewardItem');
    const isRewardActive = Boolean(curGroup && curGroup.activityReward);
    if (rewardCheckbox) rewardCheckbox.checked = isRewardActive;
    if (rewardItem) {
        if (isRewardActive) rewardItem.classList.add('is-active');
        else rewardItem.classList.remove('is-active');
    }

    if (rewardCheckbox) {
        rewardCheckbox.onchange = e => {
            if (!curGroup) return;
            curGroup.activityReward = e.target.checked ? 1 : 0;
            if (curGroup.activityReward) {
                if (rewardItem) rewardItem.classList.add('is-active');
                toast(formatText(TEXT_CONFIG.groups.rewardOpenedToast, { label: curGroup.label }));
            } else {
                if (rewardItem) rewardItem.classList.remove('is-active');
                toast(formatText(TEXT_CONFIG.groups.rewardClosedToast, { label: curGroup.label }));
            }
            renderGroupTabs();
            renderConfigPreview();
        };
    }
}

// 渲染侧边栏方案列表
export function renderSchemeList() {
    const group = getCurGroup();
    if (!group) return;

    const listContainer = $('schemeList');
    if (!listContainer) return;

    listContainer.innerHTML = group.schemes.map((s, idx) => {
        const displayName = getSchemeDisplayName(s, idx);
        const isDefault = (idx + 1 === group.defaultScheme);
        const isActive = (idx === appState.curSchemeIdx);
        const friendText = s.friend ? `${TEXT_CONFIG.sidebar.friendPrefix}${getFriendLabel(s.friend)}` : TEXT_CONFIG.sidebar.noFriend;
        const defaultTag = isDefault ? TEXT_CONFIG.sidebar.defaultTag : '';
        const itemTitle = formatText(TEXT_CONFIG.sidebar.schemeItemTitle, {
            index: idx + 1,
            name: displayName,
            defaultTag
        });
        return `
            <div class="scheme-item ${isActive ? 'active' : ''} ${isDefault ? 'is-default' : ''}" 
                 draggable="true"
                 data-index="${idx}"
                 onclick="window.selectScheme(${idx})"
                 title="${escapeHtml(itemTitle)}">
                <span class="drag-handle" title="${escapeHtml(TEXT_CONFIG.sidebar.dragHandleTitle)}">⋮⋮</span>
                <div class="scheme-item-content">
                    <div class="scheme-item-top">
                        <span class="scheme-item-index">${idx + 1}.</span>

                        <span class="scheme-item-name">${escapeHtml(displayName)}</span>
                        ${isDefault ? '<span class="scheme-item-default-badge">默认</span>' : ''}
                    </div>
                    <div class="scheme-item-sub">${escapeHtml(friendText)}</div>
                </div>
            </div>
        `;
    }).join('');

    setupSchemeDragAndDrop();
}

// 绑定方案拖拽重排事件（基于 SortableJS）
export function setupSchemeDragAndDrop() {
    const container = $('schemeList');
    if (!container || typeof Sortable === 'undefined') return;

    if (container._sortableInstance) {
        try {
            container._sortableInstance.destroy();
        } catch (e) {}
    }

    container._sortableInstance = Sortable.create(container, {
        animation: 180,
        handle: '.drag-handle',
        draggable: '.scheme-item',
        ghostClass: 'scheme-sortable-ghost',
        chosenClass: 'scheme-sortable-chosen',
        dragClass: 'scheme-sortable-drag',
        fallbackTolerance: 3,
        onEnd: function(evt) {
            const oldIdx = evt.oldIndex;
            const newIdx = evt.newIndex;
            if (oldIdx === undefined || newIdx === undefined || oldIdx === newIdx) return;

            const group = getCurGroup();
            if (!group || !group.schemes) return;

            const [movedItem] = group.schemes.splice(oldIdx, 1);
            group.schemes.splice(newIdx, 0, movedItem);

            appState.curSchemeIdx = newIdx;

            // 维护默认方案编号
            let defIdx = group.defaultScheme - 1;
            if (defIdx === oldIdx) {
                defIdx = newIdx;
            } else if (oldIdx < defIdx && newIdx >= defIdx) {
                defIdx--;
            } else if (oldIdx > defIdx && newIdx <= defIdx) {
                defIdx++;
            }
            group.defaultScheme = defIdx + 1;

            commitChanges();
            renderSchemeList();
            renderSchemeDetails();
            renderConfigPreview();
            toast(formatText(TEXT_CONFIG.sidebar.sortAdjustedToast, { oldIndex: oldIdx + 1, newIndex: newIdx + 1 }));
        }
    });
}

// 方案名称内联编辑交互
export function startEditSchemeName() {
    const curScheme = getCurScheme();
    if (!curScheme) return;

    $('schemeNameView').style.display = 'none';
    $('schemeNameEdit').style.display = 'inline-flex';

    const input = $('schemeNameInput');
    input.value = curScheme.name || curScheme.friend || formatText(TEXT_CONFIG.sidebar.defaultSchemeName, { index: appState.curSchemeIdx + 1 });
    input.focus();
    input.select();
}

export function cancelEditSchemeName() {
    $('schemeNameEdit').style.display = 'none';
    $('schemeNameView').style.display = 'inline-flex';
}

export function saveSchemeName() {
    const curScheme = getCurScheme();
    if (!curScheme) return;

    const input = $('schemeNameInput');
    const val = input.value.trim();
    curScheme.name = val;
    curScheme._customName = Boolean(val);

    cancelEditSchemeName();
    renderSchemeDetails();
    renderSchemeList();
    renderConfigPreview();
    toast(formatText(TEXT_CONFIG.schemeBar.saveNameToast, { name: getSchemeDisplayName(curScheme, appState.curSchemeIdx) }));
}

// 渲染方案栏与属性详情
export function renderSchemeDetails() {
    const group = getCurGroup();
    const curScheme = getCurScheme();
    if (!group || !curScheme) return;

    const displayName = getSchemeDisplayName(curScheme, appState.curSchemeIdx);

    $('schemeNamePrefix').textContent = formatText(TEXT_CONFIG.schemeBar.schemePrefix, { index: appState.curSchemeIdx + 1 });
    $('schemeNameText').textContent = displayName;
    cancelEditSchemeName();

    const friendSelect = $('schemeFriendSelect');
    const curFriendVal = (curScheme.friend || '').trim();
    const lowerCur = curFriendVal.toLowerCase();

    let optionsHtml = (TEXT_CONFIG.supportedFriends || SUPPORTED_FRIENDS).map(f => `
        <option value="${f.key}">${f.label}</option>
    `).join('');

    const exists = (TEXT_CONFIG.supportedFriends || SUPPORTED_FRIENDS).some(f => f.key.toLowerCase() === lowerCur);
    if (curFriendVal && !exists) {
        optionsHtml += `<option value="${curFriendVal}">${curFriendVal}${TEXT_CONFIG.schemeBar.customFriendSuffix}</option>`;
    }

    friendSelect.innerHTML = optionsHtml;
    const matchedOpt = Array.from(friendSelect.options).find(opt => opt.value.toLowerCase() === lowerCur);
    friendSelect.value = matchedOpt ? matchedOpt.value : curFriendVal;

    friendSelect.onchange = e => {
        const oldFriend = curScheme.friend || '';
        curScheme.friend = e.target.value;
        if (!curScheme._customName || !curScheme.name || curScheme.name === oldFriend) {
            curScheme.name = curScheme.friend;
        }
        $('schemeNameText').textContent = getSchemeDisplayName(curScheme, appState.curSchemeIdx);
        renderSchemeList();
        renderConfigPreview();
    };

    const isCurDefault = (appState.curSchemeIdx + 1 === group.defaultScheme);
    const checkbox = $('defaultSchemeCheckbox');
    const checkboxItem = $('defaultSchemeItem');
    const label = $('defaultSchemeLabel');

    checkbox.checked = isCurDefault;
    if (isCurDefault) {
        checkboxItem.classList.add('is-default');
    } else {
        checkboxItem.classList.remove('is-default');
    }
    label.textContent = TEXT_CONFIG.schemeBar.defaultCheckboxLabel;

    checkbox.onchange = e => {
        if (e.target.checked) {
            group.defaultScheme = appState.curSchemeIdx + 1;
            renderGroupTabs();
            renderSchemeList();
            renderConfigPreview();
            toast(formatText(TEXT_CONFIG.schemeBar.setDefaultSuccessToast, { index: appState.curSchemeIdx + 1 }));
        } else {
            e.target.checked = true;
            toast(TEXT_CONFIG.schemeBar.setDefaultWarnToast);
        }
    };
}


// 渲染战斗动作时序看板 (所有回合的小卡片集合)
export function renderWavesBoard(highlightTarget = null) {
    const rounds = getCurSchemeRounds();
    const container = $('wavesBoardList');
    if (!container) return;

    if (appState.curRoundIdx >= rounds.length) {
        appState.curRoundIdx = Math.max(0, rounds.length - 1);
    }

    const hintEl = $('activeWaveHint');
    if (hintEl) {
        if (appState.selectedStepState) {
            const { waveIdx, stepIdx } = appState.selectedStepState;
            const targetStep = rounds[waveIdx]?.steps?.[stepIdx];
            const stepLabel = targetStep ? getStepLabel(targetStep) : formatText(TEXT_CONFIG.stepLabels.defaultStepName, { step: stepIdx + 1 });
            hintEl.innerHTML = formatText(TEXT_CONFIG.palette.hintSelected, {
                wave: waveIdx + 1,
                label: escapeHtml(stepLabel)
            });
        } else {
            hintEl.innerHTML = TEXT_CONFIG.palette.hintDefault;
        }
    }

    container.innerHTML = rounds.map((r, waveIdx) => {
        const isActive = (waveIdx === appState.curRoundIdx);

        let stepsHtml = '';
        if (r.steps && r.steps.length) {
            stepsHtml = r.steps.map((st, stepIdx) => {
                let cls = 'skill';
                if (st.type === 'target') cls = 'target';
                else if (st.type === 'master') cls = 'master';

                const isHighlighted = highlightTarget &&
                    highlightTarget.waveIdx === waveIdx &&
                    highlightTarget.stepIdx === stepIdx;

                const isSelected = appState.selectedStepState &&
                    appState.selectedStepState.waveIdx === waveIdx &&
                    appState.selectedStepState.stepIdx === stepIdx;

                let highlightCls = '';
                if (isSelected) {
                    highlightCls = ' selected';
                } else if (isHighlighted) {
                    highlightCls = ' just-moved';
                }

                const label = getStepLabel(st);
                return `
                    <div class="timeline-chip ${cls}${highlightCls}" draggable="true" data-wave-idx="${waveIdx}" data-step-idx="${stepIdx}" onclick="window.onStepChipClick(${waveIdx}, ${stepIdx}, event)" title="${escapeHtml(TEXT_CONFIG.timeline.chipDragTitle)}">
                        <span class="chip-drag-handle">⋮⋮</span>
                        <span>${escapeHtml(label)}</span>
                        <button class="remove-btn" onclick="window.removeStep(${waveIdx}, ${stepIdx}, event)" title="${escapeHtml(TEXT_CONFIG.timeline.chipRemoveTitle)}">×</button>
                    </div>
                `;
            }).join('');
        }

        let attackHtml = '';
        if (r.attack && r.attack.length) {
            const badgesHtml = formatAttackCardsBadgesHtml(r.attack);
            attackHtml = `
                <div class="timeline-chip attack" onclick="window.editRoundAttack(${waveIdx}, event)" title="${escapeHtml(TEXT_CONFIG.timeline.chipAttackEditTitle)}">
                    <span class="attack-chip-title">${escapeHtml(TEXT_CONFIG.timeline.chipAttackTitle)}</span>
                    <div class="attack-mini-cards">${badgesHtml}</div>
                    <button class="remove-btn" onclick="window.removeAttack(${waveIdx}, event)" title="${escapeHtml(TEXT_CONFIG.timeline.chipAttackRemoveTitle)}">×</button>
                </div>
            `;
        }

        const hasContent = (r.steps && r.steps.length > 0) || (r.attack && r.attack.length > 0);
        const emptyHtml = hasContent ? '' : `<span class="timeline-empty">${escapeHtml(TEXT_CONFIG.timeline.emptyWaveHint)}</span>`;

        const deleteWaveBtnHtml = rounds.length > 1
            ? `<button class="wave-btn delete-btn" onclick="window.deleteWave(${waveIdx}, event)" title="${escapeHtml(TEXT_CONFIG.timeline.btnDeleteWaveTitle)}">${escapeHtml(TEXT_CONFIG.timeline.btnDeleteWave)}</button>`
            : '';

        const dragRailTitle = formatText(TEXT_CONFIG.timeline.waveDragTitle, { wave: waveIdx + 1 });
        const waveBadgeText = formatText(TEXT_CONFIG.timeline.waveBadge, { wave: waveIdx + 1 });

        return `
            <div class="wave-item ${isActive ? 'active' : ''}" onclick="window.setActiveWave(${waveIdx})" data-wave-idx="${waveIdx}">
                <div class="wave-drag-rail" draggable="true" data-wave-idx="${waveIdx}" title="${escapeHtml(dragRailTitle)}">
                    <span class="wave-drag-handle">⋮⋮</span>
                </div>
                <div class="wave-item-body">
                    <div class="wave-item-header">
                        <div class="wave-item-title-wrap" data-wave-idx="${waveIdx}">
                            <span class="wave-badge">${escapeHtml(waveBadgeText)}</span>
                            <span class="wave-active-indicator">${escapeHtml(TEXT_CONFIG.timeline.waveActiveIndicator)}</span>
                        </div>
                        <div class="wave-item-actions">
                            <button class="wave-btn" onclick="window.clearWave(${waveIdx}, event)" title="${escapeHtml(TEXT_CONFIG.timeline.btnClearWaveTitle)}">${escapeHtml(TEXT_CONFIG.timeline.btnClearWave)}</button>
                            ${deleteWaveBtnHtml}
                        </div>
                    </div>
                    <div class="timeline-chips" data-wave-idx="${waveIdx}">
                        ${stepsHtml}
                        ${attackHtml}
                        ${emptyHtml}
                    </div>
                </div>
            </div>
        `;
    }).join('');

    setupWavesDragAndDrop();
    setupChipsDragAndDrop();
    updateSelectionUI();
}

// 绑定各 Wave 回合拖拽重排事件（基于 SortableJS）
export function setupWavesDragAndDrop() {
    const container = $('wavesBoardList');
    if (!container || typeof Sortable === 'undefined') return;

    Sortable.create(container, {
        animation: 200,
        handle: '.wave-drag-rail',
        draggable: '.wave-item',
        filter: '.wave-item-actions, .timeline-chips, button, input',
        preventOnFilter: false,
        ghostClass: 'wave-sortable-ghost',
        chosenClass: 'wave-sortable-chosen',
        dragClass: 'wave-sortable-drag',
        fallbackTolerance: 3,
        onEnd: function(evt) {
            const oldIdx = evt.oldIndex;
            const newIdx = evt.newIndex;
            if (oldIdx === undefined || newIdx === undefined || oldIdx === newIdx) return;

            const rounds = getCurSchemeRounds();
            if (!rounds) return;

            const [movedRound] = rounds.splice(oldIdx, 1);
            rounds.splice(newIdx, 0, movedRound);

            appState.curRoundIdx = newIdx;

            commitChanges();
            renderWavesBoard();
            renderConfigPreview();
            toast(formatText(TEXT_CONFIG.timeline.waveOrderAdjustedToast, { oldIndex: oldIdx + 1, newIndex: newIdx + 1 }));
        }
    });
}


// 绑定动作卡片（技能/目标/御主技能）拖拽排序与跨回合移动（基于 SortableJS）
export function setupChipsDragAndDrop() {
    const container = $('wavesBoardList');
    if (!container || typeof Sortable === 'undefined') return;

    const chipBoxes = container.querySelectorAll('.timeline-chips');
    chipBoxes.forEach(box => {
        Sortable.create(box, {
            group: 'fgo-wave-action-chips',
            animation: 180,
            draggable: '.timeline-chip[data-step-idx]',
            filter: '.remove-btn, .attack, .timeline-empty',
            preventOnFilter: false,
            ghostClass: 'chip-sortable-ghost',
            chosenClass: 'chip-sortable-chosen',
            dragClass: 'chip-sortable-drag',
            fallbackTolerance: 3,
            onMove: function(evt) {
                if (evt.related && evt.related.classList.contains('attack')) {
                    if (evt.willInsertAfter) return false;
                }
                if (evt.related && evt.related.classList.contains('timeline-empty')) {
                    return true;
                }
                return true;
            },
            onEnd: function(evt) {
                const fromWaveIdx = Number(evt.from.dataset.waveIdx);
                const toWaveIdx = Number(evt.to.dataset.waveIdx);
                if (isNaN(fromWaveIdx) || isNaN(toWaveIdx)) return;

                const rounds = getCurSchemeRounds();
                const sourceSteps = rounds[fromWaveIdx]?.steps;
                const targetSteps = rounds[toWaveIdx]?.steps;
                if (!sourceSteps || !targetSteps) return;

                const origStepIdx = Number(evt.item.dataset.stepIdx);
                if (isNaN(origStepIdx) || origStepIdx < 0 || origStepIdx >= sourceSteps.length) {
                    renderWavesBoard();
                    return;
                }

                const targetChips = Array.from(evt.to.querySelectorAll('.timeline-chip[data-step-idx]'));
                let newStepIdx = targetChips.indexOf(evt.item);
                if (newStepIdx === -1) {
                    newStepIdx = targetSteps.length;
                }

                if (fromWaveIdx === toWaveIdx && origStepIdx === newStepIdx) {
                    return;
                }

                const [movedStep] = sourceSteps.splice(origStepIdx, 1);
                targetSteps.splice(newStepIdx, 0, movedStep);

                commitChanges();
                renderWavesBoard({ waveIdx: toWaveIdx, stepIdx: newStepIdx });
                renderConfigPreview();
                toast(`↔️ 已调整动作卡片顺序`);
            }
        });
    });

    updateSelectionUI();
}

// 切换活动回合
export function setActiveWave(waveIdx) {
    appState.curRoundIdx = waveIdx;
    appState.selectedStepState = null;
    renderWavesBoard();
}

// 插入新回合
export function addWave() {
    const rounds = getCurSchemeRounds();
    const insertIdx = (typeof appState.curRoundIdx === 'number' && appState.curRoundIdx >= 0 && appState.curRoundIdx < rounds.length)
        ? appState.curRoundIdx + 1
        : rounds.length;

    rounds.splice(insertIdx, 0, createDefaultRound());
    appState.curRoundIdx = insertIdx;
    commitChanges();
    renderWavesBoard();
    renderConfigPreview();
    toast(formatText(TEXT_CONFIG.timeline.addWaveToast, { insertIndex: insertIdx, curIndex: insertIdx + 1 }));
}

// 删除指定回合
export function deleteWave(waveIdx, event) {
    if (event) event.stopPropagation();
    const rounds = getCurSchemeRounds();
    if (rounds.length <= 1) {
        toast(TEXT_CONFIG.timeline.deleteWaveMinWarnToast);
        return;
    }
    rounds.splice(waveIdx, 1);
    if (appState.curRoundIdx >= rounds.length) {
        appState.curRoundIdx = rounds.length - 1;
    }
    commitChanges();
    renderWavesBoard();
    renderConfigPreview();
    toast(formatText(TEXT_CONFIG.timeline.deleteWaveToast, { wave: waveIdx + 1 }));
}

// 清空指定回合动作
export function clearWave(waveIdx, event) {
    if (event) event.stopPropagation();
    const rounds = getCurSchemeRounds();
    if (rounds[waveIdx]) {
        rounds[waveIdx].steps = [];
        rounds[waveIdx].attack = [];
        commitChanges();
        renderWavesBoard();
        renderConfigPreview();
        toast(formatText(TEXT_CONFIG.timeline.clearWaveToast, { wave: waveIdx + 1 }));
    }
}

// 向指定 Wave 局部插入单张动作卡片，并带有新增闪烁动画，避免整板重新渲染与整体闪烁
export function appendStepChipDOM(waveIdx, stepData) {
    const container = $('wavesBoardList');
    if (!container) return false;

    const chipsBox = container.querySelector(`.timeline-chips[data-wave-idx="${waveIdx}"]`);
    if (!chipsBox) return false;

    // 移除空白提示（如果存在）
    const emptyEl = chipsBox.querySelector('.timeline-empty');
    if (emptyEl) emptyEl.remove();

    const existingStepChips = chipsBox.querySelectorAll('.timeline-chip[data-step-idx]');
    const stepIdx = existingStepChips.length;

    let cls = 'skill';
    if (stepData.type === 'target') cls = 'target';
    else if (stepData.type === 'master') cls = 'master';

    const label = getStepLabel(stepData);

    const chip = document.createElement('div');
    chip.className = `timeline-chip ${cls} just-added`;
    chip.draggable = true;
    chip.dataset.waveIdx = String(waveIdx);
    chip.dataset.stepIdx = String(stepIdx);
    chip.onclick = (e) => onStepChipClick(waveIdx, stepIdx, e);
    chip.title = TEXT_CONFIG.timeline.chipDragTitle;
    chip.innerHTML = `
        <span class="chip-drag-handle">⋮⋮</span>
        <span>${escapeHtml(label)}</span>
        <button class="remove-btn" onclick="window.removeStep(${waveIdx}, ${stepIdx}, event)" title="${escapeHtml(TEXT_CONFIG.timeline.chipRemoveTitle)}">×</button>
    `;

    // 若当前回合已有出牌卡片，则插入在出牌卡片之前；否则直接追加在最后
    const attackChip = chipsBox.querySelector('.timeline-chip.attack');
    if (attackChip) {
        chipsBox.insertBefore(chip, attackChip);
    } else {
        chipsBox.appendChild(chip);
    }

    setTimeout(() => {
        chip.classList.remove('just-added');
    }, 450);

    return true;
}

// 局部更新被修改动作卡片的类型与文本，并附加单卡闪烁动画
export function updateStepChipDOM(waveIdx, stepIdx, stepData) {
    const container = $('wavesBoardList');
    if (!container) return false;

    const chip = container.querySelector(`.timeline-chip[data-wave-idx="${waveIdx}"][data-step-idx="${stepIdx}"]`);
    if (!chip) return false;

    let cls = 'skill';
    if (stepData.type === 'target') cls = 'target';
    else if (stepData.type === 'master') cls = 'master';

    const label = getStepLabel(stepData);

    chip.className = `timeline-chip ${cls} just-added`;
    const spanEl = chip.querySelector('span:nth-child(2)');
    if (spanEl) {
        spanEl.textContent = label;
    }

    setTimeout(() => {
        chip.classList.remove('just-added');
    }, 450);

    return true;
}

// 删除单个动作卡片（精准局部移除，无需重新渲染整板）
export function removeStep(waveIdx, stepIdx, event) {
    if (event) event.stopPropagation();
    const rounds = getCurSchemeRounds();
    if (!rounds[waveIdx]?.steps) return;

    rounds[waveIdx].steps.splice(stepIdx, 1);
    if (appState.selectedStepState &&
        appState.selectedStepState.waveIdx === waveIdx &&
        appState.selectedStepState.stepIdx === stepIdx) {
        appState.selectedStepState = null;
    }

    commitChanges();
    renderConfigPreview();

    const container = $('wavesBoardList');
    const chipsBox = container?.querySelector(`.timeline-chips[data-wave-idx="${waveIdx}"]`);
    if (chipsBox) {
        const chip = chipsBox.querySelector(`.timeline-chip[data-wave-idx="${waveIdx}"][data-step-idx="${stepIdx}"]`);
        if (chip) {
            chip.remove();
            // 重排剩余卡片 stepIdx
            const remaining = chipsBox.querySelectorAll('.timeline-chip[data-step-idx]');
            remaining.forEach((c, idx) => {
                c.dataset.stepIdx = String(idx);
                c.onclick = (e) => onStepChipClick(waveIdx, idx, e);
                const btn = c.querySelector('.remove-btn');
                if (btn) btn.onclick = (e) => removeStep(waveIdx, idx, e);
            });

            const hasAttack = Boolean(chipsBox.querySelector('.timeline-chip.attack'));
            if (remaining.length === 0 && !hasAttack && !chipsBox.querySelector('.timeline-empty')) {
                const empty = document.createElement('span');
                empty.className = 'timeline-empty';
                empty.textContent = TEXT_CONFIG.timeline.emptyWaveHint;
                chipsBox.appendChild(empty);
            }
            updateSelectionUI();
            return;
        }
    }

    renderWavesBoard();
}

// 精准局部更新/插入当前回合收尾出牌，避免全局闪烁
export function setRoundAttackDOM(waveIdx, attackCards) {
    const rounds = getCurSchemeRounds();
    if (!rounds[waveIdx]) return;
    rounds[waveIdx].attack = [...attackCards];
    commitChanges();

    const badgesHtml = formatAttackCardsBadgesHtml(rounds[waveIdx].attack);
    const chipsBox = document.querySelector(`.timeline-chips[data-wave-idx="${waveIdx}"]`);

    if (chipsBox) {
        const emptyEl = chipsBox.querySelector('.timeline-empty');
        if (emptyEl) emptyEl.remove();

        let attackChip = chipsBox.querySelector('.timeline-chip.attack');
        if (attackChip) {
            attackChip.innerHTML = `
                <span class="attack-chip-title">${escapeHtml(TEXT_CONFIG.timeline.chipAttackTitle)}</span>
                <div class="attack-mini-cards">${badgesHtml}</div>
                <button class="remove-btn" onclick="window.removeAttack(${waveIdx}, event)" title="${escapeHtml(TEXT_CONFIG.timeline.chipAttackRemoveTitle)}">×</button>
            `;
            attackChip.classList.remove('just-added');
            void attackChip.offsetWidth;
            attackChip.classList.add('just-added');
        } else {
            const newChip = document.createElement('div');
            newChip.className = 'timeline-chip attack just-added';
            newChip.setAttribute('onclick', `window.editRoundAttack(${waveIdx}, event)`);
            newChip.setAttribute('title', TEXT_CONFIG.timeline.chipAttackEditTitle);
            newChip.innerHTML = `
                <span class="attack-chip-title">${escapeHtml(TEXT_CONFIG.timeline.chipAttackTitle)}</span>
                <div class="attack-mini-cards">${badgesHtml}</div>
                <button class="remove-btn" onclick="window.removeAttack(${waveIdx}, event)" title="${escapeHtml(TEXT_CONFIG.timeline.chipAttackRemoveTitle)}">×</button>
            `;
            chipsBox.appendChild(newChip);
        }
    } else {
        renderWavesBoard();
    }

    renderConfigPreview();
    toast(formatText(TEXT_CONFIG.timeline.setAttackToast, { wave: waveIdx + 1, cards: rounds[waveIdx].attack.join(', ') }));
}

// 清除指定回合收尾出牌
export function removeAttack(waveIdx, event) {
    if (event) event.stopPropagation();
    const rounds = getCurSchemeRounds();
    if (rounds[waveIdx]) {
        rounds[waveIdx].attack = [];
        commitChanges();

        const chipsBox = document.querySelector(`.timeline-chips[data-wave-idx="${waveIdx}"]`);
        if (chipsBox) {
            const attackChip = chipsBox.querySelector('.timeline-chip.attack');
            if (attackChip) attackChip.remove();
            if (!chipsBox.querySelector('.timeline-chip')) {
                const empty = document.createElement('span');
                empty.className = 'timeline-empty';
                empty.textContent = TEXT_CONFIG.timeline.emptyWaveHint;
                chipsBox.appendChild(empty);
            }
        } else {
            renderWavesBoard();
        }

        renderConfigPreview();
        toast(formatText(TEXT_CONFIG.timeline.removeAttackToast, { wave: waveIdx + 1 }));
    }
}


// 右侧控制台与当前选中技能联动高亮渲染 (克制自然，清晰专业)
export function updatePaletteHighlight(step) {
    // 移除之前的选中高亮 class 与内联样式残余
    document.querySelectorAll('.selected-in-palette').forEach(el => {
        el.classList.remove('selected-in-palette');
        el.style.border = '';
        el.style.outline = '';
        el.style.boxShadow = '';
        el.style.background = '';
        el.style.transform = '';
    });
    document.querySelectorAll('.selected-action-btn').forEach(el => {
        el.classList.remove('selected-action-btn');
        el.style.background = '';
        el.style.color = '';
        el.style.outline = '';
        el.style.boxShadow = '';
        el.style.transform = '';
        el.style.fontWeight = '';
        el.style.borderColor = '';
        el.style.borderBottom = '';
    });
    document.querySelectorAll('.related-action-btn').forEach(el => {
        el.classList.remove('related-action-btn');
        el.style.background = '';
        el.style.color = '';
        el.style.borderColor = '';
        el.style.fontWeight = '';
        el.style.borderBottom = '';
    });

    if (!step) return;

    let targetElToScroll = null;

    if (step.type === 'target') {
        const targetNum = String(step.target || '1').trim();
        const btn = document.querySelector(`.target-btn[data-target="${targetNum}"]`);
        if (btn) {
            btn.classList.add('selected-action-btn');
            targetElToScroll = btn;
        }
    } else if (step.type === 'skill') {
        const code = String(step.code || '10').trim();
        const sId = code[0] || '1';
        const tId = code[1] || '0';

        const mainBtn = document.querySelector(`.skill-main-btn[data-skill="${sId}"]`);
        const card = mainBtn ? mainBtn.closest('.skill-card') : null;
        if (card) {
            card.classList.add('selected-in-palette');
            targetElToScroll = card;
        }

        if (tId === '0') {
            if (mainBtn) {
                mainBtn.classList.add('selected-action-btn');
            }
        } else {
            if (mainBtn) {
                mainBtn.classList.add('related-action-btn');
            }
            const targetBtn = document.querySelector(`.skill-target-btn[data-skill="${sId}"][data-target-val="${tId}"]`);
            if (targetBtn) {
                targetBtn.classList.add('selected-action-btn');
                targetElToScroll = targetBtn;
            }
        }
    } else if (step.type === 'master') {
        const code = String(step.code || '10').trim();
        const isSwap5 = code.length === 5 && code.substring(1, 3) === '00';
        const isSwapShort = code.length >= 2 && (code[1] === '4' || code[1] === '5' || code[1] === '6');

        if (isSwap5 || isSwapShort) {
            const mId = code[0] || '3';
            const swapBtn = document.querySelector(`.master-target-swap-btn[data-master-swap="${mId}"]`)
                || document.querySelector(`.master-target-swap-btn[data-master-swap="3"]`);
            const card = swapBtn ? swapBtn.closest('.master-card') : null;
            if (card) {
                card.classList.add('selected-in-palette');
                targetElToScroll = card;
            }
            if (swapBtn) {
                swapBtn.classList.add('selected-action-btn');
            }
        } else {
            const mId = code[0] || '1';
            const tId = code[1] || '0';

            const mainBtn = document.querySelector(`.master-main-btn[data-master="${mId}"]`);
            const card = mainBtn ? mainBtn.closest('.master-card') : null;
            if (card) {
                card.classList.add('selected-in-palette');
                targetElToScroll = card;
            }

            if (tId === '0') {
                if (mainBtn) {
                    mainBtn.classList.add('selected-action-btn');
                }
            } else {
                if (mainBtn) {
                    mainBtn.classList.add('related-action-btn');
                }
                const targetBtn = document.querySelector(`.master-target-btn[data-master="${mId}"][data-target-val="${tId}"]`);
                if (targetBtn) {
                    targetBtn.classList.add('selected-action-btn');
                    targetElToScroll = targetBtn;
                }
            }
        }
    }

    // 平滑定位至右侧控制台可见区域（不导致整个页面大幅跳动）
    if (targetElToScroll) {
        try {
            targetElToScroll.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' });
        } catch (e) {
            // ignore
        }
    }
}

// 高效局部更新动作选中状态与提示，避免整板重新渲染与重绘闪烁
export function updateSelectionUI() {
    const rounds = getCurSchemeRounds();

    // 1. 更新卡片上的 selected 类
    document.querySelectorAll('.timeline-chip').forEach(chip => {
        const w = Number(chip.dataset.waveIdx);
        const s = Number(chip.dataset.stepIdx);
        const isSelected = Boolean(appState.selectedStepState &&
            appState.selectedStepState.waveIdx === w &&
            appState.selectedStepState.stepIdx === s);
        chip.classList.toggle('selected', isSelected);
    });

    // 2. 更新 Wave 项目的 active 类
    document.querySelectorAll('.wave-item').forEach(item => {
        const w = Number(item.dataset.waveIdx);
        item.classList.toggle('active', w === appState.curRoundIdx);
    });

    // 3. 联动更新右侧控制台的技能高亮
    const activeStep = appState.selectedStepState
        ? rounds[appState.selectedStepState.waveIdx]?.steps?.[appState.selectedStepState.stepIdx]
        : null;
    updatePaletteHighlight(activeStep);

    // 4. 联动更新右侧出牌控制台的高亮与 1/2/3 序号标签
    const curRound = rounds[appState.curRoundIdx];
    updateAttackPaletteHighlight(curRound?.attack);

    // 5. 保持简洁的默认引导提示，不打扰用户
    const hintEl = $('activeWaveHint');
    if (hintEl) {
        hintEl.innerHTML = TEXT_CONFIG.palette.hintDefault;
    }
}

// 右侧出牌控制台联动高亮渲染：遵循游戏原生 3-Slot 槽位机制，在选中的卡牌上显示对应的 1/2/3 槽位标签
export function updateAttackPaletteHighlight(attackCards) {
    try {
        const slots = [
            (attackCards && attackCards[0]) ? String(attackCards[0]).trim() : null,
            (attackCards && attackCards[1]) ? String(attackCards[1]).trim() : null,
            (attackCards && attackCards[2]) ? String(attackCards[2]).trim() : null
        ];

        if (typeof window.syncPendingAttackCards === 'function') {
            window.syncPendingAttackCards(slots);
        }

        // 1. 清除所有出牌按钮的高亮与多序号徽标
        document.querySelectorAll('[data-attack-card]').forEach(btn => {
            btn.classList.remove('selected-attack-card');
            const container = btn.querySelector('.card-seq-badges');
            if (container) container.innerHTML = '';
        });

        // 2. 统计每个卡牌值命中的 slot 列表
        const cardSeqMap = {};
        slots.forEach((cardCode, slotIdx) => {
            if (!cardCode) return;
            const seq = slotIdx + 1;
            const norm = String(cardCode).trim().toUpperCase();
            if (!cardSeqMap[norm]) cardSeqMap[norm] = [];
            cardSeqMap[norm].push({ seq, slotIdx });
        });

        // 3. 渲染各个按钮上的徽标与高亮态
        Object.entries(cardSeqMap).forEach(([cardCode, list]) => {
            const btn = document.querySelector(`[data-attack-card="${cardCode}"]`);
            if (btn) {
                btn.classList.add('selected-attack-card');
                const container = btn.querySelector('.card-seq-badges');
                if (container) {
                    const seqLabels = {
                        1: TEXT_CONFIG.palette.seqLabel1 || '一',
                        2: TEXT_CONFIG.palette.seqLabel2 || '二',
                        3: TEXT_CONFIG.palette.seqLabel3 || '三'
                    };
                    container.innerHTML = list.map(item => {
                        const seqText = seqLabels[item.seq] || String(item.seq);
                        const tagTitle = formatText(TEXT_CONFIG.palette.cancelCardTagTitle, { seq: seqText, card: cardCode });
                        return `<span class="seq-tag seq-${item.seq}" data-remove-slot="${item.slotIdx}" title="${escapeHtml(tagTitle)}">${seqText}</span>`;
                    }).join('');
                }
            }
        });

    } catch (err) {
        console.warn('updateAttackPaletteHighlight error:', err);
    }
}

export function onStepChipClick(waveIdx, stepIdx, event) {
    if (event) event.stopPropagation();

    if (appState.selectedStepState &&
        appState.selectedStepState.waveIdx === waveIdx &&
        appState.selectedStepState.stepIdx === stepIdx) {
        appState.selectedStepState = null;
    } else {
        appState.curRoundIdx = waveIdx;
        appState.selectedStepState = { waveIdx, stepIdx };
    }
    updateSelectionUI();
}

// 渲染完整 Q 代码预览
export function renderConfigPreview() {
    const previewEl = $('configPreview');
    if (previewEl) {
        previewEl.value = generateConfigText(appState.data);
    }
}

// 将 TEXT_CONFIG 中的所有文本应用到页面所有静态 DOM 元素，使用户修改配置文件即刻生效
export function applyStaticTexts() {
    // 1. 顶部标题与操作
    const eyebrow = document.querySelector('.eyebrow');
    if (eyebrow) eyebrow.textContent = TEXT_CONFIG.masthead.eyebrow;

    const mainTitle = document.querySelector('.masthead-title h1');
    if (mainTitle) mainTitle.textContent = TEXT_CONFIG.masthead.title;

    const subtitle = document.querySelector('.masthead .subtext');
    if (subtitle) subtitle.textContent = TEXT_CONFIG.masthead.subtitle;

    const reloadBtn = $('reloadBtn');
    if (reloadBtn) {
        reloadBtn.textContent = TEXT_CONFIG.masthead.btnReload;
        reloadBtn.title = TEXT_CONFIG.masthead.btnReloadTitle;
    }

    const copyBtn = $('copyBtn');
    if (copyBtn) copyBtn.textContent = TEXT_CONFIG.masthead.btnCopy;

    const saveBtn = $('saveBtn');
    if (saveBtn) saveBtn.textContent = TEXT_CONFIG.masthead.btnSave;

    // 2. 大组设置栏
    const groupRewardLabel = $('groupRewardLabel');
    if (groupRewardLabel) groupRewardLabel.textContent = TEXT_CONFIG.groups.rewardLabel;

    const groupRewardItem = $('groupRewardItem');
    if (groupRewardItem) groupRewardItem.title = TEXT_CONFIG.groups.rewardTitle;

    // 3. 侧边栏
    const sidebarTitle = document.querySelector('.sidebar-header h2');
    if (sidebarTitle) sidebarTitle.textContent = TEXT_CONFIG.sidebar.title;

    const addSchemeBtn = $('addSchemeBtn');
    if (addSchemeBtn) addSchemeBtn.textContent = TEXT_CONFIG.sidebar.btnAddScheme;

    const resetBtn = $('resetBtn');
    if (resetBtn) resetBtn.textContent = TEXT_CONFIG.sidebar.btnReset;

    // 4. 方案详情头部
    const curSchemeLabel = document.querySelector('.scheme-header-title > span');
    if (curSchemeLabel) curSchemeLabel.textContent = TEXT_CONFIG.schemeBar.curSchemeLabel;

    const schemeNameView = $('schemeNameView');
    if (schemeNameView) schemeNameView.title = TEXT_CONFIG.schemeBar.viewTitle;

    const schemeNameInput = $('schemeNameInput');
    if (schemeNameInput) schemeNameInput.placeholder = TEXT_CONFIG.schemeBar.inputPlaceholder;

    const schemeNameSaveBtn = $('schemeNameSaveBtn');
    if (schemeNameSaveBtn) schemeNameSaveBtn.title = TEXT_CONFIG.schemeBar.btnSaveNameTitle;

    const schemeNameCancelBtn = $('schemeNameCancelBtn');
    if (schemeNameCancelBtn) schemeNameCancelBtn.title = TEXT_CONFIG.schemeBar.btnCancelNameTitle;

    const defaultSchemeItem = $('defaultSchemeItem');
    if (defaultSchemeItem) defaultSchemeItem.title = TEXT_CONFIG.schemeBar.defaultCheckboxTitle;

    const defaultSchemeLabel = $('defaultSchemeLabel');
    if (defaultSchemeLabel) defaultSchemeLabel.textContent = TEXT_CONFIG.schemeBar.defaultCheckboxLabel;

    const copyDslBtn = $('copyDslBtn');
    if (copyDslBtn) {
        copyDslBtn.textContent = TEXT_CONFIG.schemeBar.btnCopyDsl;
        copyDslBtn.title = TEXT_CONFIG.schemeBar.btnCopyDslTitle;
    }

    const importDslBtn = $('importDslBtn');
    if (importDslBtn) {
        importDslBtn.textContent = TEXT_CONFIG.schemeBar.btnImportDsl;
        importDslBtn.title = TEXT_CONFIG.schemeBar.btnImportDslTitle;
    }

    // 5. 看板头部按钮
    const timelineTitle = document.querySelector('.waves-board-title h3');
    if (timelineTitle) timelineTitle.textContent = TEXT_CONFIG.timeline.title;

    const addWaveBtn = $('addWaveBtn');
    if (addWaveBtn) {
        addWaveBtn.textContent = TEXT_CONFIG.timeline.btnAddWave;
        addWaveBtn.title = TEXT_CONFIG.timeline.btnAddWaveTitle;
    }

    const resetCurSchemeBtn = $('resetCurSchemeBtn');
    if (resetCurSchemeBtn) {
        resetCurSchemeBtn.textContent = TEXT_CONFIG.timeline.btnResetScheme;
        resetCurSchemeBtn.title = TEXT_CONFIG.timeline.btnResetSchemeTitle;
    }

    const clearCurSchemeBtn = $('clearCurSchemeBtn');
    if (clearCurSchemeBtn) {
        clearCurSchemeBtn.textContent = TEXT_CONFIG.timeline.btnClearScheme;
        clearCurSchemeBtn.title = TEXT_CONFIG.timeline.btnClearSchemeTitle;
    }

    // 6. 控制台锁定目标
    const targetTitleSpan = document.querySelector('.palette-grid.aux-grid .palette-col:nth-child(1) .palette-title span');
    if (targetTitleSpan) targetTitleSpan.textContent = TEXT_CONFIG.palette.targetTitle;

    const targetTitleSub = document.querySelector('.palette-grid.aux-grid .palette-col:nth-child(1) .palette-title small');
    if (targetTitleSub) targetTitleSub.textContent = TEXT_CONFIG.palette.targetSubtitle;

    for (let t = 1; t <= 6; t++) {
        const tBtn = document.querySelector(`button.target-btn[data-target="${t}"]`);
        if (tBtn) tBtn.textContent = TEXT_CONFIG.palette[`targetBtn${t}`] || `🎯 目标 ${t}`;
    }

    // 控制台御主技能
    const masterTitleSpan = document.querySelector('.palette-grid.aux-grid .palette-col:nth-child(2) .palette-title span');
    if (masterTitleSpan) masterTitleSpan.textContent = TEXT_CONFIG.palette.masterTitle;

    const masterTitleSub = document.querySelector('.palette-grid.aux-grid .palette-col:nth-child(2) .palette-title small');
    if (masterTitleSub) masterTitleSub.textContent = TEXT_CONFIG.palette.masterSubtitle;

    [1, 2, 3].forEach(mId => {
        const mBtn = document.querySelector(`button.master-main-btn[data-master="${mId}"] span`);
        if (mBtn) mBtn.textContent = formatText(TEXT_CONFIG.palette.masterMainBtn, { id: mId });
        const mBtnParent = document.querySelector(`button.master-main-btn[data-master="${mId}"]`);
        if (mBtnParent) mBtnParent.title = formatText(TEXT_CONFIG.palette.masterMainBtnTitle, { id: mId });

        [1, 2, 3].forEach(tVal => {
            const tBtn = document.querySelector(`button.master-target-btn[data-master="${mId}"][data-target-val="${tVal}"]`);
            if (tBtn) tBtn.title = formatText(TEXT_CONFIG.palette.masterTargetBtnTitle, { id: mId, target: tVal });
        });

        const swapBtn = document.querySelector(`button.master-target-swap-btn[data-master-swap="${mId}"]`);
        if (swapBtn) {
            swapBtn.textContent = TEXT_CONFIG.palette.masterSwapBtn;
            swapBtn.title = formatText(TEXT_CONFIG.palette.masterSwapBtnTitle, { id: mId });
        }
    });

    // 从者技能
    const s1Title = document.querySelector('.servants-palette .palette-col:nth-child(1) .palette-title span');
    if (s1Title) s1Title.textContent = TEXT_CONFIG.palette.servant1Title;
    const s1Sub = document.querySelector('.servants-palette .palette-col:nth-child(1) .palette-title small');
    if (s1Sub) s1Sub.textContent = TEXT_CONFIG.palette.servant1Subtitle;

    const s2Title = document.querySelector('.servants-palette .palette-col:nth-child(2) .palette-title span');
    if (s2Title) s2Title.textContent = TEXT_CONFIG.palette.servant2Title;
    const s2Sub = document.querySelector('.servants-palette .palette-col:nth-child(2) .palette-title small');
    if (s2Sub) s2Sub.textContent = TEXT_CONFIG.palette.servant2Subtitle;

    const s3Title = document.querySelector('.servants-palette .palette-col:nth-child(3) .palette-title span');
    if (s3Title) s3Title.textContent = TEXT_CONFIG.palette.servant3Title;
    const s3Sub = document.querySelector('.servants-palette .palette-col:nth-child(3) .palette-title small');
    if (s3Sub) s3Sub.textContent = TEXT_CONFIG.palette.servant3Subtitle;

    for (let s = 1; s <= 9; s++) {
        const skillNum = s;
        const mainBtn = document.querySelector(`button.skill-main-btn[data-skill="${s}"] span`);
        if (mainBtn) mainBtn.textContent = formatText(TEXT_CONFIG.palette.skillMainBtn, { id: skillNum });
        const mainBtnParent = document.querySelector(`button.skill-main-btn[data-skill="${s}"]`);
        if (mainBtnParent) mainBtnParent.title = formatText(TEXT_CONFIG.palette.skillMainBtnTitle, { id: skillNum });

        [1, 2, 3].forEach(tVal => {
            const tBtn = document.querySelector(`button.skill-target-btn[data-skill="${s}"][data-target-val="${tVal}"]`);
            if (tBtn) tBtn.title = formatText(TEXT_CONFIG.palette.skillTargetBtnTitle, { id: skillNum, target: tVal });
        });
    }

    // 出牌控制台
    const attackTitle = document.querySelector('.attack-title-wrap span');
    if (attackTitle) attackTitle.textContent = TEXT_CONFIG.palette.attackTitle;

    const attackSub = document.querySelector('.attack-title-wrap small');
    if (attackSub) {
        if (TEXT_CONFIG?.palette?.attackSubtitle) {
            attackSub.textContent = TEXT_CONFIG.palette.attackSubtitle;
            attackSub.style.display = '';
        } else {
            attackSub.remove();
        }
    }


    const rowLabels = document.querySelectorAll('.picker-row-label');
    if (rowLabels[0]) rowLabels[0].textContent = TEXT_CONFIG.palette.categoryNp;
    if (rowLabels[1]) rowLabels[1].textContent = TEXT_CONFIG.palette.categoryColor;
    if (rowLabels[2]) rowLabels[2].textContent = TEXT_CONFIG.palette.categoryNormal;

    // 弹窗部分静态元素
    const targetModalTitle = $('targetModalTitle');
    if (targetModalTitle) targetModalTitle.textContent = TEXT_CONFIG.modals.targetModal.title;

    const opt0 = document.querySelector('#targetModal [data-target-val="0"]');
    if (opt0) opt0.textContent = TEXT_CONFIG.modals.targetModal.optSelf;
    const opt1 = document.querySelector('#targetModal [data-target-val="1"]');
    if (opt1) opt1.textContent = TEXT_CONFIG.modals.targetModal.optServant1;
    const opt2 = document.querySelector('#targetModal [data-target-val="2"]');
    if (opt2) opt2.textContent = TEXT_CONFIG.modals.targetModal.optServant2;
    const opt3 = document.querySelector('#targetModal [data-target-val="3"]');
    if (opt3) opt3.textContent = TEXT_CONFIG.modals.targetModal.optServant3;

    const swapTitle = $('swapModalTitle');
    if (swapTitle) swapTitle.textContent = TEXT_CONFIG.modals.swapModal.titleDefault;

    const confirmSwapBtn = $('confirmSwapBtn');
    if (confirmSwapBtn) confirmSwapBtn.textContent = TEXT_CONFIG.modals.swapModal.btnConfirm;

    const importDslTitle = document.querySelector('#importDslModal h4');
    if (importDslTitle) importDslTitle.textContent = TEXT_CONFIG.modals.importDslModal.title;

    const importDslText = $('importDslText');
    if (importDslText) importDslText.placeholder = TEXT_CONFIG.modals.importDslModal.placeholder;

    const importDslNewBtn = $('importDslNewBtn');
    if (importDslNewBtn) {
        importDslNewBtn.textContent = TEXT_CONFIG.modals.importDslModal.btnImportNew;
        importDslNewBtn.title = TEXT_CONFIG.modals.importDslModal.btnImportNewTitle;
    }

    const importDslOverwriteBtn = $('importDslOverwriteBtn');
    if (importDslOverwriteBtn) {
        importDslOverwriteBtn.textContent = TEXT_CONFIG.modals.importDslModal.btnOverwrite;
        importDslOverwriteBtn.title = TEXT_CONFIG.modals.importDslModal.btnOverwriteTitle;
    }

    const importDslPasteBtn = $('importDslPasteBtn');
    if (importDslPasteBtn) {
        importDslPasteBtn.textContent = TEXT_CONFIG.modals.importDslModal.btnPasteClipboard;
        importDslPasteBtn.title = TEXT_CONFIG.modals.importDslModal.btnPasteClipboardTitle;
    }
}

// 全量视图刷新
export function render() {
    applyStaticTexts();
    renderGroupTabs();
    renderSchemeList();
    renderSchemeDetails();
    renderWavesBoard();
    renderConfigPreview();
}

// 注册模态弹窗回调，保持数据与视图实时同步
registerUpdateCallback(opts => {
    if (opts?.renderBoardOnly) {
        renderWavesBoard();
        renderConfigPreview();
    } else if (opts?.fullRender) {
        render();
    }
});

