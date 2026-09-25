import { appState, setInitialSnapshot } from './state.js';
import { parseConfigFileText, setLastSavedConfigText, generateConfigText, isConfigDirty } from './dsl.js';
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

function getNowTimeString() {
    const d = new Date();
    const pad = n => String(n).padStart(2, '0');
    return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

// 统一更新配置同步与就绪状态胶囊
export function updateSyncStatus(type, label, tooltip) {
    const syncStatus = $('syncStatus');
    if (!syncStatus) return;
    syncStatus.className = `sync-status-badge ${type || ''}`.trim();
    syncStatus.textContent = label;
    if (tooltip !== undefined) {
        syncStatus.title = tooltip;
    }
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
    updateSyncStatus('', '⏳ 读取中...', '正在从本地磁盘读取配置文件 Q/battle_v4_config.q...');

    try {
        const res = await fetch('/api/config');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        if (data.text) {
            parseConfigFileText(data.text, appState.data);
            setInitialSnapshot(appState.data);
            setLastSavedConfigText(data.text);
            updateSaveButtonState();
            const activeGroup = Number(appState.data.runnerSettings?.activeGroup);
            appState.curGroupIdx = (!isNaN(activeGroup) && activeGroup >= 0 && activeGroup < appState.data.groups.length) ? activeGroup : 3;
            const activeGrp = appState.data.groups?.[appState.curGroupIdx];
            const defScheme = activeGrp?.defaultScheme;
            appState.curSchemeIdx = (typeof defScheme === 'number' && defScheme >= 1 && defScheme <= (activeGrp?.schemes?.length || 0)) ? defScheme - 1 : 0;
            appState.curRoundIdx = 0;

            const fullPath = data.path || 'Q/battle_v4_config.q';
            const shortPath = fullPath.replace(/\\/g, '/').split('/').slice(-2).join('/');
            const now = getNowTimeString();
            const activeGroupName = appState.data.groups?.[appState.curGroupIdx]?.name || `大组 ${appState.curGroupIdx}`;
            const tooltip = `【本地配置已就绪】\n• 来源文件：${shortPath}\n• 完整路径：${fullPath}\n• 载入时间：${now}\n• 生效战区：${activeGroupName}\n• 状态说明：本地配置已解析就绪，可随时编辑调整`;

            updateSyncStatus('ready', '✅ 配置已就绪', tooltip);
            toast(formatText(TEXT_CONFIG.messages.autoLoadSuccess, { path: shortPath }));
            if (typeof onSuccess === 'function') onSuccess();
        }
    } catch (err) {
        console.warn(TEXT_CONFIG.messages.autoLoadFailWarn, err);
        setLastSavedConfigText(generateConfigText(appState.data));
        updateSaveButtonState();
        updateSyncStatus('pending', '⚠️ 本地临时缓存', '【未连接到后端服务】\n• 无法连接本地 Python 服务 (端口 8098)\n• 当前使用内存初始配置，保存等高级功能受限');
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
                            const now = getNowTimeString();
                            const elapsed = syncData.elapsed_ms != null ? `${syncData.elapsed_ms}ms` : '毫秒级';
                            const tooltip = `【自动补推完成】\n• 连通设备：${data.device}\n• 直推目标：/sdcard/FGO_Q/battle_v4_config.mq\n• 传输耗时：${elapsed}\n• 触发原因：检测到模拟器连线恢复，自动完成挂起的配置同步\n• 补推时间：${now}`;
                            updateSyncStatus('synced', '✅ 补推已完成', tooltip);
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
            const savedPath = (data.path || '').replace(/\\/g, '/').split('/').slice(-2).join('/') || 'Q/battle_v4_config.q';
            const now = getNowTimeString();
            const bName = data.backup ? data.backup.replace(/\\/g, '/').split('/').pop() : '无';

            if (data.adb && data.adb.success && data.adb.connected) {
                hasPendingSimulatorSync = false;
                const dev = data.adb.device || '模拟器';
                const elapsed = data.adb.elapsed_ms != null ? `${data.adb.elapsed_ms}ms` : '毫秒级';
                const tooltip = `【保存并直推完成】\n• 源文件：${savedPath} (已落盘)\n• 历史快照：${bName}\n• PC 助手：已覆写本地工程目录\n• 模拟器：已直推 /sdcard/FGO_Q/ (设备: ${dev}, 耗时: ${elapsed})\n• 保存时间：${now}`;
                updateSyncStatus('synced', '✅ 已保存并直推', tooltip);
                toast(`✅ 已保存到磁盘并在约 ${elapsed} 内直推至模拟器 (${dev})`);
                const indicator = $('adbIndicator');
                if (indicator) {
                    indicator.className = 'adb-badge connected';
                    indicator.textContent = `📱 模拟器在线 (${dev})`;
                    indicator.title = `模拟器已连线: ${dev}\n点击可手动再次同步`;
                }
            } else {
                hasPendingSimulatorSync = true; // 关键：保存过了但模拟器未连接，记录待补推
                const tooltip = `【本地保存完成 / 模拟器待补推】\n• 源文件：${savedPath} (已落盘)\n• 历史快照：${bName}\n• PC 助手：已覆写本地工程目录\n• 模拟器：当前未连接，已挂起同步标记\n• 补推机制：模拟器开机就绪后，将由 10 秒轻量心跳自动静默补推\n• 保存时间：${now}`;
                updateSyncStatus('pending', '⚠️ 已保存 (待补推)', tooltip);
                toast(`✅ 已保存到本地工程与 PC 助手 (⚠️ 模拟器未连接，连上后自动补推)`);
            }
        } else {
            throw new Error(data.message || '保存失败');
        }
    } catch (err) {
        const errMsg = formatText(TEXT_CONFIG.messages.saveError, { error: err.message });
        toast(errMsg);
        updateSyncStatus('error', '❌ 保存失败', `【保存失败】\n• 错误原因：${err.message}\n• 建议：检查后台 Python 服务 (端口 8098) 是否存活或文件是否被独占`);
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

export function getCurrentRunnerState() {
    return currentRunnerState;
}

// 统一更新按键脚本状态徽标与控制按钮
export function updateRunnerUI(data) {
    const indicator = $('runnerIndicator');
    const runBtn = $('runBattleBtn');
    const stopBtn = $('stopBattleBtn');

    if (!indicator) return;

    // 辅助工具：无论此前处于何种状态，严格将控制按钮还原为就绪/待命形态
    const restoreReadyButtons = (runDisabled = false, runTitle = '') => {
        if (runBtn) {
            runBtn.style.display = 'inline-flex';
            runBtn.disabled = runDisabled;
            runBtn.textContent = '▶ 运行战斗';
            if (runTitle) runBtn.title = runTitle;
        }
        if (stopBtn) {
            stopBtn.style.display = 'none';
            stopBtn.disabled = false;
            stopBtn.textContent = '⏹ 停止战斗';
            stopBtn.title = '停止战斗';
        }
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
    // 如果之前正在战斗或正在停止，现在变回了 IDLE 或 OFFLINE，说明战斗已被成功停止/完成
    if (lastKnownRunnerState === 'RUNNING' || lastKnownRunnerState === 'STOPPING') {
        if (newState === 'IDLE') {
            toast('⏹ 战斗脚本已停止并返回待命（按钮已还原就绪）', 3200);
        } else if (newState === 'OFFLINE') {
            toast('⏹ 战斗脚本已退出停止（按钮已还原就绪）', 3200);
        }
    }

    lastKnownRunnerState = newState;
    currentRunnerState = newState;

    // 3. 根据新状态渲染顶部界面
    if (!data || !data.connected) {
        // 模拟器未连接
        indicator.className = 'runner-badge offline';
        indicator.textContent = '⚪ 脚本未启动';
        indicator.title = '模拟器离线或未连接\n启动模拟器后在按键助手或模拟器运行脚本';
        restoreReadyButtons(false, '模拟器未连接，点击查看引导');
    } else if (newState === 'OFFLINE') {
        // 模拟器在线，但按键脚本未启动或已退出
        indicator.className = 'runner-badge offline';
        const ageMsg = data.heartbeat_age_s ? ` (离线 ${data.heartbeat_age_s}s)` : '';
        indicator.textContent = `⚪ 脚本未启动${ageMsg}`;
        indicator.title = `${data.message || '模拟器在线，但按键脚本未在运行'}\n请在 PC 手机助手按 F5 启动 battle_v4_runner 进入待命`;
        restoreReadyButtons(false, '脚本未启动，点击查看启动引导（需在 PC 助手按 F5 启动）');
    } else if (newState === 'RUNNING') {
        // 战斗执行中
        indicator.className = 'runner-badge running';
        const roundText = data.total_rounds > 0 ? `第 ${data.round || 1}/${data.total_rounds} 轮` : `第 ${data.round || 1} 轮`;
        indicator.textContent = `⚔️ ${roundText}`;
        indicator.title = `【按键脚本战斗中】\n• 战斗进度：${roundText}\n• 当前动作：${data.action || '战斗执行中'}\n• 活跃时间：${data.time || ''}\n点击右侧可停止战斗`;

        if (runBtn) runBtn.style.display = 'none';
        if (stopBtn) {
            stopBtn.style.display = 'inline-flex';
            stopBtn.disabled = false;
            stopBtn.textContent = '⏹ 停止战斗';
            stopBtn.title = '点击停止战斗，脚本将在当前安全动作后停止并返回待命';
        }
    } else if (newState === 'STOPPING') {
        // 正在停止中
        indicator.className = 'runner-badge stopping';
        indicator.textContent = '⏳ 正在停止...';
        indicator.title = '正在等待战斗执行到安全节点并退出...';

        if (runBtn) runBtn.style.display = 'none';
        if (stopBtn) {
            stopBtn.style.display = 'inline-flex';
            stopBtn.disabled = true;
            stopBtn.textContent = '⏳ 停止中...';
            stopBtn.title = '正在等待战斗执行到安全节点并退出...';
        }
    } else {
        // IDLE 待命中
        indicator.className = 'runner-badge idle';
        indicator.textContent = '🟢 脚本待命';
        indicator.title = `【按键脚本已在后台待命】\n• 状态：随时可点击「▶ 运行战斗」即时启动\n• 最近心跳：${data.time || '刚刚'}\n• 提示消息：${data.message || '就绪'}`;

        restoreReadyButtons(false, '启动自动战斗（未保存改动将自动保存并直推至模拟器）');
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
            statusDot.title = '脚本未启动';
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
        const interval = (data && data.state === 'RUNNING') ? 1000 : 2500;
        runnerWatcherTimer = setTimeout(poll, interval);
    };

    poll();
}

// 网页直控：运行战斗
export async function triggerRunBattle(getConfigTextCallback) {
    const runBtn = $('runBattleBtn');

    // 1. 运行前先立即做一次毫秒级状态即时核实（消除轮询延迟）
    let currentData = null;
    try {
        currentData = await checkRunnerStatus();
    } catch (_) {}

    // 2. 模拟器连接检查
    if (!currentData || !currentData.connected) {
        toast('⚠️ 模拟器尚未连接，无法启动战斗！\n请先开启模拟器并确保 ADB 连通。', 4500);
        return;
    }

    // 3. 按键脚本启动状态检查：若离线/未启动，给出明确友好的文字提醒并阻断
    if (!currentData.alive || currentData.state === 'OFFLINE') {
        const tipMsg = '⚠️ 按键脚本尚未在模拟器中启动！\n\n' +
                       '📌 启动指引：\n' +
                       '1. 请在 PC 手机助手按 F5（或在模拟器按键精灵中启动 battle_v4_runner）；\n' +
                       '2. 待顶部状态显示为「🟢 脚本待命」；\n' +
                       '3. 再点击「▶ 运行战斗」即可秒级启动战斗。';
        toast(tipMsg, 7000);
        return;
    }

    // 4. 若已在战斗中，防止重复点击
    if (currentData.state === 'RUNNING') {
        toast('ℹ️ 战斗已经在执行中！\n若需终止，请点击右上角的「⏹ 停止战斗」。', 3500);
        return;
    }

    // 5. 状态确认就绪（IDLE 待命中），开始执行下发
    if (runBtn) {
        runBtn.disabled = true;
        runBtn.textContent = '⏳ 启动中...';
    }

    try {
        let configText = '';
        if (typeof getConfigTextCallback === 'function') {
            configText = getConfigTextCallback();
        }

        const res = await fetch('/api/run', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
            body: JSON.stringify({ text: configText })
        });
        const data = await res.json();

        if (data.success) {
            if (data.sync && data.sync.success) {
                setInitialSnapshot(appState.data);
                setLastSavedConfigText(configText);
                updateSaveButtonState();
                updateSyncStatus('synced', '✅ 已保存并同步', '运行前已自动保存最新配置并直推模拟器');
            }
            toast('🚀 战斗启动指令已下发！按键脚本正在执行...');
            await checkRunnerStatus();
        } else {
            toast(`⚠️ 启动战斗失败: ${data.message || '未知原因'}`);
            await checkRunnerStatus();
        }
    } catch (err) {
        toast(`❌ 下发启动指令异常: ${err.message}`);
        await checkRunnerStatus();
    } finally {
        if (runBtn && currentRunnerState !== 'RUNNING') {
            runBtn.disabled = false;
            runBtn.textContent = '▶ 运行战斗';
        }
    }
}

// 网页直控：停止战斗
export async function triggerStopBattle() {
    const stopBtn = $('stopBattleBtn');
    const runBtn = $('runBattleBtn');

    if (stopBtn) {
        stopBtn.disabled = true;
        stopBtn.textContent = '⏳ 正在停止...';
    }

    try {
        const res = await fetch('/api/stop', { method: 'POST' });
        const data = await res.json();
        if (data.success) {
            toast('⏹ 停止指令已下发，脚本将在当前安全动作后停止并返回待命', 3000);
        } else {
            toast(`⚠️ 下发停止指令失败: ${data.message || '未知原因'}`);
        }
    } catch (err) {
        toast(`❌ 停止异常: ${err.message}`);
    } finally {
        // 立即拉取最新状态
        const statusData = await checkRunnerStatus();
        // 兜底保护：若状态已经是 OFFLINE 或 IDLE（非战斗中），强制瞬间还原按钮，彻底杜绝状态卡滞
        if (!statusData || statusData.state !== 'RUNNING') {
            if (runBtn) {
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


