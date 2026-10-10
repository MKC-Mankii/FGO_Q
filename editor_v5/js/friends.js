// ==========================================================================
// 管理助战 (Friend Servant Management) 业务逻辑模块
// ==========================================================================

import { $, toast, showConfirmModal } from './api.js';
import { TEXT_CONFIG } from './text_config.js';

// 系统推荐初始预置从者备份（供用户误删后一键补全恢复）
export const DEFAULT_BUILTIN_FRIENDS = [
    {
        key: "aobao",
        name: "奥伯龙",
        shortLabel: "奥伯龙",
        builtin: true,
        images: ["friendAobao1.png", "friendAobao2.png", "friendAobao3.png", "friendAobao5.png"],
        description: "70充能群充核心拐"
    },
    {
        key: "aobaoshan",
        name: "奥伯龙+善",
        shortLabel: "奥伯龙+善",
        builtin: true,
        images: ["friendAobao3Shan.png"],
        description: "善阵营奥伯龙"
    },
    {
        key: "cdai",
        name: "术呆",
        shortLabel: "术呆",
        builtin: true,
        images: ["friendCDai.png", "friendCDai2.png", "friendCDai3.png"],
        description: "蓝卡核心拐"
    },
    {
        key: "daoman",
        name: "道满",
        shortLabel: "道满",
        builtin: true,
        images: ["friendDaoMan.png", "DaoMan.png", "friendDaoMan3.png"],
        description: "混沌恶暴击拐/即死打手"
    },
    {
        key: "cba",
        name: "术斯卡蒂",
        shortLabel: "术斯卡蒂",
        builtin: true,
        images: ["friendCba.png"],
        description: "绿卡核心拐"
    },
    {
        key: "rba",
        name: "尺斯卡蒂",
        shortLabel: "尺斯卡蒂",
        builtin: true,
        images: ["friendRba1.png", "friendRba2.png", "friendRba3.png", "friendRba4.png"],
        description: "尺阶绿卡核心拐"
    },
    {
        key: "rbashan",
        name: "尺斯卡蒂+善",
        shortLabel: "尺斯卡蒂+善",
        builtin: true,
        images: ["friendRba3Shan.png"],
        description: "善阵营尺斯卡蒂"
    },
    {
        key: "shahu",
        name: "杀狐",
        shortLabel: "杀狐",
        builtin: true,
        images: ["friendShaHu1.png", "friendShaHu2.png", "friendShaHu3.png"],
        description: "红卡核心拐"
    },
    {
        key: "shahushan",
        name: "杀狐+善",
        shortLabel: "杀狐+善",
        builtin: true,
        images: ["friendShaHuShan1.png", "friendShaHuShan2.png", "friendShaHuShan3.png"],
        description: "善阵营杀狐"
    },
    {
        key: "princess",
        name: "公主",
        shortLabel: "公主",
        builtin: true,
        images: ["friendPrincess.png", "friendPrincess2.png", "friendPrincess3.png"],
        description: "爱尔奎特·月癌阶光炮打手"
    },
    {
        key: "princess120",
        name: "公主120",
        shortLabel: "公主120",
        builtin: true,
        images: ["friendPrincess120.png", "friendPrincess1202.png", "friendPrincess1203.png"],
        description: "120级满级公主"
    },
    {
        key: "taigong",
        name: "太公望",
        shortLabel: "太公望",
        builtin: true,
        images: ["friendtaigong.png"],
        description: "骑阶绿卡多核辅助/打手"
    },
    {
        key: "sparrow",
        name: "红阎魔",
        shortLabel: "红阎魔",
        builtin: true,
        images: ["friendSparrow.png"],
        description: "剑阶单体打手"
    },
    {
        key: "mary",
        name: "奥尔加玛丽",
        shortLabel: "奥尔加玛丽",
        builtin: true,
        images: ["friendMary1.png", "friendMary2.png", "friendMary3.png"],
        description: "所长打手"
    },
    {
        key: "keli",
        name: "水飞嫂",
        shortLabel: "水飞嫂",
        builtin: true,
        images: ["friendKeli1.png", "friendKeli2.png", "friendKeli3.png"],
        description: "狂阶光炮打手"
    },
    {
        key: "bdai",
        name: "狂呆",
        shortLabel: "狂呆",
        builtin: true,
        images: ["friendBdai1.png", "friendBdai2.png", "friendBdai3.png"],
        description: "狂阶单体打手"
    }
];

