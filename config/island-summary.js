// Pure calendar selection; all-day events remain relevant until local midnight.
function nextEvent(events, now) {
    const time = new Date(now);
    const today = time.getFullYear() + '-' + String(time.getMonth() + 1).padStart(2, '0') + '-' + String(time.getDate()).padStart(2, '0');
    return events.filter(e => e && /^\d{4}-\d{2}-\d{2}$/.test(e.date) && typeof e.title === 'string')
        .map(e => {
            const allDay = !e.time;
            const start = new Date(e.date + 'T' + (allDay ? '00:00' : e.time) + ':00').getTime();
            return Object.assign({}, e, {start: start, allDay: allDay});
        })
        .filter(e => Number.isFinite(e.start) && (e.allDay ? e.date >= today : e.start >= now))
        .sort((a, b) => a.start - b.start)[0] || null;
}
function eventLabel(event, now) {
    if (!event) return '';
    const date = new Date(event.start);
    const current = new Date(now);
    const sameDay = date.toDateString() === current.toDateString();
    if (event.allDay) return sameDay ? 'Сегодня · весь день' : date.toLocaleDateString('ru-RU') + ' · весь день';
    const minutes = Math.ceil((event.start - now) / 60000);
    if (minutes < 60) return minutes <= 1 ? 'Сейчас' : 'Через ' + minutes + ' мин';
    return (sameDay ? 'Сегодня' : date.toLocaleDateString('ru-RU')) + ' · ' + event.time;
}
function notificationLabel(count) {
    const last = count % 10, teen = count % 100;
    const noun = teen >= 11 && teen <= 14 ? 'уведомлений' : last === 1 ? 'уведомление' : last >= 2 && last <= 4 ? 'уведомления' : 'уведомлений';
    return count + ' ' + noun;
}
