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
        initialSearchArea: null, // 目标初始配置的匹配范围（用于检测修改与一键还原）
        showCrop: true,    // 是否在画面中呈现截图选区 (默认显示)
        showSearch: true,  // 是否在画面中呈现匹配范围 (默认显示)
        activeMode: 'crop',// 当前可编辑目标: 'crop' | 'search' (同时仅能有一种)
        lastInteractedArea: 'crop', // 最近一次交互的选区模式 ('crop' | 'search')
        
        tapCoord: null,    // 点击锚点 [x, y]
        matchedRect: null, // [x, y, w, h] 测试匹配结果
        selectedDevice: null, // 当前选中的模拟器标识

        // 视口外框与缩放平移状态
        zoom: 1.0,
        panX: 0,
        panY: 0,
        isSpacePressed: false,
        isPanning: false,
        panStartX: 0,
        panStartY: 0,
        frameWidth: 0,
        frameHeight: 0,
        
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
        dom.tabSupport = document.getElementById('tabNavSupport');
        dom.supportView = document.getElementById('supportViewMain');

        dom.targetsList = document.getElementById('calTargetsList');
        dom.targetCountBadge = document.getElementById('calTargetCountBadge');
        dom.categoryTabs = document.querySelectorAll('.cal-cat-btn');

        dom.canvas = document.getElementById('calScreenCanvas');
        dom.ctx = dom.canvas ? dom.canvas.getContext('2d') : null;
        dom.emptyState = document.getElementById('calEmptyState');
        dom.canvasWrapper = document.getElementById('calCanvasWrapper');
        dom.viewportFrame = document.getElementById('calViewportFrame');
        dom.zoomToolbar = document.getElementById('calZoomToolbar');
        dom.btnZoomIn = document.getElementById('calBtnZoomIn');
        dom.btnZoomOut = document.getElementById('calBtnZoomOut');
        dom.btnZoomReset = document.getElementById('calBtnZoomReset');
        dom.btnZoomFit = document.getElementById('calBtnZoomFit');
        dom.zoomHint = document.getElementById('calZoomHint');
        dom.arrowHint = document.getElementById('calArrowHint');

        // 同步顶部导航栏当前选中的模拟器
        const topAdbSelect = document.getElementById('adbDeviceSelect');
        if (topAdbSelect && topAdbSelect.value) {
            state.selectedDevice = topAdbSelect.value;
        } else if (typeof window.getSelectedAdbDevice === 'function') {
            state.selectedDevice = window.getSelectedAdbDevice() || null;
        }

        dom.btnCapture = document.getElementById('calBtnCapture');
        dom.btnLoadImage = document.getElementById('calBtnLoadImage');
        dom.fileInput = document.getElementById('calFileInput');
        dom.btnTestMatch = document.getElementById('calBtnTestMatch');
        dom.btnSaveTarget = document.getElementById('calBtnSaveTarget');
        dom.screenBadge = document.getElementById('calScreenBadge');
        dom.chkShowCrop = document.getElementById('chkShowCrop');
        dom.chkShowSearch = document.getElementById('chkShowSearch');
        dom.radioEditCrop = document.getElementById('radioEditCrop');
        dom.radioEditSearch = document.getElementById('radioEditSearch');
        dom.layerCropItem = document.getElementById('layerCropItem');
        dom.layerSearchItem = document.getElementById('layerSearchItem');

        // 新增截图选区与匹配范围独立操作按钮 (显示/隐藏 与 编辑)
        dom.btnToggleCropVis = document.getElementById('btnToggleCropVis');
        dom.btnToggleSearchVis = document.getElementById('btnToggleSearchVis');
        dom.btnEditCrop = document.getElementById('btnEditCrop');
        dom.btnEditSearch = document.getElementById('btnEditSearch');

        dom.targetName = document.getElementById('calTargetName');
        dom.targetKey = document.getElementById('calTargetKey');
        dom.targetFile = document.getElementById('calTargetFile');
        dom.targetAnchor = document.getElementById('calTargetAnchor');
        dom.targetDesc = document.getElementById('calTargetDesc');

        // 资产名称展示与内联编辑控件
        dom.targetNameWrap = document.getElementById('calTargetNameWrap');
        dom.targetNameEditor = document.getElementById('calTargetNameEditor');
        dom.targetNameInput = document.getElementById('calTargetNameInput');
        dom.btnSaveTargetName = document.getElementById('btnSaveTargetName');
        dom.btnCancelTargetName = document.getElementById('btnCancelTargetName');

        // 图片文件名展示与内联编辑控件
        dom.targetFileWrap = document.getElementById('calTargetFileWrap');
        dom.targetFileEditIcon = document.getElementById('calTargetFileEditIcon');
        dom.targetFileEditor = document.getElementById('calTargetFileEditor');
        dom.targetFileInput = document.getElementById('calTargetFileInput');
        dom.btnSaveTargetFile = document.getElementById('btnSaveTargetFile');
        dom.btnCancelTargetFile = document.getElementById('btnCancelTargetFile');

        // 目标描述展示与内联编辑控件
        dom.descDisplay = document.getElementById('calDescDisplay');
        dom.descEditor = document.getElementById('calDescEditor');
        dom.targetDescInput = document.getElementById('calTargetDescInput');
        dom.btnSaveTargetDesc = document.getElementById('btnSaveTargetDesc');
        dom.btnCancelTargetDesc = document.getElementById('btnCancelTargetDesc');

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
        dom.btnResetSearchArea = document.getElementById('btnResetSearchArea');

        // 点击锚点控件
        dom.inTapX = document.getElementById('calInTapX');
        dom.inTapY = document.getElementById('calInTapY');

        dom.previewImg = document.getElementById('calPreviewImg');
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
            if (dom.supportView) dom.supportView.style.display = 'none';
            if (dom.container) dom.container.classList.add('active');
            if (shell) shell.classList.add('calibration-active');

            if (dom.tabConfig) dom.tabConfig.classList.remove('active');
            if (dom.tabExtra) dom.tabExtra.classList.remove('active');
            if (dom.tabSupport) dom.tabSupport.classList.remove('active');
            if (dom.tabCalibrate) dom.tabCalibrate.classList.add('active');

            if (subtext) subtext.textContent = '校准不同分辨率与环境下的界面找图区域与点击坐标。';
            if (twinBattle) twinBattle.classList.remove('context-active');
            if (twinExtra) twinExtra.classList.remove('context-active');

            loadTargets();
            if (window.checkAdbStatus) {
                window.checkAdbStatus();
            }
            updateViewportFrameDimensions();
            if (!state.screenImage) {
                captureScreen({ silent: true });
            }
        } else if (viewName === 'extra') {
            console.log('[View] 切换到整备工作台');
            if (dom.container) dom.container.classList.remove('active');
            if (shell) shell.classList.remove('calibration-active');
            if (dom.configView) dom.configView.style.display = 'none';
            if (dom.settingsBar) dom.settingsBar.style.display = 'none';
            if (dom.supportView) dom.supportView.style.display = 'none';
            if (dom.extraView) dom.extraView.style.display = '';

            if (dom.tabConfig) dom.tabConfig.classList.remove('active');
            if (dom.tabCalibrate) dom.tabCalibrate.classList.remove('active');
            if (dom.tabSupport) dom.tabSupport.classList.remove('active');
            if (dom.tabExtra) dom.tabExtra.classList.add('active');

            if (subtext) subtext.textContent = '自动化执行从者强化、礼装强化、技能升级、友情点召唤与无限池抽奖。';
            if (twinBattle) twinBattle.classList.remove('context-active');
            if (twinExtra) twinExtra.classList.add('context-active');
        } else if (viewName === 'support') {
            console.log('[View] 切换到管理助战视图');
            if (dom.container) dom.container.classList.remove('active');
            if (shell) shell.classList.remove('calibration-active');
            if (dom.configView) dom.configView.style.display = 'none';
            if (dom.settingsBar) dom.settingsBar.style.display = 'none';
            if (dom.extraView) dom.extraView.style.display = 'none';
            if (dom.supportView) dom.supportView.style.display = '';

            if (dom.tabConfig) dom.tabConfig.classList.remove('active');
            if (dom.tabCalibrate) dom.tabCalibrate.classList.remove('active');
            if (dom.tabExtra) dom.tabExtra.classList.remove('active');
            if (dom.tabSupport) dom.tabSupport.classList.add('active');

            if (subtext) subtext.textContent = '管理助战从者档案、代号索引与特征匹配图槽位。';
            if (twinBattle) twinBattle.classList.remove('context-active');
            if (twinExtra) twinExtra.classList.remove('context-active');

            if (window.friendsModule && window.friendsModule.loadFriends) {
                window.friendsModule.loadFriends();
            }
        } else {
            console.log('[View] 切换到战术配置时序视图');
            if (dom.container) dom.container.classList.remove('active');
            if (shell) shell.classList.remove('calibration-active');
            if (dom.extraView) dom.extraView.style.display = 'none';
            if (dom.supportView) dom.supportView.style.display = 'none';
            if (dom.configView) dom.configView.style.display = '';
            if (dom.settingsBar) dom.settingsBar.style.display = '';

            if (dom.tabCalibrate) dom.tabCalibrate.classList.remove('active');
            if (dom.tabExtra) dom.tabExtra.classList.remove('active');
            if (dom.tabSupport) dom.tabSupport.classList.remove('active');
            if (dom.tabConfig) dom.tabConfig.classList.add('active');

            if (subtext) subtext.textContent = '可视化配置各关卡技能、换人与出牌时序。';
            if (twinBattle) twinBattle.classList.add('context-active');
            if (twinExtra) twinExtra.classList.remove('context-active');
        }
    };

    // 统一同步卡片头部独立操作按钮 UI 状态 (显示/隐藏 与 可编辑)
    function updateControlButtonsUI() {
        // 1. 截图选区显示按钮
        if (dom.btnToggleCropVis) {
            const isVis = Boolean(state.showCrop);
            dom.btnToggleCropVis.classList.toggle('is-active', isVis);
            dom.btnToggleCropVis.title = isVis ? '当前已在画面中显示，点击隐藏' : '当前已隐藏，点击在画面中显示';
            const dot = dom.btnToggleCropVis.querySelector('.cal-opt-dot');
            if (dot) dot.className = `cal-opt-dot ${isVis ? 'green' : 'muted'}`;
            const text = dom.btnToggleCropVis.querySelector('.cal-opt-text');
            if (text) text.textContent = isVis ? '显示' : '隐藏';
        }

        // 2. 截图选区编辑按钮 (保持文字恒为“编辑”，仅通过图标勾选状态表达，避免按钮宽度跳动)
        if (dom.btnEditCrop) {
            const isEditing = state.activeMode === 'crop';
            dom.btnEditCrop.classList.toggle('is-active', isEditing);
            dom.btnEditCrop.title = isEditing ? '当前已勾选为编辑目标（可在画面中拖拽调整），点击取消编辑' : '点击勾选为编辑目标（勾选后可在画面中拖拽调整）';
            const text = dom.btnEditCrop.querySelector('.cal-opt-text');
            if (text) text.textContent = '编辑';
        }

        // 3. 匹配范围显示按钮
        if (dom.btnToggleSearchVis) {
            const isVis = Boolean(state.showSearch);
            dom.btnToggleSearchVis.classList.toggle('is-active', isVis);
            dom.btnToggleSearchVis.title = isVis ? '当前已在画面中显示，点击隐藏' : '当前已隐藏，点击在画面中显示';
            const dot = dom.btnToggleSearchVis.querySelector('.cal-opt-dot');
            if (dot) dot.className = `cal-opt-dot ${isVis ? 'blue' : 'muted'}`;
            const text = dom.btnToggleSearchVis.querySelector('.cal-opt-text');
            if (text) text.textContent = isVis ? '显示' : '隐藏';
        }

        // 4. 匹配范围编辑按钮 (保持文字恒为“编辑”，仅通过图标勾选状态表达，避免按钮宽度跳动)
        if (dom.btnEditSearch) {
            const isEditing = state.activeMode === 'search';
            dom.btnEditSearch.classList.toggle('is-active', isEditing);
            dom.btnEditSearch.title = isEditing ? '当前已勾选为编辑目标（可在画面中拖拽调整），点击取消编辑' : '点击勾选为编辑目标（勾选后可在画面中拖拽调整）';
            const text = dom.btnEditSearch.querySelector('.cal-opt-text');
            if (text) text.textContent = '编辑';
        }

        // 5. 卡片外框激活态高亮联动
        if (dom.cardCrop) dom.cardCrop.classList.toggle('active-mode', state.activeMode === 'crop');
        if (dom.cardSearch) dom.cardSearch.classList.toggle('active-mode', state.activeMode === 'search');

        // 6. 兼容性旧元素同步
        if (dom.chkShowCrop) dom.chkShowCrop.checked = Boolean(state.showCrop);
        if (dom.chkShowSearch) dom.chkShowSearch.checked = Boolean(state.showSearch);
        if (dom.radioEditCrop) dom.radioEditCrop.checked = state.activeMode === 'crop';
        if (dom.radioEditSearch) dom.radioEditSearch.checked = state.activeMode === 'search';
        if (dom.layerCropItem) dom.layerCropItem.classList.toggle('is-editing', state.activeMode === 'crop');
        if (dom.layerSearchItem) dom.layerSearchItem.classList.toggle('is-editing', state.activeMode === 'search');
    }

    // 交互模式切换 (同时仅能有一种处于可编辑状态，设为可编辑时自动保证其显示)
    function setEditMode(mode) {
        state.activeMode = mode;
        if (mode) {
            state.lastInteractedArea = mode;
        }

        if (mode === 'crop') {
            state.showCrop = true;
        } else if (mode === 'search') {
            state.showSearch = true;
        }

        updateControlButtonsUI();
        renderCanvas();
    }

    // 切换编辑模式勾选状态 (支持点击已激活目标取消编辑，实现画面完全只读保护)
    function toggleEditMode(mode) {
        if (state.activeMode === mode) {
            setEditMode(null);
        } else {
            setEditMode(mode);
        }
    }

    // 切换截图选区显示状态 (仅切换画面可见性，不影响当前编辑目标)
    function toggleCropVisibility() {
        state.showCrop = !state.showCrop;
        updateControlButtonsUI();
        renderCanvas();
    }

    // 切换匹配范围显示状态 (仅切换画面可见性，不影响当前编辑目标)
    function toggleSearchVisibility() {
        state.showSearch = !state.showSearch;
        updateControlButtonsUI();
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
            item.dataset.key = t.key;
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

        // 更新顶部宽幅目标属性
        if (dom.targetName) dom.targetName.textContent = target.name;
        if (dom.targetKey) dom.targetKey.textContent = target.key;
        if (dom.targetFile) {
            if (target.category === 'tap') {
                dom.targetFile.textContent = '纯点击坐标 (无图片)';
                if (dom.targetFileWrap) {
                    dom.targetFileWrap.classList.add('cal-readonly');
                    dom.targetFileWrap.title = '纯点击坐标无需图片文件';
                }
                if (dom.targetFileEditIcon) dom.targetFileEditIcon.style.display = 'none';
            } else {
                dom.targetFile.textContent = target.file || `${target.key}.png`;
                if (dom.targetFileWrap) {
                    dom.targetFileWrap.classList.remove('cal-readonly');
                    dom.targetFileWrap.title = '点击编辑图片文件名';
                }
                if (dom.targetFileEditIcon) dom.targetFileEditIcon.style.display = 'inline-flex';
            }
        }
        if (dom.targetAnchor) dom.targetAnchor.value = target.anchor || 'center';
        
        // 恢复名称、文件名、描述为展示态并渲染文本
        if (dom.targetNameEditor && dom.targetNameWrap) {
            dom.targetNameEditor.style.display = 'none';
            dom.targetNameWrap.style.display = 'inline-flex';
        }
        if (dom.targetFileEditor && dom.targetFileWrap) {
            dom.targetFileEditor.style.display = 'none';
            dom.targetFileWrap.style.display = 'inline-flex';
        }
        if (dom.descEditor && dom.descDisplay) {
            dom.descEditor.style.display = 'none';
            dom.descDisplay.style.display = 'inline-flex';
        }
        if (dom.targetDesc) {
            const hasDesc = Boolean(target.description && target.description.trim());
            dom.targetDesc.textContent = hasDesc ? target.description : '暂无描述 (点击添加)';
            dom.targetDesc.classList.toggle('empty-desc', !hasDesc);
        }

        const isTap = target.category === 'tap';

        // 载入双套坐标范围
        if (isTap) {
            state.initialSearchArea = target.search_area ? [...target.search_area] : null;
            state.searchArea = state.initialSearchArea ? [...state.initialSearchArea] : null;
            state.cropArea = target.crop_area ? [...target.crop_area] : null;
            state.tapCoord = target.tap_coord ? [...target.tap_coord] : null;

            if (dom.btnSaveTarget) {
                dom.btnSaveTarget.textContent = '💾 保存点击锚点';
                dom.btnSaveTarget.title = '更新本地配置中的纯点击坐标与锚点属性';
            }
            if (dom.btnTestMatch) dom.btnTestMatch.style.display = 'none';
        } else {
            state.initialSearchArea = target.search_area ? [...target.search_area] : (target.area ? [...target.area] : [0, 0, 1440, 810]);
            state.searchArea = [...state.initialSearchArea];
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

    // 检查当前匹配范围相对既有配置是否发生变更
    function isSearchAreaModified() {
        if (!state.initialSearchArea && !state.searchArea) return false;
        if (!state.initialSearchArea || !state.searchArea) return true;
        if (state.initialSearchArea.length !== state.searchArea.length) return true;
        return state.initialSearchArea.some((v, i) => v !== state.searchArea[i]);
    }

    // 更新还原匹配范围按钮状态
    function updateResetSearchButtonUI() {
        if (!dom.btnResetSearchArea) return;
        const modified = isSearchAreaModified();
        dom.btnResetSearchArea.disabled = !modified;
        if (modified && state.initialSearchArea) {
            dom.btnResetSearchArea.title = `点击还原为初始配置坐标: (${state.initialSearchArea.join(', ')})`;
        } else {
            dom.btnResetSearchArea.title = '当前坐标与配置一致，无需还原';
        }
    }

    // 执行还原初始匹配范围
    function resetSearchArea() {
        if (!state.initialSearchArea) return;
        state.searchArea = [...state.initialSearchArea];
        updateInputsFromState();
        renderCanvas();
        updateResetSearchButtonUI();
    }

    // 通用异步持久化更新目标元数据至后端 profile
    async function saveTargetMetadata(curTarget, tipText = '✔ 保存成功') {
        try {
            const res = await fetch('/api/calibrate/save_target', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    target_key: curTarget.key,
                    file: curTarget.file,
                    name: curTarget.name,
                    category: curTarget.category,
                    anchor: dom.targetAnchor ? dom.targetAnchor.value : (curTarget.anchor || 'center'),
                    search_area: curTarget.search_area || null,
                    tap_coord: curTarget.tap_coord || null,
                    description: curTarget.description || '',
                    rect: null
                })
            });
            const data = await res.json();
            if (data.success) {
                setSaveStatusTip('success', tipText, 2500);
            } else {
                setSaveStatusTip('error', data.error ? `✖ 保存失败: ${data.error}` : '✖ 保存失败', 3500);
            }
        } catch (e) {
            console.warn('[Calibration] 保存目标元数据异常:', e);
            setSaveStatusTip('error', '✖ 网络或服务异常', 3500);
        }
    }

    // 局部更新左侧清单列表中对应项目的名称与子标题
    function updateTargetListItemUI(key) {
        if (!dom.targetsList) return;
        const curTarget = state.targets.find(t => t.key === key);
        if (!curTarget) return;
        const item = dom.targetsList.querySelector(`.cal-target-item[data-key="${key}"]`);
        if (item) {
            const titleEl = item.querySelector('.cal-target-title');
            if (titleEl) titleEl.textContent = curTarget.name;
            const subEl = item.querySelector('.cal-target-sub');
            if (subEl) {
                const isTap = curTarget.category === 'tap';
                const tapSub = curTarget.tap_coord ? `Tap (${curTarget.tap_coord[0]}, ${curTarget.tap_coord[1]})` : '未设坐标';
                subEl.textContent = isTap ? tapSub : (curTarget.file || '待截图');
            }
        }
    }

    // 1. 资产名称内联编辑
    function startEditTargetName() {
        if (!state.selectedKey) return;
        const curTarget = state.targets.find(t => t.key === state.selectedKey);
        if (!curTarget) return;

        if (dom.targetNameInput) {
            dom.targetNameInput.value = curTarget.name || '';
        }
        if (dom.targetNameWrap) dom.targetNameWrap.style.display = 'none';
        if (dom.targetNameEditor) {
            dom.targetNameEditor.style.display = 'inline-flex';
            if (dom.targetNameInput) {
                dom.targetNameInput.focus();
                dom.targetNameInput.select();
            }
        }
    }

    function cancelTargetName() {
        if (dom.targetNameEditor) dom.targetNameEditor.style.display = 'none';
        if (dom.targetNameWrap) dom.targetNameWrap.style.display = 'inline-flex';
    }

    async function commitTargetName() {
        if (!state.selectedKey) return;
        const curTarget = state.targets.find(t => t.key === state.selectedKey);
        if (!curTarget) return;

        const newName = dom.targetNameInput ? dom.targetNameInput.value.trim() : '';
        const oldName = curTarget.name || '';

        if (!newName) {
            cancelTargetName();
            return;
        }

        curTarget.name = newName;
        if (dom.targetName) dom.targetName.textContent = newName;
        cancelTargetName();
        updateTargetListItemUI(curTarget.key);

        if (newName !== oldName) {
            saveTargetMetadata(curTarget, '✔ 资产名称已更新');
        }
    }

    // 2. 图片文件名内联编辑 (仅编辑 .png 前面的内容)
    function startEditTargetFile() {
        if (!state.selectedKey) return;
        const curTarget = state.targets.find(t => t.key === state.selectedKey);
        if (!curTarget || curTarget.category === 'tap') return;

        const currentFile = curTarget.file || `${curTarget.key}.png`;
        const baseName = currentFile.replace(/\.png$/i, '');

        if (dom.targetFileInput) {
            dom.targetFileInput.value = baseName;
        }
        if (dom.targetFileWrap) dom.targetFileWrap.style.display = 'none';
        if (dom.targetFileEditor) {
            dom.targetFileEditor.style.display = 'inline-flex';
            if (dom.targetFileInput) {
                dom.targetFileInput.focus();
                dom.targetFileInput.select();
            }
        }
    }

    function cancelTargetFile() {
        if (dom.targetFileEditor) dom.targetFileEditor.style.display = 'none';
        if (dom.targetFileWrap) dom.targetFileWrap.style.display = 'inline-flex';
    }

    async function commitTargetFile() {
        if (!state.selectedKey) return;
        const curTarget = state.targets.find(t => t.key === state.selectedKey);
        if (!curTarget || curTarget.category === 'tap') return;

        let rawBase = dom.targetFileInput ? dom.targetFileInput.value.trim() : '';
        rawBase = rawBase.replace(/\.png$/i, '').trim();
        rawBase = rawBase.replace(/[\/\\:*?"<>|]/g, '_');

        if (!rawBase) {
            cancelTargetFile();
            return;
        }

        const newFile = `${rawBase}.png`;
        const oldFile = curTarget.file || `${curTarget.key}.png`;

        curTarget.file = newFile;
        if (dom.targetFile) dom.targetFile.textContent = newFile;
        cancelTargetFile();
        updateTargetListItemUI(curTarget.key);

        if (newFile !== oldFile) {
            curTarget.image_url = `/api/calibrate/image/${encodeURIComponent(newFile)}?t=${Date.now()}`;
            if (dom.previewImg && dom.previewImg.style.display !== 'none') {
                dom.previewImg.src = curTarget.image_url;
            }
            saveTargetMetadata(curTarget, '✔ 图片文件名已更新');
        }
    }

    // 3. 目标描述内联编辑
    function startEditTargetDescription() {
        if (!state.selectedKey) return;
        const curTarget = state.targets.find(t => t.key === state.selectedKey);
        if (!curTarget) return;

        if (dom.targetDescInput) {
            dom.targetDescInput.value = curTarget.description || '';
        }
        if (dom.descDisplay) dom.descDisplay.style.display = 'none';
        if (dom.descEditor) {
            dom.descEditor.style.display = 'flex';
            if (dom.targetDescInput) {
                dom.targetDescInput.focus();
                dom.targetDescInput.select();
            }
        }
    }

    function cancelTargetDescription() {
        if (dom.descEditor) dom.descEditor.style.display = 'none';
        if (dom.descDisplay) dom.descDisplay.style.display = 'inline-flex';
    }

    async function commitTargetDescription() {
        if (!state.selectedKey) return;
        const curTarget = state.targets.find(t => t.key === state.selectedKey);
        if (!curTarget) return;

        const newDesc = dom.targetDescInput ? dom.targetDescInput.value.trim() : '';
        const oldDesc = curTarget.description || '';
        curTarget.description = newDesc;

        if (dom.targetDesc) {
            const hasDesc = Boolean(newDesc);
            dom.targetDesc.textContent = hasDesc ? newDesc : '暂无描述 (点击添加)';
            dom.targetDesc.classList.toggle('empty-desc', !hasDesc);
        }

        cancelTargetDescription();

        if (newDesc !== oldDesc) {
            saveTargetMetadata(curTarget, '✔ 描述已保存');
        }
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

        // 同步检查并刷新“还原”按钮状态
        updateResetSearchButtonUI();

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

    // 获取当前全局选中的目标模拟器 (同步使用顶部导航栏的模拟器)
    function getActiveDevice() {
        if (state.selectedDevice) return state.selectedDevice;
        const topAdbSelect = document.getElementById('adbDeviceSelect');
        if (topAdbSelect && topAdbSelect.value) return topAdbSelect.value;
        if (typeof window.getSelectedAdbDevice === 'function') {
            const dev = window.getSelectedAdbDevice();
            if (dev) return dev;
        }
        return undefined;
    }

    // 计算屏幕有效游戏视口与黑边偏移 (与 calibration.py 保持完全一致)
    function computeViewport(w, h) {
        const BASE_WIDTH = 1440;
        const BASE_HEIGHT = 810;
        const BASE_RATIO = BASE_WIDTH / BASE_HEIGHT;
        const safeH = h || 1;
        const screen_ratio = w / safeH;
        let viewport_w, viewport_h, offset_x = 0, offset_y = 0, scale;

        if (screen_ratio >= BASE_RATIO) {
            viewport_h = h;
            offset_y = 0;
            viewport_w = Math.round(h * BASE_RATIO);
            offset_x = Math.round((w - viewport_w) / 2.0);
            scale = h / BASE_HEIGHT;
        } else {
            viewport_w = w;
            offset_x = 0;
            viewport_h = Math.round(w / BASE_RATIO);
            offset_y = Math.round((h - viewport_h) / 2.0);
            scale = w / BASE_WIDTH;
        }

        return {
            screen_w: w,
            screen_h: h,
            offset_x: offset_x,
            offset_y: offset_y,
            viewport_w: viewport_w,
            viewport_h: viewport_h,
            scale: Math.round(scale * 10000) / 10000,
            screen_ratio: Math.round(screen_ratio * 10000) / 10000
        };
    }

    // 从本地文件 (图片文件) 载入标定画面
    function loadLocalImageFile(file) {
        if (!file) return;
        if (!file.type.startsWith('image/') && !file.name.match(/\.(png|jpe?g|webp|bmp)$/i)) {
            showToast('请选择有效的图片文件 (PNG/JPG/WebP/BMP)');
            return;
        }
        const reader = new FileReader();
        reader.onload = function (e) {
            const dataUrl = e.target.result;
            const img = new Image();
            img.onload = function () {
                const w = img.naturalWidth || img.width;
                const h = img.naturalHeight || img.height;
                const vp = computeViewport(w, h);

                state.screenWidth = w;
                state.screenHeight = h;
                state.viewport = vp;
                state.screenImage = img;

                if (dom.screenBadge) {
                    dom.screenBadge.textContent = `${w}×${h} (${file.name})`;
                    dom.screenBadge.title = `本地图片: ${file.name}\n尺寸: ${w}×${h}\n比例: ${vp.screen_ratio.toFixed(2)}:1`;
                }

                if (dom.emptyState) dom.emptyState.style.display = 'none';
                if (dom.canvas) {
                    dom.canvas.width = w;
                    dom.canvas.height = h;
                }
                updateViewportFrameDimensions();
                state.zoom = 1.0;
                state.panX = 0;
                state.panY = 0;
                updateCanvasTransform();
                renderCanvas();
                updatePreview();
                showToast(`✔ 已载入本地图片: ${file.name} (${w}×${h})`);
            };
            img.onerror = function () {
                showToast('本地图片载入失败，请确认文件格式无误');
            };
            img.src = dataUrl;
        };
        reader.onerror = function () {
            showToast('读取本地图片文件出错');
        };
        reader.readAsDataURL(file);
    }

    // IndexedDB 目录与文件 Handle 本地持久化 (用于文件夹按钮记忆上次打开的目录位置)
    const IDB_NAME = 'fgo_calibration_db';
    const IDB_STORE = 'handles';

    function openCalibrationDB() {
        return new Promise((resolve) => {
            if (!window.indexedDB) return resolve(null);
            try {
                const req = indexedDB.open(IDB_NAME, 1);
                req.onupgradeneeded = () => {
                    const db = req.result;
                    if (!db.objectStoreNames.contains(IDB_STORE)) {
                        db.createObjectStore(IDB_STORE);
                    }
                };
                req.onsuccess = () => resolve(req.result);
                req.onerror = () => resolve(null);
            } catch (e) {
                resolve(null);
            }
        });
    }

    async function saveLastImageHandle(handle) {
        if (!handle) return;
        try {
            const db = await openCalibrationDB();
            if (!db) return;
            const tx = db.transaction(IDB_STORE, 'readwrite');
            tx.objectStore(IDB_STORE).put(handle, 'last_image_handle');
        } catch (e) {
            console.warn('[Calibration] saveLastImageHandle error:', e);
        }
    }

    async function getLastImageHandle() {
        try {
            const db = await openCalibrationDB();
            if (!db) return null;
            return new Promise((resolve) => {
                const tx = db.transaction(IDB_STORE, 'readonly');
                const req = tx.objectStore(IDB_STORE).get('last_image_handle');
                req.onsuccess = () => resolve(req.result || null);
                req.onerror = () => resolve(null);
            });
        } catch (e) {
            return null;
        }
    }

    // 从服务端返回的数据包直接载入图片
    function loadImageFromData(data) {
        if (!data || !data.image_base64) return;
        const w = data.width;
        const h = data.height;
        const vp = data.viewport || computeViewport(w, h);

        state.screenWidth = w;
        state.screenHeight = h;
        state.viewport = vp;

        if (dom.screenBadge) {
            dom.screenBadge.textContent = `${w}×${h} (${data.file_name})`;
            dom.screenBadge.title = `本地路径: ${data.file_path || data.file_name}\n尺寸: ${w}×${h}\n比例: ${vp.screen_ratio.toFixed(2)}:1`;
        }

        const img = new Image();
        img.onload = function () {
            state.screenImage = img;
            if (dom.emptyState) dom.emptyState.style.display = 'none';
            if (dom.canvas) {
                dom.canvas.width = w;
                dom.canvas.height = h;
            }
            updateViewportFrameDimensions();
            state.zoom = 1.0;
            state.panX = 0;
            state.panY = 0;
            updateCanvasTransform();
            renderCanvas();
            updatePreview();
            showToast(`✔ 已载入本地图片: ${data.file_name} (${w}×${h})`);
        };
        img.src = data.image_base64;
    }

    // 打开文件选择框：记忆并定位上次打开的文件夹位置
    async function openImageFileDialog() {
        // 方案 1: 优先使用现代浏览器标准 File System Access API
        // 传入 id 和 startIn (通过 IndexedDB 记录上次选中的 FileSystemFileHandle)
        // 规范确保相同 id 及 startIn 可以在重新打开时精确定位到上次的文件目录！
        if (window.showOpenFilePicker) {
            try {
                const pickerOptions = {
                    id: 'fgo_calibration_image_picker',
                    types: [{
                        description: '图片文件 (*.png, *.jpg, *.jpeg, *.webp, *.bmp)',
                        accept: {
                            'image/*': ['.png', '.jpg', '.jpeg', '.webp', '.bmp']
                        }
                    }],
                    excludeAcceptAllOption: false,
                    multiple: false
                };

                const lastHandle = await getLastImageHandle();
                if (lastHandle) {
                    pickerOptions.startIn = lastHandle;
                }

                const [handle] = await window.showOpenFilePicker(pickerOptions);
                if (handle) {
                    await saveLastImageHandle(handle);
                    const file = await handle.getFile();
                    loadLocalImageFile(file);
                    return;
                }
            } catch (err) {
                if (err && err.name === 'AbortError') {
                    return; // 用户主动取消
                }
                console.warn('[Calibration] showOpenFilePicker fallback:', err);
            }
        }

        // 方案 2: 若浏览器不支持 showOpenFilePicker，调用后端原生文件选择对话框
        // 后端通过 calibration_settings.json 持久化记录 last_open_dir 并在打开时自动定位
        if (dom.btnLoadImage) dom.btnLoadImage.disabled = true;
        try {
            const hintDir = localStorage.getItem('cal_last_open_dir') || '';
            const res = await fetch('/api/calibrate/pick_image', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ last_dir: hintDir })
            });
            if (res.ok) {
                const data = await res.json();
                if (data.cancelled) return;
                if (data.success && data.image_base64) {
                    if (data.last_dir) {
                        localStorage.setItem('cal_last_open_dir', data.last_dir);
                    }
                    loadImageFromData(data);
                    return;
                } else if (data.error) {
                    showToast('选择图片失败: ' + data.error);
                    return;
                }
            }
        } catch (e) {
            console.warn('[Calibration] Backend pick_image failed, fallback to input:', e);
        } finally {
            if (dom.btnLoadImage) dom.btnLoadImage.disabled = false;
        }

        // 方案 3: 保底兼容使用隐藏的 input[type=file]
        if (dom.fileInput) {
            dom.fileInput.value = '';
            dom.fileInput.click();
        }
    }

    // 抓取模拟器当前屏幕 (同步使用顶部导航栏选中的模拟器)
    async function captureScreen(options = {}) {
        const silent = Boolean(options && options.silent === true);
        if (dom.btnCapture) {
            dom.btnCapture.disabled = true;
            dom.btnCapture.textContent = '⏳';
            dom.btnCapture.title = '正在抓取屏幕...';
        }
        try {
            const dev = getActiveDevice() || '';
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
            }

            state.screenWidth = data.width;
            state.screenHeight = data.height;
            state.viewport = data.viewport;

            if (dom.screenBadge) {
                dom.screenBadge.textContent = `${data.width}×${data.height} (${data.viewport.screen_ratio.toFixed(2)}:1)`;
                dom.screenBadge.title = `模拟器屏幕\n尺寸: ${data.width}×${data.height}\n比例: ${data.viewport.screen_ratio.toFixed(2)}:1`;
            }

            const img = new Image();
            img.onload = function () {
                state.screenImage = img;
                if (dom.emptyState) dom.emptyState.style.display = 'none';
                dom.canvas.width = data.width;
                dom.canvas.height = data.height;
                updateViewportFrameDimensions();
                state.zoom = 1.0;
                state.panX = 0;
                state.panY = 0;
                updateCanvasTransform();
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
                dom.btnCapture.textContent = '📸';
                dom.btnCapture.title = '截取当前画面 (快捷键: F8 / 空格)';
            }
        }
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
        } else {
            // 3. 既无截图选区，也无库内图片
            if (dom.previewImg) {
                dom.previewImg.src = '';
                dom.previewImg.style.display = 'none';
            }
            if (placeholder) placeholder.style.display = 'block';
        }
    }

    // 分析光标所在位置的命中行为 (仅允许编辑已勾选“编辑”的范围，未勾选编辑严禁在画面中交互)
    function getHoverAction(cx, cy) {
        const curTarget = state.targets.find(t => t.key === state.selectedKey);
        const isTap = curTarget && curTarget.category === 'tap';

        // 纯点击锚点类型：优先判定准星移动
        if (isTap) {
            if (state.tapCoord && Math.hypot(cx - state.tapCoord[0], cy - state.tapCoord[1]) <= 16) {
                return { action: 'move_tap', target: 'tap', cursor: 'move' };
            }
            return { action: 'set_tap', target: 'tap', cursor: 'crosshair' };
        }

        // 若当前未开启任何编辑模式（截图选区和匹配范围均未勾选“编辑”）
        // 若画面中存在选区，点击对应选区可智能切换并激活对应编辑模式
        if (!state.activeMode) {
            if (state.showCrop && state.cropArea && isInsideRect(cx, cy, state.cropArea)) {
                return { action: 'select_mode', target: 'crop', cursor: 'pointer' };
            }
            if (state.showSearch && state.searchArea && isInsideRect(cx, cy, state.searchArea)) {
                return { action: 'select_mode', target: 'search', cursor: 'pointer' };
            }
            return { action: null, target: null, cursor: 'default' };
        }

        const activeVisible = state.activeMode === 'crop' ? state.showCrop : state.showSearch;
        const activeRect = activeVisible ? (state.activeMode === 'crop' ? state.cropArea : state.searchArea) : null;

        const otherMode = state.activeMode === 'crop' ? 'search' : 'crop';
        const otherVisible = otherMode === 'crop' ? state.showCrop : state.showSearch;
        const otherRect = otherVisible ? (otherMode === 'crop' ? state.cropArea : state.searchArea) : null;

        // 1. 检查当前处于可编辑状态且可见框的内部 (平移拖动当前已勾选“编辑”的目标)
        if (activeRect && isInsideRect(cx, cy, activeRect)) {
            return { action: 'move', target: state.activeMode, cursor: 'move' };
        }

        // 2. 检查未勾选编辑的另一范围框：
        // 若当前处于 search 模式，但用户点击了画面中可见的截图选区 (cropArea)，智能选中并切换到 crop 编辑模式
        // 注意：当处于 crop 编辑模式且显示 searchArea 时，绝不能拦截 searchArea 内部的点击，否则无法在匹配范围内框选截图选区
        if (otherMode === 'crop' && otherRect && isInsideRect(cx, cy, otherRect)) {
            return { action: 'select_mode', target: 'crop', cursor: 'pointer' };
        }

        // 3. 空白区域 (重新框选绘制当前处于编辑状态的目标)
        return { action: 'draw', target: state.activeMode, cursor: 'crosshair' };
    }

    // ===== 视口外框自适应、缩放与空格平移机制 =====

    // 计算并同步视口外框尺寸：
    // 关键规范：在整个 editor 放大的时候，外框自适应扩大，但物理像素最大只能放大到原图 100% 原始尺寸 (严格避免物理尺寸超过原图)
    function updateViewportFrameDimensions() {
        if (!dom.viewportFrame || !dom.canvasWrapper) return;
        const pad = 24; // 12px 留白边距
        const availW = Math.max(100, dom.canvasWrapper.clientWidth - pad);
        const availH = Math.max(100, dom.canvasWrapper.clientHeight - pad);

        const imgW = (state.screenWidth && state.screenWidth > 0) ? state.screenWidth : 1440;
        const imgH = (state.screenHeight && state.screenHeight > 0) ? state.screenHeight : 810;
        const ratio = imgW / imgH;

        // 【关键修复】：考虑高分屏/Windows缩放比例 (devicePixelRatio)，
        // 确保画框在整个 editor 放大或全屏时，物理像素最大只能放大到原图 100% 原始尺寸，绝不物理放大超过原图！
        const dpr = window.devicePixelRatio || 1;
        const nativeCSSW = Math.round(imgW / dpr);
        const nativeCSSH = Math.round(imgH / dpr);

        const targetMaxW = Math.min(availW, nativeCSSW);
        const targetMaxH = Math.min(availH, nativeCSSH);

        let frameW = targetMaxW;
        let frameH = frameW / ratio;

        if (frameH > targetMaxH) {
            frameH = targetMaxH;
            frameW = frameH * ratio;
        }

        frameW = Math.round(frameW);
        frameH = Math.round(frameH);

        dom.viewportFrame.style.width = frameW + 'px';
        dom.viewportFrame.style.height = frameH + 'px';

        state.frameWidth = frameW;
        state.frameHeight = frameH;

        updateCanvasTransform();
    }

    // 更新 Canvas 视口变换 (平移与缩放)
    function updateCanvasTransform() {
        if (!dom.canvas) return;
        const zoom = state.zoom || 1.0;
        let panX = state.panX || 0;
        let panY = state.panY || 0;

        const frameW = state.frameWidth || (dom.viewportFrame ? dom.viewportFrame.clientWidth : 1440);
        const frameH = state.frameHeight || (dom.viewportFrame ? dom.viewportFrame.clientHeight : 810);

        if (zoom <= 1.001) {
            panX = 0;
            panY = 0;
            state.panX = 0;
            state.panY = 0;
        } else {
            const scaledW = frameW * zoom;
            const scaledH = frameH * zoom;
            const maxPanX = Math.max(0, (scaledW - frameW) / 2);
            const maxPanY = Math.max(0, (scaledH - frameH) / 2);
            const buffer = 40;
            panX = Math.max(-(maxPanX + buffer), Math.min(maxPanX + buffer, panX));
            panY = Math.max(-(maxPanY + buffer), Math.min(maxPanY + buffer, panY));
            state.panX = panX;
            state.panY = panY;
        }

        dom.canvas.style.transform = `translate(${Math.round(panX)}px, ${Math.round(panY)}px) scale(${zoom.toFixed(4)})`;

        // 更新缩放指示数字 (精确反映物理显示像素相对原图 1:1 像素的真实比例)
        if (dom.btnZoomReset) {
            const imgW = (state.screenWidth && state.screenWidth > 0) ? state.screenWidth : 1440;
            const dpr = window.devicePixelRatio || 1;
            const effectiveZoomPercent = Math.round(zoom * ((frameW * dpr) / imgW) * 100);
            dom.btnZoomReset.textContent = `${effectiveZoomPercent}%`;
            dom.btnZoomReset.title = `当前缩放: ${effectiveZoomPercent}% (点击在 100% 原始尺寸 与 适应外框 间切换)`;
        }
    }

    // 应用缩放 (支持指定聚焦锚点坐标 clientX, clientY，实现滚轮聚焦缩放)
    function applyZoom(newZoom, clientX, clientY) {
        const minZoom = 0.35;
        const maxZoom = 6.0;
        const targetZoom = Math.max(minZoom, Math.min(maxZoom, newZoom));
        const oldZoom = state.zoom || 1.0;

        if (Math.abs(targetZoom - oldZoom) < 0.001) return;

        if (clientX !== undefined && clientY !== undefined && dom.viewportFrame) {
            const rect = dom.viewportFrame.getBoundingClientRect();
            const mx = clientX - (rect.left + rect.width / 2);
            const my = clientY - (rect.top + rect.height / 2);
            const ratio = targetZoom / oldZoom;
            state.panX = (state.panX || 0) * ratio + mx * (1 - ratio);
            state.panY = (state.panY || 0) * ratio + my * (1 - ratio);
        }

        state.zoom = targetZoom;
        updateCanvasTransform();
    }

    // 方向键微调当前激活选区 (1px 精细微调，Shift + 方向键 10px 快速移动)
    function handleArrowKeyNudge(e) {
        if (!dom.container || !dom.container.classList.contains('active')) return;
        if (!state.screenImage) return;

        const tag = (e.target && e.target.tagName) ? e.target.tagName.toLowerCase() : '';
        if (tag === 'input' || tag === 'textarea' || (e.target && e.target.isContentEditable)) {
            return;
        }

        const isArrow = e.key === 'ArrowUp' || e.key === 'ArrowDown' || e.key === 'ArrowLeft' || e.key === 'ArrowRight';
        if (!isArrow) return;

        e.preventDefault();

        const step = e.shiftKey ? 10 : 1;
        let dx = 0;
        let dy = 0;
        if (e.key === 'ArrowUp') dy = -step;
        else if (e.key === 'ArrowDown') dy = step;
        else if (e.key === 'ArrowLeft') dx = -step;
        else if (e.key === 'ArrowRight') dx = step;

        const maxW = (dom.canvas && dom.canvas.width) || state.screenWidth || 1440;
        const maxH = (dom.canvas && dom.canvas.height) || state.screenHeight || 810;

        const curTarget = state.targets.find(t => t.key === state.selectedKey);
        const isTap = curTarget && curTarget.category === 'tap';

        // 1. 纯点击坐标微调
        if (isTap) {
            if (!state.tapCoord || state.tapCoord.length < 2) return;
            const nx = Math.max(0, Math.min(maxW, state.tapCoord[0] + dx));
            const ny = Math.max(0, Math.min(maxH, state.tapCoord[1] + dy));
            state.tapCoord = [Math.round(nx), Math.round(ny)];
            updateInputsFromState();
            updatePreview();
            renderCanvas();
            triggerNudgeFeedback();
            return;
        }

        // 2. 确定当前微调目标选区
        let targetMode = state.activeMode;
        if (!targetMode) {
            targetMode = state.lastInteractedArea || (state.showCrop && state.cropArea ? 'crop' : 'search');
            if (targetMode) {
                setEditMode(targetMode);
            }
        }

        if (targetMode === 'crop') {
            if (!state.cropArea || state.cropArea.length !== 4) return;
            const minX = Math.min(state.cropArea[0], state.cropArea[2]);
            const minY = Math.min(state.cropArea[1], state.cropArea[3]);
            const maxX = Math.max(state.cropArea[0], state.cropArea[2]);
            const maxY = Math.max(state.cropArea[1], state.cropArea[3]);
            const w = maxX - minX;
            const h = maxY - minY;
            let nx1 = minX + dx;
            let ny1 = minY + dy;
            nx1 = Math.max(0, Math.min(maxW - w, nx1));
            ny1 = Math.max(0, Math.min(maxH - h, ny1));
            state.cropArea = [Math.round(nx1), Math.round(ny1), Math.round(nx1 + w), Math.round(ny1 + h)];
            state.lastInteractedArea = 'crop';
            updateInputsFromState();
            updatePreview();
            renderCanvas();
            triggerNudgeFeedback();
        } else if (targetMode === 'search') {
            if (!state.searchArea || state.searchArea.length !== 4) return;
            const minX = Math.min(state.searchArea[0], state.searchArea[2]);
            const minY = Math.min(state.searchArea[1], state.searchArea[3]);
            const maxX = Math.max(state.searchArea[0], state.searchArea[2]);
            const maxY = Math.max(state.searchArea[1], state.searchArea[3]);
            const w = maxX - minX;
            const h = maxY - minY;
            let nx1 = minX + dx;
            let ny1 = minY + dy;
            nx1 = Math.max(0, Math.min(maxW - w, nx1));
            ny1 = Math.max(0, Math.min(maxH - h, ny1));
            state.searchArea = [Math.round(nx1), Math.round(ny1), Math.round(nx1 + w), Math.round(ny1 + h)];
            state.lastInteractedArea = 'search';
            updateInputsFromState();
            updateResetSearchButtonUI();
            renderCanvas();
            triggerNudgeFeedback();
        }
    }

    // 微调反馈动画
    function triggerNudgeFeedback() {
        if (dom.arrowHint) {
            dom.arrowHint.classList.add('is-active');
            clearTimeout(dom.arrowHint._timer);
            dom.arrowHint._timer = setTimeout(() => {
                if (dom.arrowHint) dom.arrowHint.classList.remove('is-active');
            }, 250);
        }
    }

    // 监听键盘空格键、方向键与平移拖拽事件
    function setupSpacePanEvents() {
        window.addEventListener('keydown', (e) => {
            const tag = (e.target && e.target.tagName) ? e.target.tagName.toLowerCase() : '';
            if (tag === 'input' || tag === 'textarea' || (e.target && e.target.isContentEditable)) {
                if (e.key === 'Escape') {
                    e.target.blur();
                }
                return;
            }

            // 方向键微调选区
            if (e.key === 'ArrowUp' || e.key === 'ArrowDown' || e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
                handleArrowKeyNudge(e);
                return;
            }

            if (e.code === 'Space' || e.key === ' ') {
                if (!dom.container || !dom.container.classList.contains('active')) return;

                e.preventDefault();
                if (!state.isSpacePressed) {
                    state.isSpacePressed = true;
                    if (dom.viewportFrame) dom.viewportFrame.classList.add('cal-space-ready');
                    if (dom.zoomHint) dom.zoomHint.classList.add('is-active');
                }
            }
        });

        window.addEventListener('keyup', (e) => {
            if (e.code === 'Space' || e.key === ' ') {
                state.isSpacePressed = false;
                if (!state.isPanning) {
                    if (dom.viewportFrame) dom.viewportFrame.classList.remove('cal-space-ready');
                    if (dom.zoomHint) dom.zoomHint.classList.remove('is-active');
                }
            }
        });

        window.addEventListener('blur', () => {
            state.isSpacePressed = false;
            state.isPanning = false;
            if (dom.viewportFrame) {
                dom.viewportFrame.classList.remove('cal-space-ready', 'cal-is-panning');
            }
            if (dom.zoomHint) dom.zoomHint.classList.remove('is-active');
        });

        // 视口容器滚轮缩放
        if (dom.viewportFrame) {
            dom.viewportFrame.addEventListener('wheel', (e) => {
                e.preventDefault();
                const factor = e.deltaY < 0 ? 1.15 : (1 / 1.15);
                applyZoom((state.zoom || 1.0) * factor, e.clientX, e.clientY);
            }, { passive: false });
        }

        // 外框空白处按住空格也能平移
        if (dom.viewportFrame) {
            dom.viewportFrame.addEventListener('mousedown', (e) => {
                if (state.isSpacePressed || e.button === 1) {
                    e.preventDefault();
                    e.stopPropagation();
                    state.isPanning = true;
                    state.panStartX = e.clientX - (state.panX || 0);
                    state.panStartY = e.clientY - (state.panY || 0);
                    dom.viewportFrame.classList.add('cal-is-panning');
                }
            });

            // 双击视口外框快速在 100% 原始尺寸 与 适应外框 间切换
            dom.viewportFrame.addEventListener('dblclick', (e) => {
                if (state.dragState && state.dragState.action) return;
                if (dom.btnZoomReset) dom.btnZoomReset.click();
            });
        }

        // 响应窗口与外层容器尺寸变化
        window.addEventListener('resize', updateViewportFrameDimensions);
        if (window.ResizeObserver && dom.canvasWrapper) {
            const ro = new ResizeObserver(() => {
                updateViewportFrameDimensions();
            });
            ro.observe(dom.canvasWrapper);
        }

        // 响应高分屏/DPI/跨显示器切换导致的 devicePixelRatio 变化
        try {
            const dprMediaQuery = window.matchMedia(`(resolution: ${window.devicePixelRatio || 1}dpr)`);
            if (dprMediaQuery && dprMediaQuery.addEventListener) {
                dprMediaQuery.addEventListener('change', () => {
                    updateViewportFrameDimensions();
                });
            }
        } catch (e) {
            // 忽略某些老旧引擎不支持
        }
    }

    // Canvas 鼠标交互 (双范围绘制与框内平移拖拽，无控制手柄)
    function setupCanvasEvents() {
        if (!dom.canvas) return;

        setupSpacePanEvents();

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
            if (state.isPanning) return;
            if (state.isSpacePressed) {
                dom.canvas.style.cursor = 'grab';
                return;
            }
            if (state.dragState && state.dragState.action) return;
            if (!state.screenImage) return;
            const [cx, cy] = getCanvasPos(e);
            const hover = getHoverAction(cx, cy);
            dom.canvas.style.cursor = hover.cursor || 'default';
        });

        dom.canvas.addEventListener('mouseleave', function () {
            if (dom.canvas && !state.isSpacePressed) dom.canvas.style.cursor = 'default';
        });

        // 鼠标按下：判定平移或新建框选
        dom.canvas.addEventListener('mousedown', function (e) {
            if (!state.screenImage) return;

            // 1. 若按住空格键或使用中键：启动平移！
            if (state.isSpacePressed || e.button === 1) {
                e.preventDefault();
                e.stopPropagation();
                state.isPanning = true;
                state.panStartX = e.clientX - (state.panX || 0);
                state.panStartY = e.clientY - (state.panY || 0);
                if (dom.viewportFrame) dom.viewportFrame.classList.add('cal-is-panning');
                return;
            }

            const [cx, cy] = getCanvasPos(e);

            const curTarget = state.targets.find(t => t.key === state.selectedKey);
            const isTap = curTarget && curTarget.category === 'tap';

            // 纯点击锚点：仅左键直接设定并允许即时拖动微调
            if (isTap) {
                if (e.button === 0) {
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
                }
                return;
            }

            // 确保点击画布时退出输入框焦点，以便方向键直接控制选区
            if (document.activeElement && ['input', 'textarea'].includes((document.activeElement.tagName || '').toLowerCase())) {
                document.activeElement.blur();
            }

            // 仅响应普通左键 (e.button === 0 且无 altKey)
            if (e.button !== 0 || e.altKey) return;

            const hover = getHoverAction(cx, cy);
            if (!hover || !hover.action) {
                return;
            }

            if (hover.action === 'select_mode') {
                setEditMode(hover.target);
                return;
            }

            if (hover.action === 'move') {
                const rect = hover.target === 'crop' ? state.cropArea : state.searchArea;
                if (!rect) return;
                state.dragState = {
                    action: 'move',
                    target: hover.target,
                    startPos: [cx, cy],
                    initialRect: [...rect]
                };
            } else if (hover.action === 'draw') {
                if (!state.activeMode) return;
                state.dragState = {
                    action: 'draw',
                    target: state.activeMode,
                    startPos: [cx, cy],
                    initialRect: [cx, cy, cx, cy]
                };
                if (state.activeMode === 'crop') {
                    state.cropArea = [cx, cy, cx, cy];
                } else if (state.activeMode === 'search') {
                    state.searchArea = [cx, cy, cx, cy];
                }
            }

            state.matchedRect = null;
            if (dom.matchResult) dom.matchResult.style.display = 'none';
        });

        // 全局拖动更新
        window.addEventListener('mousemove', function (e) {
            // 平移中直接更新视口位置
            if (state.isPanning) {
                state.panX = e.clientX - state.panStartX;
                state.panY = e.clientY - state.panStartY;
                updateCanvasTransform();
                return;
            }

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
            }

            if (!updatedRect) return;

            if (target === 'crop') {
                state.cropArea = updatedRect;
                state.lastInteractedArea = 'crop';
                updatePreview();
            } else {
                state.searchArea = updatedRect;
                state.lastInteractedArea = 'search';
            }

            updateInputsFromState();
            renderCanvas();
        });

        // 鼠标抬起结束拖动或平移
        window.addEventListener('mouseup', function () {
            if (state.isPanning) {
                state.isPanning = false;
                if (dom.viewportFrame) {
                    dom.viewportFrame.classList.remove('cal-is-panning');
                    if (!state.isSpacePressed) {
                        dom.viewportFrame.classList.remove('cal-space-ready');
                    }
                }
                if (dom.zoomHint && !state.isSpacePressed) {
                    dom.zoomHint.classList.remove('is-active');
                }
                return;
            }

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

            const curDev = getActiveDevice();
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
                        description: curTarget ? curTarget.description : undefined,
                        device: curDev
                    })
                });
                const data = await res.json();
                if (data.success) {
                    const targetTitle = (curTarget && curTarget.name) ? curTarget.name : state.selectedKey;
                    showToast(`✔ 点击锚点「${targetTitle}」已保存并推送到模拟器`);
                    setSaveStatusTip('success', `✔ 已保存锚点并推送 (${state.tapCoord.join(', ')})`, 4500);
                    window.dispatchEvent(new CustomEvent('calibration-targets-updated', { detail: { target_key: state.selectedKey } }));
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
            const curDev = getActiveDevice();
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
                    description: curTarget ? curTarget.description : undefined,
                    device: curDev,
                    image_base64: state.screenImage ? state.screenImage.src : undefined
                })
            });
            const data = await res.json();
            if (data.success) {
                const targetTitle = (curTarget && curTarget.name) ? curTarget.name : state.selectedKey;
                showToast(`✔ 目标「${targetTitle}」截图选区与配置已保存并推送到模拟器！`);
                setSaveStatusTip('success', '✔ 已保存选区并推送到模拟器', 4500);
                window.dispatchEvent(new CustomEvent('calibration-targets-updated', { detail: { target_key: state.selectedKey } }));
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
            const curDev = getActiveDevice();
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
        if (dom.btnLoadImage) {
            dom.btnLoadImage.onclick = openImageFileDialog;
        }

        // 绑定缩放与平移操作控件
        if (dom.btnZoomIn) {
            dom.btnZoomIn.onclick = () => applyZoom((state.zoom || 1.0) * 1.25);
        }
        if (dom.btnZoomOut) {
            dom.btnZoomOut.onclick = () => applyZoom((state.zoom || 1.0) / 1.25);
        }
        if (dom.btnZoomFit) {
            dom.btnZoomFit.onclick = () => {
                state.zoom = 1.0;
                state.panX = 0;
                state.panY = 0;
                updateCanvasTransform();
            };
        }
        if (dom.btnZoomReset) {
            dom.btnZoomReset.onclick = () => {
                const imgW = (state.screenWidth && state.screenWidth > 0) ? state.screenWidth : 1440;
                const frameW = state.frameWidth || (dom.viewportFrame ? dom.viewportFrame.clientWidth : 1440);
                const dpr = window.devicePixelRatio || 1;
                // 计算使物理显示像素严格等于原图物理像素 (100% 原始尺寸) 所需的 zoom 缩放值
                const native100Zoom = imgW / (frameW * dpr);

                // 如果当前缩放已经处于 100% 原图尺寸 (误差在 3% 内)，则一键切换回 1.0 适应外框
                if (Math.abs((state.zoom || 1.0) - native100Zoom) < 0.03) {
                    state.zoom = 1.0;
                } else {
                    state.zoom = native100Zoom;
                }
                state.panX = 0;
                state.panY = 0;
                updateCanvasTransform();
            };
        }

        if (dom.fileInput) {
            dom.fileInput.onchange = (e) => {
                const file = e.target.files && e.target.files[0];
                if (file) {
                    loadLocalImageFile(file);
                }
            };
        }

        // 支持拖拽本地图片文件到 Canvas 工作区直接载入
        const canvasWrapper = document.querySelector('.cal-canvas-wrapper');
        if (canvasWrapper) {
            canvasWrapper.addEventListener('dragover', (e) => {
                e.preventDefault();
                e.stopPropagation();
                if (e.dataTransfer) e.dataTransfer.dropEffect = 'copy';
                canvasWrapper.classList.add('cal-dragover');
            });
            canvasWrapper.addEventListener('dragleave', (e) => {
                e.preventDefault();
                e.stopPropagation();
                canvasWrapper.classList.remove('cal-dragover');
            });
            canvasWrapper.addEventListener('drop', (e) => {
                e.preventDefault();
                e.stopPropagation();
                canvasWrapper.classList.remove('cal-dragover');
                const file = e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0];
                if (file) {
                    loadLocalImageFile(file);
                }
            });
        }

        if (dom.btnSaveTarget) dom.btnSaveTarget.onclick = saveTarget;
        if (dom.btnTestMatch) dom.btnTestMatch.onclick = testMatch;

        // 监听全局顶部模拟器变更，自动同步当前标定所使用的模拟器
        window.addEventListener('adb-device-changed', (e) => {
            if (e.detail && e.detail.device) {
                state.selectedDevice = e.detail.device;
            }
        });

        // 1. 显示/隐藏 独立操作按钮
        if (dom.btnToggleCropVis) {
            dom.btnToggleCropVis.addEventListener('click', (e) => {
                e.stopPropagation();
                toggleCropVisibility();
            });
        }

        if (dom.btnToggleSearchVis) {
            dom.btnToggleSearchVis.addEventListener('click', (e) => {
                e.stopPropagation();
                toggleSearchVisibility();
            });
        }

        // 2. 可编辑 独立操作按钮 (支持切换勾选与取消勾选)
        if (dom.btnEditCrop) {
            dom.btnEditCrop.addEventListener('click', (e) => {
                e.stopPropagation();
                toggleEditMode('crop');
            });
        }

        if (dom.btnEditSearch) {
            dom.btnEditSearch.addEventListener('click', (e) => {
                e.stopPropagation();
                toggleEditMode('search');
            });
        }

        // 兼容支持旧版复选框与单选框
        if (dom.chkShowCrop) {
            dom.chkShowCrop.addEventListener('change', () => {
                state.showCrop = dom.chkShowCrop.checked;
                updateControlButtonsUI();
                renderCanvas();
            });
        }

        if (dom.chkShowSearch) {
            dom.chkShowSearch.addEventListener('change', () => {
                state.showSearch = dom.chkShowSearch.checked;
                updateControlButtonsUI();
                renderCanvas();
            });
        }

        if (dom.radioEditCrop) {
            dom.radioEditCrop.addEventListener('change', () => {
                if (dom.radioEditCrop.checked) setEditMode('crop');
            });
        }

        if (dom.radioEditSearch) {
            dom.radioEditSearch.addEventListener('change', () => {
                if (dom.radioEditSearch.checked) setEditMode('search');
            });
        }

        if (dom.layerCropItem) {
            dom.layerCropItem.addEventListener('click', (e) => {
                if (e.target.closest('.cal-layer-check')) return;
                toggleEditMode('crop');
            });
        }

        if (dom.layerSearchItem) {
            dom.layerSearchItem.addEventListener('click', (e) => {
                if (e.target.closest('.cal-layer-check')) return;
                toggleEditMode('search');
            });
        }

        // 点击卡片或标题直接切换对应编辑目标
        if (dom.cardCrop) {
            dom.cardCrop.addEventListener('click', (e) => {
                if (e.target.closest('button') || e.target.closest('input')) return;
                setEditMode('crop');
            });
            const header = dom.cardCrop.querySelector('.cal-card-title-left');
            if (header) {
                header.addEventListener('click', (e) => {
                    e.stopPropagation();
                    toggleEditMode('crop');
                });
            }
        }

        if (dom.cardSearch) {
            dom.cardSearch.addEventListener('click', (e) => {
                if (e.target.closest('button') || e.target.closest('input')) return;
                setEditMode('search');
            });
            const header = dom.cardSearch.querySelector('.cal-card-title-left');
            if (header) {
                header.addEventListener('click', (e) => {
                    e.stopPropagation();
                    toggleEditMode('search');
                });
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
                    const curDev = getActiveDevice();
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

        // 还原匹配范围按钮
        if (dom.btnResetSearchArea) {
            dom.btnResetSearchArea.onclick = () => {
                resetSearchArea();
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

        // 资产名称点击编辑交互
        if (dom.targetNameWrap) {
            dom.targetNameWrap.addEventListener('click', () => {
                startEditTargetName();
            });
        }

        if (dom.btnSaveTargetName) {
            dom.btnSaveTargetName.addEventListener('click', (e) => {
                e.stopPropagation();
                commitTargetName();
            });
        }

        if (dom.btnCancelTargetName) {
            dom.btnCancelTargetName.addEventListener('click', (e) => {
                e.stopPropagation();
                cancelTargetName();
            });
        }

        if (dom.targetNameInput) {
            dom.targetNameInput.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    commitTargetName();
                } else if (e.key === 'Escape') {
                    e.preventDefault();
                    cancelTargetName();
                }
            });

            dom.targetNameInput.addEventListener('blur', (e) => {
                const rel = e.relatedTarget;
                if (rel === dom.btnSaveTargetName || rel === dom.btnCancelTargetName) {
                    return;
                }
                commitTargetName();
            });
        }

        // 图片文件名点击编辑交互 (纯点击类型禁止编辑)
        if (dom.targetFileWrap) {
            dom.targetFileWrap.addEventListener('click', () => {
                if (!dom.targetFileWrap.classList.contains('cal-readonly')) {
                    startEditTargetFile();
                }
            });
        }

        if (dom.btnSaveTargetFile) {
            dom.btnSaveTargetFile.addEventListener('click', (e) => {
                e.stopPropagation();
                commitTargetFile();
            });
        }

        if (dom.btnCancelTargetFile) {
            dom.btnCancelTargetFile.addEventListener('click', (e) => {
                e.stopPropagation();
                cancelTargetFile();
            });
        }

        if (dom.targetFileInput) {
            dom.targetFileInput.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    commitTargetFile();
                } else if (e.key === 'Escape') {
                    e.preventDefault();
                    cancelTargetFile();
                }
            });

            dom.targetFileInput.addEventListener('blur', (e) => {
                const rel = e.relatedTarget;
                if (rel === dom.btnSaveTargetFile || rel === dom.btnCancelTargetFile) {
                    return;
                }
                commitTargetFile();
            });
        }

        // 目标描述点击编辑交互
        if (dom.descDisplay) {
            dom.descDisplay.addEventListener('click', () => {
                startEditTargetDescription();
            });
        }

        if (dom.btnSaveTargetDesc) {
            dom.btnSaveTargetDesc.addEventListener('click', (e) => {
                e.stopPropagation();
                commitTargetDescription();
            });
        }

        if (dom.btnCancelTargetDesc) {
            dom.btnCancelTargetDesc.addEventListener('click', (e) => {
                e.stopPropagation();
                cancelTargetDescription();
            });
        }

        if (dom.targetDescInput) {
            dom.targetDescInput.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    commitTargetDescription();
                } else if (e.key === 'Escape') {
                    e.preventDefault();
                    cancelTargetDescription();
                }
            });

            dom.targetDescInput.addEventListener('blur', (e) => {
                const rel = e.relatedTarget;
                if (rel === dom.btnSaveTargetDesc || rel === dom.btnCancelTargetDesc) {
                    return;
                }
                commitTargetDescription();
            });
        }

        // 目标吸附对齐方式变更联动
        if (dom.targetAnchor) {
            dom.targetAnchor.addEventListener('change', () => {
                if (!state.selectedKey) return;
                const curTarget = state.targets.find(t => t.key === state.selectedKey);
                if (curTarget) {
                    curTarget.anchor = dom.targetAnchor.value;
                }
            });
        }

        setupCanvasEvents();
    }

    // 暴露供主界面全局保存、快捷键与自动化协同调用的标定工作台 API
    window.calibrationStudio = {
        saveTarget: saveTarget,
        hasActiveTarget: () => Boolean(state.selectedKey),
        hasCropArea: () => Boolean(state.cropArea && state.cropArea.length === 4),
        getCurrentTarget: () => state.targets.find(t => t.key === state.selectedKey),
        captureScreen: captureScreen,
        openImageFileDialog: openImageFileDialog,
        loadLocalImageFile: loadLocalImageFile,
        applyZoom: applyZoom,
        updateViewportFrameDimensions: updateViewportFrameDimensions,
        loadTargets: loadTargets,
        getState: () => state
    };

    // 暴露供助战面板等快速定位目标的辅助方法
    window.selectCalibrationTargetByKey = function (targetKey) {
        if (!targetKey) return;
        state.activeCategory = 'friend';
        if (dom.categoryTabs) {
            dom.categoryTabs.forEach(btn => {
                btn.classList.toggle('active', btn.dataset.cat === 'friend');
            });
        }
        renderTargetsList();
        selectTarget(targetKey);
    };

    document.addEventListener('DOMContentLoaded', function () {
        initDom();
        updateControlButtonsUI();
        bindEvents();
        loadTargets();
        updateViewportFrameDimensions();
    });
})();
