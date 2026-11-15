import { appState, getCurGroup, getCurScheme } from './state.js';
import { CARD_INFO } from './constants.js';
import { getCurSchemeRounds, commitChanges, parseRoundDsl, compileSchemeDsl, extractDslFromText, getBaseCardCode } from './dsl.js';
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

    const attPriM = $('attackPriorityModal');
    if (attPriM) attPriM.classList.remove('show');

    closeCardPrefPopover();

    const impM = $('importDslModal');
    if (impM) impM.classList.remove('show');

    const editM = $('editStepModal');
    if (editM) editM.classList.remove('show');

    if (typeof window.closeConfirmModal === 'function') {
        window.closeConfirmModal();
    } else {
        const confM = $('confirmModal');
        if (confM) confM.classList.remove('show');
    }

    appState.pendingAction = null;
    appState.currentEditingStepInfo = null;
}

// 辅助函数：解析并格式化单个卡牌标记/优先级长链的显示文案与样式类
export function formatCardBadgeLabel(str) {
    if (!str) return { label: '', typeCls: 'normal', fullTitle: '' };
    const full = String(str).trim().toUpperCase();
    const isChain = full.includes('>');
    const atoms = full.split('>').map(s => s.trim()).filter(Boolean);
    const first = atoms[0] || full;

    const isMustCrit = full.startsWith('!') || full.includes('!');
    let base = first;
    if (base.startsWith('!')) base = base.slice(1);
    if (base.endsWith('!')) base = base.slice(0, -1);

    let label = base;
    let typeCls = 'normal';

    if (base === '6') { label = TEXT_CONFIG.cards?.np1Badge || '👑 宝1'; typeCls = 'np'; }
    else if (base === '7') { label = TEXT_CONFIG.cards?.np2Badge || '👑 宝2'; typeCls = 'np'; }
    else if (base === '8') { label = TEXT_CONFIG.cards?.np3Badge || '👑 宝3'; typeCls = 'np'; }
    else if (base === 'B') { label = TEXT_CONFIG.cards?.busterBadge || '🔴 红卡'; typeCls = 'buster'; }
    else if (base === 'A') { label = TEXT_CONFIG.cards?.artsBadge || '🔵 蓝卡'; typeCls = 'arts'; }
    else if (base === 'Q') { label = TEXT_CONFIG.cards?.quickBadge || '🟢 绿卡'; typeCls = 'quick'; }
    else if (base === '*') { label = '🃏 任意'; typeCls = 'normal'; }
    else if (base.startsWith('H')) {
        typeCls = 'hero';
        const hNum = base[1] || '1';
        const colors = base.slice(2);
        const colorName = colors === 'B' ? '红' : (colors === 'A' ? '蓝' : (colors === 'Q' ? '绿' : ''));
        label = colorName ? `从${hNum}·${colorName}` : (TEXT_CONFIG.cards?.[`hero${hNum}Badge`] || `⚔️ 从${hNum}`);
    }
    else if (/^[BAQ][123]+$/.test(base)) {
        const colorChar = base[0];
        const heroes = base.slice(1);
        typeCls = colorChar === 'B' ? 'buster' : (colorChar === 'A' ? 'arts' : 'quick');
        const colorName = colorChar === 'B' ? '红' : (colorChar === 'A' ? '蓝' : '绿');
        label = `${colorName}·${heroes.split('').join('>')}`;
    }
    else {
        label = formatText(TEXT_CONFIG.cards?.normalBadge || '🃏 普{num}', { num: base });
        typeCls = 'normal';
    }

    if (isMustCrit) {
        label += '★';
    }
    if (isChain) {
        label += '…';
    }

    return { label, typeCls, fullTitle: full };
}

// 格式化出牌卡片文案 (文本纯字符串格式)
export function formatAttackCards(cards) {
    if (!cards || !cards.length) return '';
    return cards.map(c => {
        const info = formatCardBadgeLabel(c);
        return info.label;
    }).join(' + ');
}

// 生成左侧已选出牌小组件内部的 3 张牌独立框体 HTML（带独立色系与位置卡基础色）
export function formatAttackCardsBadgesHtml(cards) {
    if (!cards || !cards.length) return '';
    return cards.map(c => {
        const info = formatCardBadgeLabel(c);
        return `<span class="attack-mini-card ${info.typeCls}" title="${escapeHtml(info.fullTitle)}">${info.label}</span>`;
    }).join('');
}

// 点击时序中的出牌卡片：切换当前回合并直接打开出牌高级倾向配置弹窗
export function editRoundAttack(waveIdx, event) {
    if (event) event.stopPropagation();
    appState.curRoundIdx = waveIdx;
    if (typeof window.setActiveWave === 'function') {
        window.setActiveWave(waveIdx);
    }
    openAttackPriorityModal(waveIdx);
}

let currentAttackModalWave = 0;
let currentAttackModalSlots = ['7', 'B', 'B'];

