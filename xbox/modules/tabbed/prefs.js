import Adw from 'gi://Adw';
import Gio from 'gi://Gio';
import Gtk from 'gi://Gtk';

import { _ } from '../i18nPrefs.js';

function switchRow(settings, key, title, subtitle = '') {
    const row = new Adw.SwitchRow({ title, subtitle });
    settings.bind(key, row, 'active', Gio.SettingsBindFlags.DEFAULT);
    return row;
}

export function addTabbedPages(window, settings) {
    const groupPage = new Adw.PreferencesPage({ title: _('Tabbed Windows'), icon_name: 'view-grid-symbolic' });
    window.add(groupPage);

    const mergeGroup = new Adw.PreferencesGroup({ title: _('Auto Grouping') });
    groupPage.add(mergeGroup);

    mergeGroup.add(switchRow(settings, 'auto-merge', _('Auto-merge Windows'), _('Auto-group when a second window of the same app appears, no shortcut needed')));
    mergeGroup.add(stringCombo(settings, 'auto-group-mode', _('Auto-group Policy'), _('When new windows automatically join existing groups'),
        [_('Never'), _('Always'), _('Fullscreen Only')], ['never', 'always', 'fullscreen-only']));
    mergeGroup.add(excludeAppsRow(settings));
    mergeGroup.add(switchRow(settings, 'allow-cross-app', _('Allow Cross-app Merging')));
    mergeGroup.add(switchRow(settings, 'group-per-workspace', _('Group per Workspace'), _('When off, groups can span workspaces')));
    mergeGroup.add(switchRow(settings, 'merge-includes-minimized', _('Merge Includes Minimized Windows'), _('Applies during manual merge')));
    mergeGroup.add(switchRow(settings, 'new-tab-activates', _('New Window Steals Focus on Joining')));
    mergeGroup.add(switchRow(settings, 'restore-groups-on-login', _('Restore Groups on Login')));

    const barGroup = new Adw.PreferencesGroup({ title: _('Tab Bar') });
    groupPage.add(barGroup);

    barGroup.add(switchRow(settings, 'show-tab-bar', _('Show Tab Bar'), _('When off, use shortcuts only')));
    barGroup.add(stringCombo(settings, 'tab-bar-position', _('Tab Bar Position'), _('Falls back to top when panel mode fails'),
        [_('Above Window'), _('Below Window'), _('In Panel')], ['top', 'bottom', 'panel']));
    barGroup.add(switchRow(settings, 'switch-animation', _('Fade Animation on Tab Switch')));
    barGroup.add(switchRow(settings, 'panel-indicator', _('Show Tab Count in Panel')));
    barGroup.add(stringCombo(settings, 'close-activates-direction', _('Activate After Closing Tab'), '',
        [_('Left Tab'), _('Right Tab'), _('Most Recently Active')], ['left', 'right', 'last-active']));
    barGroup.add(switchRow(settings, 'number-keys-switch', _('Ctrl+Number Jumps to Tab'), _('Takes over the app\'s Ctrl+number shortcuts')));
    barGroup.add(spinRow(settings, 'tear-off-threshold', _('Tear-off Threshold (pixels)'), 8, 100, 1));
    barGroup.add(spinRow(settings, 'bar-auto-hide-ms', _('Auto-hide Delay (ms)'), 0, 5000, 100));
}

function stringCombo(settings, key, title, subtitle, labels, values) {
    const row = new Adw.ComboRow({
        title,
        subtitle,
        model: Gtk.StringList.new(labels),
    });
    const current = values.indexOf(settings.get_string(key));
    row.selected = current >= 0 ? current : 0;
    row.connect('notify::selected', () => {
        const idx = row.selected;
        if (idx >= 0 && idx < values.length)
            settings.set_string(key, values[idx]);
    });
    const id = settings.connect(`changed::${key}`, () => {
        const next = values.indexOf(settings.get_string(key));
        if (next >= 0 && next !== row.selected)
            row.selected = next;
    });
    row.connect('destroy', () => settings.disconnect(id));
    return row;
}

function spinRow(settings, key, title, min, max, step) {
    const row = new Adw.SpinRow({
        title,
        adjustment: new Gtk.Adjustment({
            lower: min,
            upper: max,
            step_increment: step,
            page_increment: step * 10,
            value: settings.get_int(key),
        }),
    });
    row.connect('notify::value', () => settings.set_int(key, Math.round(row.value)));
    const id = settings.connect(`changed::${key}`, () => {
        const value = settings.get_int(key);
        if (Math.round(row.value) !== value)
            row.value = value;
    });
    row.connect('destroy', () => settings.disconnect(id));
    return row;
}

function excludeAppsRow(settings) {
    const row = new Adw.EntryRow({
        title: _('Apps Never Auto-grouped'),
        text: (settings.get_strv('group-exclude-apps') ?? []).join(', '),
        show_apply_button: true,
    });
    row.connect('apply', () => {
        const apps = row.text.split(',').map(s => s.trim()).filter(s => s.length > 0);
        settings.set_strv('group-exclude-apps', apps);
    });
    return row;
}
