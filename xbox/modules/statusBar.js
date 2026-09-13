import GLib from 'gi://GLib';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import { ExtensionModule } from './base.js';

const PANEL_BOXES = ['_centerBox', '_rightBox', '_leftBox'];
const POSITION_INDEX = { center: 0, right: 1, left: 2 };

const MANUAL_KEYS = {
    panelSize: 'panel-size',
    iconSize: 'panel-icon-size',
    buttonPadding: 'panel-button-padding-size',
    iconSpacing: 'panel-icon-spacing',
    clockPosition: 'clock-position',
    clockOffset: 'clock-position-offset',
};

const MACOS_KEYS = {
    panelSize: 'macos-panel-size',
    iconSize: 'macos-icon-size',
    buttonPadding: 'macos-button-padding-size',
    iconSpacing: 'macos-icon-spacing',
    clockPosition: 'macos-clock-position',
    clockOffset: 'macos-clock-offset',
};

const SETTING_KEYS = [
    'macos-style',
    ...Object.values(MANUAL_KEYS),
    ...Object.values(MACOS_KEYS),
    'macos-panel-opacity',
    'macos-panel-radius',
    'macos-panel-margin',
];

export default class StatusBarModule extends ExtensionModule {
    enable() {
        if (!this.settings.get_boolean('status-bar-enabled'))
            return;

        this._settingsIds = [];
        this._panelSignals = [];
        this._clockOrigin = null;
        this._applyId = 0;
        this._originPanelHeight = Main.panel.height;
        this._macosActive = this.settings.get_boolean('macos-style');

        for (const key of SETTING_KEYS) {
            this._settingsIds.push(this.settings.connect(`changed::${key}`, () => {
                if (key === 'macos-style')
                    this._macosActive = this.settings.get_boolean('macos-style');
                this._applyAll();
            }));
        }

        this._captureClockOrigin();
        this._applyAll();

        for (const name of [...PANEL_BOXES, null]) {
            const box = name ? Main.panel[name] : Main.panel;
            if (!box)
                continue;
            this._panelSignals.push([box, box.connect('child-added', () => this._scheduleApply())]);
        }
    }

    disable() {
        for (const id of this._settingsIds)
            this.settings.disconnect(id);
        this._settingsIds = [];

        for (const [box, id] of this._panelSignals) {
            try {
                box.disconnect(id);
            } catch (e) { /* actor already gone */ }
        }
        this._panelSignals = [];

        if (this._applyId) {
            GLib.source_remove(this._applyId);
            this._applyId = 0;
        }

        this._clearStyles();
        Main.panel.height = this._originPanelHeight;
        this._restoreClock();
    }

