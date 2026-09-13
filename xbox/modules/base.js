import { ExtensionState } from 'resource:///org/gnome/shell/misc/extensionUtils.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const ACTIVE_STATES = new Set(
    [ExtensionState.ENABLED, ExtensionState.ACTIVE, ExtensionState.ENABLING]
        .filter(state => state !== undefined));

export function isExtensionActive(uuid) {
    const ext = Main.extensionManager.lookup(uuid);
    return !!ext && ACTIVE_STATES.has(ext.state);
}

export class ExtensionModule {
    constructor(extension) {
        this.extension = extension;
        this.settings = extension.getSettings();
        this._signalIds = [];
    }

    get name() {
        return this.constructor.name;
    }

    enable() {}

    disable() {}

    connectSignal(object, signal, callback) {
        const id = object.connect(signal, callback);
        this._signalIds.push([object, id]);
        return id;
    }

    disconnectSignals() {
        for (const [object, id] of this._signalIds) {
            try {
                object.disconnect(id);
            } catch (e) {
                logError(e, `[xbox] disconnect ${this.name}`);
            }
        }
        this._signalIds = [];
    }
}
