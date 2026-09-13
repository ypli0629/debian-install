import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import { TabBar } from './tabbar.js';
import { applyPlacement, detachBar, isBarVisible, scheduleAutoHide, cancelAutoHide, TabIndicator } from './placement.js';
import { OverviewIntegration } from './overview.js';
import { restoreGroups, saveGroups } from './groupState.js';

function framesEqual(a, b) {
    return a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
}

class WindowGroup {
    constructor(ext, windows, active, { appId = '' } = {}) {
        this._ext = ext;
        this._windows = [];
        this._signals = new Map();
        this._saved = new Map();
        this._active = null;
        this._appId = appId;
        this._syncQueued = false;
        this._destroyed = false;
        this._placement = null;
        this._autoHideId = 0;
        this._prevActive = null;

        this._bar = new TabBar({
            onActivate: win => this.activateTab(win),
            onClose: win => win.delete(global.get_current_time()),
            onReorder: (win, targetIndex) => this._reorder(win, targetIndex),
            onTearOff: win => this.removeWindow(win),
            onNewWindow: () => this._ext.launchNewWindow(this),
            onWheel: dir => this.cycle(dir),
            tearOffThreshold: () => this._ext._settingInt('tear-off-threshold', 24),
        });
        applyPlacement(this);
        this._barEnterId = this._bar.connect('enter-event', () => {
            cancelAutoHide(this);
        });
        this._barLeaveId = this._bar.connect('leave-event', () => {
            if (this._bar.visible)
                scheduleAutoHide(this);
        });

        for (const win of windows)
            this.addWindow(win, { stack: false });

        this._stackTo(active);
        this._active = active;
        this._render();
        this._updatePosition();
        this._updateVisibility();
        for (const win of windows)
            this._ext._overview.refresh(win);
        this._ext._saveState();
    }

    get windows() {
        return this._windows;
    }

    get active() {
        return this._active;
    }

    get appId() {
        return this._appId;
    }

    hasWindow(win) {
        return this._windows.includes(win);
    }

    workspaceIndex() {
        return this._active ? this._active.get_workspace().index() : -1;
    }

    belongsToApp(app) {
        return this._appId !== '' && this._appId !== null && app?.get_id() === this._appId;
    }

    addWindow(win, { stack = true } = {}) {
        if (this._destroyed || this._windows.includes(win))
            return;
        this._saved.set(win, win.get_frame_rect());
        this._windows.push(win);
        const ids = [
            win.connect('unmanaging', () => this.removeWindow(win, { restore: false })),
            win.connect('position-changed', () => this._onGeometryChanged(win)),
            win.connect('size-changed', () => this._onGeometryChanged(win)),
            win.connect('notify::title', () => this._bar.updateTitle(win, win.get_title() ?? '')),
            win.connect('workspace-changed', () => {
                if (this._ext._settingBool('group-per-workspace', true) &&
                    win.get_workspace().index() !== this.workspaceIndex())
                    this.removeWindow(win);
            }),
        ];
        this._signals.set(win, ids);
        if (stack)
            this._stackTo(this._active ?? win);
        this._render();
        this._updatePosition();
        this._ext._overview.refresh(win);
        this._ext._saveState();
    }

    removeWindow(win, { restore = true } = {}) {
        if (this._destroyed || !this._windows.includes(win))
            return;

        const idx = this._windows.indexOf(win);
        const ids = this._signals.get(win) ?? [];
        for (const id of ids)
            win.disconnect(id);
        this._signals.delete(win);
        this._windows.splice(idx, 1);

        const frame = this._saved.get(win);
        this._saved.delete(win);
        if (restore && frame) {
            try {
                win.move_resize_frame(false, frame.x, frame.y, frame.width, frame.height);
            } catch (e) { /* window may already be gone */ }
        }
        this._ext._overview.refresh(win);

        if (this._windows.length <= 1) {
            this.dissolve();
            return;
        }
        if (this._active === win) {
            this._active = this._pickNextActive(idx);
            this._stackTo(this._active);
            this._active.activate(global.get_current_time());
        }
        this._ext._overview.refresh(this._active);
        this._render();
        this._updatePosition();
        this._updateVisibility();
    }

