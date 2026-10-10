import { appState, setInitialSnapshot } from './state.js';
import { parseConfigFileText, setLastSavedConfigText, generateConfigText, isConfigDirty, commitChanges, getCurSchemeRounds } from './dsl.js';
import { TEXT_CONFIG, formatText } from './text_config.js';

// DOM 简写与提示
export const $ = id => document.getElementById(id);

export const toast = (msg, duration = 2400) => {
    const t = $('toast');
    if (!t) return;
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => t.classList.remove('show'), duration);
};

// 挂载到全局 window 对象供跨模块调用（覆盖浏览器由于 <div id="toast"> 产生的 DOM 元素引用）
try {
    window.toast = toast;
} catch (e) {
    console.warn('Failed to bind window.toast:', e);
}

function getNowTimeString() {
    const d = new Date();
    const pad = n => String(n).padStart(2, '0');
    return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

// 人类友好时长自动进位格式化（如超过 60 秒自动进位为几分几秒，支持天/小时/分/秒）
export function formatDuration(seconds) {
    const s = Math.max(0, Math.floor(Number(seconds) || 0));
    if (s < 60) {
        return `${s}秒`;
    }
    const days = Math.floor(s / 86400);
    const hours = Math.floor((s % 86400) / 3600);
    const minutes = Math.floor((s % 3600) / 60);
    const secs = s % 60;

    let res = '';
    if (days > 0) res += `${days}天`;
    if (hours > 0) res += `${hours}小时`;
    if (minutes > 0 || (hours > 0 && secs > 0)) res += `${minutes}分`;
    if (secs > 0 || (!days && !hours)) res += `${secs}秒`;
    return res;
}

// 统一更新配置同步与就绪状态胶囊 (方案 B：静默模式 —— 正常就绪时自动隐藏，仅异常告警时浮现)
export function updateSyncStatus(type, label, tooltip) {
    const syncStatus = $('syncStatus');
    if (!syncStatus) return;
    syncStatus.className = `sync-status-badge ${type || ''}`.trim();
    syncStatus.textContent = label;
    if (tooltip !== undefined) {
        syncStatus.title = tooltip;
    }

    const isAbnormal = (type === 'error' || type === 'pending' || type === 'warning');
    syncStatus.style.display = isAbnormal ? 'inline-flex' : 'none';
}

// 同步更新保存按钮待保存 (Dirty) 呼吸动效与状态（严格锁定尺寸不变）
export function updateSaveButtonState() {
    const btn = $('saveBtn');
    if (!btn) return;
    if (btn.disabled) return;

    if (isConfigDirty()) {
        if (!btn.classList.contains('has-changes')) {
            btn.classList.add('has-changes');
            btn.title = '当前有未保存的修改 (按 Ctrl + S 或点击保存)';
        }
    } else {
        if (btn.classList.contains('has-changes')) {
            btn.classList.remove('has-changes');
            btn.title = '所有配置已保存并同步';
        }
    }
}

// 请求后端终止本地服务
export async function shutdownServer() {
    const btn = $('shutdownBtn');
    if (btn) btn.disabled = true;

    try {
        await fetch('/api/shutdown', { method: 'POST' });
    } catch (_) {
        // 忽略网络断开
    }

    updateSyncStatus('error', '🛑 服务已关闭', '【本地服务已停止】\n• Python 后端服务已安全退出，端口 8098 已释放\n• 如需继续使用，请双击桌面快捷方式重新启动');
    toast(TEXT_CONFIG.masthead.shutdownDone);
    if (btn) {
        btn.textContent = '已退出';
        btn.style.opacity = '0.5';
    }
}

// 从本地服务加载 Q 配置文件
export async function loadConfigFromBackend(onSuccess) {
    updateSyncStatus('', '⏳ 读取中', '正在从本地磁盘读取配置文件 Q/battle_v5_config.q...');

    try {
        const res = await fetch('/api/config');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        if (data.text) {
            parseConfigFileText(data.text, appState.data);
            const activeGroup = Number(appState.data.runnerSettings?.activeGroup);
            appState.curGroupIdx = (!isNaN(activeGroup) && activeGroup >= 0 && activeGroup < appState.data.groups.length) ? activeGroup : 3;
            const activeGrp = appState.data.groups?.[appState.curGroupIdx];
            const defScheme = activeGrp?.defaultScheme;
            appState.curSchemeIdx = (typeof defScheme === 'number' && defScheme >= 1 && defScheme <= (activeGrp?.schemes?.length || 0)) ? defScheme - 1 : 0;
            appState.curRoundIdx = 0;

            // 预先建立基准文本与初始快照，避免 render() 内部的 renderConfigPreview 误判未保存状态
            getCurSchemeRounds();
            commitChanges();
            const canonicalText = generateConfigText(appState.data);
            setInitialSnapshot(appState.data);
            setLastSavedConfigText(canonicalText);

            const fullPath = data.path || 'Q/battle_v5_config.q';
            const shortPath = fullPath.replace(/\\/g, '/').split('/').slice(-2).join('/');
            const now = getNowTimeString();
            const activeGroupName = appState.data.groups?.[appState.curGroupIdx]?.name || `大组 ${appState.curGroupIdx}`;
            const tooltip = `【本地配置已就绪】\n• 来源文件：${shortPath}\n• 完整路径：${fullPath}\n• 载入时间：${now}\n• 生效战区：${activeGroupName}\n• 状态说明：本地配置已解析就绪，可随时编辑调整`;

            updateSyncStatus('ready', '✅ 配置就绪', tooltip);
            toast(formatText(TEXT_CONFIG.messages.autoLoadSuccess, { path: shortPath }));
            if (typeof onSuccess === 'function') onSuccess();

            // 视图全量渲染完成后再次核实保存按钮状态为干净就绪
            updateSaveButtonState();
        }
    } catch (err) {
        console.warn(TEXT_CONFIG.messages.autoLoadFailWarn, err);
        getCurSchemeRounds();
        commitChanges();
        const fallbackText = generateConfigText(appState.data);
        setInitialSnapshot(appState.data);
        setLastSavedConfigText(fallbackText);
        updateSaveButtonState();
        updateSyncStatus('pending', '⚠️ 本地缓存', '【未连接到后端服务】\n• 无法连接本地 Python 服务 (端口 8098)\n• 当前使用内存初始配置，保存等高级功能受限');
        if (typeof onSuccess === 'function') onSuccess();
    }
}

let adbWatcherTimer = null;
let hasPendingSimulatorSync = false; // 只有发生过“保存时模拟器未连接”才置为 true

export function getPendingSimulatorSync() {
    return hasPendingSimulatorSync;
}

export function setPendingSimulatorSync(val) {
    hasPendingSimulatorSync = Boolean(val);
}

let adbSelectBound = false;
let currentDevicesInfo = [];
let currentSelectedDevice = null;
let isDropdownOpen = false;
let isProbingDevices = false;

const escapeHtml = str => String(str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function populateDeviceSelect(selectEl, devicesInfo, currentDevice) {
    if (!selectEl) return;
    selectEl.innerHTML = '';
    if (!devicesInfo || devicesInfo.length === 0) {
        const opt = document.createElement('option');
        opt.value = '';
        opt.textContent = '未检测到模拟器';
        selectEl.appendChild(opt);
        return;
    }

    devicesInfo.forEach(info => {
        const opt = document.createElement('option');
        opt.value = info.id;
        opt.textContent = info.label;
        if (info.id === currentDevice) {
            opt.selected = true;
        }
        selectEl.appendChild(opt);
    });

    if (currentDevice) {
        selectEl.value = currentDevice;
    }
}

export function renderCustomDeviceDropdown(devicesInfo, activeDevice, isProbing = false) {
    const dropdown = $('adbDeviceDropdown');
    const trigger = $('adbDeviceDropdownTrigger');
    const labelEl = $('adbDeviceDropdownLabel');
    const menu = $('adbDeviceDropdownMenu');
    const statusDot = $('adbStatusDot');
    if (!dropdown || !trigger || !labelEl) return;

    if (isProbing) {
        trigger.classList.add('is-loading');
        if (statusDot) {
            statusDot.className = 'adb-status-dot probing';
        }
        labelEl.textContent = '正在探测模拟器...';
        trigger.title = '正在探测当前运行中的模拟器，请稍候...';
        return;
    }

    trigger.classList.remove('is-loading');
    currentDevicesInfo = Array.isArray(devicesInfo) ? devicesInfo : [];
    currentSelectedDevice = activeDevice || (currentDevicesInfo[0] ? currentDevicesInfo[0].id : null);

    if (currentDevicesInfo.length === 0) {
        trigger.classList.add('is-empty');
        if (statusDot) {
            statusDot.className = 'adb-status-dot offline';
        }
        labelEl.textContent = '未检测到模拟器 (点击探测)';
        trigger.title = '未检测到运行中的模拟器，点击重新探测';

        if (menu) {
            menu.innerHTML = `
                <div class="adb-dropdown-empty">
                    <div style="font-weight:600; margin-bottom:4px; color:#4a5568;">⚠️ 未检测到运行中的模拟器</div>
                    <div class="adb-dropdown-empty-sub">请先打开模拟器，然后再点击此处探测</div>
                </div>
            `;
        }
    } else {
        trigger.classList.remove('is-empty');
        if (statusDot) {
            statusDot.className = 'adb-status-dot online';
        }
        const active = currentDevicesInfo.find(d => d.id === currentSelectedDevice) || currentDevicesInfo[0];
        const displayLabel = active ? (active.label || active.id) : '选择目标模拟器';
        labelEl.textContent = displayLabel;
        trigger.title = `目标模拟器: ${displayLabel} (在线)\n点击重新探测并展开列表`;

        if (menu) {
            menu.innerHTML = '';
            const header = document.createElement('div');
            header.className = 'adb-dropdown-header';
            header.innerHTML = `<span>在线模拟器 (${currentDevicesInfo.length})</span>`;
            menu.appendChild(header);

            currentDevicesInfo.forEach(info => {
                const isSel = (info.id === currentSelectedDevice);
                const item = document.createElement('div');
                item.className = 'adb-dropdown-item' + (isSel ? ' is-selected' : '');
                item.innerHTML = `
                    <span class="adb-status-dot online" style="margin-right: 2px;"></span>
                    <div class="adb-dropdown-item-info">
                        <span class="adb-dropdown-item-title">${escapeHtml(info.label || info.id)}</span>
                        ${info.model ? `<span class="adb-dropdown-item-sub">${escapeHtml(info.type || '模拟器')} · ${escapeHtml(info.model)}</span>` : ''}
                    </div>
                    ${isSel ? '<span class="adb-dropdown-check">✓</span>' : ''}
                `;
                item.onclick = async (e) => {
                    e.stopPropagation();
                    closeDeviceDropdown();
                    if (info.id !== currentSelectedDevice) {
                        await selectAdbDevice(info.id);
                    }
                };
                menu.appendChild(item);
            });
        }
    }
}

export function openDeviceDropdown() {
    const dropdown = $('adbDeviceDropdown');
    const menu = $('adbDeviceDropdownMenu');
    if (!dropdown || !menu) return;
    dropdown.classList.add('is-open');
    menu.style.display = 'block';
    isDropdownOpen = true;
}

export function closeDeviceDropdown() {
    const dropdown = $('adbDeviceDropdown');
    const menu = $('adbDeviceDropdownMenu');
    if (!dropdown || !menu) return;
    dropdown.classList.remove('is-open');
    menu.style.display = 'none';
    isDropdownOpen = false;
}

async function handleDropdownTriggerClick(e) {
    if (e) e.stopPropagation();

    // 如果当前正在探测中，避免重复触发
    if (isProbingDevices) return;

    // 如果下拉菜单当前已展开，点击触发按钮则直接收起
    if (isDropdownOpen) {
        closeDeviceDropdown();
        return;
    }

    // 核心逻辑：点击下拉框时，先探测模拟器，然后再展开当前真实的模拟器列表
    isProbingDevices = true;
    renderCustomDeviceDropdown(currentDevicesInfo, currentSelectedDevice, true);

    try {
        const data = await refreshAdbDevices(true);
        // refreshAdbDevices 内部已经刷新了 currentDevicesInfo / currentSelectedDevice 并调用了 renderCustomDeviceDropdown
        // 探测完成后展开真实的模拟器列表
        openDeviceDropdown();

        const count = (data && data.devices_info) ? data.devices_info.length : 0;
        if (count > 0) {
            toast(`✅ 模拟器探测完成，已发现 ${count} 个模拟器`);
        } else {
            toast('⚠️ 未检测到运行中的模拟器，请确认模拟器已开启');
        }
    } catch (err) {
        console.error('探测模拟器异常:', err);
        toast(`探测模拟器异常: ${err.message}`);
        renderCustomDeviceDropdown(currentDevicesInfo, currentSelectedDevice, false);
    } finally {
        isProbingDevices = false;
    }
}

export async function selectAdbDevice(device) {
    if (!device) return;
    try {
        const res = await fetch('/api/adb/device', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
            body: JSON.stringify({ device })
        });
        const data = await res.json();
        if (data.success && data.status) {
            toast(`📱 已切换模拟器: ${data.status.device_label || data.device}`);
            currentSelectedDevice = data.device;
            renderCustomDeviceDropdown(currentDevicesInfo, currentSelectedDevice);

            const adbSelect = $('adbDeviceSelect');
            const calSelect = $('calDeviceSelect');
            if (adbSelect && adbSelect.value !== data.device) adbSelect.value = data.device;
            if (calSelect && calSelect.value !== data.device) calSelect.value = data.device;

            const indicator = $('adbIndicator');
            if (indicator) {
                indicator.title = `${data.status.message}\n当前设备: ${data.status.device_label || data.device}\n点击可手动同步配置`;
            }

            window.dispatchEvent(new CustomEvent('adb-device-changed', { detail: data.status }));
        } else {
            toast(`切换模拟器失败: ${data.error || '未知错误'}`);
        }
    } catch (e) {
        console.error('Failed to select device:', e);
        toast(`切换模拟器异常: ${e.message}`);
    }
}

let isRefreshingAdbStatus = false;
let lastAdbRefreshTime = 0;

export async function refreshAdbDevices(force = false) {
    const now = Date.now();
    if (isRefreshingAdbStatus) return;
    if (!force && now - lastAdbRefreshTime < 1500) return;
    isRefreshingAdbStatus = true;
    lastAdbRefreshTime = now;

    try {
        const url = force ? '/api/adb/status?refresh=1' : '/api/adb/status';
        const res = await fetch(url);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();

        const indicator = $('adbIndicator');
        const adbSelect = $('adbDeviceSelect');
        const calSelect = $('calDeviceSelect');

        if (data.connected) {
            if (indicator) {
                indicator.className = 'adb-badge connected';
                indicator.textContent = '🟢 在线';
                indicator.title = `${data.message}\nADB路径: ${data.adb_path || ''}\n点击可手动再次同步`;
            }
            currentDevicesInfo = data.devices_info || [];
            currentSelectedDevice = data.device || (currentDevicesInfo[0] ? currentDevicesInfo[0].id : null);
            renderCustomDeviceDropdown(currentDevicesInfo, currentSelectedDevice);

            if (adbSelect) {
                populateDeviceSelect(adbSelect, data.devices_info, currentSelectedDevice);
            }
            if (calSelect) {
                populateDeviceSelect(calSelect, data.devices_info, currentSelectedDevice);
            }
        } else {
            if (indicator) {
                indicator.className = 'adb-badge offline';
                indicator.textContent = '🔴 离线';
                indicator.title = `${data.message || '未检测到模拟器'}\n点击重新检测`;
            }
            currentDevicesInfo = [];
            currentSelectedDevice = null;
            renderCustomDeviceDropdown([], null);
            if (adbSelect) populateDeviceSelect(adbSelect, [], null);
            if (calSelect) populateDeviceSelect(calSelect, [], null);
        }
        return data;
    } catch (e) {
        console.warn('Failed to refresh ADB devices:', e);
    } finally {
        isRefreshingAdbStatus = false;
    }
}

// 检查模拟器 ADB 连接状态，并在“有待补推配置”且“模拟器刚连上”时自动补推
export async function checkAdbStatus(getConfigTextCallback) {
    const indicator = $('adbIndicator');
    const trigger = $('adbDeviceDropdownTrigger');
    const adbSelect = $('adbDeviceSelect');
    const calSelect = $('calDeviceSelect');
    if (!trigger && !indicator) return;

    if (!adbSelectBound) {
        if (trigger) {
            trigger.addEventListener('click', handleDropdownTriggerClick);
        }

        // 点击外部区域或按 Esc 自动关闭下拉菜单
        document.addEventListener('click', (e) => {
            const dropdown = $('adbDeviceDropdown');
            if (dropdown && !dropdown.contains(e.target)) {
                closeDeviceDropdown();
            }
        });
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                closeDeviceDropdown();
            }
        });

        // 兼容原生 select change 事件（若有外部调用）
        if (adbSelect) {
            adbSelect.addEventListener('change', () => {
                selectAdbDevice(adbSelect.value);
            });
        }
        adbSelectBound = true;
    }

    if (calSelect && !calSelect.__refreshBound) {
        calSelect.addEventListener('change', () => {
            selectAdbDevice(calSelect.value);
        });
        calSelect.addEventListener('mouseenter', () => {
            refreshAdbDevices(false);
        });
        calSelect.addEventListener('mousedown', () => {
            refreshAdbDevices(true);
        });
        calSelect.__refreshBound = true;
    }

    try {
        const res = await fetch('/api/adb/status');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        
        if (data.connected) {
            if (indicator) {
                indicator.className = 'adb-badge connected';
                indicator.textContent = '🟢 在线';
                indicator.title = `${data.message}\nADB路径: ${data.adb_path || ''}\n点击可手动再次同步`;
            }

            currentDevicesInfo = data.devices_info || [];
            currentSelectedDevice = data.device || (currentDevicesInfo[0] ? currentDevicesInfo[0].id : null);
            renderCustomDeviceDropdown(currentDevicesInfo, currentSelectedDevice);

            if (adbSelect) {
                populateDeviceSelect(adbSelect, data.devices_info, data.device);
            }
            if (calSelect) {
                populateDeviceSelect(calSelect, data.devices_info, data.device);
            }

            // 核心条件：只有当保存过且此前模拟器未连接（存在待补推标记）时，才自动触发一次补推！
            if (hasPendingSimulatorSync) {
                hasPendingSimulatorSync = false; // 消费待补推标记
                if (typeof getConfigTextCallback === 'function') {
                    const text = getConfigTextCallback();
                    try {
                        const syncRes = await fetch('/api/sync', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json; charset=utf-8' },
                            body: JSON.stringify({ text, device: data.device })
                        });
                        const syncData = await syncRes.json();
                        if (syncData.success) {
                            const now = getNowTimeString();
                            const elapsed = syncData.elapsed_ms != null ? `${syncData.elapsed_ms}ms` : '毫秒级';
                            const tooltip = `【自动补推完成】\n• 连通设备：${data.device}\n• 直推目标：/sdcard/FGO_Q/battle_v5_config.mq\n• 传输耗时：${elapsed}\n• 触发原因：检测到模拟器连线恢复，自动完成挂起的配置同步\n• 补推时间：${now}`;
                            updateSyncStatus('synced', '✅ 已同步', tooltip);
                            toast(`⚡ 模拟器已连接，已自动补推未同步的配置 (${data.device})`);
                        } else {
                            // 补推失败则恢复待补推标记，等待下一次心跳再试
                            hasPendingSimulatorSync = true;
                        }
                    } catch (e) {
                        hasPendingSimulatorSync = true;
                        console.warn('[ADB] 自动补推异常:', e);
                    }
                }
            }
        } else {
            if (indicator) {
                indicator.className = 'adb-badge offline';
                indicator.textContent = '📱 离线';
                indicator.title = `${data.message || '未连接模拟器'}\n每隔 10 秒自动检测重连，点击可立即检测`;
            }
            currentDevicesInfo = [];
            currentSelectedDevice = null;
            renderCustomDeviceDropdown([], null);
            if (adbSelect) {
                populateDeviceSelect(adbSelect, [], null);
            }
            if (calSelect) {
                calSelect.innerHTML = '<option value="">未检测到在线模拟器</option>';
            }
        }
    } catch (_) {
        if (indicator) {
            indicator.className = 'adb-badge offline';
            indicator.textContent = '📱 离线';
            indicator.title = '无法连接本地服务或模拟器，每隔 10 秒自动检测，点击可立即重试';
        }
        currentDevicesInfo = [];
        currentSelectedDevice = null;
        renderCustomDeviceDropdown([], null);
        if (adbSelect) {
            populateDeviceSelect(adbSelect, [], null);
        }
        if (calSelect) {
            calSelect.innerHTML = '<option value="">服务未连接</option>';
        }
    }
}

