import Gio from 'gi://Gio';
import GObject from 'gi://GObject';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';

import { ExtensionModule, isExtensionActive } from './base.js';
import { _ } from './i18n.js';

const PROXY_SCHEMA = 'org.gnome.system.proxy';
const PROXY_MODE_KEY = 'mode';
const ACTIVE_MODE_KEY = 'active-mode';
const MODE_TEXT = { none: _('Off'), manual: _('Manual'), auto: _('Auto') };
const MODE_LIST = ['none', 'manual', 'auto'];

const ProxyMenuToggle = GObject.registerClass(
class ProxyMenuToggle extends QuickSettings.QuickMenuToggle {
    _init(proxySettings, settings) {
        super._init({
            title: _('Proxy'),
            iconName: 'preferences-system-network-proxy-symbolic',
        });

        this._proxySettings = proxySettings;
        this._settings = settings;

        this.menu.setHeader('preferences-system-network-proxy-symbolic', _('Proxy'));

        const itemsSection = new PopupMenu.PopupMenuSection();
        this._modeToItem = {};
        for (const mode of MODE_LIST) {
            this._modeToItem[mode] = itemsSection.addAction(
                MODE_TEXT[mode],
                () => this._proxySettings.set_string(PROXY_MODE_KEY, mode));
        }
        this.menu.addMenuItem(itemsSection);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.menu.addSettingsAction(_('Network Settings'), 'gnome-network-panel.desktop');

        this.connect('clicked', () => this._toggleActive());
        this.connect('destroy', () => (this._modeToItem = null));

        this._reflectSettings();
    }

    _toggleActive() {
        if (this.checked)
            this._proxySettings.set_string(PROXY_MODE_KEY, 'none');
        else
            this._proxySettings.set_string(PROXY_MODE_KEY, this._settings.get_string(ACTIVE_MODE_KEY));
    }

    _reflectSettings() {
        const mode = this._proxySettings.get_string(PROXY_MODE_KEY);
        if (mode === 'none') {
            this.checked = false;
            this.subtitle = null;
        } else {
            this.checked = true;
            this.subtitle = MODE_TEXT[mode] ?? null;
            this._settings.set_string(ACTIVE_MODE_KEY, mode);
        }
        for (const itemMode of MODE_LIST) {
            this._modeToItem[itemMode].setOrnament(
                mode === itemMode ? PopupMenu.Ornament.DOT : PopupMenu.Ornament.NONE);
        }
    }
});

export default class ProxySwitcherModule extends ExtensionModule {
    enable() {
        if (!this.settings.get_boolean('proxy-switcher-enabled'))
            return;

        if (isExtensionActive('ProxySwitcher@flannaghan.com')) {
            log('[xbox] 独立扩展 ProxySwitcher 正在运行，已跳过代理切换模块以避免重复');
            return;
        }

        if (Gio.Settings.list_schemas().indexOf(PROXY_SCHEMA) === -1) {
            log(`[xbox] 缺少 schema ${PROXY_SCHEMA}，已跳过代理切换模块`);
            return;
        }

        this._proxySettings = Gio.Settings.new(PROXY_SCHEMA);
        this._toggle = new ProxyMenuToggle(this._proxySettings, this.settings);

        this._indicator = new QuickSettings.SystemIndicator(this.extension);
        this._indicator.quickSettingsItems.push(this._toggle);
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);

        this._modeChangedId = this._proxySettings.connect(`changed::${PROXY_MODE_KEY}`,
            () => this._toggle?._reflectSettings());
    }

    disable() {
        if (this._modeChangedId) {
            this._proxySettings.disconnect(this._modeChangedId);
            this._modeChangedId = 0;
        }
        this._proxySettings = null;

        if (this._indicator) {
            this._indicator.quickSettingsItems.forEach(item => item.destroy());
            this._indicator.destroy();
            this._indicator = null;
        }
        this._toggle = null;
    }
}
