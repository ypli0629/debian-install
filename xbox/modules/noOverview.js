import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import { ExtensionModule } from './base.js';

export default class NoOverviewModule extends ExtensionModule {
    enable() {
        if (!this.settings.get_boolean('no-overview-enabled'))
            return;

        this._startupId = Main.layoutManager.connect('startup-complete',
            () => Main.overview.hide());
    }

    disable() {
        if (this._startupId) {
            Main.layoutManager.disconnect(this._startupId);
            this._startupId = 0;
        }
    }
}
