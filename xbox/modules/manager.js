export class ModuleManager {
    constructor(extension) {
        this.extension = extension;
        this._modules = [];
    }

    add(module) {
        this._modules.push(module);
    }

    enableAll() {
        for (const module of this._modules) {
            try {
                module.enable();
            } catch (e) {
                logError(e, `[xbox] enable ${module.name}`);
            }
        }
    }

    disableAll() {
        for (const module of [...this._modules].reverse()) {
            try {
                module.disable();
            } catch (e) {
                logError(e, `[xbox] disable ${module.name}`);
            }
        }
        this._modules = [];
    }
}
