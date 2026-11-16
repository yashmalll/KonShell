.pragma library

function normalize(value) {
    return String(value ?? "").trim().toLocaleLowerCase();
}

function parseQuery(value, scope) {
    const text = String(value ?? "").trim();
    const prefixes = { "@": "apps", "#": "notes", ">": "actions", "?": "settings" };
    return { scope: prefixes[text[0]] ?? scope ?? "all",
        text: normalize(prefixes[text[0]] ? text.slice(1) : text) };
}

function score(query, value) {
    if (!query) return 1;
    const text = normalize(value);
    if (text === query) return 200;
    if (text.startsWith(query)) return 140 - Math.min(30, text.length * 0.1);
    if (text.includes(query)) return 100 - Math.min(30, text.length * 0.1);
    let position = 0;
    let previous = -2;
    let first = -1;
    let result = 0;
    for (let i = 0; i < text.length && position < query.length; i++) {
        if (text[i] !== query[position]) continue;
        result += 2 + (i === previous + 1 ? 5 : 0) + (i === 0 || " -_./".includes(text[i - 1]) ? 8 : 0);
        if (first < 0) first = i;
        previous = i;
        position++;
    }
    if (query.length >= 4 && previous - first + 1 > query.length * 2) return 0;
    return position === query.length ? Math.max(1, result - text.length * 0.1) : 0;
}

function rank(query, candidates) {
    return candidates.map((item, index) => ({ item, index,
        score: Math.max(score(query, item.name), score(query, item.keywords || "") * 0.65)
            + (query ? (item.boost || 0) : 0) }))
        .filter(row => row.score > 0 && (!query || score(query, row.item.name) > 0 || score(query, row.item.keywords || "") > 0))
        .sort((a, b) => b.score - a.score || a.index - b.index)
        .map(row => row.item);
}
