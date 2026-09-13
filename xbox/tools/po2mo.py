#!/usr/bin/env python3
"""Compile a gettext .po file into a binary .mo file (no gettext tools needed)."""

import ast
import struct
import sys


def parse_po(path):
    entries = {}
    msgid = None
    msgstr = None
    mode = None

    def flush():
        nonlocal msgid, msgstr, mode
        if msgid is not None and msgstr is not None:
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
            else:
                raise SystemExit(f'{path}: unexpected line: {line!r}')

    flush()
    return entries


def write_mo(entries, out_path):
    if '' not in entries:
        entries[''] = 'Content-Type: text/plain; charset=UTF-8\n'

    items = sorted(entries.items(), key=lambda kv: kv[0].encode('utf-8'))
    keys = [k.encode('utf-8') for k, _ in items]
    values = [v.encode('utf-8') for _, v in items]

    count = len(items)
    key_table_offset = 28
    value_table_offset = key_table_offset + 8 * count
    data_offset = value_table_offset + 8 * count

    key_table = b''
    value_table = b''
    data = bytearray()

    def add(blob):
        offset = data_offset + len(data)
        data.extend(blob)
        data.append(0)
        return offset

    for key in keys:
        offset = add(key)
        key_table += struct.pack('<II', len(key), offset)

    for value in values:
        offset = add(value)
        value_table += struct.pack('<II', len(value), offset)

    header = struct.pack('<IIIIIII', 0x950412DE, 0, count,
                         key_table_offset, value_table_offset, 0, 0)

    with open(out_path, 'wb') as handle:
        handle.write(header)
        handle.write(key_table)
        handle.write(value_table)
        handle.write(data)


def main(argv):
    if len(argv) != 3:
        raise SystemExit('usage: po2mo.py INPUT.po OUTPUT.mo')
    entries = parse_po(argv[1])
    write_mo(entries, argv[2])
    print(f'compiled {len(entries)} entries -> {argv[2]}')


if __name__ == '__main__':
    main(sys.argv)
