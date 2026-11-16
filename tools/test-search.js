const fs = require("fs");
const assert = require("assert/strict");
const source = fs.readFileSync(require("path").join(__dirname, "../config/search.js"), "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const Search = new Function(source + "\nreturn { parseQuery, score, rank };")();
assert.deepEqual(Search.parseQuery("  #  Идея  ", "all"), {scope: "notes", text: "идея"});
assert.deepEqual(Search.parseQuery("? WiFi", "apps"), {scope: "settings", text: "wifi"});
assert.deepEqual(Search.parseQuery("> фокус", "all"), {scope: "actions", text: "фокус"});
assert.deepEqual(Search.parseQuery("@ Firefox", "all"), {scope: "apps", text: "firefox"});
assert.equal(Search.score("камера", "Настройки камеры"), 0);
assert(Search.score("кмр", "Камера") > 0);
assert(Search.score("камера", "Камера") > Search.score("камера", "Камера устройства"));
const candidates = [
    {name: "Firefox", boost: 10},
    {name: "Фокус", keywords: "focus концентрация"},
    {name: "Фокусировка", keywords: "focus"}
];
assert.deepEqual(Search.rank("фокус", candidates).map(x => x.name), ["Фокус", "Фокусировка"]);
assert.equal(Search.rank("focus", candidates).length, 2);
assert.equal(Search.rank("абвгдежз", candidates).length, 0);
assert.deepEqual(Search.rank("", candidates), candidates);
console.log("Search ranking and category prefixes: OK");