export function openAttackPriorityModal(waveIdx) {
    if (waveIdx === undefined || waveIdx === null) {
        waveIdx = appState.curRoundIdx;
    }
    const rounds = getCurSchemeRounds();
    if (!rounds || !rounds[waveIdx]) return;

    currentAttackModalWave = waveIdx;
    const roundAttack = rounds[waveIdx].attack;
    if (Array.isArray(roundAttack) && roundAttack.length === 3) {
        currentAttackModalSlots = [...roundAttack];
    } else {
        currentAttackModalSlots = ['7', 'B', 'B'];
    }

    const titleEl = $('attackPriorityModalTitle');
    if (titleEl) {
        titleEl.textContent = formatText(TEXT_CONFIG.modals?.attackPriorityModal?.title || '⚙️ Wave {wave} 出牌高级倾向', { wave: waveIdx + 1 });
    }

    renderAttackPriorityModalBody();

    const modal = $('attackPriorityModal');
    if (modal) {
        modal.classList.add('show');
    }
}

export function renderAttackPriorityModalBody() {
    const body = $('attackPriorityModalBody');
    if (!body) return;

    let html = '';
    currentAttackModalSlots.forEach((token, slotIdx) => {
        const norm = String(token || '').trim().toUpperCase();
        const base = getBaseCardCode(norm);
        const slotNum = slotIdx + 1;
        const isNP = ['6', '7', '8'].includes(base);
        const isNormal = ['1', '2', '3', '4', '5'].includes(base);
        const isHero = /^H[123]$/.test(base);
        const isColor = ['B', 'A', 'Q'].includes(base);

        const badgeHtml = formatAttackCardsBadgesHtml([norm]);

        if (isNP) {
            const npName = base === '6' ? '从者 1' : (base === '7' ? '从者 2' : '从者 3');
            html += `
                <div class="attack-slot-box disabled-slot">
                    <div class="attack-slot-header">
                        <span class="attack-slot-title">👑 第 ${slotNum} 位：${npName} 宝具 (${base})</span>
                        <div class="attack-mini-cards">${badgeHtml}</div>
                    </div>
                    <div class="attack-slot-hint">👑 宝具卡固定释放对应从者宝具，无需额外倾向配置。</div>
                </div>
            `;
        } else if (isNormal) {
            html += `
                <div class="attack-slot-box disabled-slot">
                    <div class="attack-slot-header">
                        <span class="attack-slot-title">🃏 第 ${slotNum} 位：位置普攻卡 ${base}</span>
                        <div class="attack-mini-cards">${badgeHtml}</div>
                    </div>
                    <div class="attack-slot-hint">🃏 固定位置普攻卡按固定位置出牌，无需倾向配置。</div>
                </div>
            `;
        } else if (isHero) {
            const heroNum = base[1];
            const presets = [
                { token: base, label: '无' },
                { token: `${base}B`, label: '红卡 (B)' },
                { token: `${base}A`, label: '蓝卡 (A)' },
                { token: `${base}Q`, label: '绿卡 (Q)' }
            ];

            const presetBtnsHtml = presets.map(p => {
                const isActive = norm === p.token;
                return `<button type="button" class="pref-preset-btn ${isActive ? 'active' : ''}" onclick="window.setAttackSlotPref(${slotIdx}, '${p.token}')">${escapeHtml(p.label)}</button>`;
            }).join('');

            html += `
                <div class="attack-slot-box">
                    <div class="attack-slot-header">
                        <span class="attack-slot-title">⚔️ 第 ${slotNum} 位：从者 ${heroNum} 手卡</span>
                        <div style="display:flex; align-items:center; gap:8px;">
                            <input type="text" class="pref-custom-token-input" value="${escapeHtml(norm)}" oninput="window.setAttackSlotPref(${slotIdx}, this.value)" title="自定义 DSL 指令代码">
                            <div class="attack-mini-cards">${badgeHtml}</div>
                        </div>
                    </div>
                    <div class="attack-slot-hint">优先锁定<b>从者 ${heroNum}</b> 的手卡，可指定其色卡选择偏好：</div>
                    <div class="pref-presets-row">
                        ${presetBtnsHtml}
                    </div>
                </div>
            `;
        } else if (isColor) {
            const colorName = base === 'B' ? '红卡 (Buster)' : (base === 'A' ? '蓝卡 (Arts)' : '绿卡 (Quick)');
            const heroPart = norm.slice(base.length);
            const hero1 = heroPart[0] || '';
            const hero2 = heroPart[1] || '';

            const tier1BtnsHtml = [
                { id: '', label: '无', active: hero1 === '' },
                { id: '1', label: '从1', active: hero1 === '1' },
                { id: '2', label: '从2', active: hero1 === '2' },
                { id: '3', label: '从3', active: hero1 === '3' }
            ].map(b => `<button type="button" class="pref-preset-btn ${b.active ? 'active' : ''}" onclick="window.setColorModalSlotTierPref(${slotIdx}, 1, '${b.id}', '${base}')">${escapeHtml(b.label)}</button>`).join('');

            const tier2BtnsHtml = [
                { id: '', label: '无', active: hero2 === '', disabled: false },
                { id: '1', label: '从1', active: hero2 === '1', disabled: hero1 === '1' },
                { id: '2', label: '从2', active: hero2 === '2', disabled: hero1 === '2' },
                { id: '3', label: '从3', active: hero2 === '3', disabled: hero1 === '3' }
            ].map(b => `<button type="button" class="pref-preset-btn ${b.active ? 'active' : ''} ${b.disabled ? 'disabled' : ''}" ${b.disabled ? 'disabled' : ''} onclick="window.setColorModalSlotTierPref(${slotIdx}, 2, '${b.id}', '${base}')">${escapeHtml(b.label)}</button>`).join('');

            html += `
                <div class="attack-slot-box">
                    <div class="attack-slot-header">
                        <span class="attack-slot-title">🎨 第 ${slotNum} 位：${colorName}</span>
                        <div style="display:flex; align-items:center; gap:8px;">
                            <input type="text" class="pref-custom-token-input" value="${escapeHtml(norm)}" oninput="window.setAttackSlotPref(${slotIdx}, this.value)" title="自定义 DSL 指令代码">
                            <div class="attack-mini-cards">${badgeHtml}</div>
                        </div>
                    </div>
                    <div class="attack-slot-hint">优先锁定<b>${colorName}</b>，可分别指定第一优先从者与第二优先从者：</div>
                    <div style="display:flex; flex-direction:column; gap:6px; margin-top:6px;">
                        <div style="display:flex; align-items:center; gap:8px;">
                            <span class="pref-tier-label" style="font-weight:700;">首选</span>
                            <div class="pref-presets-row" style="margin:0;">
                                ${tier1BtnsHtml}
                            </div>
                        </div>
                        <div style="display:flex; align-items:center; gap:8px; ${hero1 ? '' : 'opacity:0.45; pointer-events:none;'}">
                            <span class="pref-tier-label" style="font-weight:700;">次选</span>
                            <div class="pref-presets-row" style="margin:0;">
                                ${tier2BtnsHtml}
                            </div>
                        </div>
                    </div>
                </div>
            `;
        } else {
            html += `
                <div class="attack-slot-box disabled-slot">
                    <div class="attack-slot-header">
                        <span class="attack-slot-title">第 ${slotNum} 位：未选卡</span>
                    </div>
                    <div class="attack-slot-hint">未设置卡牌，请先在控制台选择卡牌。</div>
                </div>
            `;
        }
    });

    body.innerHTML = html;

    const previewEl = $('attackPriorityPreviewDsl');
    if (previewEl) {
        previewEl.textContent = `a${currentAttackModalSlots.join(', ')}`;
    }
}

