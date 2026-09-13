import Adw from 'gi://Adw';
import Gdk from 'gi://Gdk';
import Gio from 'gi://Gio';
import Gtk from 'gi://Gtk';

import { _ } from './i18nPrefs.js';

function switchRow(settings, key, title, subtitle = '') {
    const row = new Adw.SwitchRow({ title, subtitle });
    settings.bind(key, row, 'active', Gio.SettingsBindFlags.DEFAULT);
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

function doubleSpinRow(settings, key, title, min, max, step, subtitle = '') {
    const row = new Adw.SpinRow({
        title,
        subtitle,
        digits: 2,
        adjustment: new Gtk.Adjustment({
            lower: min,
            upper: max,
            step_increment: step,
            page_increment: step * 10,
            value: settings.get_double(key),
        }),
    });
    row.connect('notify::value', () => {
        settings.set_double(key, Math.round(row.value * 100) / 100);
    });
    const id = settings.connect(`changed::${key}`, () => {
        const value = settings.get_double(key);
        if (Math.abs(row.value - value) > 0.001)
            row.value = value;
    });
    row.connect('destroy', () => settings.disconnect(id));
    return row;
}

function accelLabel(accel) {
    const [ok, keyval, mods] = Gtk.accelerator_parse(accel);
    return ok ? Gtk.accelerator_get_label(keyval, mods) : accel;
}

function shortcutSubtitle(settings) {
    const accels = settings.get_strv('shortcut-keybind');
    if (accels.length === 0)
        return _('Not set (click \'Set\' to record)');
    return accels.map(accelLabel).join('，');
}

function openShortcutEditor(parent, settings) {
    const dialog = new Gtk.Window({
        modal: true,
        transient_for: parent,
        title: _('Set Shortcut'),
        default_width: 360,
    });

    const box = new Gtk.Box({
        orientation: Gtk.Orientation.VERTICAL,
        spacing: 12,
        margin_top: 18,
        margin_bottom: 18,
        margin_start: 18,
        margin_end: 18,
    });
    box.append(new Gtk.Label({
        label: _('Press the key combination to use\nEsc to cancel · Backspace to clear'),
        justify: Gtk.Justification.CENTER,
    }));
    dialog.set_child(box);

    const isModifier = keyval => [
        Gdk.KEY_Shift_L, Gdk.KEY_Shift_R,
        Gdk.KEY_Control_L, Gdk.KEY_Control_R,
        Gdk.KEY_Alt_L, Gdk.KEY_Alt_R,
        Gdk.KEY_Super_L, Gdk.KEY_Super_R,
        Gdk.KEY_Meta_L, Gdk.KEY_Meta_R,
        Gdk.KEY_Hyper_L, Gdk.KEY_Hyper_R,
        Gdk.KEY_Caps_Lock,
    ].includes(keyval);

    const controller = new Gtk.EventControllerKey();
    controller.connect('key-pressed', (_c, keyval, _keycode, state) => {
        const mods = state & Gtk.accelerator_get_default_mod_mask();
        if (keyval === Gdk.KEY_Escape) {
            dialog.close();
            return Gdk.EVENT_STOP;
        }
        if (keyval === Gdk.KEY_BackSpace || keyval === Gdk.KEY_Delete) {
            settings.set_strv('shortcut-keybind', []);
            dialog.close();
            return Gdk.EVENT_STOP;
        }
        if (isModifier(keyval))
            return Gdk.EVENT_STOP;
        if (Gtk.accelerator_valid(keyval, mods)) {
            settings.set_strv('shortcut-keybind', [Gtk.accelerator_name(keyval, mods)]);
            dialog.close();
            return Gdk.EVENT_STOP;
        }
        return Gdk.EVENT_PROPAGATE;
    });
    dialog.add_controller(controller);
    dialog.present();
}

function shortcutRow(settings) {
    const row = new Adw.ActionRow({
        title: _('Show Top Bar Shortcut'),
        subtitle: shortcutSubtitle(settings),
    });

    const setButton = new Gtk.Button({ label: _('Set'), valign: Gtk.Align.CENTER });
    setButton.connect('clicked', () => openShortcutEditor(row.get_root(), settings));

    const clearButton = new Gtk.Button({
        icon_name: 'edit-clear-symbolic',
        valign: Gtk.Align.CENTER,
        tooltip_text: _('Clear'),
    });
    clearButton.add_css_class('flat');
    clearButton.connect('clicked', () => settings.set_strv('shortcut-keybind', []));

    row.add_suffix(setButton);
    row.add_suffix(clearButton);
    row.activatable_widget = setButton;

    const id = settings.connect('changed::shortcut-keybind', () => {
        row.subtitle = shortcutSubtitle(settings);
    });
    row.connect('destroy', () => settings.disconnect(id));
    return row;
}

export function addHideTopBarPages(window, settings) {
    const page = new Adw.PreferencesPage({
        title: _('Hide Top Bar'),
        icon_name: 'view-fullscreen-symbolic',
    });
    window.add(page);

    const triggerGroup = new Adw.PreferencesGroup({
        title: _('Trigger'),
        description: _('The Hide Top Bar module is controlled by the \'General → Features → Hide Top Bar\' toggle.'),
    });
    page.add(triggerGroup);

    triggerGroup.add(switchRow(settings, 'mouse-sensitive', _('Show when the mouse approaches the screen edge'),
        _('The top bar appears when the pointer reaches the top edge of the screen')));
    triggerGroup.add(spinRow(settings, 'edge-trigger-size', _('Edge trigger area'), 0, 50, 1,
        _('Trigger within this many pixels of the top edge; larger is more sensitive')));
    triggerGroup.add(switchRow(settings, 'mouse-sensitive-fullscreen-window', _('Also allow triggering in fullscreen')));
    triggerGroup.add(switchRow(settings, 'mouse-triggers-overview', _('Also show the overview when triggered')));
    triggerGroup.add(switchRow(settings, 'hot-corner', _('Keep hot corner when hidden')));
    triggerGroup.add(switchRow(settings, 'keep-round-corners', _('Keep top rounded corners when hidden')));
    triggerGroup.add(switchRow(settings, 'show-in-overview', _('Show top bar in overview')));

    const intellihideGroup = new Adw.PreferencesGroup({ title: _('Intellihide') });
    page.add(intellihideGroup);
    intellihideGroup.add(switchRow(settings, 'enable-intellihide', _('Enable intellihide'),
        _('Only hide when a window occupies the top bar area')));
    intellihideGroup.add(switchRow(settings, 'enable-active-window', _('Only for the active window')));

    const animationGroup = new Adw.PreferencesGroup({ title: _('Animation') });
    page.add(animationGroup);
    animationGroup.add(doubleSpinRow(settings, 'animation-time-overview', _('Overview animation duration (seconds)'), 0, 2, 0.05));
    animationGroup.add(doubleSpinRow(settings, 'animation-time-autohide', _('Autohide animation duration (seconds)'), 0, 2, 0.05));

    const pressureGroup = new Adw.PreferencesGroup({
        title: _('Pressure barrier (fallback trigger)'),
        description: _('The top bar appears when the pointer pushes against the screen edge and accumulates to the threshold.'),
    });
    page.add(pressureGroup);
    pressureGroup.add(spinRow(settings, 'pressure-threshold', _('Pressure threshold (pixels)'), 1, 1000, 10,
        _('How deep the pointer must push into the screen edge')));
    pressureGroup.add(spinRow(settings, 'pressure-timeout', _('Pressure timeout (ms)'), 100, 5000, 100,
        _('How long to hold against the edge before it counts as a trigger')));

    const shortcutGroup = new Adw.PreferencesGroup({ title: _('Shortcut') });
    page.add(shortcutGroup);
    shortcutGroup.add(shortcutRow(settings));
    shortcutGroup.add(switchRow(settings, 'shortcut-toggles', _('Press again to toggle show/hide')));
    shortcutGroup.add(doubleSpinRow(settings, 'shortcut-delay', _('Autohide delay after shortcut (seconds)'), 0, 10, 0.5));
}