export const friendsState = {
    friends: [],
    imageStatus: {},
    selectedKey: null,
    searchKeyword: '',
    isCreating: false,
    editingBuffer: null
};

/**
 * 辅助函数：将 key 转换为首字母大写的 PascalCase（用于文件名规范）
 * 如 "aobao" -> "Aobao", "tiamat" -> "Tiamat", "cdai" -> "CDai"
 */
function toPascalCase(str) {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1);
}

/**
 * 从后端加载助战配置（带多重降级兜底保证）
 */
export async function loadFriends() {
    let data = null;
    try {
        const res = await fetch('/api/friends?t=' + Date.now());
        if (res.ok) {
            data = await res.json();
        }
    } catch (e) {
        console.warn('API /api/friends 请求失败，尝试降级读取静态文件:', e);
    }

    // 降级策略 1：读取静态 /profiles/friends.json
    if (!data || !Array.isArray(data.friends) || data.friends.length === 0) {
        try {
            const fallbackRes = await fetch('/profiles/friends.json?t=' + Date.now());
            if (fallbackRes.ok) {
                const fbData = await fallbackRes.json();
                if (fbData && Array.isArray(fbData.friends)) {
                    data = {
                        status: 'ok',
                        friends: fbData.friends,
                        image_status: {}
                    };
                }
            }
        } catch (fbErr) {
            console.warn('静态 profiles/friends.json 读取失败:', fbErr);
        }
    }

    if (data && Array.isArray(data.friends) && data.friends.length > 0) {
        friendsState.friends = data.friends;
        friendsState.imageStatus = data.image_status || {};
        
        // 同步更新全局 TEXT_CONFIG.supportedFriends
        syncToTextConfig();

        // 渲染左侧名录
        renderFriendsSidebar();

        // 恢复选中项或默认选中第一个
        if (!friendsState.selectedKey && friendsState.friends.length > 0) {
            selectFriend(friendsState.friends[0].key);
        } else if (friendsState.selectedKey) {
            const cur = friendsState.friends.find(f => f.key === friendsState.selectedKey);
            if (cur) {
                selectFriend(cur.key);
            } else if (friendsState.friends.length > 0) {
                selectFriend(friendsState.friends[0].key);
            }
        }
    } else {
        console.error('助战配置加载完全失败');
        toast('⚠️ 助战配置加载异常，请尝试刷新页面');
    }
}

/**
 * 将助战名录同步到 TEXT_CONFIG.supportedFriends，驱动战术编排下拉框
 */
function syncToTextConfig() {
    const list = [
        { key: "", label: "-- 留空 / 无助战 --", shortLabel: "无助战" }
    ];
    friendsState.friends.forEach(f => {
        list.push({
            key: f.key,
            label: `${f.name} (${f.key})`,
            shortLabel: f.shortLabel || f.name
        });
    });
    TEXT_CONFIG.supportedFriends = list;

    // 触发外部更新事件（如战术编排下拉框刷新）
    if (typeof window.onFriendsUpdated === 'function') {
        window.onFriendsUpdated();
    }
}

/**
 * 渲染左侧助战名录
 */
