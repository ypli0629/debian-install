let gettext = str => str;

try {
    const mod = await import('resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js');
    if (typeof mod.gettext === 'function')
        gettext = mod.gettext;
} catch (e) {
    /* Not running inside the preferences process: fall back to identity. */
}

export function _(str) {
    try {
        return gettext(str);
    } catch (e) {
        return str;
    }
}
