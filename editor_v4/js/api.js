import { appState, setInitialSnapshot } from './state.js';
import { parseConfigFileText } from './dsl.js';
import { TEXT_CONFIG, formatText } from './text_config.js';

// DOM 简写与提示
export const $ = id => document.getElementById(id);

export const toast = msg => {
    const t = $('toast');
    if (!t) return;
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => t.classList.remove('show'), 2200);
};

// 请求后端终止本地服务
export async function shutdownServer() {
    const syncStatus = $('syncStatus');
    const btn = $('shutdownBtn');
    if (btn) btn.disabled = true;

    try {
        await fetch('/api/shutdown', { method: 'POST' });
    } catch (_) {
        // 忽略网络断开
    }

    if (syncStatus) {
        syncStatus.textContent = '🛑 本地服务已安全停止';
        syncStatus.style.color = '#a0aec0';
    }
    toast(TEXT_CONFIG.masthead.shutdownDone);
    if (btn) {
        btn.textContent = '已退出';
        btn.style.opacity = '0.5';
    }
}

// 从本地服务加载 Q 配置文件
export async function loadConfigFromBackend(onSuccess) {
    const syncStatus = $('syncStatus');
    if (syncStatus) {
        syncStatus.textContent = TEXT_CONFIG.masthead.syncReading;
        syncStatus.style.color = 'var(--text-muted)';
    }

    try {
        const res = await fetch('/api/config');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        if (data.text) {
            parseConfigFileText(data.text, appState.data);
            setInitialSnapshot(appState.data);
            const activeGroup = Number(appState.data.runnerSettings?.activeGroup);
            appState.curGroupIdx = (!isNaN(activeGroup) && activeGroup >= 0 && activeGroup < appState.data.groups.length) ? activeGroup : 3;
            appState.curSchemeIdx = 0;
            appState.curRoundIdx = 0;

            const shortPath = data.path.replace(/\\/g, '/').split('/').slice(-2).join('/');
            if (syncStatus) {
                syncStatus.textContent = formatText(TEXT_CONFIG.masthead.syncSuccess, { path: shortPath });
                syncStatus.style.color = '#68d391';
            }
            toast(formatText(TEXT_CONFIG.messages.autoLoadSuccess, { path: shortPath }));
            if (typeof onSuccess === 'function') onSuccess();
        }
    } catch (err) {
        console.warn(TEXT_CONFIG.messages.autoLoadFailWarn, err);
        if (syncStatus) {
            syncStatus.textContent = TEXT_CONFIG.masthead.syncLocalFallback;
            syncStatus.style.color = 'var(--gold)';
        }
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

// 检查模拟器 ADB 连接状态，并在“有待补推配置”且“模拟器刚连上”时自动补推
export async function checkAdbStatus(getConfigTextCallback) {
    const indicator = $('adbIndicator');
    if (!indicator) return;

    try {
        const res = await fetch('/api/adb/status');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        
        if (data.connected) {
            indicator.className = 'adb-badge connected';
            indicator.textContent = `📱 模拟器在线 (${data.device})`;
            indicator.title = `${data.message}\nADB路径: ${data.adb_path || ''}\n点击可手动再次同步`;

            // 核心条件：只有当保存过且此前模拟器未连接（存在待补推标记）时，才自动触发一次补推！
            if (hasPendingSimulatorSync) {
                hasPendingSimulatorSync = false; // 消费待补推标记
                if (typeof getConfigTextCallback === 'function') {
                    const text = getConfigTextCallback();
                    try {
                        const syncRes = await fetch('/api/sync', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json; charset=utf-8' },
                            body: JSON.stringify({ text })
                        });
                        const syncData = await syncRes.json();
                        if (syncData.success) {
                            toast(`⚡ 模拟器已连接，已自动补推未同步的配置 (${data.device})`);
                            const syncStatus = $('syncStatus');
                            if (syncStatus) {
                                syncStatus.textContent = `⚡ 模拟器已连接，已补推最新配置 (${data.device})`;
                                syncStatus.style.color = '#68d391';
                            }
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
            indicator.className = 'adb-badge offline';
            indicator.textContent = '📱 模拟器离线';
            indicator.title = `${data.message || '未连接模拟器'}\n每隔 10 秒自动检测重连，点击可立即检测`;
        }
    } catch (_) {
        indicator.className = 'adb-badge offline';
        indicator.textContent = '📱 模拟器离线';
        indicator.title = '无法连接本地服务或模拟器，每隔 10 秒自动检测，点击可立即重试';
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
    const syncStatus = $('syncStatus');
    const originalText = btn ? btn.textContent : '';

    if (btn) {
        btn.disabled = true;
        btn.textContent = TEXT_CONFIG.masthead.btnSaving;
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
            const savedPath = (data.path || '').replace(/\\/g, '/').split('/').slice(-2).join('/') || 'Q/battle_v4_config.q';
            
            let statusText = `✅ 已保存: ${savedPath}`;
            let toastText = `✅ 已保存到磁盘: ${savedPath}`;
            let statusColor = '#68d391';

            if (data.adb) {
                if (data.adb.success && data.adb.connected) {
                    hasPendingSimulatorSync = false;
                    const dev = data.adb.device || '模拟器';
                    statusText = `✅ 已保存工程与 PC 助手，并同步至模拟器 (${dev})`;
                    toastText += ` (⚡ 模拟器直推成功: ${dev}, ${data.adb.elapsed_ms || 0}ms)`;
                    statusColor = '#68d391';
                    const indicator = $('adbIndicator');
                    if (indicator) {
                        indicator.className = 'adb-badge connected';
                        indicator.textContent = `📱 模拟器在线 (${dev})`;
                    }
                } else {
                    hasPendingSimulatorSync = true; // 关键：保存过了但模拟器未连接，记录待补推
                    statusText = `✅ 已保存工程与 PC 助手 (⚠️ 模拟器未连接，连上后自动补推)`;
                    toastText += ` (⚠️ 模拟器未连接，已保存本地与 PC 助手，连上后自动补推)`;
                    statusColor = '#ecc94b';
                }
            }

            if (data.backup) {
                const bName = data.backup.replace(/\\/g, '/').split('/').pop();
                statusText += ` [快照: ${bName}]`;
            }

            toast(toastText);
            if (syncStatus) {
                syncStatus.textContent = statusText;
                syncStatus.style.color = statusColor;
            }
        } else {
            throw new Error(data.message || '保存失败');
        }
    } catch (err) {
        const errMsg = formatText(TEXT_CONFIG.messages.saveError, { error: err.message });
        toast(errMsg);
        if (syncStatus) {
            syncStatus.textContent = errMsg;
            syncStatus.style.color = '#fc8181';
        }
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.textContent = originalText;
        }
    }
}