// 启动 10 秒周期轻量心跳监测与自动补推
export function startAdbAutoWatcher(getConfigTextCallback) {
    if (adbWatcherTimer) clearInterval(adbWatcherTimer);
    // 首次检测
    checkAdbStatus(getConfigTextCallback);
    // 固化为 10 秒轻量心跳探测一次 (消耗近乎为 0)
    adbWatcherTimer = setInterval(() => {
        checkAdbStatus(getConfigTextCallback);
    }, 10000);
}

// 保存配置到本地文件（支持后端自动备份快照与模拟器 ADB 直推）
export async function saveConfigToBackend(configText) {
    const btn = $('saveBtn');
    const originalText = btn ? btn.textContent : '';

    if (btn) {
        btn.disabled = true;
        btn.textContent = TEXT_CONFIG.masthead.btnSaving;
        btn.classList.remove('has-changes');
    }

    try {
        const res = await fetch('/api/save', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
            body: JSON.stringify({ text: configText })
        });
        const data = await res.json();
        if (data.success) {
            setInitialSnapshot(appState.data);
            setLastSavedConfigText(configText);
            const savedPath = (data.path || '').replace(/\\/g, '/').split('/').slice(-2).join('/') || 'Q/battle_v5_config.q';
            const now = getNowTimeString();
            const bName = data.backup ? data.backup.replace(/\\/g, '/').split('/').pop() : '无';

            if (data.adb && data.adb.success && data.adb.connected) {
                hasPendingSimulatorSync = false;
                const dev = data.adb.device || '模拟器';
                const elapsed = data.adb.elapsed_ms != null ? `${data.adb.elapsed_ms}ms` : '毫秒级';
                const tooltip = `【保存并直推完成】\n• 源文件：${savedPath} (已落盘)\n• 历史快照：${bName}\n• PC 助手：已覆写本地工程目录\n• 模拟器：已直推 /sdcard/FGO_Q/ (设备: ${dev}, 耗时: ${elapsed})\n• 保存时间：${now}`;
                updateSyncStatus('synced', '✅ 已同步', tooltip);
                toast(`✅ 已保存到磁盘并在约 ${elapsed} 内直推至模拟器 (${dev})`);
                const indicator = $('adbIndicator');
                if (indicator) {
                    indicator.className = 'adb-badge connected';
                    indicator.textContent = '🟢 在线';
                    indicator.title = `模拟器已连线: ${dev}\n点击可手动再次同步`;
                }
            } else {
                hasPendingSimulatorSync = true; // 关键：保存过了但模拟器未连接，记录待补推
                const tooltip = `【本地保存完成 / 模拟器待补推】\n• 源文件：${savedPath} (已落盘)\n• 历史快照：${bName}\n• PC 助手：已覆写本地工程目录\n• 模拟器：当前未连接，已挂起同步标记\n• 补推机制：模拟器开机就绪后，将由 10 秒轻量心跳自动静默补推\n• 保存时间：${now}`;
                updateSyncStatus('pending', '⚠️ 待补推', tooltip);
                toast(`✅ 已保存到本地工程与 PC 助手 (⚠️ 模拟器未连接，连上后自动补推)`);
            }
            return { success: true, data };
        } else {
            throw new Error(data.message || '保存失败');
        }
    } catch (err) {
        const errMsg = formatText(TEXT_CONFIG.messages.saveError, { error: err.message });
        toast(errMsg);
        updateSyncStatus('error', '❌ 保存失败', `【保存失败】\n• 错误原因：${err.message}\n• 建议：检查后台 Python 服务 (端口 8098) 是否存活或文件是否被独占`);
        return { success: false, error: err.message };
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.textContent = originalText;
        }
        updateSaveButtonState();
    }
}

