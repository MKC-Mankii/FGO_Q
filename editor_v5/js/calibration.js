/**
 * FGO_Q V5 Calibration Studio 视觉交互逻辑模块
 * - 支持同时在画面中呈现「运行时匹配范围 (Search Area)」与「截图裁切范围 (Crop Area)」
 * - 两个范围均支持双向鼠标交互框选与数值精细微调
 */
(function () {
    const state = {
        targets: [],
        selectedKey: null,
        currentCategory: 'all',
        screenImage: null, // Image 对象
        screenWidth: 0,
        screenHeight: 0,
        viewport: null,
        
        // 核心双套范围
        cropArea: null,    // 截图裁切范围 [x1, y1, x2, y2] (可为 null)
        searchArea: null,  // 运行时匹配搜图范围 [x1, y1, x2, y2]
        showCrop: true,    // 是否在画面中呈现截图选区 (默认显示)
        showSearch: true,  // 是否在画面中呈现匹配范围 (默认显示)
        activeMode: 'crop',// 当前可编辑目标: 'crop' | 'search' (同时仅能有一种)
        
        tapCoord: null,    // 点击锚点 [x, y]
        matchedRect: null, // [x, y, w, h] 测试匹配结果
        selectedDevice: null, // 当前选中的模拟器标识
        
        // 鼠标拖拽与手柄调整状态
        dragState: {
            action: null,
            target: null,
            startPos: [0, 0],
            initialRect: null
        }
    };

    const dom = {};

    function initDom() {
        dom.container = document.getElementById('calibrationView');
        dom.configView = document.getElementById('configViewMain');
        dom.extraView = document.getElementById('extraViewMain');
        dom.settingsBar = document.getElementById('runnerSettingsBar');
        dom.tabConfig = document.getElementById('tabNavConfig');
        dom.tabExtra = document.getElementById('tabNavExtra');
        dom.tabCalibrate = document.getElementById('tabNavCalibrate');

        dom.targetsList = document.getElementById('calTargetsList');
        dom.targetCountBadge = document.getElementById('calTargetCountBadge');
        dom.categoryTabs = document.querySelectorAll('.cal-cat-btn');

        dom.canvas = document.getElementById('calScreenCanvas');
        dom.ctx = dom.canvas ? dom.canvas.getContext('2d') : null;
        dom.emptyState = document.getElementById('calEmptyState');

        dom.deviceSelect = document.getElementById('calDeviceSelect');
        dom.btnRefreshDevices = document.getElementById('calBtnRefreshDevices');
        dom.btnCapture = document.getElementById('calBtnCapture');
        dom.btnTestMatch = document.getElementById('calBtnTestMatch');
        dom.btnSaveTarget = document.getElementById('calBtnSaveTarget');
        dom.screenBadge = document.getElementById('calScreenBadge');
        dom.chkShowCrop = document.getElementById('chkShowCrop');
        dom.chkShowSearch = document.getElementById('chkShowSearch');
        dom.radioEditCrop = document.getElementById('radioEditCrop');
        dom.radioEditSearch = document.getElementById('radioEditSearch');
        dom.layerCropItem = document.getElementById('layerCropItem');
        dom.layerSearchItem = document.getElementById('layerSearchItem');

        dom.targetName = document.getElementById('calTargetName');
        dom.targetKey = document.getElementById('calTargetKey');
        dom.targetAnchor = document.getElementById('calTargetAnchor');
        dom.targetDesc = document.getElementById('calTargetDesc');

        // 截图选区控件
        dom.cropX1 = document.getElementById('calCropX1');
        dom.cropY1 = document.getElementById('calCropY1');
        dom.cropX2 = document.getElementById('calCropX2');
        dom.cropY2 = document.getElementById('calCropY2');
        dom.cropSizeBadge = document.getElementById('calCropSizeBadge');
        dom.btnAutoDetectCrop = document.getElementById('btnAutoDetectCrop');

        // 匹配范围控件
        dom.searchX1 = document.getElementById('calSearchX1');
        dom.searchY1 = document.getElementById('calSearchY1');
        dom.searchX2 = document.getElementById('calSearchX2');
        dom.searchY2 = document.getElementById('calSearchY2');
        dom.searchSizeBadge = document.getElementById('calSearchSizeBadge');
        dom.btnExpandSearchFromCrop = document.getElementById('btnExpandSearchFromCrop');

        // 点击锚点控件
        dom.inTapX = document.getElementById('calInTapX');
        dom.inTapY = document.getElementById('calInTapY');

        dom.previewImg = document.getElementById('calPreviewImg');
        dom.previewSourceBadge = document.getElementById('calPreviewSourceBadge');
        dom.previewPlaceholder = document.getElementById('calPreviewPlaceholder');
        dom.matchResult = document.getElementById('calMatchResult');
        dom.cardCrop = document.querySelector('.cal-card-crop');
        dom.cardSearch = document.querySelector('.cal-card-search');
        dom.saveTip = document.getElementById('calSaveTip');
    }

    // 保存按钮旁的状态提示胶囊
    function setSaveStatusTip(type, msg, duration = 4000) {
        if (!dom.saveTip) {
            dom.saveTip = document.getElementById('calSaveTip');
        }
        if (!dom.saveTip) return;
        dom.saveTip.className = `cal-save-tip ${type}`;
        dom.saveTip.textContent = msg;
        dom.saveTip.style.display = 'inline-flex';
        clearTimeout(setSaveStatusTip.timer);
        if (duration > 0) {
            setSaveStatusTip.timer = setTimeout(() => {
                if (dom.saveTip) {
                    dom.saveTip.style.display = 'none';
                }
            }, duration);
        }
    }

    // 安全消息轻提示，优先使用全局方法，降级使用原生 DOM，避免与 DOM 元素 window.toast 冲突报错
    function showToast(msg) {
        if (typeof window.toast === 'function') {
            try {
                window.toast(msg);
                return;
            } catch (err) {
                console.warn('[Calibration] window.toast 执行失败，使用本地降级提示:', err);
            }
        }
        const t = document.getElementById('toast');
        if (t) {
            t.textContent = msg;
            t.classList.add('show');
            clearTimeout(showToast.timer);
            showToast.timer = setTimeout(() => t.classList.remove('show'), 2400);
        }
    }

    // 视图切换
    window.switchEditorView = function (viewName) {
        if (!dom.container) {
            initDom();
        }
        const shell = document.querySelector('.shell');
        const subtext = document.querySelector('.masthead-bottom-row .subtext');
        const twinBattle = document.getElementById('btnRunBattle');
        const twinExtra = document.getElementById('btnRunExtra');

        if (viewName === 'calibrate') {
            console.log('[Calibration] 切换到屏幕标定与资产工作台');
            if (dom.configView) dom.configView.style.display = 'none';
            if (dom.settingsBar) dom.settingsBar.style.display = 'none';
            if (dom.extraView) dom.extraView.style.display = 'none';
            if (dom.container) dom.container.classList.add('active');
            if (shell) shell.classList.add('calibration-active');

            if (dom.tabConfig) dom.tabConfig.classList.remove('active');
            if (dom.tabExtra) dom.tabExtra.classList.remove('active');
            if (dom.tabCalibrate) dom.tabCalibrate.classList.add('active');

            if (subtext) subtext.textContent = '校准不同分辨率与环境下的界面找图区域与点击坐标。';
            if (twinBattle) twinBattle.classList.remove('context-active');
            if (twinExtra) twinExtra.classList.remove('context-active');

            loadTargets();
            if (window.checkAdbStatus) {
                window.checkAdbStatus();
            }
            if (!state.screenImage) {
                captureScreen({ silent: true });
            }
        } else if (viewName === 'extra') {
            console.log('[View] 切换到整备工作台');
            if (dom.container) dom.container.classList.remove('active');
            if (shell) shell.classList.remove('calibration-active');
            if (dom.configView) dom.configView.style.display = 'none';
            if (dom.settingsBar) dom.settingsBar.style.display = 'none';
            if (dom.extraView) dom.extraView.style.display = '';

            if (dom.tabConfig) dom.tabConfig.classList.remove('active');
            if (dom.tabCalibrate) dom.tabCalibrate.classList.remove('active');
            if (dom.tabExtra) dom.tabExtra.classList.add('active');

            if (subtext) subtext.textContent = '自动化执行从者强化、礼装强化、技能升级、友情点召唤与无限池抽奖。';
            if (twinBattle) twinBattle.classList.remove('context-active');
            if (twinExtra) twinExtra.classList.add('context-active');
        } else {
            console.log('[View] 切换到战术配置时序视图');
            if (dom.container) dom.container.classList.remove('active');
            if (shell) shell.classList.remove('calibration-active');
            if (dom.extraView) dom.extraView.style.display = 'none';
            if (dom.configView) dom.configView.style.display = '';
            if (dom.settingsBar) dom.settingsBar.style.display = '';

            if (dom.tabCalibrate) dom.tabCalibrate.classList.remove('active');
            if (dom.tabExtra) dom.tabExtra.classList.remove('active');
            if (dom.tabConfig) dom.tabConfig.classList.add('active');

            if (subtext) subtext.textContent = '可视化配置各关卡技能、换人与出牌时序。';
            if (twinBattle) twinBattle.classList.add('context-active');
            if (twinExtra) twinExtra.classList.remove('context-active');
        }
    };

    // 交互模式切换 (同时仅有一种处于可编辑状态，设为可编辑时自动保证其显示)
    function setEditMode(mode) {
        state.activeMode = mode;

        if (mode === 'crop') {
            state.showCrop = true;
            if (dom.chkShowCrop) dom.chkShowCrop.checked = true;
            if (dom.radioEditCrop) dom.radioEditCrop.checked = true;
            if (dom.layerCropItem) dom.layerCropItem.classList.add('is-editing');
            if (dom.layerSearchItem) dom.layerSearchItem.classList.remove('is-editing');
            if (dom.cardCrop) dom.cardCrop.classList.add('active-mode');
            if (dom.cardSearch) dom.cardSearch.classList.remove('active-mode');
        } else if (mode === 'search') {
            state.showSearch = true;
            if (dom.chkShowSearch) dom.chkShowSearch.checked = true;
            if (dom.radioEditSearch) dom.radioEditSearch.checked = true;
            if (dom.layerSearchItem) dom.layerSearchItem.classList.add('is-editing');
            if (dom.layerCropItem) dom.layerCropItem.classList.remove('is-editing');
            if (dom.cardSearch) dom.cardSearch.classList.add('active-mode');
            if (dom.cardCrop) dom.cardCrop.classList.remove('active-mode');
        }
        renderCanvas();
    }

    // 加载目标清单
    async function loadTargets() {
        try {
            const res = await fetch('/api/calibrate/targets');
            const data = await res.json();
            state.targets = data.targets || [];
            renderTargetsList();
            if (!state.selectedKey && state.targets.length > 0) {
                selectTarget(state.targets[0].key);
            }
        } catch (e) {
            console.error('Failed to load targets:', e);
        }
    }

    function renderTargetsList() {
        if (!dom.targetsList) return;
        dom.targetsList.innerHTML = '';

        const filtered = state.targets.filter(t => {
            if (state.currentCategory === 'all') return true;
            return t.category === state.currentCategory;
        });

        if (dom.targetCountBadge) {
            if (state.currentCategory === 'all') {
                dom.targetCountBadge.textContent = `${state.targets.length} 项`;
            } else {
                dom.targetCountBadge.textContent = `${filtered.length} / ${state.targets.length} 项`;
            }
        }

        filtered.forEach(t => {
            const isTap = t.category === 'tap';
            const item = document.createElement('div');
            item.className = 'cal-target-item' + (t.key === state.selectedKey ? ' selected' : '');
            item.onclick = () => selectTarget(t.key);

            const dot = document.createElement('div');
            if (isTap) {
                dot.className = 'cal-target-status-dot tap' + (t.tap_coord ? ' active' : '');
                dot.title = t.tap_coord ? `纯点击锚点: (${t.tap_coord[0]}, ${t.tap_coord[1]})` : '纯点击锚点 (未设坐标)';
            } else {
                dot.className = 'cal-target-status-dot' + (t.has_image ? ' active' : '');
                dot.title = t.has_image ? '已存在本地标定图片' : '未标定（待截图）';
            }

            const thumb = document.createElement('div');
            thumb.className = 'cal-target-thumb';
            if (isTap) {
                thumb.innerHTML = `<span style="font-size:16px;">🎯</span>`;
            } else if (t.has_image && t.image_url) {
                thumb.innerHTML = `<img src="${t.image_url}" alt="${t.name}">`;
            } else {
                thumb.innerHTML = `<span style="font-size:10px; color:#4a5568;">无图</span>`;
            }

            const info = document.createElement('div');
            info.className = 'cal-target-info';
            const tapSub = t.tap_coord ? `Tap (${t.tap_coord[0]}, ${t.tap_coord[1]})` : '未设坐标';
            const subText = isTap ? tapSub : (t.file || '待截图');
            info.innerHTML = `
                <div class="cal-target-title">${t.name}</div>
                <div class="cal-target-sub">${subText}</div>
            `;

            item.appendChild(dot);
            item.appendChild(thumb);
            item.appendChild(info);
            dom.targetsList.appendChild(item);
        });
    }

    function selectTarget(key) {
        state.selectedKey = key;
        state.matchedRect = null;
        if (dom.matchResult) dom.matchResult.style.display = 'none';

        const target = state.targets.find(t => t.key === key);
        if (!target) return;

        // 更新列表选中态
        document.querySelectorAll('.cal-target-item').forEach(el => el.classList.remove('selected'));
        const curIdx = state.targets.filter(t => state.currentCategory === 'all' || t.category === state.currentCategory).findIndex(t => t.key === key);
        if (curIdx >= 0 && dom.targetsList.children[curIdx]) {
            dom.targetsList.children[curIdx].classList.add('selected');
        }

        // 更新右侧面板属性
        if (dom.targetName) dom.targetName.textContent = target.name;
        if (dom.targetKey) dom.targetKey.textContent = target.key;
        if (dom.targetAnchor) dom.targetAnchor.value = target.anchor || 'center';
        if (dom.targetDesc) dom.targetDesc.textContent = target.description || '暂无描述';

        const isTap = target.category === 'tap';

        // 载入双套坐标范围
        if (isTap) {
            state.searchArea = target.search_area ? [...target.search_area] : null;
            state.cropArea = target.crop_area ? [...target.crop_area] : null;
            state.tapCoord = target.tap_coord ? [...target.tap_coord] : null;

            if (dom.btnSaveTarget) {
                dom.btnSaveTarget.textContent = '💾 保存点击锚点';
                dom.btnSaveTarget.title = '更新本地配置中的纯点击坐标与锚点属性';
            }
            if (dom.btnTestMatch) dom.btnTestMatch.style.display = 'none';
        } else {
            state.searchArea = target.search_area ? [...target.search_area] : (target.area ? [...target.area] : [0, 0, 1440, 810]);
            state.cropArea = target.crop_area ? [...target.crop_area] : null;
            state.tapCoord = target.tap_coord ? [...target.tap_coord] : null;

            if (dom.btnSaveTarget) {
                dom.btnSaveTarget.textContent = '💾 保存选区配置并推送';
                dom.btnSaveTarget.title = '保存截图选区与匹配范围，更新本地配置并推送到模拟器 /sdcard/FGO_Q/images/';
            }
            if (dom.btnTestMatch) dom.btnTestMatch.style.display = '';
        }

        // 默认进入截图编辑模式
        setEditMode('crop');

        updateInputsFromState();
        updatePreview();
        renderCanvas();
    }

    function updateInputsFromState() {
        // 1. 截图选区 inputs
        if (state.cropArea && state.cropArea.length === 4) {
            const [cx1, cy1, cx2, cy2] = state.cropArea;
            if (dom.cropX1) dom.cropX1.value = cx1;
            if (dom.cropY1) dom.cropY1.value = cy1;
            if (dom.cropX2) dom.cropX2.value = cx2;
            if (dom.cropY2) dom.cropY2.value = cy2;
            const cw = cx2 - cx1;
            const ch = cy2 - cy1;
            if (dom.cropSizeBadge) {
                dom.cropSizeBadge.textContent = `${cw} × ${ch} px`;
                dom.cropSizeBadge.style.color = '#68d391';
            }
        } else {
            if (dom.cropX1) dom.cropX1.value = '';
            if (dom.cropY1) dom.cropY1.value = '';
            if (dom.cropX2) dom.cropX2.value = '';
            if (dom.cropY2) dom.cropY2.value = '';
            if (dom.cropSizeBadge) {
                dom.cropSizeBadge.textContent = '未预设';
                dom.cropSizeBadge.style.color = '#ecc94b';
            }
        }

        // 2. 运行时匹配范围 inputs
        if (state.searchArea && state.searchArea.length === 4) {
            const [sx1, sy1, sx2, sy2] = state.searchArea;
            if (dom.searchX1) dom.searchX1.value = sx1;
            if (dom.searchY1) dom.searchY1.value = sy1;
            if (dom.searchX2) dom.searchX2.value = sx2;
            if (dom.searchY2) dom.searchY2.value = sy2;
            const sw = sx2 - sx1;
            const sh = sy2 - sy1;
            if (dom.searchSizeBadge) {
                dom.searchSizeBadge.textContent = `${sw} × ${sh} px`;
                dom.searchSizeBadge.style.color = '#63b3ed';
            }
        } else {
            if (dom.searchX1) dom.searchX1.value = '';
            if (dom.searchY1) dom.searchY1.value = '';
            if (dom.searchX2) dom.searchX2.value = '';
            if (dom.searchY2) dom.searchY2.value = '';
            if (dom.searchSizeBadge) {
                dom.searchSizeBadge.textContent = '-';
                dom.searchSizeBadge.style.color = '#718096';
            }
        }

        // 3. 点击锚点
        if (state.tapCoord) {
            if (dom.inTapX) dom.inTapX.value = state.tapCoord[0];
            if (dom.inTapY) dom.inTapY.value = state.tapCoord[1];
        } else {
            if (dom.inTapX) dom.inTapX.value = '';
            if (dom.inTapY) dom.inTapY.value = '';
        }
    }

    // 从 inputs 更新 state
    function updateStateFromInputs() {
        // 读取截图范围
        const cx1 = parseInt(dom.cropX1.value);
        const cy1 = parseInt(dom.cropY1.value);
        const cx2 = parseInt(dom.cropX2.value);
        const cy2 = parseInt(dom.cropY2.value);
        if (!isNaN(cx1) && !isNaN(cy1) && !isNaN(cx2) && !isNaN(cy2)) {
            state.cropArea = [cx1, cy1, cx2, cy2];
        }

        // 读取匹配范围
        const sx1 = parseInt(dom.searchX1.value);
        const sy1 = parseInt(dom.searchY1.value);
        const sx2 = parseInt(dom.searchX2.value);
        const sy2 = parseInt(dom.searchY2.value);
        if (!isNaN(sx1) && !isNaN(sy1) && !isNaN(sx2) && !isNaN(sy2)) {
            state.searchArea = [sx1, sy1, sx2, sy2];
        }

        // 读取锚点
        const tx = parseInt(dom.inTapX.value);
        const ty = parseInt(dom.inTapY.value);
        if (!isNaN(tx) && !isNaN(ty)) {
            state.tapCoord = [tx, ty];
        } else {
            state.tapCoord = null;
        }

        updateInputsFromState();
        updatePreview();
        renderCanvas();
    }

    // 抓取模拟器当前屏幕
    async function captureScreen(options = {}) {
        const silent = Boolean(options && options.silent === true);
        if (dom.btnCapture) {
            dom.btnCapture.disabled = true;
            dom.btnCapture.textContent = '📸 正在抓屏...';
        }
        try {
            const dev = (dom.deviceSelect ? dom.deviceSelect.value : '') || state.selectedDevice || '';
            const url = dev ? `/api/calibrate/screen?device=${encodeURIComponent(dev)}` : '/api/calibrate/screen';
            const res = await fetch(url);
            const data = await res.json();
            if (!data.success) {
                console.warn('[Calibration] 抓取屏幕失败:', data.error || '未知原因');
                if (!silent) {
                    showToast('抓取屏幕失败: ' + (data.error || '未知原因'));
                }
                return;
            }

            if (data.device) {
                state.selectedDevice = data.device;
                if (dom.deviceSelect && dom.deviceSelect.value !== data.device) {
                    dom.deviceSelect.value = data.device;
                }
            }

            state.screenWidth = data.width;
            state.screenHeight = data.height;
            state.viewport = data.viewport;

            if (dom.screenBadge) {
                dom.screenBadge.textContent = `${data.width}×${data.height} (${data.viewport.screen_ratio.toFixed(2)}:1)`;
            }

            const img = new Image();
            img.onload = function () {
                state.screenImage = img;
                if (dom.emptyState) dom.emptyState.style.display = 'none';
                dom.canvas.width = data.width;
                dom.canvas.height = data.height;
                renderCanvas();
                updatePreview();
            };
            img.src = data.image_base64;
        } catch (e) {
            console.error('[Calibration] Capture screen error:', e);
            if (!silent) {
                showToast('请求截屏接口异常: ' + e.message);
            }
        } finally {
            if (dom.btnCapture) {
                dom.btnCapture.disabled = false;
                dom.btnCapture.textContent = '📸 截取当前画面';
            }
        }
    }

    // 获取矩形的 8 个控制手柄坐标
    function getRectHandles(rect) {
        if (!rect || rect.length !== 4) return null;
        const x1 = Math.min(rect[0], rect[2]);
        const y1 = Math.min(rect[1], rect[3]);
        const x2 = Math.max(rect[0], rect[2]);
        const y2 = Math.max(rect[1], rect[3]);
        const midX = Math.round((x1 + x2) / 2);
        const midY = Math.round((y1 + y2) / 2);
        return {
            nw: [x1, y1],
            n:  [midX, y1],
            ne: [x2, y1],
            e:  [x2, midY],
            se: [x2, y2],
            s:  [midX, y2],
            sw: [x1, y2],
            w:  [x1, midY]
        };
    }

    // 命中手柄检测 (像素容差 radius)
    function hitTestHandle(cx, cy, rect, radius = 9) {
        const handles = getRectHandles(rect);
        if (!handles) return null;
        for (const [key, [hx, hy]] of Object.entries(handles)) {
            if (Math.hypot(cx - hx, cy - hy) <= radius) {
                return key;
            }
        }
        return null;
    }

    // 辅助测试点击点是否命中矩形内部
    function isInsideRect(cx, cy, rect) {
        if (!rect || rect.length !== 4) return false;
        const x1 = Math.min(rect[0], rect[2]);
        const y1 = Math.min(rect[1], rect[3]);
        const x2 = Math.max(rect[0], rect[2]);
        const y2 = Math.max(rect[1], rect[3]);
        return cx >= x1 && cx <= x2 && cy >= y1 && cy <= y2;
    }

    // 绘制 8 个控制手柄
    function drawHandles(rect, strokeColor, fillColor) {
        const handles = getRectHandles(rect);
        if (!handles) return;
        const handleSize = 7;
        dom.ctx.fillStyle = fillColor;
        dom.ctx.strokeStyle = strokeColor;
        dom.ctx.lineWidth = 1.5;
        for (const [key, [px, py]] of Object.entries(handles)) {
            dom.ctx.fillRect(px - handleSize / 2, py - handleSize / 2, handleSize, handleSize);
            dom.ctx.strokeRect(px - handleSize / 2, py - handleSize / 2, handleSize, handleSize);
        }
    }

    // 绘制 Canvas：同时渲染匹配范围 (蓝) 与截图选区 (绿)，且均呈现清晰标识
    function renderCanvas() {
        if (!dom.ctx || !state.screenImage) return;

        dom.ctx.clearRect(0, 0, dom.canvas.width, dom.canvas.height);
        // 1. 底层模拟器截屏
        dom.ctx.drawImage(state.screenImage, 0, 0);

        // 2. 黑边与安全视口
        if (state.viewport && state.viewport.offset_x > 0) {
            dom.ctx.fillStyle = 'rgba(0, 0, 0, 0.45)';
            dom.ctx.fillRect(0, 0, state.viewport.offset_x, dom.canvas.height);
            dom.ctx.fillRect(dom.canvas.width - state.viewport.offset_x, 0, state.viewport.offset_x, dom.canvas.height);
            dom.ctx.strokeStyle = 'rgba(255, 255, 255, 0.2)';
            dom.ctx.lineWidth = 1;
            dom.ctx.setLineDash([4, 4]);
            dom.ctx.strokeRect(state.viewport.offset_x, 0, state.viewport.viewport_w, state.viewport.viewport_h);
            dom.ctx.setLineDash([]);
        }

        // 3. 测试匹配命中结果 (高亮亮绿框)
        if (state.matchedRect) {
            const [mx, my, mw, mh] = state.matchedRect;
            dom.ctx.save();
            dom.ctx.strokeStyle = '#38a169';
            dom.ctx.lineWidth = 3;
            dom.ctx.fillStyle = 'rgba(72, 187, 120, 0.2)';
            dom.ctx.fillRect(mx, my, mw, mh);
            dom.ctx.strokeRect(mx, my, mw, mh);

            dom.ctx.fillStyle = '#48bb78';
            dom.ctx.font = 'bold 13px sans-serif';
            dom.ctx.fillText('✔ 匹配命中', mx, Math.max(20, my - 6));
            dom.ctx.restore();
        }

        // 4. 绘制运行时匹配搜索范围 (蓝色，虚线/高亮)
        let hasSearch = false;
        let sTagY = 16;
        if (state.showSearch && state.searchArea && state.searchArea.length === 4) {
            const sx1 = Math.min(state.searchArea[0], state.searchArea[2]);
            const sy1 = Math.min(state.searchArea[1], state.searchArea[3]);
            const sx2 = Math.max(state.searchArea[0], state.searchArea[2]);
            const sy2 = Math.max(state.searchArea[1], state.searchArea[3]);
            const sw = sx2 - sx1;
            const sh = sy2 - sy1;
            const isAct = (state.activeMode === 'search');
            hasSearch = true;

            dom.ctx.save();
            dom.ctx.fillStyle = isAct ? 'rgba(49, 130, 206, 0.16)' : 'rgba(49, 130, 206, 0.08)';
            dom.ctx.fillRect(sx1, sy1, sw, sh);

            dom.ctx.strokeStyle = isAct ? '#63b3ed' : '#3182ce';
            dom.ctx.lineWidth = isAct ? 2.5 : 1.5;
            if (!isAct) {
                dom.ctx.setLineDash([6, 4]);
            } else {
                dom.ctx.setLineDash([]);
                dom.ctx.shadowColor = 'rgba(66, 153, 225, 0.8)';
                dom.ctx.shadowBlur = 8;
            }
            dom.ctx.strokeRect(sx1, sy1, sw, sh);
            dom.ctx.setLineDash([]);
            dom.ctx.shadowBlur = 0;

            if (isAct) {
                drawHandles([sx1, sy1, sx2, sy2], '#3182ce', '#ffffff');
            }

            // 匹配范围标签徽标
            const tagText = `🔍 匹配范围: ${sw}×${sh}`;
            dom.ctx.font = 'bold 11px monospace';
            const tw = dom.ctx.measureText(tagText).width;
            sTagY = Math.max(16, sy1 - 4);
            dom.ctx.fillStyle = 'rgba(23, 28, 38, 0.88)';
            dom.ctx.fillRect(sx1, sTagY - 12, tw + 10, 15);
            dom.ctx.strokeStyle = '#3182ce';
            dom.ctx.lineWidth = 1;
            dom.ctx.strokeRect(sx1, sTagY - 12, tw + 10, 15);
            dom.ctx.fillStyle = '#63b3ed';
            dom.ctx.fillText(tagText, sx1 + 5, sTagY - 1);
            dom.ctx.restore();
        }

        // 5. 绘制截图裁切选区范围 (绿色，实线/光晕)
        if (state.showCrop && state.cropArea && state.cropArea.length === 4) {
            const cx1 = Math.min(state.cropArea[0], state.cropArea[2]);
            const cy1 = Math.min(state.cropArea[1], state.cropArea[3]);
            const cx2 = Math.max(state.cropArea[0], state.cropArea[2]);
            const cy2 = Math.max(state.cropArea[1], state.cropArea[3]);
            const cw = cx2 - cx1;
            const ch = cy2 - cy1;
            const isAct = (state.activeMode === 'crop');

            dom.ctx.save();
            dom.ctx.fillStyle = isAct ? 'rgba(72, 187, 120, 0.22)' : 'rgba(72, 187, 120, 0.12)';
            dom.ctx.fillRect(cx1, cy1, cw, ch);

            dom.ctx.strokeStyle = isAct ? '#48bb78' : '#38a169';
            dom.ctx.lineWidth = isAct ? 3 : 2;
            if (isAct) {
                dom.ctx.shadowColor = 'rgba(72, 187, 120, 0.9)';
                dom.ctx.shadowBlur = 10;
            }
            dom.ctx.strokeRect(cx1, cy1, cw, ch);
            dom.ctx.shadowBlur = 0;

            if (isAct) {
                drawHandles([cx1, cy1, cx2, cy2], '#48bb78', '#ffffff');
            }

            // 截图选区标签徽标 (智能防重叠避让)
            const tagText = `✂️ 截图选区: ${cw}×${ch}`;
            dom.ctx.font = 'bold 11px monospace';
            const tw = dom.ctx.measureText(tagText).width;
            let cTagY = Math.max(16, cy1 - 4);
            if (hasSearch && Math.abs(cTagY - sTagY) < 20) {
                // 若顶部重叠，截图框标签下移到底部
                cTagY = Math.min(dom.canvas.height - 4, cy2 + 16);
            }
            dom.ctx.fillStyle = 'rgba(23, 28, 38, 0.88)';
            dom.ctx.fillRect(cx1, cTagY - 12, tw + 10, 15);
            dom.ctx.strokeStyle = '#48bb78';
            dom.ctx.lineWidth = 1;
            dom.ctx.strokeRect(cx1, cTagY - 12, tw + 10, 15);
            dom.ctx.fillStyle = '#68d391';
            dom.ctx.fillText(tagText, cx1 + 5, cTagY - 1);
            dom.ctx.restore();
        }

        // 6. 绘制点击锚点 (Tap Point 红十字准星)
        if (state.tapCoord) {
            const [tx, ty] = state.tapCoord;
            const curTarget = state.targets.find(t => t.key === state.selectedKey);
            const isTap = curTarget && curTarget.category === 'tap';
            const r = isTap ? 16 : 12;

            dom.ctx.save();
            dom.ctx.strokeStyle = '#e53e3e';
            dom.ctx.lineWidth = 2;

            dom.ctx.beginPath();
            dom.ctx.moveTo(tx - r, ty);
            dom.ctx.lineTo(tx + r, ty);
            dom.ctx.moveTo(tx, ty - r);
            dom.ctx.lineTo(tx, ty + r);
            dom.ctx.stroke();

            dom.ctx.beginPath();
            dom.ctx.arc(tx, ty, 4, 0, Math.PI * 2);
            dom.ctx.fillStyle = '#e53e3e';
            dom.ctx.fill();

            if (isTap) {
                dom.ctx.beginPath();
                dom.ctx.arc(tx, ty, 20, 0, Math.PI * 2);
                dom.ctx.strokeStyle = 'rgba(245, 101, 101, 0.65)';
                dom.ctx.lineWidth = 2;
                dom.ctx.stroke();

                dom.ctx.fillStyle = '#feb2b2';
                dom.ctx.font = 'bold 12px sans-serif';
                dom.ctx.fillText(`🎯 ${curTarget.name} (${tx}, ${ty})`, tx + 14, ty - 8);
            } else {
                dom.ctx.fillStyle = '#fc8181';
                dom.ctx.font = 'bold 11px sans-serif';
                dom.ctx.fillText(`Tap (${tx}, ${ty})`, tx + 8, ty - 6);
            }
            dom.ctx.restore();
        }
    }

    // 更新右侧特征小图预览 (严格基于截图选区 cropArea，纯点击目标展示放大十字准星，绝不混用 searchArea)
    function updatePreview() {
        const target = state.targets.find(t => t.key === state.selectedKey);
        const badge = dom.previewSourceBadge;
        const placeholder = dom.previewPlaceholder;
        const isTap = target && target.category === 'tap';

        // 0. 如果是纯点击锚点
        if (isTap) {
            if (state.tapCoord && state.screenImage) {
                const [tx, ty] = state.tapCoord;
                const cropW = 140;
                const cropH = 140;
                const x1 = Math.max(0, Math.min(state.screenWidth - cropW, tx - Math.floor(cropW / 2)));
                const y1 = Math.max(0, Math.min(state.screenHeight - cropH, ty - Math.floor(cropH / 2)));

                const offCanvas = document.createElement('canvas');
                offCanvas.width = cropW;
                offCanvas.height = cropH;
                const offCtx = offCanvas.getContext('2d');
                offCtx.drawImage(state.screenImage, x1, y1, cropW, cropH, 0, 0, cropW, cropH);

                // 绘制中心准星
                const cx = tx - x1;
                const cy = ty - y1;
                offCtx.strokeStyle = '#e53e3e';
                offCtx.lineWidth = 2;
                offCtx.beginPath();
                offCtx.moveTo(cx - 12, cy); offCtx.lineTo(cx + 12, cy);
                offCtx.moveTo(cx, cy - 12); offCtx.lineTo(cx, cy + 12);
                offCtx.stroke();
                offCtx.beginPath();
                offCtx.arc(cx, cy, 3, 0, Math.PI * 2);
                offCtx.fillStyle = '#e53e3e';
                offCtx.fill();

                if (dom.previewImg) {
                    dom.previewImg.src = offCanvas.toDataURL('image/png');
                    dom.previewImg.style.display = 'block';
                }
                if (placeholder) placeholder.style.display = 'none';
                if (badge) {
                    badge.textContent = `点击锚点局部 (${tx}, ${ty})`;
                    badge.style.color = '#fc8181';
                }
                return;
            } else {
                if (dom.previewImg) {
                    dom.previewImg.src = '';
                    dom.previewImg.style.display = 'none';
                }
                if (placeholder) {
                    placeholder.style.display = 'block';
                    placeholder.innerHTML = `🎯 纯点击锚点<br><span style="font-size:10px; color:#fc8181;">坐标: (${state.tapCoord ? state.tapCoord.join(', ') : '未设置'})</span><br><span style="font-size:10px; color:#a0aec0;">在画面中左键点击可直接移动锚点</span>`;
                }
                if (badge) {
                    badge.textContent = '纯点击锚点';
                    badge.style.color = '#fc8181';
                }
                return;
            }
        }

        // 1. 如果存在有效的截图选区 cropArea，且当前已截取加载了模拟器屏幕
        if (state.cropArea && state.cropArea.length === 4) {
            const x1 = Math.min(state.cropArea[0], state.cropArea[2]);
            const y1 = Math.min(state.cropArea[1], state.cropArea[3]);
            const x2 = Math.max(state.cropArea[0], state.cropArea[2]);
            const y2 = Math.max(state.cropArea[1], state.cropArea[3]);
            const w = x2 - x1;
            const h = y2 - y1;

            if (w > 0 && h > 0 && state.screenImage) {
                const offCanvas = document.createElement('canvas');
                offCanvas.width = w;
                offCanvas.height = h;
                const offCtx = offCanvas.getContext('2d');
                offCtx.drawImage(state.screenImage, x1, y1, w, h, 0, 0, w, h);

                if (dom.previewImg) {
                    dom.previewImg.src = offCanvas.toDataURL('image/png');
                    dom.previewImg.style.display = 'block';
                }
                if (placeholder) placeholder.style.display = 'none';
                if (badge) {
                    badge.textContent = `实时截图选区 (${w}×${h})`;
                    badge.style.color = '#68d391';
                }
                return;
            }
        }

        // 2. 若未框选 cropArea，则展示当前目标在仓库中的既有特征图
        if (target && target.image_url) {
            if (dom.previewImg) {
                dom.previewImg.src = target.image_url;
                dom.previewImg.style.display = 'block';
            }
            if (placeholder) placeholder.style.display = 'none';
            if (badge) {
                badge.textContent = '库内存档特征图 (待框选重截)';
                badge.style.color = '#ecc94b';
            }
        } else {
            // 3. 既无截图选区，也无库内图片
            if (dom.previewImg) {
                dom.previewImg.src = '';
                dom.previewImg.style.display = 'none';
            }
            if (placeholder) placeholder.style.display = 'block';
            if (badge) {
                badge.textContent = '未预设选区';
                badge.style.color = '#a0aec0';
            }
        }
    }

    // 光标映射表
    const CURSOR_MAP = {
        nw: 'nwse-resize',
        se: 'nwse-resize',
        ne: 'nesw-resize',
        sw: 'nesw-resize',
        n:  'ns-resize',
        s:  'ns-resize',
        e:  'ew-resize',
        w:  'ew-resize',
        move: 'move',
        pointer: 'pointer',
        crosshair: 'crosshair'
    };

    // 分析光标所在位置的命中行为 (仅可编辑且可见的图层响应手柄拖拽)
    function getHoverAction(cx, cy) {
        const curTarget = state.targets.find(t => t.key === state.selectedKey);
        const isTap = curTarget && curTarget.category === 'tap';

        // 纯点击锚点类型：优先判定准星手柄
        if (isTap) {
            if (state.tapCoord && Math.hypot(cx - state.tapCoord[0], cy - state.tapCoord[1]) <= 16) {
                return { action: 'move_tap', target: 'tap', cursor: 'move' };
            }
            return { action: 'set_tap', target: 'tap', cursor: 'crosshair' };
        }

        const activeVisible = state.activeMode === 'crop' ? state.showCrop : state.showSearch;
        const activeRect = activeVisible ? (state.activeMode === 'crop' ? state.cropArea : state.searchArea) : null;

        const otherMode = state.activeMode === 'crop' ? 'search' : 'crop';
        const otherVisible = otherMode === 'crop' ? state.showCrop : state.showSearch;
        const otherRect = otherVisible ? (otherMode === 'crop' ? state.cropArea : state.searchArea) : null;

        // 1. 优先检查当前处于可编辑状态且可见框的手柄 (缩放)
        if (activeRect) {
            const h = hitTestHandle(cx, cy, activeRect, 9);
            if (h) return { action: h, target: state.activeMode, cursor: CURSOR_MAP[h] };
        }

        // 2. 检查当前处于可编辑状态且可见框的内部 (平移拖动)
        if (activeRect && isInsideRect(cx, cy, activeRect)) {
            return { action: 'move', target: state.activeMode, cursor: 'move' };
        }

        // 3. 检查另一可见模式框 (点击可自动切换为唯一可编辑目标)
        if (otherRect) {
            const h = hitTestHandle(cx, cy, otherRect, 9);
            if (h) return { action: 'switch_handle', handle: h, target: otherMode, cursor: CURSOR_MAP[h] };
            if (isInsideRect(cx, cy, otherRect)) {
                return { action: 'switch_move', target: otherMode, cursor: 'pointer' };
            }
        }

        // 4. 空白区域 (重新框选绘制当前可编辑模式)
        return { action: 'draw', target: state.activeMode, cursor: 'crosshair' };
    }

    // Canvas 鼠标交互 (双范围绘制、手柄拉伸缩放、整体拖拽平移)
    function setupCanvasEvents() {
        if (!dom.canvas) return;

        function getCanvasPos(e) {
            const rect = dom.canvas.getBoundingClientRect();
            const scaleX = dom.canvas.width / rect.width;
            const scaleY = dom.canvas.height / rect.height;
            return [
                Math.round((e.clientX - rect.left) * scaleX),
                Math.round((e.clientY - rect.top) * scaleY)
            ];
        }

        // 鼠标悬停动态切换光标指示
        dom.canvas.addEventListener('mousemove', function (e) {
            if (state.dragState && state.dragState.action) return;
            if (!state.screenImage) return;
            const [cx, cy] = getCanvasPos(e);
            const hover = getHoverAction(cx, cy);
            dom.canvas.style.cursor = hover.cursor || 'crosshair';
        });

        // 鼠标按下：判定手柄缩放、移动、切换或新建绘制
        dom.canvas.addEventListener('mousedown', function (e) {
            if (!state.screenImage) return;
            const [cx, cy] = getCanvasPos(e);

            const curTarget = state.targets.find(t => t.key === state.selectedKey);
            const isTap = curTarget && curTarget.category === 'tap';

            // 纯点击锚点：左键或右键直接设定并允许即时拖动微调
            if (isTap) {
                if (e.button === 0 || e.button === 2) {
                    e.preventDefault();
                    state.tapCoord = [cx, cy];
                    state.dragState = {
                        action: 'move_tap',
                        target: 'tap',
                        startPos: [cx, cy]
                    };
                    updateInputsFromState();
                    updatePreview();
                    renderCanvas();
                    return;
                }
            }

            // Alt + 点击 或 右键：通用设置 Tap 点击锚点
            if (e.altKey || e.button === 2) {
                e.preventDefault();
                state.tapCoord = [cx, cy];
                updateInputsFromState();
                updatePreview();
                renderCanvas();
                return;
            }

            if (e.button !== 0) return;

            const hover = getHoverAction(cx, cy);

            if (hover.action === 'switch_handle') {
                setEditMode(hover.target);
                const rect = hover.target === 'crop' ? state.cropArea : state.searchArea;
                state.dragState = {
                    action: hover.handle,
                    target: hover.target,
                    startPos: [cx, cy],
                    initialRect: [...rect]
                };
            } else if (hover.action === 'switch_move') {
                setEditMode(hover.target);
                const rect = hover.target === 'crop' ? state.cropArea : state.searchArea;
                state.dragState = {
                    action: 'move',
                    target: hover.target,
                    startPos: [cx, cy],
                    initialRect: [...rect]
                };
            } else if (hover.action === 'move') {
                const rect = hover.target === 'crop' ? state.cropArea : state.searchArea;
                state.dragState = {
                    action: 'move',
                    target: hover.target,
                    startPos: [cx, cy],
                    initialRect: [...rect]
                };
            } else if (CURSOR_MAP[hover.action]) {
                const rect = hover.target === 'crop' ? state.cropArea : state.searchArea;
                state.dragState = {
                    action: hover.action,
                    target: hover.target,
                    startPos: [cx, cy],
                    initialRect: [...rect]
                };
            } else {
                // 空白区域绘制新建矩形
                state.dragState = {
                    action: 'draw',
                    target: state.activeMode,
                    startPos: [cx, cy],
                    initialRect: [cx, cy, cx, cy]
                };
                if (state.activeMode === 'crop') {
                    state.cropArea = [cx, cy, cx, cy];
                } else {
                    state.searchArea = [cx, cy, cx, cy];
                }
            }

            state.matchedRect = null;
            if (dom.matchResult) dom.matchResult.style.display = 'none';
        });

        // 全局拖动更新
        window.addEventListener('mousemove', function (e) {
            if (!state.dragState || !state.dragState.action || !state.screenImage) return;
            const [cx, cy] = getCanvasPos(e);
            const { action, target, startPos, initialRect } = state.dragState;
            const maxW = dom.canvas.width;
            const maxH = dom.canvas.height;

            if (action === 'move_tap') {
                const tx = Math.max(0, Math.min(maxW, cx));
                const ty = Math.max(0, Math.min(maxH, cy));
                state.tapCoord = [tx, ty];
                updateInputsFromState();
                updatePreview();
                renderCanvas();
                return;
            }

            let updatedRect = null;

            if (action === 'draw') {
                const x1 = Math.max(0, Math.min(startPos[0], cx));
                const y1 = Math.max(0, Math.min(startPos[1], cy));
                const x2 = Math.min(maxW, Math.max(startPos[0], cx));
                const y2 = Math.min(maxH, Math.max(startPos[1], cy));
                updatedRect = [x1, y1, x2, y2];
            } else if (action === 'move') {
                const dx = cx - startPos[0];
                const dy = cy - startPos[1];
                const w = initialRect[2] - initialRect[0];
                const h = initialRect[3] - initialRect[1];
                let nx1 = initialRect[0] + dx;
                let ny1 = initialRect[1] + dy;
                nx1 = Math.max(0, Math.min(maxW - w, nx1));
                ny1 = Math.max(0, Math.min(maxH - h, ny1));
                updatedRect = [Math.round(nx1), Math.round(ny1), Math.round(nx1 + w), Math.round(ny1 + h)];
            } else {
                // 缩放手柄调整对应边界
                const dx = cx - startPos[0];
                const dy = cy - startPos[1];
                let [x1, y1, x2, y2] = initialRect;

                if (action.includes('w')) x1 += dx;
                if (action.includes('e')) x2 += dx;
                if (action.includes('n')) y1 += dy;
                if (action.includes('s')) y2 += dy;

                // 限制在画布安全视口边界内
                x1 = Math.max(0, Math.min(maxW, x1));
                x2 = Math.max(0, Math.min(maxW, x2));
                y1 = Math.max(0, Math.min(maxH, y1));
                y2 = Math.max(0, Math.min(maxH, y2));

                updatedRect = [
                    Math.round(Math.min(x1, x2)),
                    Math.round(Math.min(y1, y2)),
                    Math.round(Math.max(x1, x2)),
                    Math.round(Math.max(y1, y2))
                ];
            }

            if (target === 'crop') {
                state.cropArea = updatedRect;
                updatePreview();
            } else {
                state.searchArea = updatedRect;
            }

            updateInputsFromState();
            renderCanvas();
        });

        // 鼠标抬起结束拖动
        window.addEventListener('mouseup', function () {
            if (!state.dragState || !state.dragState.action) return;
            const { action, target, initialRect } = state.dragState;
            state.dragState.action = null;

            // 如果是 draw 模式但宽高过小 (<4px 单次误触点击)，恢复原值避免框消失
            const curRect = target === 'crop' ? state.cropArea : state.searchArea;
            if (curRect && (curRect[2] - curRect[0] < 4 || curRect[3] - curRect[1] < 4)) {
                if (action === 'draw' && initialRect && (initialRect[2] - initialRect[0] >= 4)) {
                    if (target === 'crop') state.cropArea = initialRect;
                    else state.searchArea = initialRect;
                }
            }

            updateInputsFromState();
            updatePreview();
            renderCanvas();
        });

        // 阻止右键默认菜单
        dom.canvas.addEventListener('contextmenu', e => e.preventDefault());
    }

    // 保存目标特征 (双向落盘：仓库覆写+模拟器热推，持久化保存 crop_area 与 search_area，纯点击目标持久化 tap_coord)
    async function saveTarget() {
        if (!state.selectedKey) {
            alert('请先在左侧选择需要标定的目标！');
            return false;
        }
        const curTarget = state.targets.find(t => t.key === state.selectedKey);
        const isTap = curTarget && curTarget.category === 'tap';

        // 纯点击锚点保存流程
        if (isTap) {
            if (!state.tapCoord || state.tapCoord.length !== 2) {
                alert('请先在画布上设定有效的点击锚点坐标！');
                return false;
            }

            if (dom.btnSaveTarget) {
                dom.btnSaveTarget.disabled = true;
                dom.btnSaveTarget.textContent = '💾 正在保存点击锚点...';
            }

            const curDev = (dom.deviceSelect ? dom.deviceSelect.value : '') || state.selectedDevice || undefined;
            try {
                const res = await fetch('/api/calibrate/save_target', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        target_key: state.selectedKey,
                        name: curTarget ? curTarget.name : undefined,
                        category: curTarget ? curTarget.category : undefined,
                        tap_coord: state.tapCoord,
                        anchor: dom.targetAnchor ? dom.targetAnchor.value : 'center',
                        device: curDev
                    })
                });
                const data = await res.json();
                if (data.success) {
                    const targetTitle = (curTarget && curTarget.name) ? curTarget.name : state.selectedKey;
                    showToast(`✔ 点击锚点「${targetTitle}」已保存并推送到模拟器`);
                    setSaveStatusTip('success', `✔ 已保存锚点并推送 (${state.tapCoord.join(', ')})`, 4500);
                    await loadTargets();
                    selectTarget(state.selectedKey);
                    return true;
                } else {
                    const err = data.error || '未知错误';
                    setSaveStatusTip('error', `✖ 保存失败: ${err}`, 5000);
                    showToast(`✖ 保存失败: ${err}`);
                    return false;
                }
            } catch (e) {
                console.error('Save tap target error:', e);
                setSaveStatusTip('error', `✖ 保存异常: ${e.message}`, 5000);
                showToast(`✖ 保存异常: ${e.message}`);
                return false;
            } finally {
                if (dom.btnSaveTarget) {
                    dom.btnSaveTarget.disabled = false;
                    dom.btnSaveTarget.textContent = '💾 保存点击锚点';
                }
            }
        }

        // 视觉特征图目标：优先使用 cropArea 作为裁切矩形；若没有设定，则提示或使用 searchArea
        const targetCrop = state.cropArea || state.searchArea;
        if (!targetCrop || targetCrop.length !== 4) {
            setSaveStatusTip('error', '请先在画布上框选有效的目标范围！', 4000);
            showToast('请先在画布上框选有效的目标范围！');
            return false;
        }

        if (dom.btnSaveTarget) {
            dom.btnSaveTarget.disabled = true;
            dom.btnSaveTarget.textContent = '💾 正在双向保存与热推...';
        }

        try {
            const curDev = (dom.deviceSelect ? dom.deviceSelect.value : '') || state.selectedDevice || undefined;
            const res = await fetch('/api/calibrate/save_target', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    target_key: state.selectedKey,
                    file: curTarget ? curTarget.file : undefined,
                    name: curTarget ? curTarget.name : undefined,
                    category: curTarget ? curTarget.category : undefined,
                    rect: targetCrop, // 用于裁切 PNG 并写入 crop_area
                    search_area: state.searchArea, // 运行时匹配搜图范围
                    tap_coord: state.tapCoord,
                    anchor: dom.targetAnchor ? dom.targetAnchor.value : 'center',
                    device: curDev,
                    image_base64: state.screenImage ? state.screenImage.src : undefined
                })
            });
            const data = await res.json();
            if (data.success) {
                const targetTitle = (curTarget && curTarget.name) ? curTarget.name : state.selectedKey;
                showToast(`✔ 目标「${targetTitle}」截图选区与配置已保存并推送到模拟器！`);
                setSaveStatusTip('success', '✔ 已保存选区并推送到模拟器', 4500);
                await loadTargets();
                selectTarget(state.selectedKey);
                return true;
            } else {
                const err = data.error || '未知错误';
                setSaveStatusTip('error', `✖ 保存失败: ${err}`, 5000);
                showToast(`✖ 保存失败: ${err}`);
                return false;
            }
        } catch (e) {
            console.error('Save target error:', e);
            setSaveStatusTip('error', `✖ 保存异常: ${e.message}`, 5000);
            showToast(`✖ 保存异常: ${e.message}`);
            return false;
        } finally {
            if (dom.btnSaveTarget) {
                dom.btnSaveTarget.disabled = false;
                dom.btnSaveTarget.textContent = '💾 保存选区配置并推送';
            }
        }
    }

    // 测试模板匹配度
    async function testMatch() {
        if (!state.selectedKey) return;
        if (dom.btnTestMatch) {
            dom.btnTestMatch.disabled = true;
            dom.btnTestMatch.textContent = '🔍 正在匹配...';
        }

        try {
            const curDev = (dom.deviceSelect ? dom.deviceSelect.value : '') || state.selectedDevice || undefined;
            const res = await fetch('/api/calibrate/test_match', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    target_key: state.selectedKey,
                    search_area: state.searchArea || null,
                    device: curDev
                })
            });
            const data = await res.json();
            if (data.success && data.match) {
                const m = data.match;
                state.matchedRect = m.matched_rect;
                renderCanvas();

                if (dom.matchResult) {
                    dom.matchResult.className = 'cal-match-result ' + (m.matched ? 'success' : 'fail');
                    dom.matchResult.style.display = 'block';
                    dom.matchResult.innerHTML = `
                        <strong>${m.matched ? '✔ 匹配成功' : '✖ 匹配度偏低'}</strong><br>
                        置信度: <strong>${m.confidence_text}</strong> (阈值 80%)<br>
                        中心坐标: (${m.center_coord[0]}, ${m.center_coord[1]})
                    `;
                }
            } else {
                alert('匹配测试失败: ' + (data.error || '未找到目标模板'));
            }
        } catch (e) {
            console.error('Test match error:', e);
            alert('匹配测试异常: ' + e.message);
        } finally {
            if (dom.btnTestMatch) {
                dom.btnTestMatch.disabled = false;
                dom.btnTestMatch.textContent = '🔍 测试匹配';
            }
        }
    }

    // 绑定事件
    function bindEvents() {
        if (dom.btnCapture) dom.btnCapture.onclick = () => captureScreen({ silent: false });
        if (dom.btnSaveTarget) dom.btnSaveTarget.onclick = saveTarget;
        if (dom.btnTestMatch) dom.btnTestMatch.onclick = testMatch;

        // 模拟器设备切换
        if (dom.deviceSelect) {
            dom.deviceSelect.addEventListener('change', () => {
                if (window.selectAdbDevice) {
                    window.selectAdbDevice(dom.deviceSelect.value);
                }
            });
        }

        // 刷新检测在线模拟器
        if (dom.btnRefreshDevices) {
            dom.btnRefreshDevices.onclick = async () => {
                dom.btnRefreshDevices.style.transform = 'rotate(360deg)';
                if (window.checkAdbStatus) {
                    await window.checkAdbStatus();
                }
                setTimeout(() => {
                    if (dom.btnRefreshDevices) dom.btnRefreshDevices.style.transform = '';
                }, 400);
            };
        }

        // 监听全局设备变更
        window.addEventListener('adb-device-changed', (e) => {
            if (e.detail && e.detail.device) {
                state.selectedDevice = e.detail.device;
                if (dom.deviceSelect && dom.deviceSelect.value !== e.detail.device) {
                    dom.deviceSelect.value = e.detail.device;
                }
            }
        });

        // 勾选显示/隐藏 截图选区 (默认显示)
        if (dom.chkShowCrop) {
            dom.chkShowCrop.addEventListener('change', () => {
                state.showCrop = dom.chkShowCrop.checked;
                // 若隐藏了当前处于编辑状态的目标且另一方可见，则自动把编辑权切换至另一方
                if (!state.showCrop && state.activeMode === 'crop' && state.showSearch) {
                    setEditMode('search');
                }
                renderCanvas();
            });
        }

        // 勾选显示/隐藏 匹配范围 (默认显示)
        if (dom.chkShowSearch) {
            dom.chkShowSearch.addEventListener('change', () => {
                state.showSearch = dom.chkShowSearch.checked;
                // 若隐藏了当前处于编辑状态的目标且另一方可见，则自动把编辑权切换至另一方
                if (!state.showSearch && state.activeMode === 'search' && state.showCrop) {
                    setEditMode('crop');
                }
                renderCanvas();
            });
        }

        // 单选可编辑状态 (同时仅限一种可编辑)
        if (dom.radioEditCrop) {
            dom.radioEditCrop.addEventListener('change', () => {
                if (dom.radioEditCrop.checked) {
                    setEditMode('crop');
                }
            });
        }

        if (dom.radioEditSearch) {
            dom.radioEditSearch.addEventListener('change', () => {
                if (dom.radioEditSearch.checked) {
                    setEditMode('search');
                }
            });
        }

        // 点击图层控制区或卡片标题直接激活对应编辑模式
        if (dom.layerCropItem) {
            dom.layerCropItem.addEventListener('click', (e) => {
                if (e.target.closest('.cal-layer-check')) return;
                setEditMode('crop');
            });
        }

        if (dom.layerSearchItem) {
            dom.layerSearchItem.addEventListener('click', (e) => {
                if (e.target.closest('.cal-layer-check')) return;
                setEditMode('search');
            });
        }

        if (dom.cardCrop) {
            const header = dom.cardCrop.querySelector('.cal-card-title-left');
            if (header) {
                header.addEventListener('click', () => setEditMode('crop'));
            }
        }

        if (dom.cardSearch) {
            const header = dom.cardSearch.querySelector('.cal-card-title-left');
            if (header) {
                header.addEventListener('click', () => setEditMode('search'));
            }
        }

        // 智能识别截图区域按钮 (在当前画面中利用库内特征图精准对齐定位)
        if (dom.btnAutoDetectCrop) {
            dom.btnAutoDetectCrop.onclick = async () => {
                if (!state.selectedKey) {
                    alert('请先在左侧选择目标特征！');
                    return;
                }

                // 1. 若尚未抓屏，先自动截取模拟器屏幕
                if (!state.screenImage) {
                    await captureScreen();
                    if (!state.screenImage) return;
                }

                dom.btnAutoDetectCrop.disabled = true;
                const originalHtml = dom.btnAutoDetectCrop.innerHTML;
                dom.btnAutoDetectCrop.textContent = '🔍 正在智能识图中...';

                try {
                    const curDev = (dom.deviceSelect ? dom.deviceSelect.value : '') || state.selectedDevice || undefined;
                    const curTarget = state.targets.find(t => t.key === state.selectedKey);
                    const res = await fetch('/api/calibrate/test_match', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            target_key: state.selectedKey,
                            file: curTarget ? curTarget.file : undefined,
                            search_area: state.searchArea || null,
                            device: curDev,
                            image_base64: state.screenImage ? state.screenImage.src : undefined
                        })
                    });
                    const data = await res.json();
                    if (data.success && data.match) {
                        const m = data.match;
                        if (m.matched_rect && m.matched_rect.length === 4) {
                            const [bx, by, bw, bh] = m.matched_rect;
                            state.cropArea = [bx, by, bx + bw, by + bh];
                            state.matchedRect = m.matched_rect;
                            setEditMode('crop');
                            updateInputsFromState();
                            updatePreview();
                            renderCanvas();

                            if (dom.matchResult) {
                                dom.matchResult.className = 'cal-match-result ' + (m.matched ? 'success' : 'fail');
                                dom.matchResult.style.display = 'block';
                                dom.matchResult.innerHTML = `
                                    <div style="line-height:1.6;">
                                        <strong>${m.matched ? '✔ 智能识别定位成功' : '⚠ 相似度较低'}</strong><br>
                                        置信度: <strong>${m.confidence_text}</strong> (阈值 80%)<br>
                                        已自动框选推荐选区: [${state.cropArea.join(', ')}]<br>
                                        <div style="margin-top:6px; font-size:11px; color:#a0aec0; border-top:1px dashed rgba(255,255,255,0.1); padding-top:4px;">
                                            👉 确认推荐选区无误后，点击上方「💾 保存选区配置并推送」即可保存
                                        </div>
                                    </div>
                                `;
                            }
                        } else {
                            alert('未在当前画面中识别到特征: ' + (m.message || '置信度过低'));
                        }
                    } else {
                        alert('智能识别失败: ' + (data.error || '未找到该目标在仓库中的基准特征图'));
                    }
                } catch (e) {
                    console.error('Auto detect crop error:', e);
                    alert('智能识别请求异常: ' + e.message);
                } finally {
                    dom.btnAutoDetectCrop.disabled = false;
                    dom.btnAutoDetectCrop.innerHTML = originalHtml;
                }
            };
        }

        if (dom.btnExpandSearchFromCrop) {
            dom.btnExpandSearchFromCrop.onclick = () => {
                if (state.cropArea) {
                    const [cx1, cy1, cx2, cy2] = state.cropArea;
                    const maxW = dom.canvas.width || 1440;
                    const maxH = dom.canvas.height || 810;
                    state.searchArea = [
                        Math.max(0, cx1 - 30),
                        Math.max(0, cy1 - 30),
                        Math.min(maxW, cx2 + 30),
                        Math.min(maxH, cy2 + 30)
                    ];
                    setEditMode('search');
                    updateInputsFromState();
                    renderCanvas();
                } else {
                    alert('请先设定截图选区！');
                }
            };
        }

        // 分类标签过滤
        dom.categoryTabs.forEach(btn => {
            btn.onclick = () => {
                dom.categoryTabs.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                state.currentCategory = btn.dataset.cat;
                renderTargetsList();
            };
        });

        // 坐标 Inputs 实时修改与焦点智能联动
        const cropInputs = [dom.cropX1, dom.cropY1, dom.cropX2, dom.cropY2];
        cropInputs.forEach(inp => {
            if (inp) {
                inp.addEventListener('focus', () => setEditMode('crop'));
                inp.addEventListener('input', () => {
                    setEditMode('crop');
                    updateStateFromInputs();
                });
            }
        });

        const searchInputs = [dom.searchX1, dom.searchY1, dom.searchX2, dom.searchY2];
        searchInputs.forEach(inp => {
            if (inp) {
                inp.addEventListener('focus', () => setEditMode('search'));
                inp.addEventListener('input', () => {
                    setEditMode('search');
                    updateStateFromInputs();
                });
            }
        });

        [dom.inTapX, dom.inTapY].forEach(inp => {
            if (inp) inp.addEventListener('input', updateStateFromInputs);
        });

        setupCanvasEvents();
    }

    // 暴露供主界面全局保存、快捷键与自动化协同调用的标定工作台 API
    window.calibrationStudio = {
        saveTarget: saveTarget,
        hasActiveTarget: () => Boolean(state.selectedKey),
        hasCropArea: () => Boolean(state.cropArea && state.cropArea.length === 4),
        getCurrentTarget: () => state.targets.find(t => t.key === state.selectedKey),
        captureScreen: captureScreen,
        loadTargets: loadTargets,
        getState: () => state
    };

    document.addEventListener('DOMContentLoaded', function () {
        initDom();
        bindEvents();
        loadTargets();
    });
})();
