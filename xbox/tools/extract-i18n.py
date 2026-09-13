#!/usr/bin/env python3
"""Check gettext coverage for the Xbox extension.

Collects every _('...') message id from the JS sources plus the metadata
description, then verifies that locale/zh_CN.po provides a non-empty
translation that differs from the source string.

Exit code is non-zero when any problem is found.
"""

import ast
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATTERN = re.compile(r"_\(\s*'((?:[^'\\]|\\.)*)'\s*\)")
PO = os.path.join(ROOT, 'locale', 'zh_CN.po')
METADATA = os.path.join(ROOT, 'metadata.json')


def js_files():
    for base, _dirs, files in os.walk(ROOT):
        if '/.git' in base or '/locale' in base or '/tools' in base:
            continue
        for name in files:
            if name.endswith('.js'):
                yield os.path.join(base, name)


def collect_msgids():
    found = {}
    for path in js_files():
        with open(path, encoding='utf-8') as handle:
            text = handle.read()
        for match in PATTERN.finditer(text):
            msgid = ast.literal_eval("'" + match.group(1) + "'")
            found.setdefault(msgid, []).append(os.path.relpath(path, ROOT))

    if os.path.exists(METADATA):
        with open(METADATA, encoding='utf-8') as handle:
            description = json.load(handle).get('description')
        if description:
            found.setdefault(description, []).append('metadata.json')

    return found


def parse_po(path):
    entries = {}
    msgid = None
    msgstr = None
    mode = None

    def flush():
        nonlocal msgid, msgstr, mode
        if msgid is not None and msgid != '' and msgstr is not None:
            entries[msgid] = msgstr
        msgid = msgstr = None
        mode = None

    with open(path, encoding='utf-8') as handle:
        for raw in handle:
            line = raw.rstrip('\n')
            if line.startswith('#'):
                continue
            if line.startswith('msgid '):
                flush()
                msgid = ast.literal_eval(line[6:].strip())
                mode = 'id'
            elif line.startswith('msgstr '):
                msgstr = ast.literal_eval(line[7:].strip())
                mode = 'str'
            elif line.startswith('"') and mode is not None:
                part = ast.literal_eval(line.strip())
                if mode == 'id':
                    msgid += part
                else:
                    msgstr += part
            elif line == '':
                flush()
    flush()
    return entries


def main():
    found = collect_msgids()
    entries = parse_po(PO) if os.path.exists(PO) else {}

    missing = sorted(set(found) - set(entries))
    empty = sorted(k for k in found if k in entries and not entries[k].strip())
    untranslated = sorted(k for k in found
                          if k in entries and entries[k].strip() and entries[k] == k)
    unused = sorted(set(entries) - set(found))

    print(f'msgids in code : {len(found)}')
    print(f'in {os.path.relpath(PO, ROOT)} : {len(entries)}')
    print(f'missing        : {len(missing)}')
    for msgid in missing:
        print(f'  MISSING       {msgid!r}  <- {", ".join(found[msgid])}')
    for msgid in empty:
        print(f'  EMPTY         {msgid!r}')
    for msgid in untranslated:
        print(f'  UNTRANSLATED  {msgid!r}  <- {", ".join(found[msgid])}')
    if unused:
        print(f'unused         : {len(unused)}')
        for msgid in unused:
            print(f'  UNUSED        {msgid!r}')

    problems = len(missing) + len(empty) + len(untranslated)
    print('OK' if problems == 0 else f'FAILED ({problems} problems)')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
