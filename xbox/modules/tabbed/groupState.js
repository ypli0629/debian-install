export function serializeGroups(groups) {
    const out = [];
    for (const g of groups) {
        try {
            const appId = g.appId ?? '';
            const wsIndex = g.workspaceIndex();
            const seqs = [];
            const seen = new Set();
            for (const win of g.windows) {
                const seq = win.get_stable_sequence();
                if (!seen.has(seq)) {
                    seen.add(seq);
                    seqs.push(seq);
                }
            }
            if (seqs.length === 0)
                continue;
            const activeSeq = g.active ? g.active.get_stable_sequence() : null;
            out.push(`${appId}|${wsIndex}|${seqs.join(',')}|${activeSeq ?? ''}`);
        } catch (e) {
            continue;
        }
    }
    return out;
}

export function saveGroups(settings, groups) {
    try {
        settings.set_strv('saved-groups', serializeGroups(groups));
    } catch (e) { /* settings unavailable */ }
}

export function restoreGroups(settings) {
    const result = [];
    let entries = [];
    try {
        entries = settings.get_strv('saved-groups') ?? [];
    } catch (e) {
        return result;
    }
    for (const entry of entries) {
        if (typeof entry !== 'string' || entry.length === 0)
            continue;
        const parts = entry.split('|');
        if (parts.length !== 4)
            continue;
        const [appId, wsPart, seqPart, activePart] = parts;
        const wsIndex = Number.parseInt(wsPart, 10);
        if (!Number.isInteger(wsIndex) || wsIndex < 0)
            continue;
        const sequences = [];
        const seen = new Set();
        for (const raw of seqPart.split(',')) {
            const seq = Number.parseInt(raw, 10);
            if (!Number.isInteger(seq) || seq < 0 || seen.has(seq))
                continue;
            seen.add(seq);
            sequences.push(seq);
        }
        if (sequences.length === 0)
            continue;
        let activeSeq = null;
        if (activePart.length > 0) {
            const parsed = Number.parseInt(activePart, 10);
            if (Number.isInteger(parsed) && sequences.includes(parsed))
                activeSeq = parsed;
        }
        result.push({
            appId: appId.length > 0 ? appId : null,
            workspaceIndex: wsIndex,
            sequences,
            activeSeq,
        });
    }
    return result;
}