export function renderFriendsSidebar() {
    const listEl = $('friendsListContainer');
    const countEl = $('friendsCountText');
    if (!listEl) return;

    const kw = (friendsState.searchKeyword || '').trim().toLowerCase();
    const filtered = friendsState.friends.filter(f => {
        if (!kw) return true;
        return (f.name && f.name.toLowerCase().includes(kw)) ||
               (f.key && f.key.toLowerCase().includes(kw)) ||
               (f.shortLabel && f.shortLabel.toLowerCase().includes(kw));
    });

    if (countEl) {
        countEl.textContent = `共 ${friendsState.friends.length} 位助战从者`;
    }

    if (filtered.length === 0) {
        listEl.innerHTML = `
            <div style="padding: 24px 12px; text-align: center; color: var(--text-subtle); font-size: 12.5px;">
                ${kw ? '无匹配从者' : '暂无助战数据'}
            </div>
        `;
        return;
    }

    listEl.innerHTML = filtered.map(f => {
        const isActive = (!friendsState.isCreating && friendsState.selectedKey === f.key);
        const images = f.images || [];
        const total = images.length;
        const readyCount = images.filter(img => Boolean(friendsState.imageStatus[img])).length;

        let statusClass = 'ready';
        let statusText = `已标定 ${readyCount}/${total}`;
        if (readyCount === 0) {
            statusClass = 'empty';
            statusText = total > 0 ? `待标定 0/${total}` : '未配槽位';
        } else if (readyCount < total) {
            statusClass = 'partial';
            statusText = `部分标定 ${readyCount}/${total}`;
        }

        // 首张已标定图片作为头像预览
        const firstReadyImg = images.find(img => Boolean(friendsState.imageStatus[img]));
        const avatarHtml = firstReadyImg 
            ? `<img src="images/${firstReadyImg}" alt="${f.name}">`
            : `<span>${(f.shortLabel || f.name || '助').charAt(0)}</span>`;

        return `
            <div class="friend-item ${isActive ? 'active' : ''}" onclick="window.friendsModule.selectFriend('${f.key}')">
                <div class="friend-item-avatar">${avatarHtml}</div>
                <div class="friend-item-info">
                    <div class="friend-item-title">${f.name || f.key}</div>
                    <div class="friend-item-badges">
                        <span class="friend-key-badge">${f.key}</span>
                        <span class="friend-status-badge ${statusClass}">${statusText}</span>
                    </div>
                </div>
            </div>
        `;
    }).join('');
}

/**
 * 选中某个助战从者并进入编辑
 */
export function selectFriend(key) {
    const friend = friendsState.friends.find(f => f.key === key);
    if (!friend) return;

    friendsState.isCreating = false;
    friendsState.selectedKey = key;
    // 深拷贝到编辑缓冲区
    friendsState.editingBuffer = JSON.parse(JSON.stringify(friend));
    if (!Array.isArray(friendsState.editingBuffer.images)) {
        friendsState.editingBuffer.images = [];
    }

    renderFriendsSidebar();
    renderFriendDetail();
}

/**
 * 触发新建助战从者
 */
export function createNewFriend() {
    friendsState.isCreating = true;
    friendsState.selectedKey = null;

    friendsState.editingBuffer = {
        key: '',
        name: '',
        builtin: false,
        images: [],
        description: ''
    };

    renderFriendsSidebar();
    renderFriendDetail();

    // 聚焦于全称输入框
    setTimeout(() => {
        const input = $('friendNameInput');
        if (input) input.focus();
    }, 50);
}

/**
 * 动态刷新删除按钮的保护状态与唯一定制悬浮提示
 * 保护规则：
 * - 匹配特征图全部有图时（total > 0 且 readyCount === total），删除按钮置灰禁用不让点，鼠标悬浮显示保护原因；
 * - 存在待标定槽位或无槽位时，允许点击删除；
 * - 确保仅在外层 wrapper 上存在唯一个 [data-tip] 气泡，清除 button 上的属性，防止多个提示重叠。
 */