let runnerWatcherTimer = null;
let currentRunnerState = 'OFFLINE';
let lastKnownRunnerState = 'OFFLINE';

// 启停瞬态锁存标志（Transient Guard Flags）
// 防止下发指令后由于按键脚本读指令的时延，被旧的 IDLE / RUNNING 心跳冲刷还原导致按钮误跳动
let isStartingBattle = false;
let isStoppingBattle = false;

export function getCurrentRunnerState() {
    return currentRunnerState;
}

// 渲染停止按钮状态（尺寸保持与双核分体按钮完全一致，并承载战斗回合与进度信息）
export function updateStopButtonState(options = {}) {
    const stopBtn = $('stopBattleBtn');
    if (!stopBtn) return;
    const {
        icon = '⏹',
        actionText = '停止任务',
        roundText = '',
        subRoundText = '',
        actionDetail = '',
        disabled = false,
        title = ''
    } = options;

    const twinGroup = $('twinRunGroup');
    const twinW = (twinGroup && twinGroup.offsetWidth > 0) ? twinGroup.offsetWidth : 190;
    stopBtn.style.minWidth = `${twinW}px`;
    stopBtn.disabled = disabled;
    if (title) stopBtn.title = title;

    let infoHtml = '';
    if (roundText || subRoundText || actionDetail) {
        infoHtml = `<span class="stop-divider"></span><span class="stop-info-part">`;
        if (roundText) {
            infoHtml += `<span class="stop-round-badge">${roundText}</span>`;
        }
        if (subRoundText) {
            infoHtml += `<span class="stop-subround-badge">${subRoundText}</span>`;
        }
        if (actionDetail && !subRoundText) {
            infoHtml += `<span class="stop-subround-badge">${actionDetail}</span>`;
        }
        infoHtml += `</span>`;
    }

    stopBtn.innerHTML = `<span class="stop-action-part"><span class="stop-icon">${icon}</span><span class="stop-text">${actionText}</span></span>${infoHtml}`;
}

