import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import { trySpawnCommandLine } from 'resource:///org/gnome/shell/misc/util.js';

import { ExtensionModule } from './base.js';
import { _ } from './i18n.js';

const XboxIndicator = GObject.registerClass(
class XboxIndicator extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'Xbox');
        this.add_child(new St.Icon({
            icon_name: 'emblem-system-symbolic',
            style_class: 'system-status-icon xbox-icon',
        }));
    }
});

function lockScreen() {
    Gio.DBus.session.call(
        'org.gnome.ScreenSaver',
        '/org/gnome/ScreenSaver',
        'org.gnome.ScreenSaver',
        'Lock',
        null,
        null,
        Gio.DBusCallFlags.NONE,
        -1,
        null,
        null);
}

const ACTIONS = [
    { label: _('Show Overview'), run: () => Main.overview.toggle() },
    { label: _('System Settings'), run: () => trySpawnCommandLine('gnome-control-center') },
    { label: _('Lock Screen'), run: () => lockScreen() },
];

export default class QuickActionsModule extends ExtensionModule {
    enable() {
        if (!this.settings.get_boolean('show-panel-indicator'))
            return;

        this._indicator = new XboxIndicator();
        for (const action of ACTIONS)
            this._indicator.menu.addAction(action.label, action.run);

        this._indicator.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._indicator.menu.addAction(_('Extension Settings'), () => this.extension.openPreferences());

        Main.panel.addToStatusArea(
            'xbox',
            this._indicator,
            this.settings.get_int('panel-offset'),
            this.settings.get_string('panel-position'));
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
