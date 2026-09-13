import { ExtensionPreferences } from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

import { addMainPages } from './modules/prefsPages.js';
import { addTabbedPages } from './modules/tabbed/prefs.js';
import { addHideTopBarPages } from './modules/hideTopBarPrefs.js';

export default class XboxPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings();

        addMainPages(window, settings);
        addHideTopBarPages(window, settings);
        addTabbedPages(window, settings);
    }
}