// 统一更新按键脚本状态徽标与控制按钮
export function updateRunnerUI(data) {
    const indicator = $('runnerIndicator');
    const twinGroup = $('twinRunGroup');
    const btnRunBattle = $('btnRunBattle');
    const btnRunExtra = $('btnRunExtra');
    const stopBtn = $('stopBattleBtn');
    const extraLockBanner = $('extraRunningLockBanner');
    const configLockBanner = $('configRunningLockBanner');
    const extraLockText = $('extraLockBannerText');
    const configLockText = $('configLockBannerText');

    if (!indicator) return;

    // 辅助工具：无论此前处于何种状态，严格将控制按钮还原为就绪/待命形态
    const restoreReadyButtons = (runDisabled = false, runTitle = '') => {
        if (twinGroup) {
            twinGroup.style.display = 'inline-flex';
        }
        if (btnRunBattle) {
            btnRunBattle.disabled = runDisabled;
            if (runTitle) btnRunBattle.title = runTitle;
        }
        if (btnRunExtra) {
            btnRunExtra.disabled = runDisabled;
            if (runTitle) btnRunExtra.title = runTitle;
        }
        if (stopBtn) {
            stopBtn.style.display = 'none';
            stopBtn.disabled = false;
        }
        if (extraLockBanner) extraLockBanner.style.display = 'none';
        if (configLockBanner) configLockBanner.style.display = 'none';
    };

    // 1. 计算最新状态
    let newState = 'OFFLINE';
    if (!data || !data.connected) {
        newState = 'OFFLINE';
    } else if (!data.alive || data.state === 'OFFLINE') {
        newState = 'OFFLINE';
    } else if (data.state === 'STOPPING') {
        newState = 'STOPPING';
    } else if (data.state === 'RUNNING') {
        newState = 'RUNNING';
    } else {
        newState = 'IDLE';
    }

    // 2. 状态变迁检测 (State Transition Tracking)
    if (lastKnownRunnerState === 'RUNNING' || lastKnownRunnerState === 'STOPPING') {
        if (newState === 'IDLE') {
            toast('⏹ 任务脚本已停止并返回待命（按钮已还原就绪）', 3200);
        } else if (newState === 'OFFLINE') {
            toast('⏹ 任务脚本已退出停止（按钮已还原就绪）', 3200);
        }
    }

    lastKnownRunnerState = newState;
    currentRunnerState = newState;

    const readyEnvBtn = $('readyEnvBtn');

    // 瞬态锁存防护：启动中/停止中期间阻断旧状态引发的 UI 回跳
    if (isStartingBattle) {
        if (newState === 'RUNNING') {
            isStartingBattle = false;
        } else {
            if (indicator) indicator.style.display = 'none';
            if (readyEnvBtn) {
                readyEnvBtn.style.display = 'inline-flex';
                if (!isReadyEnvExecuting && !isCancellingReadyEnv) {
                    updateReadyEnvBtn('✅', '已就绪', 'ready');
                }
            }
            if (twinGroup) twinGroup.style.display = 'none';
            if (stopBtn) {
                stopBtn.style.display = 'inline-flex';
                updateStopButtonState({
                    icon: '⏳',
                    actionText: '启动中...',
                    roundText: '等待脚本响应',
                    disabled: true,
                    title: '指令已下发，脚本启动中...'
                });
            }
            return;
        }
    }

    if (isStoppingBattle) {
        if (newState === 'IDLE' || newState === 'OFFLINE') {
            isStoppingBattle = false;
        } else {
            if (indicator) indicator.style.display = 'none';
            if (readyEnvBtn) {
                readyEnvBtn.style.display = 'inline-flex';
                if (!isReadyEnvExecuting && !isCancellingReadyEnv) {
                    updateReadyEnvBtn('✅', '已就绪', 'ready');
                }
            }
            if (twinGroup) twinGroup.style.display = 'none';
            if (stopBtn) {
                stopBtn.style.display = 'inline-flex';
                updateStopButtonState({
                    icon: '⏳',
                    actionText: '正在停止...',
                    roundText: '安全等待退出',
                    disabled: true,
                    title: '正在等待任务执行到安全节点并退出...'
                });
            }
            return;
        }
    }

    // 3. 根据新状态渲染顶部界面与分体/合体按钮 (indicator 隐藏，就绪环境专钮专用)
    if (indicator) indicator.style.display = 'none';

    if (!data || !data.connected) {
        if (readyEnvBtn) {
            readyEnvBtn.style.display = 'inline-flex';
            isEnvironmentReady = false;
            if (!isReadyEnvExecuting && !isCancellingReadyEnv) {
                updateReadyEnvBtn('⚡', '就绪环境', 'default');
                readyEnvBtn.title = '【模拟器未连接】点击检查并就绪环境（请确保模拟器已启动并开启 ADB）';
            }
        }
        restoreReadyButtons(false, '模拟器未连接，点击查看引导');
    } else if (newState === 'OFFLINE') {
        if (readyEnvBtn) {
            readyEnvBtn.style.display = 'inline-flex';
            if (!isReadyEnvExecuting && !isCancellingReadyEnv) {
                isEnvironmentReady = false;
                updateReadyEnvBtn('⚡', '就绪环境', 'default');
                const offlineDuration = data.heartbeat_age_s ? formatDuration(data.heartbeat_age_s) : '';
                let tipMsg = '【按键脚本未启动】点击智能就绪环境（自动拉起脚本待命并推进至 FGO 游戏主页，执行中可再次点击取消）';
                if (offlineDuration) tipMsg += ` (已离线 ${offlineDuration})`;
                tipMsg += '\n• 右键可展开/收起脚本监控日志面板';
                readyEnvBtn.title = tipMsg;
            }
        }
        restoreReadyButtons(false, '按键脚本未启动，建议先点击「就绪环境」就绪后再运行');
    } else if (newState === 'RUNNING') {
        if (readyEnvBtn) {
            readyEnvBtn.style.display = 'inline-flex';
            isEnvironmentReady = true;
            if (!isReadyEnvExecuting && !isCancellingReadyEnv) {
                updateReadyEnvBtn('✅', '已就绪', 'ready');
                readyEnvBtn.title = '【环境已就绪】按键脚本执行中\n• 点击展开/收起脚本监控日志\n• 战斗状态请查看右侧控制按钮';
            }
        }
        const isExtra = data && (
            (data.mode && data.mode.toUpperCase() === 'EXTRA') ||
            (data.action && (data.action.includes('Extra') || data.action.includes('强化') || data.action.includes('再临') || data.action.includes('灵基') || data.action.includes('突破') || data.action.includes('整备') || data.action.includes('抽卡') || data.action.includes('召唤') || data.action.includes('友情') || data.action.includes('池') || data.action.includes('圣杯') || data.action.includes('转临'))) ||
            (data.msg && (data.msg.includes('Extra') || data.msg.includes('强化') || data.msg.includes('再临') || data.msg.includes('灵基') || data.msg.includes('突破') || data.msg.includes('整备') || data.msg.includes('抽卡') || data.msg.includes('召唤') || data.msg.includes('友情') || data.msg.includes('池') || data.msg.includes('圣杯') || data.msg.includes('转临')))
        );

        const round = (data && data.round) || 1;
        const totalRounds = (data && data.total_rounds) || 0;
        const subRound = (data && data.sub_round) || 0;

        if (isExtra) {
            const countText = totalRounds > 0 ? `第 ${round}/${totalRounds} 次` : `第 ${round} 次`;
            if (stopBtn) {
                stopBtn.style.display = 'inline-flex';
                updateStopButtonState({
                    icon: '⏹',
                    actionText: '停止整备',
                    roundText: countText,
                    actionDetail: data.action ? data.action.replace(/^Extra\s*/i, '').slice(0, 10) : '',
                    disabled: false,
                    title: `点击停止整备任务 (${countText})，脚本将在当前安全动作后退出并返回待命`
                });
            }
            if (configLockBanner) {
                configLockBanner.style.display = 'flex';
                if (configLockText) configLockText.textContent = `整备任务正在执行中 [${data.action || '进行中'}]，战斗功能已锁定。请先停止当前任务。`;
            }
            if (extraLockBanner) extraLockBanner.style.display = 'none';
        } else {
            const roundText = totalRounds > 0 ? `第 ${round}/${totalRounds} 轮` : `第 ${round} 轮`;
            const subRoundText = subRound > 0 ? `${subRound}/3 面` : '';

            if (stopBtn) {
                stopBtn.style.display = 'inline-flex';
                updateStopButtonState({
                    icon: '⏹',
                    actionText: '停止战斗',
                    roundText: roundText,
                    subRoundText: subRoundText,
                    disabled: false,
                    title: `点击停止战斗 (${roundText}${subRoundText ? ` · ${subRoundText}` : ''})，脚本将在当前安全动作后退出并返回待命`
                });
            }
            if (extraLockBanner) {
                extraLockBanner.style.display = 'flex';
                if (extraLockText) extraLockText.textContent = `战斗正在执行中 (${roundText})，整备功能已锁定。请先停止战斗。`;
            }
            if (configLockBanner) configLockBanner.style.display = 'none';
        }

        if (twinGroup) twinGroup.style.display = 'none';
    } else if (newState === 'STOPPING') {
        if (readyEnvBtn) {
            readyEnvBtn.style.display = 'inline-flex';
            isEnvironmentReady = true;
            if (!isReadyEnvExecuting && !isCancellingReadyEnv) {
                updateReadyEnvBtn('✅', '已就绪', 'ready');
                readyEnvBtn.title = '【环境已就绪】任务正在停止中\n• 点击展开/收起脚本监控日志';
            }
        }
        if (twinGroup) twinGroup.style.display = 'none';
        if (stopBtn) {
            stopBtn.style.display = 'inline-flex';
            const round = (data && data.round) || 1;
            const totalRounds = (data && data.total_rounds) || 0;
            const roundText = totalRounds > 0 ? `第 ${round}/${totalRounds} 轮` : (round > 0 ? `第 ${round} 轮` : '');
            updateStopButtonState({
                icon: '⏳',
                actionText: '正在停止...',
                roundText: roundText || '安全退出中',
                disabled: true,
                title: '正在等待任务执行到安全节点并退出...'
            });
        }
    } else {
        // newState === 'IDLE'
        if (readyEnvBtn) {
            readyEnvBtn.style.display = 'inline-flex';
            if (!isReadyEnvExecuting && !isCancellingReadyEnv) {
                const isReady = Boolean(data && data.environment_ready) || isEnvironmentReady;
                isEnvironmentReady = isReady;
                if (isReady) {
                    updateReadyEnvBtn('✅', '已就绪', 'ready');
                    let readyTip = '【环境已就绪】按键脚本已在后台待命且已处于游戏主页\n• 点击展开/收起脚本监控日志\n• 右键可重新检查就绪环境';
                    if (data && data.time) readyTip += `\n• 最近心跳: ${data.time}`;
                    readyEnvBtn.title = readyTip;
                } else {
                    updateReadyEnvBtn('⚡', '就绪环境', 'default');
                    readyEnvBtn.title = '【按键脚本已在后台待命】建议点击智能就绪环境确保游戏处于主页待命\n• 右键可展开/收起脚本监控日志面板';
                }
            }
        }
        restoreReadyButtons(false, '启动自动化任务（未保存改动将自动保存并直推至模拟器）');
    }
}

