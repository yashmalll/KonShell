const fs = require("fs");
const path = require("path");
const assert = require("assert/strict");
function readLibrary(name, exports) {
    const source = fs.readFileSync(path.join(__dirname, "../config", name), "utf8")
        .replace(/^\.pragma library\s*$/m, "");
    return new Function(source + `\nreturn {${exports}};`)();
}
const schema = readLibrary("settings-schema.js", "sections,options");
const nav = readLibrary("settings-navigation.js", "groups,canonicalSection,groupFor,isAdvanced,isRelevant");
const sections = nav.groups.flatMap(group => group.sections);
assert.equal(new Set(sections).size, sections.length);
for (const section of schema.sections) {
    assert(sections.includes(nav.canonicalSection(section.id)), `Missing section ${section.id}`);
}
assert.equal(nav.canonicalSection("controlCenter"), "bar");
assert.equal(nav.groupFor("controlCenter").id, "island");
assert.equal(nav.canonicalSection("unknown"), "appearance");
assert.equal(nav.isAdvanced(schema.options.find(option => option.key === "bar.autoHide")), false);
assert.equal(nav.isAdvanced(schema.options.find(option => option.component === "barLayout")), true);
assert(schema.options.filter(option => option.type === "action").every(nav.isAdvanced));
const values = {"bar.islandNotifications": true, "bar.islandOsd": true, "osd.enabled": true, "lock.pinEnabled": false, "theme.source": "wallpaper"};
const read = key => values[key];
const option = key => schema.options.find(item => item.key === key);
assert.equal(nav.isRelevant(option("controlCenter.width"), read), false);
assert.equal(nav.isRelevant(option("notifications.position"), read), false);
assert.equal(nav.isRelevant(option("osd.position"), read), false);
assert.equal(nav.isRelevant(option("theme.seedColor"), read), false);
assert.equal(nav.isRelevant(schema.options.find(o => o.component === "pin"), read), false);
values["bar.islandNotifications"] = false;
values["bar.islandOsd"] = false;
values["lock.pinEnabled"] = true;
values["theme.source"] = "color";
assert.equal(nav.isRelevant(option("notifications.position"), read), true);
assert.equal(nav.isRelevant(option("osd.position"), read), true);
assert.equal(nav.isRelevant(option("theme.seedColor"), read), true);
assert.equal(nav.isRelevant(schema.options.find(o => o.component === "pin"), read), true);
console.log("Settings navigation coverage, legacy routes and contextual visibility: OK");
