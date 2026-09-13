import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import Shell from 'gi://Shell';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

import { _ } from '../i18n.js';

const MAX_TITLE = 42;
const BAR_GAP = 4;
const DRAG_THRESHOLD = 6;
const TEAR_OFF_MARGIN = 24;

const ACCENT_COLORS = {
    red: ['#e62d42', '#f66151'],
    orange: ['#ed5b00', '#ff7800'],
    yellow: ['#c88800', '#f5c211'],
    green: ['#3a944a', '#33d17a'],
    blue: ['#3584e4', '#62a0ea'],
    purple: ['#9141ac', '#c061cb'],
    pink: ['#d56199', '#f17db9'],
    slate: ['#6f8396', '#a0aab5'],
};

function hexToRgba(hex, alpha) {
    const v = parseInt(hex.slice(1), 16);
    return `rgba(${(v >> 16) & 255}, ${(v >> 8) & 255}, ${v & 255}, ${alpha})`;
}

export const TabBar = GObject.registerClass(
    { GTypeName: 'TabbedWindowsTabBar' },
    class TabBar extends St.BoxLayout {
        constructor(params) {
            super({
                style_class: 'tabby-bar',
                reactive: true,
                visible: false,
                vertical: false,
            });

            const p = params ?? {};
            this._callbacks = {
                onActivate: typeof p.onActivate === 'function' ? p.onActivate : null,
                onClose: typeof p.onClose === 'function' ? p.onClose : null,
                onReorder: typeof p.onReorder === 'function' ? p.onReorder : null,
                onTearOff: typeof p.onTearOff === 'function' ? p.onTearOff : null,
                onNewWindow: typeof p.onNewWindow === 'function' ? p.onNewWindow : null,
                onWheel: typeof p.onWheel === 'function' ? p.onWheel : null,
            };

            this._getTearOff = typeof p.tearOffThreshold === 'function' ? p.tearOffThreshold : () => TEAR_OFF_MARGIN;

            this._tabData = [];
            this._tabActors = [];
            this._labels = new Map();
            this._drag = null;
            this._dragHandler = 0;
            this._dragMoved = false;
            this._smoothDelta = 0;
            this._menu = null;
            this._menuManager = null;
            this._menuSource = null;
            this._settings = null;
            this._settingsIds = [];
            this._accent = null;
            this._dark = true;

            this._tabsBox = new St.BoxLayout({ vertical: false, x_expand: true });
            this.add_child(this._tabsBox);

            try {
                this._settings = Gio.Settings.new('org.gnome.desktop.interface');
            } catch (e) {
                this._settings = null;
            }
            if (this._settings) {
                for (const key of ['accent-color', 'color-scheme']) {
                    try {
                        this._settingsIds.push(
                            this._settings.connect(`changed::${key}`, () => this._readScheme())
                        );
                    } catch (e) {
                        this._settingsIds.push(0);
                    }
                }
            }
            this._readScheme();

            this.connect('scroll-event', (a, ev) => this._onScroll(ev));
            this.connect('button-press-event', (a, ev) => this._onBarPress(ev));
        }

        // ---- public API ---------------------------------------------------

        setTabs(tabs) {
            this._tabData = (tabs ?? []).map(t => ({
                win: t.win,
                title: t.title,
                active: !!t.active,
            }));
            this._rebuild();
        }

        updateTitle(win, title) {
            const d = this._tabData.find(t => t.win === win);
            if (!d)
                return;
            d.title = title;
            const label = this._labels.get(win);
            if (label)
                label.text = (title || 'Window').slice(0, MAX_TITLE);
        }

        positionAbove(frame, monitor, position = 'top') {
            if (position === 'panel')
                return;
            const [, natW] = this.get_preferred_width(-1);
            const [, natH] = this.get_preferred_height(-1);
            const width = Math.max(frame.width, natW);
            const x = Math.min(Math.max(frame.x, monitor.x), monitor.x + monitor.width - width);
            let y = Math.max(frame.y - natH - BAR_GAP, monitor.y);
            if (position === 'bottom')
                y = Math.min(frame.y + frame.height + BAR_GAP, monitor.y + monitor.height - natH);
            this.set_size(width, natH);
            this.set_position(x, y);
        }

        destroy() {
            this._endDrag();
            this._closeMenu();
            for (const id of this._settingsIds) {
                try {
                    if (id)
                        this._settings?.disconnect(id);
                } catch (e) {
                    /* settings already gone */
                }
            }
            this._settingsIds = [];
            this._settings = null;
            super.destroy();
        }

        // ---- internal: theming ---------------------------------------------

        _readScheme() {
            this._accent = null;
            this._dark = true;
            if (this._settings) {
                try {
                    const c = this._settings.get_string('accent-color');
                    if (Object.prototype.hasOwnProperty.call(ACCENT_COLORS, c))
                        this._accent = ACCENT_COLORS[c];
                } catch (e) {
                    this._accent = null;
                }
                try {
                    this._dark = this._settings.get_string('color-scheme') === 'prefer-dark';
                } catch (e) {
                    this._dark = true;
                }
            }
            this._applyBarStyle();
        }

        _applyBarStyle() {
            if (this._dark) {
                this.set_style('');
                this.remove_style_class_name('tabby-bar-light');
            } else {
                this.set_style('background-color: rgba(246, 246, 249, 0.95);');
                this.add_style_class_name('tabby-bar-light');
            }
            if (this._tabData.length > 0)
                this._rebuild();
        }

        _activeBackground() {
            if (!this._accent)
                return null;
            return hexToRgba(this._dark ? this._accent[1] : this._accent[0], 0.55);
        }

        // ---- internal: tabs -------------------------------------------------

        _rebuild() {
            this._tabsBox.destroy_all_children();
            this._tabActors = [];
            this._labels.clear();
            const tracker = Shell.WindowTracker.get_default();
            const bg = this._activeBackground();

            this._tabData.forEach((d, index) => {
                const isActive = d.active;
                const tab = new St.BoxLayout({
                    style_class: `tabby-tab ${isActive ? 'tabby-tab-active' : ''}`,
                    reactive: true,
                    x_expand: true,
                });
                if (bg && isActive)
                    tab.set_style(`background-color: ${bg};`);

                const inner = new St.BoxLayout({ style: 'spacing: 6px;' });
                try {
                    const app = tracker.get_window_app(d.win);
                    if (app)
                        inner.add_child(app.create_icon_texture(14));
                } catch (e) {
                    /* icon unavailable */
                }
                const label = new St.Label({
                    text: (d.title || 'Window').slice(0, MAX_TITLE),
                    y_align: Clutter.ActorAlign.CENTER,
                });
                inner.add_child(label);
                this._labels.set(d.win, label);

                const btn = new St.Button({
                    style_class: `tabby-btn ${isActive ? 'tabby-btn-active' : ''}`,
                    x_expand: true,
                    child: inner,
                });
                if (!this._dark && !isActive)
                    btn.set_style('color: rgba(48, 51, 53, 0.92);');
                btn.connect('clicked', () => {
                    if (this._dragMoved) {
                        this._dragMoved = false;
                        return;
                    }
                    this._emit('onActivate', d.win);
                });
                btn.connect('button-press-event', (a, ev) => this._onTabPress(d, index, ev));

                const close = new St.Button({
                    style_class: 'tabby-close',
                    child: new St.Icon({ icon_name: 'window-close-symbolic', icon_size: 10 }),
                });
                if (!this._dark)
                    close.set_style('color: rgba(48, 51, 53, 0.6);');
                close.connect('clicked', () => this._emit('onClose', d.win));

                tab.add_child(btn);
                tab.add_child(close);
                this._tabsBox.add_child(tab);
                this._tabActors.push(tab);
            });
        }

        _emit(name, ...args) {
            const fn = this._callbacks[name];
            if (typeof fn !== 'function')
                return;
            try {
                fn(...args);
            } catch (e) {
                logError(e, 'TabBar callback');
            }
        }

        // ---- internal: per-tab buttons ---------------------------------------

        _onTabPress(d, index, ev) {
            let button = 0;
            try {
                button = ev.get_button();
            } catch (e) {
                return Clutter.EVENT_PROPAGATE;
            }
            if (button === Clutter.BUTTON_MIDDLE) {
                this._emit('onClose', d.win);
                return Clutter.EVENT_STOP;
            }
            if (button === Clutter.BUTTON_SECONDARY) {
                const [x, y] = ev.get_coords();
                this._openMenu(d.win, x, y);
                return Clutter.EVENT_STOP;
            }
            if (button === Clutter.BUTTON_PRIMARY)
                return this._beginDrag(d, index, ev);
            return Clutter.EVENT_PROPAGATE;
        }

        // ---- internal: bar-level events ---------------------------------------

        _onBarPress(a, ev) {
            let button = 0;
            let clicks = 0;
            try {
                button = ev.get_button();
                clicks = ev.get_click_count();
            } catch (e) {
                return Clutter.EVENT_PROPAGATE;
            }
            if (button !== Clutter.BUTTON_PRIMARY || clicks !== 2)
                return Clutter.EVENT_PROPAGATE;
            if (!this._isBlankPress(ev))
                return Clutter.EVENT_PROPAGATE;
            this._emit('onNewWindow');
            return Clutter.EVENT_STOP;
        }

        _isBlankPress(ev) {
            let actor = ev.get_source();
            while (actor) {
                if (this._tabActors.includes(actor))
                    return false;
                if (actor === this)
                    return true;
                actor = actor.get_parent();
            }
            return true;
        }

        _onScroll(a, ev) {
            try {
                const dir = ev.get_scroll_direction();
                if (dir === Clutter.ScrollDirection.UP) {
                    this._emit('onWheel', -1);
                    return Clutter.EVENT_STOP;
                }
                if (dir === Clutter.ScrollDirection.DOWN) {
                    this._emit('onWheel', 1);
                    return Clutter.EVENT_STOP;
                }
                if (dir === Clutter.ScrollDirection.SMOOTH) {
                    const [, dy] = ev.get_scroll_delta();
                    this._smoothDelta += dy;
                    if (Math.abs(this._smoothDelta) >= 0.5) {
                        const d = this._smoothDelta > 0 ? 1 : -1;
                        this._smoothDelta = 0;
                        this._emit('onWheel', d);
                    }
                    return Clutter.EVENT_STOP;
                }
            } catch (e) {
                /* scroll event unreadable */
            }
            return Clutter.EVENT_PROPAGATE;
        }

        // ---- internal: drag to reorder / tear off ------------------------------

        _beginDrag(d, index, ev) {
            if (this._drag)
                return Clutter.EVENT_PROPAGATE;
            const [x, y] = ev.get_coords();
            this._drag = { win: d.win, actor: this._tabActors[index] ?? null, index, startX: x, startY: y, moved: false, target: index };
            this._dragHandler = global.stage.connect('captured-event', (a, e) => this._onDragEvent(e));
            return Clutter.EVENT_PROPAGATE;
        }

        _onDragEvent(ev) {
            const drag = this._drag;
            if (!drag)
                return Clutter.EVENT_PROPAGATE;
            if (drag.actor && !this._tabsBox.get_children().includes(drag.actor)) {
                this._endDrag();
                return Clutter.EVENT_PROPAGATE;
            }
            const type = ev.type();
            if (type === Clutter.EventType.MOTION) {
                const [x, y] = ev.get_coords();
                if (this._outsideBar(x, y, this._getTearOff())) {
                    const win = drag.win;
                    this._endDrag();
                    this._dragMoved = true;
                    this._emit('onTearOff', win);
                    return Clutter.EVENT_STOP;
                }
                if (Math.abs(x - drag.startX) > DRAG_THRESHOLD || Math.abs(y - drag.startY) > DRAG_THRESHOLD)
                    drag.moved = true;
                if (drag.moved) {
                    const target = this._targetIndex(x, drag.actor);
                    if (target !== drag.target && drag.actor) {
                        drag.target = target;
                        this._tabsBox.insert_child_at_index(drag.actor, target);
                    }
                    return Clutter.EVENT_STOP;
                }
                return Clutter.EVENT_PROPAGATE;
            }
            if (type === Clutter.EventType.BUTTON_RELEASE) {
                const moved = drag.moved;
                const win = drag.win;
                const index = drag.index;
                const target = drag.target;
                this._endDrag();
                if (moved) {
                    this._dragMoved = true;
                    if (target !== index)
                        this._emit('onReorder', win, target);
                }
                return Clutter.EVENT_PROPAGATE;
            }
            return Clutter.EVENT_PROPAGATE;
        }

        _outsideBar(x, y, margin) {
            const [bx, by] = this.get_transformed_position();
            const [bw, bh] = this.get_transformed_size();
            return x < bx - margin || x > bx + bw + margin || y < by - margin || y > by + bh + margin;
        }

        _targetIndex(x, actor) {
            const children = this._tabsBox.get_children();
            const current = children.indexOf(actor);
            if (current < 0)
                return children.length - 1;
            let target = current;
            for (let i = 0; i < children.length; i++) {
                if (children[i] === actor)
                    continue;
                const [tx] = children[i].get_transformed_position();
                const [tw] = children[i].get_transformed_size();
                const mid = tx + tw / 2;
                if (i < current && x < mid) {
                    target = i;
                    break;
                }
                if (i > current && x > mid)
                    target = i;
            }
            return target;
        }

        _endDrag() {
            if (this._dragHandler) {
                try {
                    global.stage.disconnect(this._dragHandler);
                } catch (e) {
                    /* handler already gone */
                }
                this._dragHandler = 0;
            }
            this._drag = null;
        }

        // ---- internal: context menu -------------------------------------------

        _openMenu(win, x, y) {
            this._closeMenu();
            try {
                const source = new St.Widget({
                    x,
                    y,
                    width: 1,
                    height: 1,
                    opacity: 0,
                    reactive: false,
                });
                Main.uiGroup.add_child(source);
                const menu = new PopupMenu.PopupMenu(source, 0.0, St.Side.TOP);
                menu.actor.add_style_class_name('tabby-menu');
                menu.addAction(_('Close Tab'), () => {
                    this._closeMenu();
                    this._emit('onClose', win);
                });
                menu.addAction(_('Move to New Window'), () => {
                    this._closeMenu();
                    this._emit('onTearOff', win);
                });
                Main.uiGroup.add_child(menu.actor);
                menu.actor.hide();
                this._menuManager = new PopupMenu.PopupMenuManager(this);
                this._menuManager.addMenu(menu);
                this._menu = menu;
                this._menuSource = source;
                menu.open();
            } catch (e) {
                this._closeMenu();
            }
        }

        _closeMenu() {
            if (this._menu) {
                const menu = this._menu;
                this._menu = null;
                try {
                    menu.close();
                } catch (e) {
                    /* menu already closed */
                }
                try {
                    menu.destroy();
                } catch (e) {
                    /* menu already destroyed */
                }
            }
            this._menuManager = null;
            if (this._menuSource) {
                try {
                    this._menuSource.destroy();
                } catch (e) {
                    /* source already destroyed */
                }
                this._menuSource = null;
            }
        }
    }
);