export function setColorModalSlotTierPref(slotIdx, tier, heroNum, base) {
    const curToken = String(currentAttackModalSlots[slotIdx] || base).trim().toUpperCase();
    const heroPart = curToken.slice(base.length);
    let hero1 = heroPart[0] || '';
    let hero2 = heroPart[1] || '';

    if (tier === 1) {
        if (!heroNum || hero1 === heroNum) {
            hero1 = '';
            hero2 = '';
        } else {
            hero1 = heroNum;
            if (hero2 === hero1) hero2 = '';
        }
    } else if (tier === 2) {
        if (!heroNum || hero2 === heroNum) {
            hero2 = '';
        } else if (heroNum !== hero1) {
            hero2 = heroNum;
        }
    }

    let newToken = base;
    if (hero1) {
        newToken += hero1;
        if (hero2) newToken += hero2;
    }

    setAttackSlotPref(slotIdx, newToken);
}

export function setAttackSlotPref(slotIdx, token) {
    if (slotIdx >= 0 && slotIdx < currentAttackModalSlots.length) {
        currentAttackModalSlots[slotIdx] = String(token || '').trim().toUpperCase();
        renderAttackPriorityModalBody();
    }
}

export function saveAttackPriorityModal() {
    const waveIdx = currentAttackModalWave;
    const rounds = getCurSchemeRounds();
    if (rounds[waveIdx]) {
        rounds[waveIdx].attack = [...currentAttackModalSlots];
        commitChanges();
        if (typeof window.setRoundAttackDOM === 'function') {
            window.setRoundAttackDOM(waveIdx, currentAttackModalSlots);
        }
        if (typeof window.syncPendingAttackCards === 'function') {
            window.syncPendingAttackCards(currentAttackModalSlots);
        }
        if (typeof window.updateAttackPaletteHighlight === 'function') {
            window.updateAttackPaletteHighlight(currentAttackModalSlots);
        }
        if (typeof window.renderConfigPreview === 'function') {
            window.renderConfigPreview();
        }
        triggerUpdate({ renderBoardOnly: true });
        toast(formatText(TEXT_CONFIG.palette.attackUpdatedToast, {
            wave: waveIdx + 1,
            cards: currentAttackModalSlots.join(' + ')
        }));
    }
    closeModal();
}

// ==================== 卡牌专属内联偏好气泡浮层 (Popover) ====================
let currentPopoverBaseCode = null;

export function closeCardPrefPopover() {
    const pop = $('attackPrefPopover');
    if (pop) {
        pop.classList.remove('show');
    }
    currentPopoverBaseCode = null;
}

export function openCardPrefPopover(baseCode, anchorEl) {
    if (!anchorEl || !baseCode) return;
    const pop = $('attackPrefPopover');
    if (!pop) return;

    // 确保弹窗内部点击不会冒泡被外部全局点击误识别并关闭
    pop.onclick = (e) => {
        e.stopPropagation();
    };

    currentPopoverBaseCode = baseCode;

    // 收集属于当前 baseCode 的所有已选 slot 索引及 token
    const slots = [];
    if (typeof window.getPendingAttackSlots === 'function') {
        const pSlots = window.getPendingAttackSlots();
        pSlots.forEach((token, idx) => {
            if (token && getBaseCardCode(token) === baseCode) {
                slots.push({ idx, token });
            }
        });
    }

    if (slots.length === 0) {
        closeCardPrefPopover();
        return;
    }

    renderCardPrefPopoverContent(baseCode, slots);

    // 计算定位
    pop.style.visibility = 'hidden';
    pop.classList.add('show');

    const rect = anchorEl.getBoundingClientRect();
    const popHeight = pop.offsetHeight || 160;
    const popWidth = pop.offsetWidth || 380;

    let left = rect.left + (rect.width / 2) - (popWidth / 2);
    if (left < 10) left = 10;
    if (left + popWidth > window.innerWidth - 10) {
        left = window.innerWidth - popWidth - 10;
    }

    let top = rect.bottom + 6;
    if (top + popHeight > window.innerHeight - 10) {
        top = Math.max(10, rect.top - popHeight - 6);
    }

    pop.style.left = `${Math.round(left)}px`;
    pop.style.top = `${Math.round(top)}px`;
    pop.style.visibility = 'visible';
}

