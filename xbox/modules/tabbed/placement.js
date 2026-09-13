import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export function applyPlacement(group) {
    if (!group || group._destroyed)
        return;
    let pos = 'top';
    try {
        pos = group._ext._settingString('tab-bar-position', 'top') ?? 'top';
    } catch (e) {
        pos = 'top';
    }
    if (group._placement === pos)
        return;

    if (group._placement === 'panel') {
        try {
            Main.panel._centerBox.remove_child(group._bar);
        } catch (e) { }
        try {
            group._bar.remove_style_class_name('tabby-bar-panel');
        } catch (e) { }
    } else if (group._placement !== null && group._placement !== undefined) {
        try {
            Main.layoutManager.removeChrome(group._bar);
        } catch (e) { }
    }

    let effective = pos;
    if (pos === 'panel') {
        let added = false;
        try {
            group._bar.add_style_class_name('tabby-bar-panel');
            Main.panel._centerBox.add_child(group._bar);
            added = true;
        } catch (e) {
            added = false;
        }
        if (!added) {
            try {
                group._bar.remove_style_class_name('tabby-bar-panel');
            } catch (e) { }
            effective = 'top';
        }
    }
    if (effective !== 'panel') {
        try {
            Main.layoutManager.addChrome(group._bar, { trackFullscreen: true });
        } catch (e) { }
    }
    group._placement = effective;
}

export function detachBar(group) {
    if (!group)
        return;
    if (group._placement === 'panel') {
        try {
            Main.panel._centerBox.remove_child(group._bar);
        } catch (e) { }
    } else {
        try {
            Main.layoutManager.removeChrome(group._bar);
        } catch (e) { }
    }
}

export function isBarVisible(group) {
    try {
        if (!group || group._destroyed)
            return false;
        if (!group._active)
            return false;
        const focus = global.display.focus_window;
        if (!focus || !group._windows.includes(focus))
            return false;
        if (Main.overview.visible)
            return false;
        if (!group._ext._settingBool('show-tab-bar', true))
            return false;
        if (group._ext._settingBool('group-per-workspace', true) &&
            group._active.get_workspace().index() !==
            global.workspace_manager.get_active_workspace_index())
            return false;
        return true;
    } catch (e) {
        return false;
    }
}

export function scheduleAutoHide(group) {
    if (!group)
        return;
    cancelAutoHide(group);
    let ms = 0;
    try {
        ms = group._ext._settingInt('bar-auto-hide-ms', 0) ?? 0;
    } catch (e) {
        ms = 0;
    }
    if (!ms || ms <= 0)
        return;
    if (!group._bar || !group._bar.visible)
        return;
    group._autoHideId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
        group._autoHideId = 0;
        try {
            group._bar.visible = false;
        } catch (e) { }
        return GLib.SOURCE_REMOVE;
    });
}

export function cancelAutoHide(group) {
    if (!group)
        return;
    const id = group._autoHideId;
    if (id) {
        try {
            GLib.source_remove(id);
        } catch (e) { }
        group._autoHideId = 0;
    }
}

export class TabIndicator {
    constructor(ext) {
        this._ext = ext;
        this._box = null;
        this._label = null;
        this._enabled = false;
    }

    attach() {
        if (this._box)
            return;
        try {
            const box = new St.BoxLayout({
                style_class: 'tabby-indicator',
                visible: false,
                y_align: Clutter.ActorAlign.CENTER,
            });
            const icon = new St.Icon({
                icon_name: 'view-paged-symbolic',
                icon_size: 14,
            });
            const label = new St.Label({
                text: '',
                y_align: Clutter.ActorAlign.CENTER,
            });
            box.add_child(icon);
            box.add_child(label);
            Main.panel._rightBox.add_child(box);
            this._box = box;
            this._label = label;
            this._enabled = true;
        } catch (e) {
            this._box = null;
            this._label = null;
            this._enabled = false;
        }
    }

    update(getGroup) {
        if (!this._box)
            return;
        let group = null;
        try {
            group = typeof getGroup === 'function' ? getGroup() : null;
        } catch (e) {
            group = null;
        }
        let enabled = true;
        try {
            enabled = this._ext._settingBool('panel-indicator', false);
        } catch (e) {
            enabled = true;
        }
        if (!enabled || !group || group._destroyed) {
            this._box.visible = false;
            return;
        }
        try {
            this._label.text = `${group._windows.length}`;
            this._box.visible = true;
        } catch (e) {
            this._box.visible = false;
        }
    }

    destroy() {
        if (this._box) {
            try {
                Main.panel._rightBox.remove_child(this._box);
            } catch (e) { }
            try {
                this._box.destroy();
            } catch (e) { }
            this._box = null;
            this._label = null;
        }
        this._enabled = false;
    }
}
