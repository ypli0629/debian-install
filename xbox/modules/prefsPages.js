import Adw from 'gi://Adw';
import Gio from 'gi://Gio';
import Gtk from 'gi://Gtk';

import { _ } from './i18nPrefs.js';

function switchRow(settings, key, title, subtitle = '') {
    const row = new Adw.SwitchRow({ title, subtitle });
    settings.bind(key, row, 'active', Gio.SettingsBindFlags.DEFAULT);
    return row;
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

function spinRow(settings, key, title, min, max, step, subtitle = '') {
    const row = new Adw.SpinRow({
        title,
        subtitle,
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

export function stringComboRow(settings, key, title, subtitle, labels, values) {
    const row = stringCombo(settings, key, title, subtitle, labels, values);
    row._xboxKey = key;
    return row;
}

export function spinRowFor(settings, key, title, min, max, step, subtitle = '') {
    const row = spinRow(settings, key, title, min, max, step, subtitle);
    row._xboxKey = key;
    return row;
}

export function switchRowFor(settings, key, title, subtitle = '') {
    const row = switchRow(settings, key, title, subtitle);
    row._xboxKey = key;
    return row;
}

export function addMainPages(window, settings) {
    const generalPage = new Adw.PreferencesPage({
        title: _('General'),
        icon_name: 'preferences-system-symbolic',
    });
    window.add(generalPage);

    const panelGroup = new Adw.PreferencesGroup({
        title: _('Top Panel'),
        description: _('Entry point for Xbox in the top panel.'),
    });
    generalPage.add(panelGroup);

    panelGroup.add(switchRowFor(settings, 'show-panel-indicator', _('Show Top Bar Icon')));
    panelGroup.add(stringComboRow(settings, 'panel-position', _('Panel Position'), '',
        [_('Left'), _('Center'), _('Right')], ['left', 'center', 'right']));
    panelGroup.add(spinRowFor(settings, 'panel-offset', _('Panel Position Offset'), 0, 20, 1));

    const moduleGroup = new Adw.PreferencesGroup({
        title: _('Feature Modules'),
        description: _('Enable features as needed; re-enable the extension after changes.'),
    });
    generalPage.add(moduleGroup);

    moduleGroup.add(switchRowFor(settings, 'tabbed-windows-enabled', _('Tabbed Windows'),
        _('macOS-style tabbed window management; disable the standalone Tabbed Windows extension')));
    moduleGroup.add(switchRowFor(settings, 'status-bar-enabled', _('Status Bar'),
        _('macOS style top bar height/icon size/spacing and clock position')));
    moduleGroup.add(switchRowFor(settings, 'no-overview-enabled', _('Don\'t Show Overview on Startup'),
        _('Automatically hide the overview after login')));
    moduleGroup.add(switchRowFor(settings, 'proxy-switcher-enabled', _('Proxy Switcher'),
        _('Add proxy mode switching to quick settings; disable the standalone Proxy Switcher extension')));
    moduleGroup.add(switchRowFor(settings, 'hide-top-bar-enabled', _('Hide Top Bar'),
        _('Automatically hide the top bar, show when the pointer approaches the top edge; disable the standalone Hide Top Bar extension')));

    const statusPage = new Adw.PreferencesPage({
        title: _('Status Bar'),
        icon_name: 'preferences-desktop-display-symbolic',
    });
    window.add(statusPage);

    const macosGroup = new Adw.PreferencesGroup({
        title: _('macOS Tahoe Style'),
        description: _('Liquid Glass inspired top bar: taller, translucent background, rounded bottom corners, roomier spacing and the clock on the right.'),
    });
    statusPage.add(macosGroup);
    macosGroup.add(switchRowFor(settings, 'macos-style', _('Enable macOS Tahoe Style'),
        _('When enabled, the options below control the preset and the manual tuning is locked')));

    const macosRows = [
        spinRowFor(settings, 'macos-panel-size', _('Top Bar Height'), 20, 64, 1,
            _('Tahoe menu bar is taller than the 24px default; 30px recommended')),
        spinRowFor(settings, 'macos-icon-size', _('Icon Size'), 12, 48, 1,
            _('Status icon size in pixels')),
        spinRowFor(settings, 'macos-button-padding-size', _('Button Padding'), 0, 30, 1,
            _('Horizontal padding of panel buttons')),
        spinRowFor(settings, 'macos-icon-spacing', _('Icon Spacing'), 0, 30, 1,
            _('Spacing between status icons')),
        stringComboRow(settings, 'macos-clock-position', _('Clock Position'), '',
            [_('Left'), _('Center'), _('Right')], ['left', 'center', 'right']),
        spinRowFor(settings, 'macos-clock-offset', _('Clock Offset'), 0, 20, 1,
            _('Position offset of the clock within its area')),
        spinRowFor(settings, 'macos-panel-opacity', _('Background Opacity'), 0, 100, 1,
            _('100 is solid; lower values add the Liquid Glass translucency')),
        spinRowFor(settings, 'macos-panel-radius', _('Corner Radius'), 0, 24, 1,
            _('Bottom corner radius of the top bar; 0 disables it')),
        spinRowFor(settings, 'macos-panel-margin', _('Side Margin'), 0, 24, 1,
            _('Horizontal margin; greater than 0 makes the bar float')),
    ];
    for (const row of macosRows)
        macosGroup.add(row);

    const tuningGroup = new Adw.PreferencesGroup({
        title: _('Manual Tuning'),
        description: _('Used when the macOS Tahoe style is off; the status bar module is controlled by the General → Feature Modules → Status Bar switch.'),
    });
    statusPage.add(tuningGroup);

    const tuningRows = [
        spinRowFor(settings, 'panel-size', _('Top Bar Height'), 0, 48, 1, _('Pixels; 0 uses the system default')),
        spinRowFor(settings, 'panel-icon-size', _('Icon Size'), 0, 48, 1, _('Pixels; 0 uses the system default')),
        spinRowFor(settings, 'panel-button-padding-size', _('Button Padding'), 0, 30, 1,
            _('Pixels; 0 uses the system default. Smaller is more compact and can fix overly wide icons')),
        spinRowFor(settings, 'panel-icon-spacing', _('Icon Spacing'), 0, 30, 1,
            _('Spacing between status icons; 0 uses the system default')),
        stringComboRow(settings, 'clock-position', _('Clock Position'), '',
            [_('Left'), _('Center'), _('Right')], ['left', 'center', 'right']),
        spinRowFor(settings, 'clock-position-offset', _('Clock Offset'), 0, 20, 1,
            _('Position offset of the clock within its area')),
    ];
    for (const row of tuningRows)
        tuningGroup.add(row);

    const syncSensitivity = () => {
        const macos = settings.get_boolean('macos-style');
        for (const row of macosRows)
            row.sensitive = macos;
        for (const row of tuningRows)
            row.sensitive = !macos;
    };
    syncSensitivity();
    const macosId = settings.connect('changed::macos-style', syncSensitivity);
    statusPage.connect('destroy', () => settings.disconnect(macosId));
}