// 规范化序列节点：任意兜底通配符 * 固定置于序列最末尾；新增其他动作时自动保持兜底在最后
export function normalizeSequenceAtoms(atoms) {
    if (!atoms || !atoms.length) return [];
    const normalAtoms = atoms.filter(a => !a.isWildcard);
    const hasWildcard = atoms.some(a => a.isWildcard);
    const mustCrit = atoms.mustCrit ?? atoms.some(a => a.mustCrit);

    let res = [];
    if (hasWildcard) {
        if (normalAtoms.length > 0) {
            res = [...normalAtoms, { isWildcard: true, hero: 0, color: '', mustCrit: false, base: '*' }];
        } else {
            res = [{ isWildcard: true, hero: 0, color: '', mustCrit: false, base: '*' }];
        }
    } else {
        res = normalAtoms;
    }
    res.mustCrit = mustCrit;
    return res;
}

export function parseCardPrefSequence(tokenStr, fallbackBaseCode) {
    if (!tokenStr || !String(tokenStr).trim()) {
        tokenStr = fallbackBaseCode || 'H1';
    }
    const fullStr = String(tokenStr).trim().toUpperCase();
    const rawTokens = fullStr.split('>').map(s => s.trim()).filter(Boolean);
    if (!rawTokens.length) {
        rawTokens.push(String(fallbackBaseCode || 'H1').trim().toUpperCase());
    }

    // 必爆为优先序列的全局属性：序列中只要有 ! 标识，整条序列均开启必爆
    const isMustCrit = fullStr.startsWith('!') || rawTokens.some(r => r.endsWith('!'));

    let atoms = rawTokens.map(raw => {
        let base = raw;
        if (base.startsWith('!')) base = base.slice(1);
        if (base.endsWith('!')) base = base.slice(0, -1);

        let hero = 0;
        let color = '';
        let isWildcard = false;

        if (base === '*') {
            isWildcard = true;
        } else if (base.startsWith('H')) {
            hero = parseInt(base[1], 10) || 1;
            color = base.slice(2);
            if (!['B', 'A', 'Q'].includes(color)) color = '';
        } else if (['B', 'A', 'Q'].includes(base)) {
            color = base;
        } else if (/^[BAQ][123]+$/.test(base)) {
            color = base[0];
            hero = parseInt(base[1], 10) || 0;
        }

        return { raw, base, hero, color, isWildcard, mustCrit: isMustCrit };
    });

    atoms = normalizeSequenceAtoms(atoms);
    atoms.mustCrit = isMustCrit;
    return atoms;
}

export function serializeCardPrefSequence(atoms, forceMustCrit) {
    if (!atoms || !atoms.length) return '';
    const isCrit = (forceMustCrit !== undefined) ? !!forceMustCrit : (atoms.mustCrit || atoms.some(a => a.mustCrit));
    return atoms.map(a => {
        let code = '';
        if (a.isWildcard) {
            code = '*';
        } else if (a.hero > 0) {
            code = `H${a.hero}${a.color || ''}`;
        } else if (a.color) {
            code = a.color;
        } else {
            code = a.base || '*';
        }
        // 若整条序列开启必爆，非兜底通配符 * 的动作均要求必爆
        if (isCrit && !a.isWildcard) {
            return `${code}!`;
        }
        return code;
    }).join('>');
}

export function getAtomDisplayLabel(atom) {
    if (atom.isWildcard) return '任意';
    let hText = atom.hero > 0 ? `从${atom.hero}` : '';
    let cText = '';
    if (atom.color === 'B') cText = '红';
    else if (atom.color === 'A') cText = '蓝';
    else if (atom.color === 'Q') cText = '绿';
    else cText = '无';

    if (hText && cText) {
        return `${hText}·${cText}`;
    } else if (hText) {
        return `${hText}·无`;
    } else if (cText && cText !== '无') {
        return `${cText}卡`;
    }
    return atom.base || '卡';
}

// FGO 指令纹章 (Command Crest) 图标体系：默认态 (空白刻印槽位) vs 定制态 (已刻印纹章 ❖)
export const CREST_SVG_DEFAULT = `<svg class="pref-crest-icon" viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linejoin="round"><polygon points="8,1.5 14.5,8 8,14.5 1.5,8" /><circle cx="8" cy="8" r="1.1" fill="currentColor" stroke="none" /></svg>`;

export const CREST_SVG_ACTIVE = `<span class="pref-crest-glyph" aria-hidden="true">❖</span>`;

