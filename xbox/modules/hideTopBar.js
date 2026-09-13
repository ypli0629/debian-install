import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import { ExtensionModule, isExtensionActive } from './base.js';
import { PanelVisibilityManager } from './hideTopBar/panelVisibilityManager.js';

export default class HideTopBarModule extends ExtensionModule {
    enable() {
        if (!this.settings.get_boolean('hide-top-bar-enabled'))
            return;

        if (isExtensionActive('hidetopbar@mathieu.bidon.ca')) {
            log('[xbox] 独立扩展 Hide Top Bar 正在运行，已跳过隐藏顶栏模块以避免冲突');
            return;
        }

        this._manager = new PanelVisibilityManager(
            this.settings, Main.layoutManager.primaryIndex);
    }

    disable() {
        this._manager?.destroy();
        this._manager = null;
    }
}