    _pickNextActive(removedIdx) {
        const dir = this._ext._settingString('close-activates-direction', 'left');
        if (dir === 'last-active') {
            const prev = this._prevActive;
            if (prev && this._windows.includes(prev))
                return prev;
        }
        if (dir === 'right')
            return this._windows[Math.min(removedIdx, this._windows.length - 1)];
        return this._windows[Math.max(0, removedIdx - 1)];
    }

    activateTab(win) {
        if (this._destroyed || !this._windows.includes(win))
            return;
        const oldActive = this._active;
        if (oldActive && oldActive !== win && this._windows.includes(oldActive))
            this._prevActive = oldActive;
        this._active = win;
        this._stackTo(win);
        this._render();
        this._updatePosition();
        win.activate(global.get_current_time());
        if (this._ext._settingBool('switch-animation', false)) {
            try {
                const actor = win.get_compositor_private();
                if (actor) {
                    actor.opacity = 0;
                    actor.ease({
                        opacity: 255,
                        duration: 140,
                        mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                    });
                }
            } catch (e) { }
        }
        this._updateVisibility();
        this._ext._overview.refresh(oldActive);
        this._ext._overview.refresh(win);
    }

    cycle(dir) {
        if (this._destroyed)
            return null;
        const i = this._windows.indexOf(this._active);
        const next = this._windows[(i + dir + this._windows.length) % this._windows.length];
        this.activateTab(next);
        return next;
    }

    _reorder(win, targetIndex) {
        if (this._destroyed || !this._windows.includes(win))
            return;
        const from = this._windows.indexOf(win);
        if (from === targetIndex)
            return;
        this._windows.splice(from, 1);
        this._windows.splice(Math.max(0, Math.min(targetIndex, this._windows.length)), 0, win);
        this._render();
        this._updatePosition();
        this._ext._saveState();
    }

    dissolve() {
        if (this._destroyed)
            return;
        this._destroyed = true;
        const windows = [...this._windows];
        for (const [win, ids] of this._signals) {
            for (const id of ids)
                win.disconnect(id);
        }
        this._signals.clear();

        for (const win of windows) {
            const frame = this._saved.get(win);
            if (frame) {
                try {
                    win.move_resize_frame(false, frame.x, frame.y, frame.width, frame.height);
                } catch (e) { /* window may already be gone */ }
            }
        }
        this._windows = [];
        this._saved.clear();

        cancelAutoHide(this);
        detachBar(this);
        this._bar.destroy();

        for (const win of windows)
            this._ext._overview.refresh(win);

        const idx = this._ext._groups.indexOf(this);
        if (idx >= 0)
            this._ext._groups.splice(idx, 1);
        this._ext._saveState();
    }

    _stackTo(active) {
        if (!active)
            return;
        const f = active.get_frame_rect();
        for (const win of this._windows) {
            if (win === active)
                continue;
            const w = win.get_frame_rect();
            if (!framesEqual(w, f))
                win.move_resize_frame(false, f.x, f.y, f.width, f.height);
        }
    }

    _onGeometryChanged(win) {
        if (win !== this._active || this._destroyed)
            return;
        this._updatePosition();
        cancelAutoHide(this);
        if (this._bar.visible)
            scheduleAutoHide(this);
        if (!this._syncQueued) {
            this._syncQueued = true;
            GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
                this._syncQueued = false;
                if (!this._destroyed && this._active)
                    this._stackTo(this._active);
                return GLib.SOURCE_REMOVE;
            });
        }
    }

    _updatePosition() {
        if (this._destroyed || !this._active)
            return;
        const f = this._active.get_frame_rect();
        const monitor = Main.layoutManager.monitors[this._active.get_monitor()] ??
            Main.layoutManager.primaryMonitor;
        this._bar.positionAbove(f, monitor, this._placement);
    }

    _updateVisibility() {
        if (this._destroyed)
            return;
        const show = isBarVisible(this);
        this._bar.visible = show;
        if (show) {
            this._updatePosition();
            cancelAutoHide(this);
            scheduleAutoHide(this);
        } else {
            cancelAutoHide(this);
        }
    }

    _render() {
        if (this._destroyed)
            return;
        this._bar.setTabs(this._windows.map(w => ({
            win: w,
            title: w.get_title() || 'Window',
            active: w === this._active,
        })));
    }
}