// 生成偏好触发器悬停 Tooltip 摘要
export function getCardPrefSummaryTooltip(baseCode, list) {
    if (!list || !list.length) return '点击定制该卡顺位偏好 (默认)';
    const hasCustomPref = list.some(item => item.fullCode && item.fullCode !== baseCode);
    if (!hasCustomPref) {
        return '点击定制该卡顺位偏好 (默认)';
    }
    const seqLabels = {
        1: TEXT_CONFIG?.palette?.seqLabel1 || '一',
        2: TEXT_CONFIG?.palette?.seqLabel2 || '二',
        3: TEXT_CONFIG?.palette?.seqLabel3 || '三'
    };
    const descParts = list.map(item => {
        const sText = seqLabels[item.seq] || String(item.seq);
        const code = item.fullCode || baseCode;
        if (code === baseCode) return `顺位【${sText}】: 默认`;
        const atoms = parseCardPrefSequence(code, baseCode);
        const seqStr = atoms.map(a => getAtomDisplayLabel(a) + (a.mustCrit && !a.isWildcard ? '★' : '')).join(' ► ');
        return `顺位【${sText}】: ${seqStr}`;
    });
    return `已定制偏好 (${descParts.join('; ')}) - 点击修改`;
}

let currentEditingSlotIdx = 0;

