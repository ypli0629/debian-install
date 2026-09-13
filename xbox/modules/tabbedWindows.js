import { ExtensionModule, isExtensionActive } from './base.js';
import { TabbedWindows } from './tabbed/controller.js';

export default class TabbedWindowsModule extends ExtensionModule {
    enable() {
        if (!this.settings.get_boolean('tabbed-windows-enabled'))
            return;

        if (isExtensionActive('tabbed-windows')) {
            log('[xbox] 独立扩展 tabbed-windows 正在运行，已跳过标签窗口模块以避免冲突');
            return;
        }

        this._controller = new TabbedWindows(this.extension);
        this._controller.enable();
    }

    disable() {
        this._controller?.disable();
        this._controller = null;
    }
}
