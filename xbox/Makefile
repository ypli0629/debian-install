UUID := xbox
EXT_DIR := $(HOME)/.local/share/gnome-shell/extensions/$(UUID)
PACKED := $(UUID).shell-extension.zip

.PHONY: all schemas locales check-i18n check-i18n-runtime verify link unlink install pack clean

all: schemas locales

schemas:
	glib-compile-schemas schemas

locales:
	python3 tools/po2mo.py locale/zh_CN.po locale/zh_CN/LC_MESSAGES/xbox.mo
	mkdir -p locale/zh/LC_MESSAGES
	cp locale/zh_CN/LC_MESSAGES/xbox.mo locale/zh/LC_MESSAGES/xbox.mo

check-i18n:
	python3 tools/extract-i18n.py

check-i18n-runtime: schemas locales
	bash tools/check-i18n.sh --runtime

verify: schemas locales check-i18n
	@fail=0; for f in $$(find . -name '*.js'); do node --check "$$f" || fail=1; done; \
	if [ $$fail -eq 0 ]; then echo "all JS OK"; else echo "JS check failed"; exit 1; fi

link: schemas locales
	mkdir -p $(dir $(EXT_DIR))
	ln -sfn $(CURDIR) $(EXT_DIR)
	@echo "linked $(CURDIR) -> $(EXT_DIR)"

unlink:
	rm -f $(EXT_DIR)

install: schemas locales
	[ -L $(EXT_DIR) ] && rm -f $(EXT_DIR) || true
	mkdir -p $(EXT_DIR)
	cp -r extension.js prefs.js stylesheet.css metadata.json modules schemas locale $(EXT_DIR)
	@echo "installed to $(EXT_DIR)"

pack: schemas locales
	gnome-extensions pack --force --extra-source=modules --extra-source=locale --out-dir=. .

clean:
	rm -f schemas/gschemas.compiled $(PACKED)
	rm -f locale/zh_CN/LC_MESSAGES/xbox.mo locale/zh/LC_MESSAGES/xbox.mo