export function renderCardPrefPopoverContent(baseCode, slots, activeSlotIdx) {
    const pop = $('attackPrefPopover');
    if (!pop || !slots || !slots.length) return;

    if (activeSlotIdx !== undefined && slots.some(s => s.idx === activeSlotIdx)) {
        currentEditingSlotIdx = activeSlotIdx;
    } else if (!slots.some(s => s.idx === currentEditingSlotIdx)) {
        currentEditingSlotIdx = slots[0].idx;
    }

    const currentSlotItem = slots.find(s => s.idx === currentEditingSlotIdx) || slots[0];
    const slotIdx = currentSlotItem.idx;
    const currentToken = currentSlotItem.token || baseCode;
    const atoms = parseCardPrefSequence(currentToken, baseCode);

    const isColor = ['B', 'A', 'Q'].includes(baseCode);
    const isHero = /^H[123]$/.test(baseCode);
    const heroNum = isHero ? (parseInt(baseCode[1], 10) || 1) : 1;
    const colorName = baseCode === 'B' ? '红卡' : (baseCode === 'A' ? '蓝卡' : '绿卡');

    const seqLabels = {
        1: TEXT_CONFIG.palette?.seqLabel1 || '①',
        2: TEXT_CONFIG.palette?.seqLabel2 || '②',
        3: TEXT_CONFIG.palette?.seqLabel3 || '③'
    };

    // 标题与槽位切换
    const cardBadgeHtml = formatAttackCardsBadgesHtml([baseCode]);
    let titleSlotHtml = '';
    if (slots.length > 1) {
        titleSlotHtml = `
            <span>偏好定制</span>
            <div class="pref-slot-tabs">
                ${slots.map(s => {
                    const sNum = s.idx + 1;
                    const sText = seqLabels[sNum] || String(sNum);
                    return `<button type="button" class="pref-slot-tab ${s.idx === slotIdx ? 'active' : ''}" onclick="window.switchCardPrefSlot('${baseCode}', ${s.idx})">顺位 ${sText}</button>`;
                }).join('')}
            </div>
        `;
    } else {
        const sNum = slotIdx + 1;
        const sText = seqLabels[sNum] || String(sNum);
        titleSlotHtml = `<span>顺位 ${sText} 偏好定制</span>`;
    }

    // 1. 上方流水线与控制条 (无高亮，统一简洁展示，必爆统一由工具栏控制)
    const isMustCrit = atoms.mustCrit ?? atoms.some(a => a.mustCrit);
    const pipelineHtml = `
        <div class="pref-pipeline-box">
            <div class="pref-pipeline-nodes">
                ${atoms.map((atom, idx) => {
                    const num = idx + 1;
                    const label = getAtomDisplayLabel(atom);
                    const arrow = idx > 0 ? '<span class="pref-pipeline-arrow">►</span>' : '';
                    return `
                        ${arrow}
                        <div class="pref-pipeline-node" data-node-idx="${idx}">
                            <span class="node-idx">${num}</span>
                            <span class="node-label">${escapeHtml(label)}</span>
                            <button type="button" class="node-del-btn" onclick="event.stopPropagation(); window.removeCardPrefNode(${slotIdx}, ${idx}, '${baseCode}')" title="删除该节点">✕</button>
                        </div>
                    `;
                }).join('')}
            </div>
        </div>
        <div class="pref-toolbar-row">
            <button type="button" class="pref-clear-btn" onclick="window.clearCardPrefSequence(${slotIdx}, '${baseCode}')" title="清空恢复默认">清空</button>
            <label class="pref-crit-toggle" title="勾选后该优先序列中的所有动作均要求100%暴击">
                <input type="checkbox" id="prefMustCritToggle" ${isMustCrit ? 'checked' : ''} onchange="window.toggleCardPrefGlobalCrit(${slotIdx}, this.checked, '${baseCode}')">
                <span>必爆</span>
            </label>
            <span class="pref-dsl-preview" title="实时 DSL 指令">${escapeHtml(serializeCardPrefSequence(atoms, isMustCrit))}</span>
        </div>
    `;

    // 2. 当前卡编辑首行 (单选 Radio，直接决定第 1 项)
    let curRowHtml = '';
    if (isHero) {
        const curColor = atoms[0]?.color || '';
        curRowHtml = `
            <div class="pref-cur-row">
                <span class="pref-row-label">当前[从${heroNum}]:</span>
                <div class="pref-row-btns">
                    <button type="button" class="pref-preset-btn ${curColor === '' ? 'active' : ''}" onclick="window.setCardPrefFirstItemColor(${slotIdx}, '', '${baseCode}')">无</button>
                    <button type="button" class="pref-preset-btn btn-color-b ${curColor === 'B' ? 'active' : ''}" onclick="window.setCardPrefFirstItemColor(${slotIdx}, 'B', '${baseCode}')">红</button>
                    <button type="button" class="pref-preset-btn btn-color-a ${curColor === 'A' ? 'active' : ''}" onclick="window.setCardPrefFirstItemColor(${slotIdx}, 'A', '${baseCode}')">蓝</button>
                    <button type="button" class="pref-preset-btn btn-color-q ${curColor === 'Q' ? 'active' : ''}" onclick="window.setCardPrefFirstItemColor(${slotIdx}, 'Q', '${baseCode}')">绿</button>
                </div>
            </div>
        `;
    } else if (isColor) {
        const curHero = atoms[0]?.hero || 0;
        curRowHtml = `
            <div class="pref-cur-row">
                <span class="pref-row-label">当前[${colorName}]:</span>
                <div class="pref-row-btns">
                    <button type="button" class="pref-preset-btn ${curHero === 0 ? 'active' : ''}" onclick="window.setCardPrefFirstItemHero(${slotIdx}, 0, '${baseCode}')">无</button>
                    <button type="button" class="pref-preset-btn ${curHero === 1 ? 'active' : ''}" onclick="window.setCardPrefFirstItemHero(${slotIdx}, 1, '${baseCode}')">从1</button>
                    <button type="button" class="pref-preset-btn ${curHero === 2 ? 'active' : ''}" onclick="window.setCardPrefFirstItemHero(${slotIdx}, 2, '${baseCode}')">从2</button>
                    <button type="button" class="pref-preset-btn ${curHero === 3 ? 'active' : ''}" onclick="window.setCardPrefFirstItemHero(${slotIdx}, 3, '${baseCode}')">从3</button>
                </div>
            </div>
        `;
    }

    // 3. 追加优先级序列行
    const hasWildcard = atoms.some(a => a.isWildcard);
    const appendHtml = `
        <div class="pref-append-section">
            <div class="pref-append-row">
                <span class="pref-row-label">从1:</span>
                <div class="pref-row-btns">
                    <button type="button" class="pref-preset-btn" onclick="window.appendCardPrefRule(${slotIdx}, 1, '', '${baseCode}')">无</button>
                    <button type="button" class="pref-preset-btn btn-color-b" onclick="window.appendCardPrefRule(${slotIdx}, 1, 'B', '${baseCode}')">红</button>
                    <button type="button" class="pref-preset-btn btn-color-a" onclick="window.appendCardPrefRule(${slotIdx}, 1, 'A', '${baseCode}')">蓝</button>
                    <button type="button" class="pref-preset-btn btn-color-q" onclick="window.appendCardPrefRule(${slotIdx}, 1, 'Q', '${baseCode}')">绿</button>
                </div>
            </div>
            <div class="pref-append-row">
                <span class="pref-row-label">从2:</span>
                <div class="pref-row-btns">
                    <button type="button" class="pref-preset-btn" onclick="window.appendCardPrefRule(${slotIdx}, 2, '', '${baseCode}')">无</button>
                    <button type="button" class="pref-preset-btn btn-color-b" onclick="window.appendCardPrefRule(${slotIdx}, 2, 'B', '${baseCode}')">红</button>
                    <button type="button" class="pref-preset-btn btn-color-a" onclick="window.appendCardPrefRule(${slotIdx}, 2, 'A', '${baseCode}')">蓝</button>
                    <button type="button" class="pref-preset-btn btn-color-q" onclick="window.appendCardPrefRule(${slotIdx}, 2, 'Q', '${baseCode}')">绿</button>
                </div>
            </div>
            <div class="pref-append-row">
                <span class="pref-row-label">从3:</span>
                <div class="pref-row-btns">
                    <button type="button" class="pref-preset-btn" onclick="window.appendCardPrefRule(${slotIdx}, 3, '', '${baseCode}')">无</button>
                    <button type="button" class="pref-preset-btn btn-color-b" onclick="window.appendCardPrefRule(${slotIdx}, 3, 'B', '${baseCode}')">红</button>
                    <button type="button" class="pref-preset-btn btn-color-a" onclick="window.appendCardPrefRule(${slotIdx}, 3, 'A', '${baseCode}')">蓝</button>
                    <button type="button" class="pref-preset-btn btn-color-q" onclick="window.appendCardPrefRule(${slotIdx}, 3, 'Q', '${baseCode}')">绿</button>
                </div>
            </div>
            <div class="pref-append-row">
                <span class="pref-row-label">色卡:</span>
                <div class="pref-row-btns">
                    <button type="button" class="pref-preset-btn btn-color-b" onclick="window.appendCardPrefRule(${slotIdx}, 0, 'B', '${baseCode}')">红</button>
                    <button type="button" class="pref-preset-btn btn-color-a" onclick="window.appendCardPrefRule(${slotIdx}, 0, 'A', '${baseCode}')">蓝</button>
                    <button type="button" class="pref-preset-btn btn-color-q" onclick="window.appendCardPrefRule(${slotIdx}, 0, 'Q', '${baseCode}')">绿</button>
                </div>
            </div>
            <div class="pref-append-row">
                <span class="pref-row-label">兜底:</span>
                <div class="pref-row-btns">
                    <button type="button" class="pref-preset-btn btn-wildcard ${hasWildcard ? 'active' : ''}" onclick="window.appendCardPrefRule(${slotIdx}, 0, '*', '${baseCode}')" title="${hasWildcard ? '已添加兜底（固定在序列最末尾，再次点击可移除）' : '添加任意手牌兜底（固定在序列最末尾）'}">${hasWildcard ? '✓ 任意 (*)' : '任意 (*)'}</button>
                </div>
            </div>
        </div>
    `;

    pop.innerHTML = `
        <div class="pref-popover-header">
            <div class="pref-popover-title">
                ${cardBadgeHtml}
                ${titleSlotHtml}
            </div>
            <button type="button" class="pref-popover-close" onclick="window.closeCardPrefPopover()" title="关闭">✕</button>
        </div>
        <div class="pref-popover-body">
            ${pipelineHtml}
            <div class="pref-popover-divider"></div>
            ${curRowHtml}
            <div class="pref-popover-divider"></div>
            ${appendHtml}
        </div>
    `;
}