let monitorAutoRefreshTimer = null;

// 更新右下角简易监控面板中的所有指标与实时日志
export function updateRunnerMonitorPanel(data) {
    const panel = $('runnerMonitorPanel');
    if (!panel) return;

    const statusDot = $('monitorStatusDot');
    const stateRoundText = $('monitorStateRoundText');
    const logTime = $('monitorLogTime');
    const progressWrap = $('monitorProgressWrap');
    const progressFill = $('monitorProgressFill');
    const progressPercent = $('monitorProgressPercent');
    const logTerminal = $('monitorLogTerminal');
    const stopBtn = $('monitorStopBtn');

    const state = (data && data.state) ? data.state.toUpperCase() : 'OFFLINE';
    const isRunning = state === 'RUNNING';
    const isStopping = state === 'STOPPING';
    const isIdle = state === 'IDLE';

    // 1. 左上角状态图标与运行提示
    if (statusDot) {
        if (!data || !data.connected) {
            statusDot.textContent = '⚪';
            statusDot.title = '模拟器离线';
        } else if (isIdle) {
            statusDot.textContent = '🟢';
            statusDot.title = '脚本待命中 (随时可开打)';
        } else if (isRunning) {
            statusDot.textContent = '⚔️';
            statusDot.title = '战斗执行中';
        } else if (isStopping) {
            statusDot.textContent = '⏳';
            statusDot.title = '正在安全退出...';
        } else {
            statusDot.textContent = '⚪';
            const offlineDuration = (data && data.heartbeat_age_s) ? formatDuration(data.heartbeat_age_s) : '';
            statusDot.title = offlineDuration ? `脚本未启动 (已离线 ${offlineDuration})` : '脚本未启动';
        }
    }

    // 2. 连战轮次（仅战斗中紧凑显示在时间前）
    const round = (data && data.round) || 0;
    const totalRounds = (data && data.total_rounds) || 0;
    if (stateRoundText) {
        if (isRunning && round > 0) {
            const rText = totalRounds > 0 ? `[第 ${round}/${totalRounds} 轮]` : `[第 ${round} 轮]`;
            stateRoundText.textContent = rText;
            stateRoundText.style.display = 'inline';
        } else {
            stateRoundText.textContent = '';
            stateRoundText.style.display = 'none';
        }
    }

    // 3. 同步时间 (紧随状态图标之后)
    if (logTime) {
        const now = new Date().toTimeString().slice(0, 8);
        logTime.textContent = now;
    }

    // 4. 连战细进度条 (战斗中显示)
    if (progressWrap && progressFill && progressPercent) {
        if (isRunning && totalRounds > 0) {
            progressWrap.style.display = 'flex';
            const pct = Math.min(100, Math.max(0, Math.round((round / totalRounds) * 100)));
            progressFill.style.width = `${pct}%`;
            progressPercent.textContent = `${pct}%`;
        } else {
            progressWrap.style.display = 'none';
        }
    }

    // 5. 右上角停止按钮 (战斗中显示)
    if (stopBtn) {
        if (isRunning) {
            stopBtn.style.display = 'inline-flex';
            stopBtn.disabled = false;
            stopBtn.textContent = '⏹';
            stopBtn.title = '点击停止战斗';
        } else if (isStopping) {
            stopBtn.style.display = 'inline-flex';
            stopBtn.disabled = true;
            stopBtn.textContent = '⏳';
            stopBtn.title = '正在停止...';
        } else {
            stopBtn.style.display = 'none';
        }
    }

    // 6. 日志输出终端 (无小标题)
    if (logTerminal) {
        if (data && data.logs && data.logs.length > 0) {
            logTerminal.textContent = data.logs.join('\n');
            logTerminal.scrollTop = logTerminal.scrollHeight;
        } else if (isRunning) {
            logTerminal.textContent = '战斗执行中，正在抓取模拟器按键精灵日志...';
        } else if (isIdle) {
            logTerminal.textContent = '按键脚本待命就绪 (IDLE)\n等待运行指令下发...';
        } else {
            logTerminal.textContent = '暂无日志输出，启动脚本或点击上方 🔄 刷新...';
        }
    }
}

// 展开右下角简易脚本监控面板
export async function openRunnerMonitorPanel() {
    const panel = $('runnerMonitorPanel');
    if (!panel) return;
    panel.style.display = 'flex';
    panel.classList.add('show');

    // 立即刷新一次
    const data = await checkRunnerStatus();
    updateRunnerMonitorPanel(data);

    // 启动面板内的定时轮询 (每秒同步一次日志)
    if (monitorAutoRefreshTimer) clearInterval(monitorAutoRefreshTimer);
    monitorAutoRefreshTimer = setInterval(async () => {
        if (!panel.classList.contains('show') || panel.style.display === 'none') {
            clearInterval(monitorAutoRefreshTimer);
            monitorAutoRefreshTimer = null;
            return;
        }
        const freshData = await checkRunnerStatus();
        updateRunnerMonitorPanel(freshData);
    }, 1000);
}

// 收起右下角简易脚本监控面板
export function closeRunnerMonitorPanel() {
    const panel = $('runnerMonitorPanel');
    if (panel) {
        panel.classList.remove('show');
        panel.style.display = 'none';
    }
    if (monitorAutoRefreshTimer) {
        clearInterval(monitorAutoRefreshTimer);
        monitorAutoRefreshTimer = null;
    }
}

// 切换展开/收起状态 (Toggle)
export function toggleRunnerMonitorPanel() {
    const panel = $('runnerMonitorPanel');
    if (!panel) return;
    if (panel.classList.contains('show') && panel.style.display !== 'none') {
        closeRunnerMonitorPanel();
    } else {
        openRunnerMonitorPanel();
    }
}

// 挂载全局方法方便外部调用
if (typeof window !== 'undefined') {
    window.openRunnerMonitor = openRunnerMonitorPanel;
    window.closeRunnerMonitor = closeRunnerMonitorPanel;
    window.toggleRunnerMonitor = toggleRunnerMonitorPanel;
}

// 查询 Runner 状态
export async function checkRunnerStatus() {
    try {
        const res = await fetch('/api/runner/status');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        updateRunnerUI(data);
        const panel = $('runnerMonitorPanel');
        if (panel && panel.classList.contains('show') && panel.style.display !== 'none') {
            updateRunnerMonitorPanel(data);
        }
        return data;
    } catch (_) {
        const fallback = { connected: false, alive: false, state: 'OFFLINE' };
        updateRunnerUI(fallback);
        const panel = $('runnerMonitorPanel');
        if (panel && panel.classList.contains('show') && panel.style.display !== 'none') {
            updateRunnerMonitorPanel(fallback);
        }
        return fallback;
    }
}