export function updateDeleteButtonState() {
    const deleteBtn = $('friendDeleteBtn');
    const deleteTipWrap = $('friendDeleteTipWrap');
    if (!deleteBtn || !deleteTipWrap) return;

    const cur = friendsState.editingBuffer;
    const isCreating = friendsState.isCreating;

    if (!cur || isCreating) {
        deleteTipWrap.style.display = 'none';
        deleteBtn.style.display = 'none';
        return;
    }

    deleteTipWrap.style.display = 'inline-flex';
    deleteBtn.style.display = 'inline-flex';

    // 彻底清除按钮本身的 data-tip 与原生 title，杜绝出现 3 个提示重叠
    deleteBtn.removeAttribute('data-tip');
    deleteBtn.removeAttribute('title');

    const images = Array.isArray(cur.images) ? cur.images : [];
    const total = images.length;
    const readyCount = images.filter(img => Boolean(friendsState.imageStatus[img])).length;

    // 保护规则：匹配特征图全部有图时置灰不让点
    const isAllReady = (total > 0 && readyCount === total);

    if (isAllReady) {
        deleteBtn.disabled = true;
        deleteTipWrap.classList.add('is-disabled');
        deleteTipWrap.setAttribute('data-tip', '特征图齐全，无法删除');
    } else {
        deleteBtn.disabled = false;
        deleteTipWrap.classList.remove('is-disabled');
        deleteTipWrap.setAttribute('data-tip', '删除此助战');
    }
}

/**
 * 渲染右侧编辑详情
 */
export function renderFriendDetail() {
    const headerTitle = $('friendDetailTitle');
    const keyInput = $('friendKeyInput');
    const nameInput = $('friendNameInput');
    const descInput = $('friendDescInput');

    const cur = friendsState.editingBuffer;
    if (!cur) return;

    const isCreating = friendsState.isCreating;

    if (headerTitle) {
        headerTitle.textContent = isCreating 
            ? '➕ 新建助战从者' 
            : `编辑助战: ${cur.name || cur.key} (${cur.key})`;
    }

    if (keyInput) {
        keyInput.value = cur.key || '';
        keyInput.readOnly = !isCreating; // 仅新建时可自定义 key
    }
    if (nameInput) nameInput.value = cur.name || '';
    if (descInput) descInput.value = cur.description || '';

    // 渲染匹配图槽位列表（内部会联动调用 updateDeleteButtonState）
    renderSlotsList();
}

/**
 * 渲染特征匹配图槽位列表
 */
export function renderSlotsList() {
    const container = $('friendSlotsContainer');
    if (!container) return;

    const cur = friendsState.editingBuffer;
    if (!cur) return;

    const images = cur.images || [];

    if (images.length === 0) {
        container.innerHTML = `
            <div style="padding: 16px; border: 1.5px dashed var(--line); border-radius: 8px; text-align: center; color: var(--text-muted); font-size: 12.5px; background: #fafcff;">
                暂无匹配图槽位。请点击下方 <strong>[➕ 添加匹配图槽位]</strong> 新增槽位。
            </div>
        `;
        updateDeleteButtonState();
        return;
    }

    container.innerHTML = images.map((imgName, idx) => {
        const isExists = Boolean(friendsState.imageStatus[imgName]);
        const targetKey = imgName.replace(/\.png$/i, '');

        const thumbHtml = isExists 
            ? `<img src="images/${imgName}?t=${Date.now()}" alt="${imgName}">`
            : `<span class="placeholder">无图</span>`;

        return `
            <div class="friend-slot-row ${isExists ? '' : 'missing'}">
                <div class="friend-slot-index">#${idx + 1}</div>
                <div class="friend-slot-thumb ${isExists ? '' : 'placeholder'}">
                    ${thumbHtml}
                </div>
                <div class="friend-slot-info">
                    <div class="friend-slot-filename">${imgName}</div>
                    <div class="friend-slot-status">
                        ${isExists 
                            ? `<span class="slot-tag ok">✅ 已标定</span>` 
                            : `<span class="slot-tag pending">⏳ 待标定</span>`
                        }
                    </div>
                </div>
                <div class="friend-slot-actions">
                    ${!isExists ? `
                        <button type="button" class="slot-btn calibrate" onclick="window.friendsModule.goToCalibrate('${targetKey}')" data-tip="去标定">
                            📐 去标定
                        </button>
                    ` : `
                        <button type="button" class="slot-btn calibrate" onclick="window.friendsModule.goToCalibrate('${targetKey}')" data-tip="重新标定">
                            🔍 重新校准
                        </button>
                    `}
                    <button type="button" class="slot-btn remove" onclick="window.friendsModule.removeSlot(${idx})" data-tip="移除槽位">
                        🗑️ 移除
                    </button>
                </div>
            </div>
        `;
    }).join('');

    // 渲染完槽位后联动刷新底部删除按钮的保护状态与单一提示
    updateDeleteButtonState();
}