export class TabbedWindows {
    constructor(extension) {
        this.extension = extension;
        this._settings = extension.getSettings();
    }

    enable() {
        this._groups = [];
        this._savePending = false;
        this._restoreId = 0;
        this._settingsIds = [];
        this._dissolvedApps = new Set();

        this._overview = new OverviewIntegration();
        this._overview.enable(win => this._isOverviewHidden(win));

        const display = global.display;
        this._displayIds = [
            display.connect('notify::focus-window', () => this._onFocusChanged()),
            display.connect('window-created', (disp, win) => this._onWindowCreated(win)),
        ];
        this._wmId = global.window_manager.connect('switch-workspace', () => this._onFocusChanged());
        this._overviewIds = [
            Main.overview.connect('showing', () => this._onFocusChanged()),
            Main.overview.connect('hiding', () => this._onFocusChanged()),
        ];

        Main.wm.addKeybinding('group-toggle', this._settings, Meta.KeyBindingFlags.NONE, Shell.ActionMode.NORMAL,
            () => this._toggleGroup());
        Main.wm.addKeybinding('ungroup-current', this._settings, Meta.KeyBindingFlags.NONE, Shell.ActionMode.NORMAL,
            () => this._removeCurrent());
        Main.wm.addKeybinding('next-tab', this._settings, Meta.KeyBindingFlags.NONE, Shell.ActionMode.NORMAL,
            () => this._cycle(1));
        Main.wm.addKeybinding('prev-tab', this._settings, Meta.KeyBindingFlags.NONE, Shell.ActionMode.NORMAL,
            () => this._cycle(-1));
        for (let i = 1; i <= 9; i++) {
            Main.wm.addKeybinding(`switch-to-tab-${i}`, this._settings, Meta.KeyBindingFlags.NONE, Shell.ActionMode.NORMAL,
                () => this._switchToTab(i));
        }

        this._indicator = new TabIndicator(this);
        this._indicator.attach();

        for (const key of ['tab-bar-position', 'show-tab-bar', 'panel-indicator', 'bar-auto-hide-ms']) {
            try {
                this._settingsIds.push(this._settings.connect(`changed::${key}`, () => this._onSettingChanged(key)));
            } catch (e) {
                this._settingsIds.push(0);
            }
        }

        if (this._settingBool('restore-groups-on-login', true)) {
            this._restoreId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1500, () => {
                this._restoreId = 0;
                this._restoreSavedGroups();
                return GLib.SOURCE_REMOVE;
            });
        }
    }

    disable() {
        if (this._restoreId) {
            GLib.source_remove(this._restoreId);
            this._restoreId = 0;
        }

        this._overview.disable();
        this._overview = null;

        for (const group of [...this._groups])
            group.dissolve();
        this._groups = [];

        for (const id of this._displayIds)
            global.display.disconnect(id);
        this._displayIds = [];
        if (this._wmId) {
            global.window_manager.disconnect(this._wmId);
            this._wmId = 0;
        }
        for (const id of this._overviewIds)
            Main.overview.disconnect(id);
        this._overviewIds = [];

        Main.wm.removeKeybinding('group-toggle');
        Main.wm.removeKeybinding('ungroup-current');
        Main.wm.removeKeybinding('next-tab');
        Main.wm.removeKeybinding('prev-tab');
        for (let i = 1; i <= 9; i++)
            Main.wm.removeKeybinding(`switch-to-tab-${i}`);

        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }

        if (this._settingsIds) {
            for (const id of this._settingsIds) {
                try {
                    if (id && this._settings)
                        this._settings.disconnect(id);
                } catch (e) { }
            }
            this._settingsIds = [];
        }

        this._settings = null;
    }

    _settingBool(key, fallback) {
        try {
            return this._settings ? this._settings.get_boolean(key) : fallback;
        } catch (e) {
            return fallback;
        }
    }

    _settingString(key, fallback) {
        try {
            return this._settings ? this._settings.get_string(key) : fallback;
        } catch (e) {
            return fallback;
        }
    }

    _settingInt(key, fallback) {
        try {
            return this._settings ? this._settings.get_int(key) : fallback;
        } catch (e) {
            return fallback;
        }
    }

    _switchToTab(n) {
        if (!this._settingBool('number-keys-switch', false))
            return;
        const focus = global.display.focus_window;
        const group = focus ? this._groupOf(focus) : null;
        if (!group)
            return;
        const win = group.windows[n - 1];
        if (win)
            group.activateTab(win);
    }

    _onSettingChanged(key) {
        if (key === 'tab-bar-position') {
            for (const g of this._groups) {
                if (g._destroyed)
                    continue;
                applyPlacement(g);
                g._updatePosition();
            }
        }
        for (const g of this._groups) {
            if (g._destroyed)
                continue;
            g._updateVisibility();
        }
        this._updateIndicator();
    }

    _updateIndicator() {
        this._indicator?.update(() => {
            const f = global.display.focus_window;
            return f ? this._groupOf(f) : null;
        });
    }

    launchNewWindow(group) {
        const app = Shell.WindowTracker.get_default().get_window_app(group.active);
        if (!app)
            return;
        try {
            const wsIndex = group.workspaceIndex();
            const launched = app.launch(global.get_current_time(), Math.max(0, wsIndex));
            if (!launched)
                app.launch();
        } catch (e) {
            try {
                app.launch();
            } catch (e2) { /* cannot launch */ }
        }
    }

    _groupOf(win) {
        return this._groups.find(g => g.hasWindow(win)) ?? null;
    }

    _isOverviewHidden(win) {
        for (const group of this._groups) {
            if (group._destroyed)
                continue;
            if (group.hasWindow(win) && group.active && win !== group.active)
                return true;
        }
        return false;
    }

    _toggleGroup() {
        const focus = global.display.focus_window;
        if (!focus || focus.window_type !== Meta.WindowType.NORMAL)
            return;

        const existing = this._groupOf(focus);
        if (existing) {
            existing.dissolve();
            const tracker = Shell.WindowTracker.get_default();
            const dissolvedId = tracker.get_window_app(focus)?.get_id();
            if (dissolvedId && this._dissolvedApps)
                this._dissolvedApps.add(dissolvedId);
            return;
        }

        const tracker = Shell.WindowTracker.get_default();
        const app = tracker.get_window_app(focus);
        if (!app)
            return;

        const crossApp = this._settingBool('allow-cross-app', false);
        const appId = crossApp ? '' : app.get_id();
        const wsIdx = focus.get_workspace().index();
        const includeMinimized = this._settingBool('merge-includes-minimized', true);
        const perWorkspace = this._settingBool('group-per-workspace', true);
        const windows = global.get_window_actors()
            .map(a => a.meta_window)
            .filter(w => w.window_type === Meta.WindowType.NORMAL &&
                !w.is_skip_taskbar() &&
                (!perWorkspace || w.get_workspace().index() === wsIdx) &&
                (includeMinimized || !w.minimized) &&
                (crossApp || tracker.get_window_app(w)?.get_id() === app.get_id()));

        if (windows.length < 2)
            return;

        this._dissolvedApps?.delete(app.get_id());
        this._groups.push(new WindowGroup(this, windows, focus, { appId }));
    }

    _removeCurrent() {
        const focus = global.display.focus_window;
        const group = focus ? this._groupOf(focus) : null;
        if (group)
            group.removeWindow(focus);
    }

    _cycle(dir) {
        const focus = global.display.focus_window;
        const group = focus ? this._groupOf(focus) : null;
        if (group)
            group.cycle(dir);
    }

    _onFocusChanged() {
        const focus = global.display.focus_window;
        for (const group of this._groups) {
            if (group._destroyed)
                continue;
            if (focus && group.hasWindow(focus) && group._active !== focus) {
                const oldActive = group._active;
                if (oldActive && group._windows.includes(oldActive))
                    group._prevActive = oldActive;
                group._active = focus;
                group._render();
                group._updatePosition();
                this._overview.refresh(oldActive);
                this._overview.refresh(focus);
            }
            group._updateVisibility();
        }
        this._updateIndicator();
    }

    _onWindowCreated(win) {
        GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
            if (!win.get_compositor_private())
                return GLib.SOURCE_REMOVE;
            const app = Shell.WindowTracker.get_default().get_window_app(win);
            if (!app || !this._autoGroupAllowed(app, win))
                return GLib.SOURCE_REMOVE;
            const perWorkspace = this._settingBool('group-per-workspace', true);
            const activates = this._settingBool('new-tab-activates', true);
            let matched = null;
            for (const group of this._groups) {
                if (group._destroyed)
                    continue;
                if (perWorkspace && group.workspaceIndex() !== win.get_workspace().index())
                    continue;
                if (group.belongsToApp(app)) {
                    matched = group;
                    break;
                }
            }
            if (matched) {
                if (!this._autoGroupAllowed(app, win, matched))
                    return GLib.SOURCE_REMOVE;
                matched.addWindow(win);
                if (activates)
                    matched.activateTab(win);
                return GLib.SOURCE_REMOVE;
            }
            this._autoMergeNewWindow(app, win);
            return GLib.SOURCE_REMOVE;
        });
    }

    _autoMergeNewWindow(app, win) {
        if (!this._settingBool('auto-merge', false))
            return;
        const tracker = Shell.WindowTracker.get_default();
        const appId = app.get_id();
        if (!appId || this._dissolvedApps?.has(appId))
            return;
        const mode = this._settingString('auto-group-mode', 'always');
        if (mode === 'fullscreen-only' && !win.fullscreen)
            return;
        const perWorkspace = this._settingBool('group-per-workspace', true);
        const includeMinimized = this._settingBool('merge-includes-minimized', true);
        const wsIdx = win.get_workspace().index();
        const windows = global.get_window_actors()
            .map(a => a.meta_window)
            .filter(w => w.window_type === Meta.WindowType.NORMAL &&
                !w.is_skip_taskbar() &&
                (!perWorkspace || w.get_workspace().index() === wsIdx) &&
                (includeMinimized || !w.minimized) &&
                tracker.get_window_app(w)?.get_id() === appId);
        if (windows.length < 2)
            return;
        const group = new WindowGroup(this, windows, win, { appId });
        this._groups.push(group);
        group.activateTab(win);
    }

    _autoGroupAllowed(app, win, group = null) {
        if (!this._settings)
            return false;
        let mode = 'always';
        try {
            mode = this._settings.get_string('auto-group-mode') ?? 'always';
        } catch (e) { /* key missing */ }
        if (mode === 'never')
            return false;
        try {
            const excluded = this._settings.get_strv('group-exclude-apps') ?? [];
            if (app.get_id() && excluded.includes(app.get_id()))
                return false;
        } catch (e) { /* key missing */ }
        if (mode === 'fullscreen-only' && group) {
            return !!(win?.fullscreen || group.active?.fullscreen);
        }
        return true;
    }

    _restoreSavedGroups() {
        const entries = restoreGroups(this._settings);
        if (entries.length === 0)
            return;
        const tracker = Shell.WindowTracker.get_default();
        for (const entry of entries) {
            const wanted = new Set(entry.sequences);
            const windows = global.get_window_actors()
                .map(a => a.meta_window)
                .filter(w => w.window_type === Meta.WindowType.NORMAL &&
                    !w.is_skip_taskbar() &&
                    w.get_workspace().index() === entry.workspaceIndex &&
                    wanted.has(w.get_stable_sequence()) &&
                    (entry.appId === null || tracker.get_window_app(w)?.get_id() === entry.appId));
            if (windows.length < 2)
                continue;
            const active = windows.find(w => w.get_stable_sequence() === entry.activeSeq) ?? windows[0];
            this._groups.push(new WindowGroup(this, windows, active, { appId: entry.appId ?? '' }));
        }
    }

    _saveState() {
        if (!this._settings || this._savePending)
            return;
        this._savePending = true;
        GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._savePending = false;
            if (this._settings)
                saveGroups(this._settings, this._groups);
            this._updateIndicator();
            return GLib.SOURCE_REMOVE;
        });
    }
}
