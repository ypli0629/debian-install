import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import GLib from 'gi://GLib';

import { ModuleManager } from './modules/manager.js';
import { _ } from './modules/i18n.js';
import QuickActionsModule from './modules/quickActions.js';
import TabbedWindowsModule from './modules/tabbedWindows.js';
import StatusBarModule from './modules/statusBar.js';
import NoOverviewModule from './modules/noOverview.js';
import ProxySwitcherModule from './modules/proxySwitcher.js';
import HideTopBarModule from './modules/hideTopBar.js';

export default class XboxExtension extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._modules = new ModuleManager(this);

        this._modules.add(new QuickActionsModule(this));
        this._modules.add(new StatusBarModule(this));
        this._modules.add(new NoOverviewModule(this));
        this._modules.add(new ProxySwitcherModule(this));
        this._modules.add(new HideTopBarModule(this));
        this._modules.add(new TabbedWindowsModule(this));

        this._modules.enableAll();

        if (GLib.getenv('XBOX_I18N_CHECK'))
            this._i18nSelfCheck();
    }

    _i18nSelfCheck() {
        const samples = [
            'Show Overview',
            'Lock Screen',
            'General',
            'All-in-one toolbox that gathers common system actions and custom utilities into the top panel.',
        ];
        const parts = samples.map(str => `${str} => ${_(str)}`);
        log(`xbox:i18n lang=${GLib.get_language_names().join(',')} | ${parts.join(' | ')}`);
    }

    disable() {
        this._modules?.disableAll();
        this._modules = null;
        this._settings = null;
    }
}