/**
 * 槽位添加：根据 key 自动推导下一个可用编号
 */
export function addSlot() {
    const cur = friendsState.editingBuffer;
    if (!cur) return;

    const baseKey = (cur.key || $('friendKeyInput').value || '').trim();
    if (!baseKey) {
        toast('⚠️ 请先输入英文代号 (Key)，再添加匹配图槽位');
        $('friendKeyInput')?.focus();
        return;
    }

    if (!Array.isArray(cur.images)) {
        cur.images = [];
    }

    // 推导下一个槽位文件名
    // 找出当前已有槽位中最大数字
    let maxIdx = 0;
    cur.images.forEach(img => {
        const match = img.match(/(\d+)\.png$/i);
        if (match) {
            const num = parseInt(match[1], 10);
            if (num > maxIdx) maxIdx = num;
        }
    });

    const nextNum = maxIdx + 1;
    const pascal = toPascalCase(baseKey);
    const newFileName = `friend${pascal}${nextNum}.png`;

    cur.images.push(newFileName);
    renderSlotsList();
    toast(`➕ 已添加槽位: ${newFileName}`);
}

/**
 * 槽位移除
 */
export function removeSlot(index) {
    const cur = friendsState.editingBuffer;
    if (!cur || !cur.images) return;

    const removed = cur.images.splice(index, 1);
    renderSlotsList();
    toast(`🗑️ 已移除槽位: ${removed[0] || ''}`);
}

/**
 * 跳转至屏幕标定裁切或重新校准
 */
export function goToCalibrate(targetKey) {
    if (typeof window.switchEditorView === 'function') {
        window.switchEditorView('calibrate');
        // 等待标定面板渲染后自动选中该 target
        setTimeout(() => {
            if (window.selectCalibrationTargetByKey) {
                window.selectCalibrationTargetByKey(targetKey);
            } else {
                // 兜底：模拟点击对应的 DOM 卡片
                const targetCard = document.querySelector(`[data-target-key="${targetKey}"]`);
                if (targetCard) {
                    targetCard.click();
                    targetCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
                }
            }
        }, 150);
    }
}

/**
 * 保存当前编辑中的助战从者
 */
export async function saveFriend() {
    const cur = friendsState.editingBuffer;
    if (!cur) return;

    const name = ($('friendNameInput')?.value || '').trim();
    const shortLabel = name;
    const desc = ($('friendDescInput')?.value || '').trim();
    let key = friendsState.isCreating 
        ? ($('friendKeyInput')?.value || '').trim().toLowerCase()
        : cur.key;

    if (!key) {
        toast('❌ 英文代号 (Key) 不能为空');
        $('friendKeyInput')?.focus();
        return;
    }
    if (!/^[a-z0-9_]+$/i.test(key)) {
        toast('❌ 英文代号仅支持字母、数字与下划线 (如 tiamat, melusine)');
        $('friendKeyInput')?.focus();
        return;
    }
    if (!name) {
        toast('❌ 从者全称不能为空');
        $('friendNameInput')?.focus();
        return;
    }

    // 检查重复 key
    if (friendsState.isCreating) {
        const exists = friendsState.friends.some(f => f.key.toLowerCase() === key.toLowerCase());
        if (exists) {
            toast(`❌ 英文代号 "${key}" 已存在，请更换！`);
            $('friendKeyInput')?.focus();
            return;
        }
    }

    cur.key = key;
    cur.name = name;
    cur.shortLabel = shortLabel;
    cur.description = desc;

    // 如果是新建，且没有任何槽位，自动补齐默认 3 个槽位
    if (friendsState.isCreating && (!cur.images || cur.images.length === 0)) {
        const pascal = toPascalCase(key);
        cur.images = [
            `friend${pascal}1.png`,
            `friend${pascal}2.png`,
            `friend${pascal}3.png`
        ];
    }

    // 更新到 friendsState.friends 列表
    let newList = [...friendsState.friends];
    if (friendsState.isCreating) {
        newList.push(cur);
    } else {
        const idx = newList.findIndex(f => f.key === cur.key);
        if (idx >= 0) {
            newList[idx] = cur;
        } else {
            newList.push(cur);
        }
    }

    // 提交到后端
    try {
        const res = await fetch('/api/friends', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
            body: JSON.stringify({ friends: newList })
        });
        const result = await res.json();
        if (result && result.success) {
            toast(`✅ 助战【${name}】配置保存成功`);
            friendsState.isCreating = false;
            friendsState.selectedKey = key;
            // 重新拉取以更新状态与 targets 映射
            await loadFriends();
        } else {
            toast(`❌ 保存失败: ${result.message || '未知错误'}`);
        }
    } catch (e) {
        console.error('保存助战失败:', e);
        toast(`❌ 网络或服务端错误: ${e.message}`);
    }
}

