import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import { Workspace } from 'resource:///org/gnome/shell/ui/workspace.js';

export class OverviewIntegration {
    constructor() {
        this._isHidden = null;
        this._origAddWindow = null;
        this._patched = false;
    }

    enable(isHidden) {
        this._isHidden = typeof isHidden === 'function' ? isHidden : null;
        this._install();
        this._sweepExisting();
    }

    disable() {
        this._restore();
        this._isHidden = null;
        this._restorePreviews();
    }

    refresh(win) {
        if (!win || !this._patched)
            return;
        const hidden = this._evalHidden(win);
        for (const ws of this._collectWorkspaces()) {
            try {
                const present = !!ws.containsMetaWindow?.(win);
                if (hidden && present) {
                    ws._doRemoveWindow?.(win);
                } else if (!hidden && !present) {
                    if (!ws._isMyWindow?.(win))
                        continue;
                    if (win.is_skip_taskbar?.())
                        continue;
                    if (win.get_compositor_private?.())
                        this._readdWindow(ws, win);
                }
            } catch (e) { /* ignore */ }
        }
    }

    // ---- internals --------------------------------------------------------

    _install() {
        if (this._patched)
            return;
        try {
            const proto = Workspace?.prototype;
            if (!proto || typeof proto._doAddWindow !== 'function')
                return;
            const orig = proto._doAddWindow;
            const self = this;
            proto._doAddWindow = function (metaWin, ...args) {
                try {
                    if (metaWin && self._evalHidden(metaWin))
                        return;
                } catch (e) { /* fall through to stock behavior */ }
                return orig.call(this, metaWin, ...args);
            };
            this._origAddWindow = orig;
            this._patched = true;
        } catch (e) {
            this._patched = false;
        }
    }

    _restore() {
        if (!this._patched)
            return;
        try {
            if (this._origAddWindow)
                Workspace.prototype._doAddWindow = this._origAddWindow;
        } catch (e) { /* prototype unreachable */ }
        this._patched = false;
        this._origAddWindow = null;
    }

    _evalHidden(win) {
        if (!this._isHidden || !win)
            return false;
        try {
            return !!this._isHidden(win);
        } catch (e) {
            return false;
        }
    }

    _sweepExisting() {
        for (const ws of this._collectWorkspaces()) {
            try {
                const clones = [...(ws._windows ?? [])];
                for (const clone of clones) {
                    const win = clone?.metaWindow;
                    if (win && this._evalHidden(win))
                        ws._doRemoveWindow?.(win);
                }
            } catch (e) { /* ignore */ }
        }
    }

    _restorePreviews() {
        let actors = [];
        try {
            actors = global.get_window_actors?.() ?? [];
        } catch (e) {
            return;
        }
        for (const ws of this._collectWorkspaces()) {
            for (const actor of actors) {
                try {
                    const win = actor?.meta_window;
                    if (!win || win.is_skip_taskbar?.())
                        continue;
                    if (!ws.containsMetaWindow?.(win) && ws._isMyWindow?.(win))
                        this._readdWindow(ws, win);
                } catch (e) { /* ignore */ }
            }
        }
    }

    _readdWindow(ws, win) {
        try {
            const id = ws._skipTaskbarSignals?.get(win);
            if (id !== undefined) {
                win.disconnect(id);
                ws._skipTaskbarSignals.delete(win);
            }
        } catch (e) { /* signal bookkeeping unavailable */ }
        try {
            this._origAddWindow?.call(ws, win);
        } catch (e) { /* ignore */ }
    }

    _collectWorkspaces() {
        const out = [];
        try {
            const views = Main?.overview?._overview?.controls?._workspacesDisplay
                ?._workspacesViews ?? [];
            for (const view of views) {
                if (Array.isArray(view?._workspaces)) {
                    for (const ws of view._workspaces) {
                        if (ws)
                            out.push(ws);
                    }
                }
                if (view?._workspacesView?._workspaces) {
                    for (const ws of view._workspacesView._workspaces) {
                        if (ws)
                            out.push(ws);
                    }
                } else if (view?._workspacesView?._workspace) {
                    out.push(view._workspacesView._workspace);
                }
                if (view?._workspace)
                    out.push(view._workspace);
            }
        } catch (e) { /* overview structure unknown */ }
        return out;
    }
}
