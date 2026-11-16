const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ctx = vm.createContext({Date, Number, String});
vm.runInContext(fs.readFileSync('config/island-summary.js', 'utf8'), ctx);
const now = new Date('2026-11-16T12:00:00').getTime();
const events = [
 {date:'2026-11-15',time:'',title:'Yesterday'},
 {date:'2026-11-16',time:'11:59',title:'Past'},
 {date:'2026-11-17',time:'09:00',title:'Tomorrow'},
 {date:'2026-11-16',time:'12:30',title:'Next'},
 {date:'broken',title:'Invalid'},
];
assert.equal(ctx.nextEvent(events, now).title,'Next');
assert.equal(ctx.eventLabel(ctx.nextEvent(events, now), now),'Через 30 мин');
assert.equal(ctx.nextEvent([...events,{date:'2026-11-16',time:'',title:'All day'}], now).title,'All day');
assert.equal(ctx.nextEvent([], now),null);
assert.equal(ctx.nextEvent([{date:'2026-11-16',time:'99:00',title:'Invalid'}],now),null);
assert.equal(ctx.nextEvent([{date:'2026-11-16',time:'',title:'Ended'}],new Date('2026-11-17T00:00:00').getTime()),null);
console.log('Upcoming events, past events and local all-day rollover: OK');

for (const [n, text] of [[1,'1 уведомление'],[2,'2 уведомления'],[11,'11 уведомлений'],[21,'21 уведомление'],[112,'112 уведомлений']]) assert.equal(ctx.notificationLabel(n),text);