/**
 * 删除助战从者
 */
export async function deleteFriend() {
    const cur = friendsState.editingBuffer;
    if (!cur || friendsState.isCreating) return;

    // 保护校验：匹配特征图全部有图时禁止删除
    const images = Array.isArray(cur.images) ? cur.images : [];
    const total = images.length;
    const readyCount = images.filter(img => Boolean(friendsState.imageStatus[img])).length;
    if (total > 0 && readyCount === total) {
        toast('⚠️ 特征图齐全，无法删除');
        return;
    }

    const confirmed = await showConfirmModal({
        title: '🗑️ 删除助战',
        message: `确定删除助战【${cur.name || cur.key}】吗？`,
        okText: '确定删除',
        isDanger: true
    });
    if (!confirmed) return;

    const newList = friendsState.friends.filter(f => f.key !== cur.key);

    try {
        const res = await fetch('/api/friends', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
            body: JSON.stringify({ friends: newList })
        });
        const result = await res.json();
        if (result && result.success) {
            toast(`🗑️ 已删除【${cur.name || cur.key}】`);
            friendsState.selectedKey = null;
            await loadFriends();
        } else {
            toast(`❌ 删除失败: ${result.message || '未知错误'}`);
        }
    } catch (e) {
        toast(`❌ 删除失败: ${e.message}`);
    }
}

/**
 * 补全恢复系统预置从者
 */
export async function restorePresets() {
    const currentKeys = new Set(friendsState.friends.map(f => (f.key || '').toLowerCase()));
    const missingPresets = DEFAULT_BUILTIN_FRIENDS.filter(p => !currentKeys.has(p.key.toLowerCase()));

    if (missingPresets.length === 0) {
        toast('ℹ️ 预设从者已齐全');
        return;
    }

    const confirmed = await showConfirmModal({
        title: '🔄 恢复预设',
        message: '确定恢复缺失的预设助战吗？',
        okText: '恢复预设',
        isDanger: false
    });
    if (!confirmed) return;

    const newList = [...friendsState.friends, ...missingPresets];

    try {
        const res = await fetch('/api/friends', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
            body: JSON.stringify({ friends: newList })
        });
        const result = await res.json();
        if (result && result.success) {
            toast('✅ 已恢复默认预设');
            await loadFriends();
        } else {
            toast(`❌ 恢复失败: ${result.message || '未知错误'}`);
        }
    } catch (e) {
        toast(`❌ 恢复失败: ${e.message}`);
    }
}

// 绑定到 window 对象供 HTML 直接调用
window.friendsModule = {
    loadFriends,
    renderFriendsSidebar,
    selectFriend,
    createNewFriend,
    addSlot,
    removeSlot,
    goToCalibrate,
    saveFriend,
    deleteFriend,
    restorePresets,
    updateDeleteButtonState
};