export function switchCardPrefSlot(baseCode, slotIdx) {
    currentEditingSlotIdx = slotIdx;
    const slots = [];
    if (typeof window.getPendingAttackSlots === 'function') {
        const pSlots = window.getPendingAttackSlots();
        pSlots.forEach((token, idx) => {
            if (token && getBaseCardCode(token) === baseCode) {
                slots.push({ idx, token });
            }
        });
    }
    renderCardPrefPopoverContent(baseCode, slots, slotIdx);
}

export function toggleCardPrefGlobalCrit(slotIdx, isChecked, baseCode) {
    let curToken = '';
    if (typeof window.getPendingAttackSlots === 'function') {
        curToken = window.getPendingAttackSlots()[slotIdx] || baseCode;
    }
    const atoms = parseCardPrefSequence(curToken, baseCode);
    atoms.mustCrit = isChecked;
    atoms.forEach(a => a.mustCrit = isChecked);
    const newToken = serializeCardPrefSequence(atoms, isChecked);
    setPopoverSlotPref(slotIdx, newToken, baseCode, slotIdx);
}

export function setCardPrefFirstItemColor(slotIdx, colorCode, baseCode) {
    let curToken = '';
    if (typeof window.getPendingAttackSlots === 'function') {
        curToken = window.getPendingAttackSlots()[slotIdx] || baseCode;
    }
    let atoms = parseCardPrefSequence(curToken, baseCode);
    const isChecked = atoms.mustCrit ?? atoms.some(a => a.mustCrit);
    const heroNum = baseCode.startsWith('H') ? (parseInt(baseCode[1], 10) || 1) : 1;

    if (!atoms.length) {
        atoms.push({ hero: heroNum, color: colorCode, mustCrit: isChecked, isWildcard: false, base: '' });
    } else {
        atoms[0].hero = heroNum;
        atoms[0].color = colorCode;
        atoms[0].isWildcard = false;
        atoms[0].mustCrit = isChecked;
    }
    atoms = normalizeSequenceAtoms(atoms);
    const newToken = serializeCardPrefSequence(atoms, isChecked);
    setPopoverSlotPref(slotIdx, newToken, baseCode, slotIdx);
}

export function setCardPrefFirstItemHero(slotIdx, heroNum, baseCode) {
    let curToken = '';
    if (typeof window.getPendingAttackSlots === 'function') {
        curToken = window.getPendingAttackSlots()[slotIdx] || baseCode;
    }
    let atoms = parseCardPrefSequence(curToken, baseCode);
    const isChecked = atoms.mustCrit ?? atoms.some(a => a.mustCrit);
    const colorChar = ['B', 'A', 'Q'].includes(baseCode) ? baseCode : '';

    if (!atoms.length) {
        atoms.push({ hero: heroNum, color: colorChar, mustCrit: isChecked, isWildcard: false, base: '' });
    } else {
        atoms[0].hero = heroNum;
        atoms[0].color = colorChar;
        atoms[0].isWildcard = false;
        atoms[0].mustCrit = isChecked;
    }
    atoms = normalizeSequenceAtoms(atoms);
    const newToken = serializeCardPrefSequence(atoms, isChecked);
    setPopoverSlotPref(slotIdx, newToken, baseCode, slotIdx);
}

export function appendCardPrefRule(slotIdx, hero, color, baseCode) {
    let curToken = '';
    if (typeof window.getPendingAttackSlots === 'function') {
        curToken = window.getPendingAttackSlots()[slotIdx] || baseCode;
    }
    let atoms = parseCardPrefSequence(curToken, baseCode);
    const isChecked = atoms.mustCrit ?? atoms.some(a => a.mustCrit);

    if (color === '*') {
        const hasWildcard = atoms.some(a => a.isWildcard);
        if (hasWildcard) {
            // 已有兜底时再次点击，可便捷切换移除兜底
            atoms = atoms.filter(a => !a.isWildcard);
            if (!atoms.length) {
                const defaultHero = baseCode.startsWith('H') ? (parseInt(baseCode[1], 10) || 1) : 0;
                const defaultColor = ['B', 'A', 'Q'].includes(baseCode) ? baseCode : '';
                atoms.push({ hero: defaultHero, color: defaultColor, mustCrit: false, isWildcard: false, base: '' });
            }
        } else {
            atoms.push({ isWildcard: true, hero: 0, color: '', mustCrit: false, base: '*' });
        }
    } else {
        // 添加其他具体动作时，自动追加；若序列中已有兜底，normalizeSequenceAtoms 会自动将兜底固定在末尾
        atoms.push({ isWildcard: false, hero: hero, color: color, mustCrit: isChecked, base: '' });
    }

    atoms = normalizeSequenceAtoms(atoms);
    const newToken = serializeCardPrefSequence(atoms, isChecked);
    setPopoverSlotPref(slotIdx, newToken, baseCode, slotIdx);
}

