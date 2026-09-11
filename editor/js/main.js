import { appState, getCurGroup, getCurScheme, resetStateToInitial } from './state.js';
import { CARD_INFO } from './constants.js';
import { getCurSchemeRounds, commitChanges, generateConfigText, resetCurSchemeRoundsToInitial, createDefaultRound, compileSchemeDsl, extractDslFromText } from './dsl.js';
import { $, toast, loadConfigFromBackend, saveConfigToBackend, shutdownServer } from './api.js';
import { TEXT_CONFIG, formatText } from './text_config.js';

// 挂载到 window 方便全局调试与查看文本字典
window.TEXT_CONFIG = TEXT_CONFIG;

import {
    closeModal,
    editRoundAttack,
    openEditStepModal,
    saveEditingStep,
    deleteCurrentEditingStep,
    setEditStepTarget,
    setEditStepSkillId,
    setEditStepSkillTarget,
    setEditStepMasterId,
    setEditStepMasterTarget,
    setEditStepSwapMasterId,
    setEditStepSwapFront,
    setEditStepSwapBack,
    doImportDsl,
    formatAttackCards
} from './modals.js';
import {
    render,
    renderGroupTabs,
    renderSchemeList,
    renderSchemeDetails,
    renderWavesBoard,
    renderConfigPreview,
    setActiveWave,
    addWave,
    deleteWave,
    clearWave,
    removeStep,
    removeAttack,
    setRoundAttackDOM,
    onStepChipClick,
    updateSelectionUI,
    updateAttackPaletteHighlight,
    appendStepChipDOM,
    updateStepChipDOM,
    startEditSchemeName,
    saveSchemeName,
    cancelEditSchemeName
} from './ui.js';

// 大组切换
export function selectGroup(idx) {
    appState.curGroupIdx = idx;
    appState.curSchemeIdx = 0;
    appState.curRoundIdx = 0;
    render();
}

// 方案切换
export function selectScheme(idx) {
    appState.curSchemeIdx = idx;
    appState.curRoundIdx = 0;
    render();
}

// 挂载全局方法供 HTML 内联事件调用 (保持 100% 向后兼容)
window.selectGroup = selectGroup;
window.selectScheme = selectScheme;
window.startEditSchemeName = startEditSchemeName;
window.saveSchemeName = saveSchemeName;
window.cancelEditSchemeName = cancelEditSchemeName;
window.closeModal = closeModal;
window.setRoundAttackDOM = setRoundAttackDOM;
window.editRoundAttack = editRoundAttack;
window.onStepChipClick = onStepChipClick;
window.removeStep = removeStep;
window.removeAttack = removeAttack;
window.setActiveWave = setActiveWave;
window.deleteWave = deleteWave;
window.clearWave = clearWave;
window.saveEditingStep = saveEditingStep;
window.deleteCurrentEditingStep = deleteCurrentEditingStep;
window.setEditStepTarget = setEditStepTarget;
window.setEditStepSkillId = setEditStepSkillId;
window.setEditStepSkillTarget = setEditStepSkillTarget;
window.setEditStepMasterId = setEditStepMasterId;
window.setEditStepMasterTarget = setEditStepMasterTarget;
window.setEditStepSwapMasterId = setEditStepSwapMasterId;
window.setEditStepSwapFront = setEditStepSwapFront;
window.setEditStepSwapBack = setEditStepSwapBack;
window.resetCurSchemeRounds = () => {
    resetCurSchemeRoundsToInitial();
    renderWavesBoard();
    renderConfigPreview();
    toast(TEXT_CONFIG.timeline.resetSchemeToast);
};

// 获取当前完整且最新的 Q 脚本配置文本（同步更新 DOM 缓存）
export function getCurrentConfigText() {
    commitChanges();
    const text = generateConfigText(appState.data);
    const previewEl = $('configPreview');
    if (previewEl) {
        previewEl.value = text;
    }
    return text;
}

// 跨浏览器兼容的剪贴板复制工具函数（支持现代 API 与 document.execCommand 回退）
export async function copyTextToClipboard(text) {
    if (!text && text !== '') return false;
    try {
        if (navigator.clipboard && window.isSecureContext) {
            await navigator.clipboard.writeText(text);
            return true;
        }
    } catch (e) {
        console.warn('navigator.clipboard.writeText failed, falling back to execCommand:', e);
    }

    try {
        const ta = document.createElement('textarea');
        ta.value = text;
        ta.style.position = 'fixed';
        ta.style.left = '-9999px';
        ta.style.top = '-9999px';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.focus();
        ta.select();
        const success = document.execCommand('copy');
        document.body.removeChild(ta);
        return success;
    } catch (err) {
        console.error('execCommand copy fallback failed:', err);
        return false;
    }
}

