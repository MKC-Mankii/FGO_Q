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
            appState.curGroupIdx = 0;
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

// 保存配置到本地文件（支持后端自动备份快照）
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
            let msg = TEXT_CONFIG.messages.saveSuccess;
            if (data.backup) {
                const bName = data.backup.replace(/\\/g, '/').split('/').pop();
                msg += formatText(TEXT_CONFIG.messages.backupSuffix, { backup: bName });
            }
            toast(msg);
            if (syncStatus) {
                syncStatus.textContent = TEXT_CONFIG.masthead.syncSavedDisk;
                syncStatus.style.color = '#68d391';
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