// 启动 Runner 状态自适应轮询
export function startRunnerStatusWatcher() {
    if (runnerWatcherTimer) clearTimeout(runnerWatcherTimer);

    const poll = async () => {
        const data = await checkRunnerStatus();
        const interval = (data && data.state === 'RUNNING') ? 1000 : 1200;
        runnerWatcherTimer = setTimeout(poll, interval);
    };

    poll();
}

let isReadyEnvExecuting = false;
let isEnvironmentReady = false;
let isCancellingReadyEnv = false;
let readyEnvAbortController = null;

// 设置就绪环境按钮的实时状态显示：
// mode: 'default' (橙色⚡就绪环境) | 'working' (可点击取消 + 流动条纹动画) | 'cancelling' (不可点击 + 红色取消过渡) | 'ready' (不可点击 + 绿色沉静基调 + ✅已就绪)
export function updateReadyEnvBtn(icon, text, mode = 'default') {
    const btn = $('readyEnvBtn');
    const monitorBtn = $('monitorReadyEnvBtn');
    if (!btn) return;
    const cleanText = (text || '就绪环境').trim();
    const isLong = cleanText.length > 4;

    btn.classList.toggle('multiline-status', isLong);
    btn.classList.toggle('working', mode === 'working');
    btn.classList.toggle('cancelling', mode === 'cancelling');
    btn.classList.toggle('ready', mode === 'ready');

    btn.innerHTML = `<span class="ready-btn-icon">${icon || '⚡'}</span><span class="ready-btn-text">${cleanText}</span>`;

    if (mode === 'working') {
        btn.disabled = false;
        btn.title = `正在就绪: ${cleanText} (再次点击取消当前执行)`;
        if (monitorBtn) {
            monitorBtn.textContent = '⏳';
            monitorBtn.title = `正在就绪: ${cleanText} (点击取消当前执行)`;
        }
    } else if (mode === 'cancelling') {
        btn.disabled = true;
        btn.title = '正在取消就绪环境，请稍候...';
        if (monitorBtn) {
            monitorBtn.textContent = '🛑';
            monitorBtn.title = '正在取消就绪环境...';
        }
    } else if (mode === 'ready') {
        btn.disabled = false;
        btn.title = '【环境已就绪】点击展开/收起脚本监控日志\n• 右键可重新就绪环境';
        if (monitorBtn) {
            monitorBtn.textContent = '✅';
            monitorBtn.title = '环境已完全就绪 (点击重新检查就绪)';
        }
    } else {
        btn.disabled = false;
        btn.title = '智能就绪环境：哪个未完成就操作哪个。都没完成则先拉起脚本再推进至 FGO 游戏主页';
        if (monitorBtn) {
            monitorBtn.textContent = '⚡';
            monitorBtn.title = '智能就绪环境 (按需唤醒并推进至 FGO 游戏主页)';
        }
    }
}

// 取消当前正在执行的就绪环境任务
export async function cancelReadyEnvironment() {
    if (!isReadyEnvExecuting || isCancellingReadyEnv) return;
    isCancellingReadyEnv = true;
    updateReadyEnvBtn('🛑', '正在取消', 'cancelling');
    toast('🛑 正在取消就绪环境...', 3000);

    // 1. 中止前端挂起的 fetch 请求
    if (readyEnvAbortController) {
        try {
            readyEnvAbortController.abort();
        } catch (_) {}
    }

    // 2. 向后端下发取消指令
    try {
        await fetch('/api/runner/ready_env/cancel', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
            body: JSON.stringify({})
        });
    } catch (e) {
        console.warn('[就绪环境] 取消指令请求异常:', e);
    }

    // 3. 界面状态平滑反馈
    updateReadyEnvBtn('🛑', '已取消', 'cancelling');
    toast('🛑 已取消就绪环境', 3000);
    await new Promise(r => setTimeout(r, 1000));

    // 4. 重置状态与按钮
    isReadyEnvExecuting = false;
    isCancellingReadyEnv = false;
    isEnvironmentReady = false;
    readyEnvAbortController = null;
    updateReadyEnvBtn('⚡', '就绪环境', 'default');
    await checkRunnerStatus();
}

// 智能就绪环境：合并「拉起脚本」与「进入主页」，按需自动执行；就绪过程中再次点击取消当前执行
export async function readyEnvironment(forceRestart = false) {
    if (isReadyEnvExecuting) {
        // 就绪过程中再次点击：取消当前执行
        return await cancelReadyEnvironment();
    }
    if (isCancellingReadyEnv) return;
    if (isEnvironmentReady && !forceRestart) {
        toggleRunnerMonitorPanel();
        return;
    }
    const btn = $('readyEnvBtn');
    if (btn && btn.classList.contains('cancelling')) return;

    isReadyEnvExecuting = true;
    isCancellingReadyEnv = false;
    readyEnvAbortController = new AbortController();

    // 工作时开启进行中的流动条纹动画效果，保持可点击以支持再次点击取消
    updateReadyEnvBtn('🔍', '检查环境', 'working');
    toast('⚡ 正在检查并自动就绪环境（按需拉起按键脚本并推进至 FGO 游戏主页，可再次点击取消）...', 8000);

    let pollTimer = null;

    // 毫秒级轮询后台实时就绪进度并实时反映到按钮上
    const pollProgress = async () => {
        if (!isReadyEnvExecuting || isCancellingReadyEnv) return;
        try {
            const resp = await fetch('/api/runner/ready_status', { cache: 'no-cache' });
            if (resp.ok) {
                const prog = await resp.json();
                if (isReadyEnvExecuting && !isCancellingReadyEnv && prog && prog.active && prog.status) {
                    updateReadyEnvBtn(prog.icon, prog.status, 'working');
                    if (prog.detail && btn) {
                        btn.title = `就绪状态: ${prog.status} (${prog.detail}) (再次点击取消当前执行)`;
                    }
                }
            }
        } catch (_) {}
        if (isReadyEnvExecuting && !isCancellingReadyEnv) {
            pollTimer = setTimeout(pollProgress, 350);
        }
    };
    pollProgress();

    try {
        const res = await fetch('/api/runner/ready_env', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
            body: JSON.stringify({ force_restart: forceRestart }),
            signal: readyEnvAbortController.signal
        });
        const data = await res.json();
        if (pollTimer) clearTimeout(pollTimer);

        if (isCancellingReadyEnv || (data && data.cancelled)) {
            return data;
        }

        isReadyEnvExecuting = false;
        readyEnvAbortController = null;

        if (data.success) {
            isEnvironmentReady = true;
            updateReadyEnvBtn('✅', '已就绪', 'ready');
            toast(data.message || '✅ 环境已完全就绪（脚本已待命且处于游戏主页）！', 5000);
            await new Promise(r => setTimeout(r, 900));
        } else {
            isEnvironmentReady = false;
            updateReadyEnvBtn('⚠️', '就绪未完', 'default');
            toast(`⚠️ 就绪环境提示: ${data.message || '未知原因'}`, 6000);
            await new Promise(r => setTimeout(r, 2200));
            updateReadyEnvBtn('⚡', '就绪环境', 'default');
        }
        await checkRunnerStatus();
        return data;
    } catch (err) {
        if (pollTimer) clearTimeout(pollTimer);
        if (err.name === 'AbortError' || isCancellingReadyEnv) {
            console.log('[就绪环境] 执行已取消 (AbortError)');
            return { success: false, cancelled: true };
        }
        isReadyEnvExecuting = false;
        isEnvironmentReady = false;
        readyEnvAbortController = null;
        updateReadyEnvBtn('❌', '就绪失败', 'default');
        toast(`❌ 就绪环境请求失败: ${err.message}`, 5000);
        await new Promise(r => setTimeout(r, 2200));
        updateReadyEnvBtn('⚡', '就绪环境', 'default');
        await checkRunnerStatus();
        return { success: false, message: err.message };
    } finally {
        if (pollTimer) clearTimeout(pollTimer);
        if (!isCancellingReadyEnv) {
            isReadyEnvExecuting = false;
            readyEnvAbortController = null;
            if (btn) {
                // 如果全部就绪，保持已就绪状态（绿色基调、✅ 已就绪）；若未完成，恢复默认状态
                if (isEnvironmentReady) {
                    updateReadyEnvBtn('✅', '已就绪', 'ready');
                } else if (!btn.classList.contains('cancelling')) {
                    updateReadyEnvBtn('⚡', '就绪环境', 'default');
                }
            }
        }
    }
}