    _scheduleApply() {
        if (this._applyId)
            return;
        this._applyId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
            this._applyId = 0;
            this._applyAll();
            return GLib.SOURCE_REMOVE;
        });
    }

    _key(role) {
        return this._macosActive ? MACOS_KEYS[role] : MANUAL_KEYS[role];
    }

    _getInt(role) {
        return this.settings.get_int(this._key(role));
    }

    _getString(role) {
        return this.settings.get_string(this._key(role));
    }

    _applyAll() {
        this._applyPanel();
        this._applyIconSpacing();
        this._applyButtonPadding();
        this._applyIconSize();
        this._applyClockPosition();
    }

    _applyPanel() {
        const styles = [];
        const size = this._getInt('panelSize');
        if (size > 0) {
            styles.push(`height: ${size}px !important;`);
            Main.panel.height = size;
        } else {
            Main.panel.height = this._originPanelHeight;
        }

        if (this._macosActive) {
            const opacity = Math.max(0, Math.min(100, this.settings.get_int('macos-panel-opacity')));
            if (opacity < 100)
                styles.push(`background-color: ${this._glassColor(opacity)} !important;`);

            const radius = this.settings.get_int('macos-panel-radius');
            if (radius > 0)
                styles.push(`border-radius: 0 0 ${radius}px ${radius}px;`);

            const margin = this.settings.get_int('macos-panel-margin');
            if (margin > 0)
                styles.push(`margin: 0 ${margin}px;`);

            Main.panel.add_style_class_name('xbox-macos-panel');
        } else {
            Main.panel.remove_style_class_name('xbox-macos-panel');
        }

        Main.panel.set_style(styles.join(' '));
    }

    _glassColor(opacity) {
        let red = 28;
        let green = 28;
        let blue = 32;
        let alpha = 255;
        try {
            const color = Main.panel.get_theme_node().get_background_color();
            if (color.alpha > 0) {
                red = color.red;
                green = color.green;
                blue = color.blue;
                alpha = color.alpha;
            } else if (St.Settings.get().color_scheme !== St.ColorScheme.PREFER_DARK) {
                red = 250;
                green = 250;
                blue = 252;
            }
        } catch (e) { /* fall back to neutral glass */ }
        const result = (alpha / 255) * (opacity / 100);
        return `rgba(${red}, ${green}, ${blue}, ${result.toFixed(3)})`;
    }

    _applyIconSpacing() {
        const spacing = this._getInt('iconSpacing');
        for (const box of this._indicatorBoxes())
            box.set_style(spacing > 0 ? `spacing: ${spacing}px;` : '');
    }

    _applyButtonPadding() {
        const pad = this._getInt('buttonPadding');
        for (const button of this._panelButtons())
            button.set_style(pad > 0 ? `-natural-hpadding: ${pad}px; -minimum-hpadding: ${pad}px;` : '');
    }

    _applyIconSize() {
        const size = this._getInt('iconSize');
        for (const icon of this._panelIcons())
            icon.set_style(size > 0 ? `icon-size: ${size}px;` : '');
    }

    _clearStyles() {
        for (const box of this._indicatorBoxes())
            box.set_style('');
        for (const button of this._panelButtons())
            button.set_style('');
        for (const icon of this._panelIcons())
            icon.set_style('');
        Main.panel.remove_style_class_name('xbox-macos-panel');
        Main.panel.set_style('');
    }

    _panelButtons() {
        const out = [];
        const visit = actor => {
            try {
                if (actor.has_style_class_name?.('panel-button'))
                    out.push(actor);
                for (const child of actor.get_children?.() ?? [])
                    visit(child);
            } catch (e) { /* ignore */ }
        };
        visit(Main.panel);
        return out;
    }

    _panelIcons() {
        const out = [];
        const visit = actor => {
            try {
                if (actor instanceof St.Icon)
                    out.push(actor);
                for (const child of actor.get_children?.() ?? [])
                    visit(child);
            } catch (e) { /* ignore */ }
        };
        visit(Main.panel);
        return out;
    }

    _indicatorBoxes() {
        const out = [];
        const visit = actor => {
            try {
                if (actor.has_style_class_name?.('panel-status-indicators-box'))
                    out.push(actor);
                for (const child of actor.get_children?.() ?? [])
                    visit(child);
            } catch (e) { /* ignore */ }
        };
        visit(Main.panel);
        return out;
    }

    _captureClockOrigin() {
        const container = Main.panel.statusArea?.dateMenu?.container;
        const parent = container?.get_parent();
        if (!container || !parent)
            return;
        this._clockOrigin = {
            container,
            parent,
            index: parent.get_children().indexOf(container),
        };
    }

    _applyClockPosition() {
        const container = Main.panel.statusArea?.dateMenu?.container;
        const parent = container?.get_parent();
        if (!container || !parent)
            return;

        const position = this._getString('clockPosition');
        const offset = Math.max(0, this._getInt('clockOffset'));
        const target = Main.panel[PANEL_BOXES[POSITION_INDEX[position] ?? 0]];
        if (!target)
            return;

        const siblings = target.get_children().filter(child => child !== container);
        let index = Math.min(offset, siblings.length);
        if (this._macosActive && position === 'right' && offset === 0)
            index = siblings.length;

        const currentIndex = parent.get_children().indexOf(container);
        if (parent === target && currentIndex === index)
            return;

        parent.remove_child(container);
        target.insert_child_at_index(container, index);
    }

    _restoreClock() {
        const origin = this._clockOrigin;
        this._clockOrigin = null;
        if (!origin?.container)
            return;
        try {
            const container = origin.container;
            const parent = container.get_parent();
            if (parent)
                parent.remove_child(container);
            if (origin.parent)
                origin.parent.insert_child_at_index(container,
                    Math.min(origin.index, origin.parent.get_children().length));
        } catch (e) { /* panel structure changed */ }
    }
}
