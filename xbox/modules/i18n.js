let gettext = str => str;

try {
    const mod = await import('resource:///org/gnome/shell/extensions/extension.js');
    if (typeof mod.gettext === 'function')
        gettext = mod.gettext;
} catch (e) {
    /* Not running inside GNOME Shell (e.g. standalone tests): fall back to identity. */
}

export function _(str) {
    try {
        return gettext(str);
    } catch (e) {
        return str;
    }
}