// 全自动拉起按键精灵与 Runner 脚本，并自动引导 FGO 进入游戏主页
export async function launchRunner() {
    const launchBtn = $('launchRunnerBtn');
    if (launchBtn) {
        launchBtn.disabled = true;
        launchBtn.textContent = '⏳ 正在拉起...';
    }
    toast('🚀 正在全自动唤醒按键精灵加载脚本，并智能推进 FGO 进入游戏主页...', 7000);

    try {
        const res = await fetch('/api/runner/launch', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
            body: JSON.stringify({})
        });
        const data = await res.json();
        if (data.success) {
            toast(data.message || '✅ 按键精灵 Runner 已就绪，且已成功进入 FGO 游戏主页！', 5000);
        } else {
            toast(`⚠️ 拉起按键脚本失败: ${data.message || '未知原因'}`, 6000);
        }
        await checkRunnerStatus();
        return data;
    } catch (err) {
        toast(`❌ 请求拉起脚本失败: ${err.message}`, 5000);
        await checkRunnerStatus();
        return { success: false, message: err.message };
    } finally {
        if (launchBtn) {
            launchBtn.disabled = false;
            launchBtn.textContent = '⚡ 拉起脚本';
        }
    }
}

// 引导推进 FGO 进入游戏主页 (点击标题、跳过公告与弹窗)
export async function navigateFgoToHome() {
    const navBtn = $('navHomeBtn');
    if (navBtn) {
        navBtn.disabled = true;
        navBtn.textContent = '⏳ 推进主页...';
    }
    toast('🚀 正在自动推进 FGO 进入游戏主页（点击标题、关闭公告与弹窗）...', 5000);

    try {
        const res = await fetch('/api/fgo/navigate_home', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
            body: JSON.stringify({})
        });
        const data = await res.json();
        if (data.success) {
            toast(data.message || '✅ 已成功就绪于 FGO 游戏主页！', 4500);
        } else {
            toast(`⚠️ 进入主页提示: ${data.message || '未知原因'}`, 5500);
        }
        return data;
    } catch (err) {
        toast(`❌ 推进主页失败: ${err.message}`, 5000);
        return { success: false, message: err.message };
    } finally {
        if (navBtn) {
            navBtn.disabled = false;
            navBtn.textContent = '🏠 进入主页';
        }
    }
}

// 网页直控：运行战斗（如果配置未保存则自动保存，以当前新配置运行战斗）
export async function triggerRunTask(mode = 'BATTLE', getConfigTextCallback) {
    const isExtra = (mode === 'EXTRA');
    const twinGroup = $('twinRunGroup');
    const stopBtn = $('stopBattleBtn');

    // 0. 主动失焦当前聚焦的输入控件，提交输入事件
    if (document.activeElement && typeof document.activeElement.blur === 'function') {
        document.activeElement.blur();
    }
    commitChanges();

    if (!appState.data.extraSettings) {
        appState.data.extraSettings = { runMode: 0, actionCount: 30, skillMaxLevel: 9 };
    }
    appState.data.extraSettings.runMode = isExtra ? 1 : 0;

    let configText = '';
    if (typeof getConfigTextCallback === 'function') {
        configText = getConfigTextCallback();
    }

    // 1. 未保存改动自动保存并直推
    const dirty = isConfigDirty();
    if (dirty || hasPendingSimulatorSync) {
        toast('💾 检测到配置有未保存改动，正在自动保存并直推最新配置...', 3000);
        const saveRes = await saveConfigToBackend(configText);
        if (!saveRes || !saveRes.success) {
            toast('❌ 自动保存最新配置失败，已终止启动以避免使用旧配置！', 5000);
            return;
        }
    }

    // 2. 毫秒级状态即时核实
    let currentData = null;
    try {
        currentData = await checkRunnerStatus();
    } catch (_) {}

    if (!currentData || !currentData.connected) {
        toast(`⚠️ 模拟器尚未连接，无法启动${isExtra ? '整备' : '战斗'}！\n最新配置已自动保存，请先开启模拟器并确保连通。`, 4500);
        return;
    }

    if (!currentData.alive || currentData.state === 'OFFLINE') {
        toast(`⚠️ 按键脚本尚未启动！\n最新配置已自动保存，请点击「⚡ 就绪环境」拉起脚本待命后再运行${isExtra ? '整备' : '战斗'}。`, 4500);
        return;
    }

    if (currentData.state === 'RUNNING') {
        toast('ℹ️ 任务已经在执行中！\n若需终止，请点击右上角的「⏹ 停止任务」。', 3500);
        return;
    }

    isStartingBattle = true;
    if (twinGroup) twinGroup.style.display = 'none';
    if (stopBtn) {
        stopBtn.style.display = 'inline-flex';
        updateStopButtonState({
            icon: '⏳',
            actionText: '启动中...',
            roundText: '等待脚本响应',
            disabled: true,
            title: isExtra ? '正在下发整备指令并等待脚本启动...' : '正在下发战斗指令并等待脚本启动...'
        });
    }

    try {
        const res = await fetch('/api/run', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
            body: JSON.stringify({ text: configText, mode: mode })
        });
        const data = await res.json();

        if (data.success) {
            setInitialSnapshot(appState.data);
            setLastSavedConfigText(configText);
            updateSaveButtonState();
            updateSyncStatus('synced', '✅ 已保存并同步', '运行前已自动保存最新配置并直推模拟器');

            toast(isExtra ? '🚀 整备启动指令已下发！已应用当前最新配置执行...' : '🚀 战斗启动指令已下发！已应用当前最新配置执行...');

            const maxBurstTries = 10;
            for (let i = 0; i < maxBurstTries; i++) {
                await new Promise(r => setTimeout(r, 300));
                if (!isStartingBattle) break;
                const statusData = await checkRunnerStatus();
                if (statusData && statusData.state === 'RUNNING') {
                    isStartingBattle = false;
                    break;
                }
                if (statusData && (!statusData.connected || statusData.state === 'OFFLINE')) {
                    isStartingBattle = false;
                    break;
                }
            }
        } else {
            toast(`⚠️ 启动失败: ${data.message || '未知原因'}`);
            isStartingBattle = false;
            await checkRunnerStatus();
        }
    } catch (err) {
        toast(`❌ 下发启动指令异常: ${err.message}`);
        isStartingBattle = false;
        await checkRunnerStatus();
    } finally {
        isStartingBattle = false;
        if (currentRunnerState !== 'RUNNING') {
            if (twinGroup) twinGroup.style.display = 'inline-flex';
            if (stopBtn) stopBtn.style.display = 'none';
        }
    }
}

export async function triggerRunBattle(getConfigTextCallback) {
    return triggerRunTask('BATTLE', getConfigTextCallback);
}

export async function triggerRunExtra(getConfigTextCallback) {
    return triggerRunTask('EXTRA', getConfigTextCallback);
}

// 探测 Extra 模拟器当前界面
export async function detectExtraScene() {
    const badge = $('extraSceneBadge');
    const desc = $('extraDetectorDesc');
    const btn = $('btnDetectScene');

    if (badge) {
        badge.className = 'scene-badge unknown';
        badge.textContent = '⏳ 探测中...';
    }
    if (btn) btn.disabled = true;

    try {
        const resp = await fetch('/api/extra/detect_scene', { cache: 'no-cache' });
        const res = await resp.json();
        if (res.success && res.scene !== 'unknown') {
            if (badge) {
                badge.className = 'scene-badge ready';
                badge.textContent = `✅ ${res.name}`;
            }
            const msg = res.message || `已识别为【${res.name}】界面，可随时启动整备。`;
            if (desc) {
                desc.textContent = msg;
                desc.title = msg;
            }
            toast(`🎯 探测到当前界面：【${res.name}】`);
        } else if (res.scene === 'error' || !res.success) {
            if (badge) {
                badge.className = 'scene-badge warn';
                badge.textContent = `⚠️ ${res.name || '探测异常'}`;
            }
            const msg = res.message || '探测发生异常，请检查模拟器连接状态。';
            if (desc) {
                desc.textContent = msg;
                desc.title = msg;
            }
            toast(`⚠️ ${res.name || '探测提示'}: ${msg}`, 4000);
        } else {
            if (badge) {
                badge.className = 'scene-badge unknown';
                badge.textContent = '⚪ 未识别场景';
            }
            const msg = res.message || '未检测到已知的强化或抽卡界面，请在 FGO 内先进入对应界面。';
            if (desc) {
                desc.textContent = msg;
                desc.title = msg;
            }
            toast(msg, 3500);
        }
        return res;
    } catch (e) {
        if (badge) {
            badge.className = 'scene-badge warn';
            badge.textContent = '❌ 探测失败';
        }
        const msg = `请求异常: ${e.message}`;
        if (desc) {
            desc.textContent = msg;
            desc.title = msg;
        }
        toast(`❌ ${msg}`);
        return { success: false, message: e.message };
    } finally {
        if (btn) btn.disabled = false;
    }
}