export function removeCardPrefNode(slotIdx, nodeIdx, baseCode) {
    let curToken = '';
    if (typeof window.getPendingAttackSlots === 'function') {
        curToken = window.getPendingAttackSlots()[slotIdx] || baseCode;
    }
    let atoms = parseCardPrefSequence(curToken, baseCode);
    const isChecked = atoms.mustCrit ?? atoms.some(a => a.mustCrit);
    if (atoms.length > 1) {
        atoms.splice(nodeIdx, 1);
    } else {
        const defaultHero = baseCode.startsWith('H') ? (parseInt(baseCode[1], 10) || 1) : 0;
        const defaultColor = ['B', 'A', 'Q'].includes(baseCode) ? baseCode : '';
        atoms[0] = { hero: defaultHero, color: defaultColor, mustCrit: false, isWildcard: false, base: '' };
    }
    atoms = normalizeSequenceAtoms(atoms);
    const newToken = serializeCardPrefSequence(atoms, isChecked);
    setPopoverSlotPref(slotIdx, newToken, baseCode, slotIdx);
}

export function toggleCardPrefNodeCrit(slotIdx, nodeIdx, baseCode) {
    let curToken = '';
    if (typeof window.getPendingAttackSlots === 'function') {
        curToken = window.getPendingAttackSlots()[slotIdx] || baseCode;
    }
    const atoms = parseCardPrefSequence(curToken, baseCode);
    if (atoms[nodeIdx] && !atoms[nodeIdx].isWildcard) {
        atoms[nodeIdx].mustCrit = !atoms[nodeIdx].mustCrit;
    }
    const newToken = serializeCardPrefSequence(atoms);
    setPopoverSlotPref(slotIdx, newToken, baseCode, slotIdx);
}

export function clearCardPrefSequence(slotIdx, baseCode) {
    const defaultHero = baseCode.startsWith('H') ? (parseInt(baseCode[1], 10) || 1) : 0;
    const defaultColor = ['B', 'A', 'Q'].includes(baseCode) ? baseCode : '';
    const atoms = [{ hero: defaultHero, color: defaultColor, mustCrit: false, isWildcard: false }];
    const newToken = serializeCardPrefSequence(atoms);
    setPopoverSlotPref(slotIdx, newToken, baseCode, slotIdx);
}

export function setPopoverSlotPref(slotIdx, token, baseCode, activeSlotIdx) {
    token = String(token || '').trim().toUpperCase();
    if (typeof window.setPendingAttackSlot === 'function') {
        window.setPendingAttackSlot(slotIdx, token);
    }

    if (typeof window.getPendingAttackSlots === 'function') {
        const curSlots = window.getPendingAttackSlots();
        const activeCards = curSlots.filter(Boolean);
        if (activeCards.length > 0 && typeof window.setRoundAttackDOM === 'function') {
            window.setRoundAttackDOM(appState.curRoundIdx, curSlots);
        }
        if (typeof window.renderPendingAttackBadges === 'function') {
            window.renderPendingAttackBadges();
        }
        if (typeof window.renderConfigPreview === 'function') {
            window.renderConfigPreview();
        }
    }

    // 重新收集当前 baseCode 的所有槽位
    const slots = [];
    if (typeof window.getPendingAttackSlots === 'function') {
        const pSlots = window.getPendingAttackSlots();
        pSlots.forEach((t, idx) => {
            if (t && getBaseCardCode(t) === baseCode) {
                slots.push({ idx, token: t });
            }
        });
    }

    if (slots.length > 0) {
        renderCardPrefPopoverContent(baseCode, slots, activeSlotIdx !== undefined ? activeSlotIdx : slotIdx);
    } else {
        closeCardPrefPopover();
    }
}

export function setColorSlotTierPref(slotIdx, tier, heroNum, baseCode) {}

if (typeof window !== 'undefined') {
    window.switchCardPrefSlot = switchCardPrefSlot;
    window.toggleCardPrefGlobalCrit = toggleCardPrefGlobalCrit;
    window.setCardPrefFirstItemColor = setCardPrefFirstItemColor;
    window.setCardPrefFirstItemHero = setCardPrefFirstItemHero;
    window.appendCardPrefRule = appendCardPrefRule;
    window.removeCardPrefNode = removeCardPrefNode;
    window.toggleCardPrefNodeCrit = toggleCardPrefNodeCrit;
    window.clearCardPrefSequence = clearCardPrefSequence;
    window.setPopoverSlotPref = setPopoverSlotPref;
    window.setColorSlotTierPref = setColorSlotTierPref;
    window.setColorModalSlotTierPref = setColorModalSlotTierPref;
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
                name: '',
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