// 初始化 DOM 事件绑定
function initEventBindings() {
    // 方案名称输入框快捷键支持：Enter 保存，ESC 取消
    const schemeNameInput = $('schemeNameInput');
    if (schemeNameInput) {
        schemeNameInput.onkeydown = e => {
            if (e.key === 'Enter') saveSchemeName();
            else if (e.key === 'Escape') cancelEditSchemeName();
        };
    }

    // 工具栏：添加下一回合
    const addWaveBtn = $('addWaveBtn');
    if (addWaveBtn) {
        addWaveBtn.onclick = () => addWave();
    }

    // 工具栏：重置方案（回到配置文件/初始状态）
    const resetCurSchemeBtn = $('resetCurSchemeBtn');
    if (resetCurSchemeBtn) {
        resetCurSchemeBtn.onclick = () => {
            resetCurSchemeRoundsToInitial();
            renderWavesBoard();
            renderConfigPreview();
            toast(TEXT_CONFIG.timeline.resetSchemeToast);
        };
    }

    // 工具栏：清空方案
    const clearCurSchemeBtn = $('clearCurSchemeBtn');
    if (clearCurSchemeBtn) {
        clearCurSchemeBtn.onclick = () => {
            const rounds = getCurSchemeRounds();
            rounds.forEach(r => {
                r.steps = [];
                r.attack = [];
            });
            commitChanges();
            renderWavesBoard();
            renderConfigPreview();
            toast(TEXT_CONFIG.timeline.clearSchemeToast);
        };
    }


    // 统一处理动作添加与就地修改（当选中某个动作卡片时，直接替换修改并取消选中；未选中时追加到末尾）
    function applyStepAction(stepData, actionDesc) {
        const rounds = getCurSchemeRounds();

        // 1. 如果处于选中动作修改模式：就地修改并单卡闪烁
        if (appState.selectedStepState) {
            const { waveIdx, stepIdx } = appState.selectedStepState;
            if (rounds[waveIdx]?.steps?.[stepIdx]) {
                rounds[waveIdx].steps[stepIdx] = stepData;
                appState.selectedStepState = null; // 修改后失去选中效果

                commitChanges();
                renderConfigPreview();

                const updated = updateStepChipDOM(waveIdx, stepIdx, stepData);
                if (!updated) {
                    renderWavesBoard();
                }
                updateSelectionUI();
                toast(formatText(TEXT_CONFIG.palette.actionModifiedToast, { wave: waveIdx + 1, step: stepIdx + 1, desc: actionDesc }));
                return;
            }
        }

        // 2. 正常追加到当前活动 Wave 末尾并单卡闪烁
        if (!rounds[appState.curRoundIdx]) return;
        if (!rounds[appState.curRoundIdx].steps) rounds[appState.curRoundIdx].steps = [];
        rounds[appState.curRoundIdx].steps.push(stepData);

        commitChanges();
        renderConfigPreview();

        const appended = appendStepChipDOM(appState.curRoundIdx, stepData);
        if (!appended) {
            renderWavesBoard();
        }
        updateSelectionUI();
        toast(formatText(TEXT_CONFIG.palette.actionAddedToast, { wave: appState.curRoundIdx + 1, desc: actionDesc }));
    }

    // 选敌点击 -> 修改选中动作或追加到当前 Wave
    document.querySelectorAll('[data-target]').forEach(btn => {
        btn.onclick = () => {
            const targetNum = btn.dataset.target;
            applyStepAction(
                { type: 'target', target: targetNum },
                formatText(TEXT_CONFIG.palette.targetDesc, { target: targetNum })
            );
        };
    });

    // 收尾出牌槽位模型：精确对应 FGO 原生 3-Slot 槽位 [Slot0, Slot1, Slot2]
    // 每个槽位存储选中的卡牌字符（如 '6', 'B', '1'），空槽位为 null
    let pendingAttackSlots = [null, null, null];

    window.syncPendingAttackCards = function(cards) {
        if (Array.isArray(cards)) {
            pendingAttackSlots = [
                cards[0] ? String(cards[0]).trim() : null,
                cards[1] ? String(cards[1]).trim() : null,
                cards[2] ? String(cards[2]).trim() : null
            ];
        } else {
            pendingAttackSlots = [null, null, null];
        }
    };

    // 取消指定槽位的出牌（slotIdx: 0, 1, 2），保留其他槽位的卡牌与顺序完全不变！
    function clearAttackSlot(slotIdx) {
        if (slotIdx >= 0 && slotIdx < 3 && pendingAttackSlots[slotIdx] !== null) {
            const removed = pendingAttackSlots[slotIdx];
            pendingAttackSlots[slotIdx] = null;
            renderPendingAttackBadges();

            // 同步当前 Wave：如果全空则清除出牌动作，否则更新有效槽位
            const activeCards = pendingAttackSlots.filter(Boolean);
            if (activeCards.length > 0) {
                setRoundAttackDOM(appState.curRoundIdx, activeCards);
            } else {
                removeAttack(appState.curRoundIdx);
            }
            const info = typeof CARD_INFO !== 'undefined' ? CARD_INFO[removed] : null;
            toast(formatText(TEXT_CONFIG.palette.cancelCardToast, { seq: slotIdx + 1, cardName: info?.label || removed }));
        }
    }
    window.clearAttackSlot = clearAttackSlot;


    // 全局捕获阶段拦截顺序标签点击：色卡上点击顺序标签直接取消对应的槽位，不触发父级按钮添加
    document.addEventListener('click', (e) => {
        const seqTag = e.target.closest('.seq-tag');
        if (seqTag && seqTag.dataset.removeSlot !== undefined) {
            e.stopPropagation();
            e.preventDefault();
            const slotIdx = Number(seqTag.dataset.removeSlot);
            if (!isNaN(slotIdx) && slotIdx >= 0 && slotIdx < 3) {
                clearAttackSlot(slotIdx);
            }
        }
    }, true);

    function renderPendingAttackBadges() {
        // 清理所有按钮上的暂存高亮与序号角标
        document.querySelectorAll('[data-attack-card]').forEach(btn => {
            btn.classList.remove('selected-attack-card');
            const container = btn.querySelector('.card-seq-badges');
            if (container) container.innerHTML = '';
        });

        // 收集各个卡牌命中的 slot 列表（如 'B' 命中 Slot0 和 Slot2 -> 显示标签 1 和 3）
        const cardSeqMap = {};
        pendingAttackSlots.forEach((cardCode, slotIdx) => {
            if (!cardCode) return;
            const seq = slotIdx + 1;
            const norm = String(cardCode).trim().toUpperCase();
            if (!cardSeqMap[norm]) cardSeqMap[norm] = [];
            cardSeqMap[norm].push({ seq, slotIdx });
        });

        // 渲染各个按钮上的角标 (带 data-remove-slot，精确指定取消哪个槽位)
        Object.entries(cardSeqMap).forEach(([cardCode, list]) => {
            const btn = document.querySelector(`[data-attack-card="${cardCode}"]`);
            if (btn) {
                btn.classList.add('selected-attack-card');
                const container = btn.querySelector('.card-seq-badges');
                if (container) {
                    const seqLabels = {
                        1: TEXT_CONFIG.palette?.seqLabel1 || '一',
                        2: TEXT_CONFIG.palette?.seqLabel2 || '二',
                        3: TEXT_CONFIG.palette?.seqLabel3 || '三'
                    };
                    container.innerHTML = list.map(item => {
                        const seqText = seqLabels[item.seq] || String(item.seq);
                        const tagTitle = formatText(TEXT_CONFIG.palette?.cancelCardTagTitle || '点击取消顺位【{seq}】({card})', { seq: seqText, card: cardCode });
                        return `<span class="seq-tag seq-${item.seq}" data-remove-slot="${item.slotIdx}" title="${tagTitle}">${seqText}</span>`;
                    }).join('');
                }
            }
        });

    }


    // 点击出牌卡片：遵循游戏原生 3-Slot 槽位机制
    document.querySelectorAll('[data-attack-card]').forEach(btn => {
        btn.onclick = (e) => {
            e.stopPropagation();
            const cardVal = btn.dataset.attackCard;
            const isColorCard = ['B', 'A', 'Q'].includes(cardVal);

            // 规则 1：已选中的非色卡再次点击 -> 取消选中对应的槽位，保留其他已选牌及其顺序位置不变！
            if (!isColorCard) {
                const existSlotIdx = pendingAttackSlots.indexOf(cardVal);
                if (existSlotIdx !== -1) {
                    clearAttackSlot(existSlotIdx);
                    return;
                }
            }

            // 规则 2：寻找第一个为空的槽位放入
            let targetSlotIdx = pendingAttackSlots.findIndex(c => c === null);

            // 规则 3：如果 3 个槽位都已满了，无法选中第 4 张牌
            if (targetSlotIdx === -1) {
                toast(TEXT_CONFIG.palette.attackFullWarnToast);
                return;
            }

            pendingAttackSlots[targetSlotIdx] = cardVal;
            renderPendingAttackBadges();

            // 选满 3 张后立即生效写入当前 Wave
            if (pendingAttackSlots.every(c => c !== null)) {
                const finalCards = [...pendingAttackSlots];
                setRoundAttackDOM(appState.curRoundIdx, finalCards);
                toast(formatText(TEXT_CONFIG.palette.attackUpdatedToast, { wave: appState.curRoundIdx + 1, cards: finalCards.join(' + ') }));
            }
        };
    });

    // 从者技能点击：修改选中动作或追加到当前 Wave
    document.querySelectorAll('[data-skill]').forEach(btn => {
        btn.onclick = (e) => {
            e.stopPropagation();
            const skill = btn.dataset.skill;
            const targetVal = btn.dataset.targetVal || '0';
            const actionDesc = targetVal === '0'
                ? formatText(TEXT_CONFIG.palette.skillDescSelf, { id: skill })
                : formatText(TEXT_CONFIG.palette.skillDescTarget, { id: skill, target: targetVal });
            applyStepAction(
                { type: 'skill', code: `${skill}${targetVal}` },
                actionDesc
            );
        };
    });

    // 御主技能点击：修改选中动作或追加到当前 Wave
    document.querySelectorAll('[data-master]').forEach(btn => {
        btn.onclick = (e) => {
            e.stopPropagation();
            const m = btn.dataset.master;
            const targetVal = btn.dataset.targetVal || '0';
            const actionDesc = targetVal === '0'
                ? formatText(TEXT_CONFIG.palette.masterDescSelf, { id: m })
                : formatText(TEXT_CONFIG.palette.masterDescTarget, { id: m, target: targetVal });
            applyStepAction(
                { type: 'master', code: `${m}${targetVal}` },
                actionDesc
            );
        };
    });

    // 目标弹窗备用点击选项 (仅限 #targetModal 内选项)
    document.querySelectorAll('#targetModal [data-target-val]').forEach(btn => {
        btn.onclick = () => {
            if (!appState.pendingAction) return;
            const targetVal = btn.dataset.targetVal;
            const rounds = getCurSchemeRounds();
            if (!rounds[appState.curRoundIdx]) return;

            if (appState.pendingAction.type === 'skill') {
                rounds[appState.curRoundIdx].steps.push({ type: 'skill', code: `${appState.pendingAction.skill}${targetVal}` });
                toast(formatText(TEXT_CONFIG.modals.targetModal.addSkillToast, { wave: appState.curRoundIdx + 1 }));
            } else if (appState.pendingAction.type === 'master') {
                rounds[appState.curRoundIdx].steps.push({ type: 'master', code: `${appState.pendingAction.master}${targetVal}` });
                toast(formatText(TEXT_CONFIG.modals.targetModal.addMasterToast, { wave: appState.curRoundIdx + 1 }));
            }

            commitChanges();
            renderWavesBoard();
            renderConfigPreview();
            closeModal();
        };
    });

    // 换人技能选择与弹窗交互
    window.openSwapModal = (mId = 3) => {
        appState.pendingSwapMasterId = Number(mId) || 3;
        appState.selectedSwapFront = 3;
        appState.selectedSwapBack = 4;
        document.querySelectorAll('[data-swap-front]').forEach(b => {
            b.classList.toggle('selected', Number(b.dataset.swapFront) === 3);
        });
        document.querySelectorAll('[data-swap-back]').forEach(b => {
            b.classList.toggle('selected', Number(b.dataset.swapBack) === 4);
        });
        const titleEl = $('swapModalTitle');
        if (titleEl) {
            titleEl.textContent = TEXT_CONFIG.modals.swapModal.titleDefault;
        }
        $('swapModal').classList.add('show');
    };

    document.querySelectorAll('[data-master-swap]').forEach(btn => {
        btn.onclick = (e) => {
            e.stopPropagation();
            const m = Number(btn.dataset.masterSwap) || 3;
            window.openSwapModal(m);
        };
    });

    document.querySelectorAll('[data-swap-front]').forEach(btn => {
        btn.onclick = () => {
            document.querySelectorAll('[data-swap-front]').forEach(b => b.classList.remove('selected'));
            btn.classList.add('selected');
            appState.selectedSwapFront = Number(btn.dataset.swapFront);
        };
    });

    document.querySelectorAll('[data-swap-back]').forEach(btn => {
        btn.onclick = () => {
            document.querySelectorAll('[data-swap-back]').forEach(b => b.classList.remove('selected'));
            btn.classList.add('selected');
            appState.selectedSwapBack = Number(btn.dataset.swapBack);
        };
    });

    const confirmSwapBtn = $('confirmSwapBtn');
    if (confirmSwapBtn) {
        confirmSwapBtn.onclick = () => {
            const m = appState.pendingSwapMasterId || 3;
            const f = appState.selectedSwapFront || 3;
            const b = appState.selectedSwapBack || 4;
            const swapCode = `${m}00${f}${b}`;
            applyStepAction(
                { type: 'master', code: swapCode },
                formatText(TEXT_CONFIG.modals.swapModal.swapDesc, { mId: m, f, b })
            );
            closeModal();
        };
    }

    // 点击空白处或按 Esc 键取消选中
    document.addEventListener('click', (e) => {
        if (appState.selectedStepState) {
            if (!e.target.closest('.timeline-chip') && !e.target.closest('.workspace-palette-col') && !e.target.closest('.modal-card')) {
                appState.selectedStepState = null;
                updateSelectionUI();
            }
        }
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && appState.selectedStepState) {
            appState.selectedStepState = null;
            updateSelectionUI();
        }
    });

    // 增加方案
    const addSchemeBtn = $('addSchemeBtn');
    if (addSchemeBtn) {
        addSchemeBtn.onclick = () => {
            const group = getCurGroup();
            const defaultRound = createDefaultRound();
            group.schemes.push({
                friend: "",
                dsl: compileSchemeDsl([defaultRound]),
                _parsedRounds: [defaultRound],
                activityReward: 0
            });
            appState.curSchemeIdx = group.schemes.length - 1;
            appState.curRoundIdx = 0;
            render();
            toast(formatText(TEXT_CONFIG.sidebar.schemeAddedToast, { count: group.schemes.length }));
        };
    }

    // 复制方案 DSL
    const copyDslBtn = $('copyDslBtn');
    if (copyDslBtn) {
        copyDslBtn.onclick = async () => {
            commitChanges();
            const scheme = getCurScheme();
            const dslStr = scheme ? (scheme.dsl || '') : '';
            const ok = await copyTextToClipboard(dslStr);
            if (ok) {
                toast(formatText(TEXT_CONFIG.schemeBar.copyDslSuccessToast, { index: appState.curSchemeIdx + 1 }));
            } else {
                toast(TEXT_CONFIG.schemeBar.copyDslFailToast);
            }
        };
    }

    // 自动识别剪贴板中的 DSL 并在输入框中填入
    async function tryAutoPasteDslFromClipboard(showToastIfEmpty = false) {
        try {
            if (navigator.clipboard && navigator.clipboard.readText) {
                const clipText = await navigator.clipboard.readText();
                const dsl = extractDslFromText(clipText);
                if (dsl) {
                    $('importDslText').value = dsl;
                    $('importDslText').select();
                    toast(TEXT_CONFIG.modals.importDslModal.clipboardDetectedToast);
                    return true;
                }
            }
        } catch (err) {
            console.warn('Clipboard read failed or permission denied:', err);
        }
        if (showToastIfEmpty) {
            toast(TEXT_CONFIG.modals.importDslModal.clipboardEmptyOrInvalid);
        }
        return false;
    }

    // 导入方案 DSL
    const importDslBtn = $('importDslBtn');
    if (importDslBtn) {
        importDslBtn.onclick = async () => {
            $('importDslText').value = '';
            $('importDslError').style.display = 'none';
            $('importDslError').textContent = '';
            $('importDslModal').classList.add('show');
            setTimeout(() => $('importDslText').focus(), 50);

            await tryAutoPasteDslFromClipboard(false);
        };
    }

    const importDslPasteBtn = $('importDslPasteBtn');
    if (importDslPasteBtn) {
        importDslPasteBtn.onclick = () => tryAutoPasteDslFromClipboard(true);
    }

    const importDslOverwriteBtn = $('importDslOverwriteBtn');
    if (importDslOverwriteBtn) importDslOverwriteBtn.onclick = () => doImportDsl(false);

    const importDslNewBtn = $('importDslNewBtn');
    if (importDslNewBtn) importDslNewBtn.onclick = () => doImportDsl(true);

    // 点击遮罩关闭弹窗
    document.querySelectorAll('.modal-overlay').forEach(overlay => {
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) closeModal();
        });
    });

    // ESC 快捷键关闭弹窗
    window.addEventListener('keydown', e => {
        if (e.key === 'Escape') closeModal();
    });

    // 复制配置文本
    const copyBtn = $('copyBtn');
    if (copyBtn) {
        copyBtn.onclick = async () => {
            const configText = getCurrentConfigText();
            const ok = await copyTextToClipboard(configText);
            if (ok) {
                toast(TEXT_CONFIG.messages.copySuccess);
            } else {
                toast(TEXT_CONFIG.messages.copyFail);
            }
        };
    }

    // 保存到本地文件
    const saveBtn = $('saveBtn');
    if (saveBtn) {
        saveBtn.onclick = () => {
            const configText = getCurrentConfigText();
            saveConfigToBackend(configText);
        };
    }

    // 重新从磁盘读取配置
    const reloadBtn = $('reloadBtn');
    if (reloadBtn) {
        reloadBtn.onclick = () => loadConfigFromBackend(render);
    }

    // 重置配置
    const resetBtn = $('resetBtn');
    if (resetBtn) {
        resetBtn.onclick = () => {
            resetStateToInitial();
            render();
            toast(TEXT_CONFIG.sidebar.resetDoneToast);
        };
    }


    // 刷新页面 (刷新当前前端状态与 DOM)
    const refreshPageBtn = $('refreshPageBtn');
    if (refreshPageBtn) {
        refreshPageBtn.onclick = () => location.reload();
    }

    // 恢复推荐窗口尺寸 (1600x1020)
    const resetSizeBtn = $('resetSizeBtn');
    if (resetSizeBtn) {
        resetSizeBtn.onclick = async () => {
            if (window.pywebview && window.pywebview.api && window.pywebview.api.resizeWindow) {
                const ok = await window.pywebview.api.resizeWindow(1600, 1020);
                if (ok) toast('📐 已重置为黄金推荐尺寸 (1600×1020)');
                else toast('调整窗口尺寸失败');
            } else {
                toast('当前不在独立桌面窗口模式下');
            }
        };
    }

    // 在系统默认浏览器中打开
    const openBrowserBtn = $('openBrowserBtn');
    if (openBrowserBtn) {
        openBrowserBtn.onclick = async () => {
            try {
                await fetch('/api/open-browser');
                toast('🌐 已在系统默认浏览器中打开');
            } catch (err) {
                toast('无法调用系统浏览器: ' + err.message);
            }
        };
    }

    // 快捷键支持：
    // 1. Ctrl+S / Command+S 保存
    // 2. F5 / Ctrl+R / Command+R 刷新页面
    window.addEventListener('keydown', e => {
        if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
            e.preventDefault();
            const configText = getCurrentConfigText();
            saveConfigToBackend(configText);
        } else if (e.key === 'F5' || ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'r')) {
            e.preventDefault();
            location.reload();
        }
    });
}

// 页面生命周期启动（单次执行保护）
let isAppBootstrapped = false;
function bootstrapApp() {
    if (isAppBootstrapped) return;
    isAppBootstrapped = true;

    // 若运行在独立桌面窗口且当前尺寸偏小，自动校准至 1500x930
    try {
        if (window.outerWidth && (window.outerWidth < 1460 || window.outerHeight < 900)) {
            window.resizeTo(1500, 930);
        }
    } catch (e) {}

    initEventBindings();
    render();
    loadConfigFromBackend(render);
}

document.addEventListener('DOMContentLoaded', bootstrapApp);
if (document.readyState !== 'loading') {
    bootstrapApp();
}