// 网页直控：停止战斗
export async function triggerStopBattle() {
    const stopBtn = $('stopBattleBtn');
    const runBtn = $('runBattleBtn');
    const twinGroup = $('twinRunGroup');

    isStoppingBattle = true;
    if (stopBtn) {
        updateStopButtonState({
            icon: '⏳',
            actionText: '正在停止...',
            roundText: '安全等待退出',
            disabled: true,
            title: '停止指令已下发，脚本将在当前安全动作后停止并返回待命'
        });
    }

    try {
        const res = await fetch('/api/stop', { method: 'POST' });
        const data = await res.json();
        if (data.success) {
            toast('⏹ 停止指令已下发，脚本将在当前安全动作后停止并返回待命', 3000);

            // 突发高频收敛探测：以 350ms 为步长等待按键脚本退出战斗循环进入待命（最多等待约 3.5 秒）
            const maxBurstTries = 10;
            for (let i = 0; i < maxBurstTries; i++) {
                await new Promise(r => setTimeout(r, 350));
                if (!isStoppingBattle) break;
                const statusData = await checkRunnerStatus();
                if (statusData && (statusData.state === 'IDLE' || statusData.state === 'OFFLINE')) {
                    isStoppingBattle = false;
                    break;
                }
            }
        } else {
            toast(`⚠️ 下发停止指令失败: ${data.message || '未知原因'}`);
            isStoppingBattle = false;
        }
    } catch (err) {
        toast(`❌ 停止异常: ${err.message}`);
        isStoppingBattle = false;
    } finally {
        isStoppingBattle = false;
        // 立即拉取最新状态并恢复稳态 UI
        const statusData = await checkRunnerStatus();
        if (!statusData || statusData.state !== 'RUNNING') {
            if (twinGroup) {
                twinGroup.style.display = 'inline-flex';
            } else if (runBtn) {
                runBtn.style.display = 'inline-flex';
                runBtn.disabled = false;
                runBtn.textContent = '▶ 运行战斗';
            }
            if (stopBtn) {
                stopBtn.style.display = 'none';
                stopBtn.disabled = false;
                stopBtn.textContent = '⏹ 停止战斗';
            }
        }
    }
}

// 挂载到 window 方便跨模块及标定工作台调用
window.toast = toast;
window.checkAdbStatus = checkAdbStatus;
window.selectAdbDevice = selectAdbDevice;
window.getSelectedAdbDevice = () => currentSelectedDevice;

// ==========================================================================
// 项目标准确认对话框 (遵循 Mooncell 模态规范)
// ==========================================================================
let activeConfirmResolver = null;

export function showConfirmModal({ title = '确认操作', message = '确定执行此操作吗？', okText = '确定', isDanger = true } = {}) {
    if (activeConfirmResolver) {
        activeConfirmResolver(false);
        activeConfirmResolver = null;
    }
    return new Promise((resolve) => {
        activeConfirmResolver = resolve;
        const modal = $('confirmModal');
        const titleEl = $('confirmModalTitle');
        const msgEl = $('confirmModalMessage');
        const okBtn = $('confirmModalOkBtn');
        const cancelBtn = $('confirmModalCancelBtn');
        if (!modal || !titleEl || !msgEl || !okBtn) {
            resolve(false);
            activeConfirmResolver = null;
            return;
        }

        titleEl.textContent = title;
        titleEl.style.borderLeftColor = isDanger ? 'var(--buster, #e7615c)' : 'var(--darkblue, #4487df)';
        msgEl.textContent = message;
        okBtn.textContent = okText;
        okBtn.className = isDanger ? 'button danger' : 'button primary';

        const finish = (result) => {
            modal.classList.remove('show');
            okBtn.onclick = null;
            if (cancelBtn) cancelBtn.onclick = null;
            if (activeConfirmResolver) {
                const r = activeConfirmResolver;
                activeConfirmResolver = null;
                r(result);
            }
        };

        okBtn.onclick = () => finish(true);
        if (cancelBtn) cancelBtn.onclick = () => finish(false);

        modal.classList.add('show');
    });
}

export function closeConfirmModal() {
    const modal = $('confirmModal');
    if (modal) modal.classList.remove('show');
    if (activeConfirmResolver) {
        const r = activeConfirmResolver;
        activeConfirmResolver = null;
        r(false);
    }
}

window.showConfirmModal = showConfirmModal;
window.closeConfirmModal = closeConfirmModal;

// ==========================================
// 职阶星图自动解放 (Editor 原生极速 ADB 引擎)
// ==========================================
let _starMapPollTimer = null;

export async function startStarMapUnlock() {
    const btnStart = $('btnStartStarMap');
    const btnStop = $('btnStopStarMap');
    const statusIcon = $('starMapStatusIcon');
    const statusText = $('starMapStatusText');
    const countBadge = $('starMapCountBadge');
    const banner = $('starMapStatusBanner');
    const autoSwipeCheck = $('cfgStarMapAutoSwipe');
    const autoSwipe = autoSwipeCheck ? autoSwipeCheck.checked : true;

    if (btnStart) btnStart.disabled = true;
    if (btnStop) btnStop.disabled = false;
    if (banner) banner.className = 'star-map-status-banner is-running';
    if (statusIcon) statusIcon.textContent = '⏳';
    if (statusText) statusText.textContent = '正在启动星图自动解放引擎...';

    try {
        const resp = await fetch('/api/star_map/start', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ auto_swipe: autoSwipe })
        });
        const res = await resp.json();
        if (!res.success) {
            toast(`❌ 启动失败: ${res.message || '未知错误'}`);
            if (btnStart) btnStart.disabled = false;
            if (btnStop) btnStop.disabled = true;
            if (banner) banner.className = 'star-map-status-banner is-error';
            if (statusIcon) statusIcon.textContent = '❌';
            if (statusText) statusText.textContent = res.message || '启动失败';
            return;
        }
        toast('🚀 星图自动解放已启动');
        pollStarMapProgress();
    } catch (e) {
        toast(`❌ 网络请求失败: ${e.message}`);
        if (btnStart) btnStart.disabled = false;
        if (btnStop) btnStop.disabled = true;
        if (banner) banner.className = 'star-map-status-banner is-error';
        if (statusIcon) statusIcon.textContent = '❌';
        if (statusText) statusText.textContent = '连接后端异常';
    }
}

export async function stopStarMapUnlock() {
    const btnStop = $('btnStopStarMap');
    if (btnStop) btnStop.disabled = true;
    try {
        await fetch('/api/star_map/stop', { method: 'POST' });
        toast('⏹ 已请求停止星图解放');
    } catch (e) {
        console.error('Stop error:', e);
    }
}

export function pollStarMapProgress() {
    if (_starMapPollTimer) clearInterval(_starMapPollTimer);

    const tick = async () => {
        const btnStart = $('btnStartStarMap');
        const btnStop = $('btnStopStarMap');
        const statusIcon = $('starMapStatusIcon');
        const statusText = $('starMapStatusText');
        const countBadge = $('starMapCountBadge');
        const banner = $('starMapStatusBanner');

        try {
            const resp = await fetch('/api/star_map/status', { cache: 'no-cache' });
            const data = await resp.json();

            if (countBadge) {
                if (data.liberated_count > 0) {
                    countBadge.style.display = 'inline-block';
                    countBadge.textContent = `已解放: ${data.liberated_count}`;
                } else {
                    countBadge.style.display = 'none';
                }
            }

            if (data.running) {
                if (btnStart) btnStart.disabled = true;
                if (btnStop) btnStop.disabled = false;
                if (banner) banner.className = 'star-map-status-banner is-running';
                if (statusIcon) statusIcon.textContent = '⚡';
                if (statusText) statusText.textContent = data.message || '正在解放中...';
            } else {
                clearInterval(_starMapPollTimer);
                _starMapPollTimer = null;
                if (btnStart) btnStart.disabled = false;
                if (btnStop) btnStop.disabled = true;

                if (data.status === 'FINISHED') {
                    if (banner) banner.className = 'star-map-status-banner is-finished';
                    if (statusIcon) statusIcon.textContent = '✅';
                    if (statusText) statusText.textContent = data.message || '解放完毕！';
                    toast(`🎉 ${data.message || '星图解放完成！'}`);
                } else if (data.status === 'CANCELLED') {
                    if (banner) banner.className = 'star-map-status-banner is-stopped';
                    if (statusIcon) statusIcon.textContent = '🛑';
                    if (statusText) statusText.textContent = '已手动停止';
                    toast('🛑 星图解放已停止');
                } else if (data.status === 'ERROR') {
                    if (banner) banner.className = 'star-map-status-banner is-error';
                    if (statusIcon) statusIcon.textContent = '❌';
                    if (statusText) statusText.textContent = data.message || '发生异常';
                } else {
                    if (banner) banner.className = 'star-map-status-banner';
                    if (statusIcon) statusIcon.textContent = '⚪';
                    if (statusText) statusText.textContent = '待命中（进入星图界面后点击开始）';
                }
            }
        } catch (e) {
            console.error('Poll star map error:', e);
        }
    };

    _starMapPollTimer = setInterval(tick, 900);
    tick();
}

window.startStarMapUnlock = startStarMapUnlock;
window.stopStarMapUnlock = stopStarMapUnlock;
window.pollStarMapProgress = pollStarMapProgress;




