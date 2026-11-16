#!/usr/bin/env python3
"""Receive KDE job progress and Unity launcher progress; no file-system polling.
Protocol: KDE/kjobwidgets src/dbus/org.kde.JobView{Server,V2,V3}.xml.
"""
import json
import sys
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib


def clean(value):
    return str(value)[:500]


class Monitor:
    def __init__(self, bus):
        self.bus = bus
        self.jobs = {}
        self.serial = 0
        self.pending_emit = False

    def changed(self):
        if not self.pending_emit:
            self.pending_emit = True
            GLib.timeout_add(100, self.publish)

    def publish(self):
        self.pending_emit = False
        print(json.dumps({'jobs': [job.data for job in self.jobs.values()]}, ensure_ascii=False), flush=True)
        return False

    def create(self, app, caps, sender, v3=False, hints=None):
        self.serial += 1
        path = '/org/kde/JobViewServer/Job' + str(self.serial)
        job = (JobV3 if v3 else JobV2)(self, path, app, caps, sender)
        self.jobs[path] = job
        if hints:
            job.apply(hints)
        self.changed()
        return dbus.ObjectPath(path)

    def owner_changed(self, name, old, new):
        if old and not new:
            for job in list(self.jobs.values()):
                if job.owner == name:
                    job.remove()


class Job(dbus.service.Object):
    def __init__(self, monitor, path, app, caps, owner):
        super().__init__(monitor.bus, path)
        self.monitor, self.path, self.owner = monitor, path, owner
        self.data = {'id': path, 'app': clean(app), 'title': 'Выполняется операция', 'percent': -1, 'suspended': False, 'capabilities': int(caps)}

    def remove(self):
        self.monitor.jobs.pop(self.path, None)
        self.remove_from_connection()
        self.monitor.changed()

    def apply(self, props):
        for key, value in props.items():
            if key in ('infoMessage', 'title'):
                self.data['title'] = clean(value)
            elif key == 'percent':
                self.data['percent'] = max(0, min(100, int(value)))
            elif key == 'suspended':
                self.data['suspended'] = bool(value)
            elif key in ('totalBytes', 'processedBytes', 'speed'):
                self.data[key] = int(value)
        self.monitor.changed()


class JobV2(Job):
    @dbus.service.method('org.kde.JobViewV2', in_signature='s', out_signature='', sender_keyword='sender')
    def terminate(self, message, sender=None):
        if sender == self.owner:
            self.remove()

    @dbus.service.method('org.kde.JobViewV2', in_signature='b', out_signature='', sender_keyword='sender')
    def setSuspended(self, value, sender=None):
        if sender == self.owner: self.apply({'suspended': value})

    @dbus.service.method('org.kde.JobViewV2', in_signature='ts', out_signature='', sender_keyword='sender')
    def setTotalAmount(self, amount, unit, sender=None):
        if sender == self.owner and unit == 'bytes': self.apply({'totalBytes': amount})

    @dbus.service.method('org.kde.JobViewV2', in_signature='ts', out_signature='', sender_keyword='sender')
    def setProcessedAmount(self, amount, unit, sender=None):
        if sender == self.owner and unit == 'bytes': self.apply({'processedBytes': amount})

    @dbus.service.method('org.kde.JobViewV2', in_signature='u', out_signature='', sender_keyword='sender')
    def setPercent(self, value, sender=None):
        if sender == self.owner: self.apply({'percent': value})

    @dbus.service.method('org.kde.JobViewV2', in_signature='t', out_signature='', sender_keyword='sender')
    def setSpeed(self, value, sender=None):
        if sender == self.owner: self.apply({'speed': value})

    @dbus.service.method('org.kde.JobViewV2', in_signature='t', out_signature='')
    def setElapsedTime(self, value): pass

    @dbus.service.method('org.kde.JobViewV2', in_signature='s', out_signature='', sender_keyword='sender')
    def setInfoMessage(self, value, sender=None):
        if sender == self.owner: self.apply({'infoMessage': value})

    @dbus.service.method('org.kde.JobViewV2', in_signature='uss', out_signature='b')
    def setDescriptionField(self, number, name, value): return True

    @dbus.service.method('org.kde.JobViewV2', in_signature='u', out_signature='')
    def clearDescriptionField(self, number): pass

    @dbus.service.method('org.kde.JobViewV2', in_signature='v', out_signature='')
    def setDestUrl(self, url): pass


class JobV3(Job):
    @dbus.service.method('org.kde.JobViewV3', in_signature='usa{sv}', out_signature='', sender_keyword='sender')
    def terminate(self, code, message, hints, sender=None):
        if sender == self.owner: self.remove()

    @dbus.service.method('org.kde.JobViewV3', in_signature='a{sv}', out_signature='', sender_keyword='sender')
    def update(self, properties, sender=None):
        if sender == self.owner: self.apply(properties)


class Server(dbus.service.Object):
    def __init__(self, monitor):
        super().__init__(monitor.bus, '/JobViewServer')
        self.monitor = monitor

    @dbus.service.method('org.kde.JobViewServer', in_signature='ssi', out_signature='o', sender_keyword='sender')
    def requestView(self, app, icon, capabilities, sender=None):
        return self.monitor.create(app, capabilities, sender)


# dbus-python merges interfaces via inheritance on a single exported object.
class CombinedServer(Server):
    @dbus.service.method('org.kde.JobViewServerV2', in_signature='sia{sv}', out_signature='o', sender_keyword='sender')
    def requestView(self, app, capabilities, hints, sender=None):
        return self.monitor.create(app, capabilities, sender, True, hints)


def main():
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    monitor = Monitor(bus)
    server = None
    # Respect an existing job server; don't replace another desktop's service.
    if not bus.name_has_owner('org.kde.JobViewServer'):
        name = dbus.service.BusName('org.kde.JobViewServer', bus, do_not_queue=True)
        server = CombinedServer(monitor)
    bus.add_signal_receiver(monitor.owner_changed, signal_name='NameOwnerChanged', dbus_interface='org.freedesktop.DBus')
    launcher = {}

    def launcher_update(uri, props, sender=None):
        key = 'launcher:' + str(sender) + ':' + str(uri)
        if props.get('progress-visible') is False or ('progress-visible' in props and not bool(props['progress-visible'])):
            launcher.pop(key, None)
        elif bool(props.get('progress-visible', key in launcher)):
            previous = launcher.get(key, {})
            launcher[key] = {'id': key, 'app': clean(str(uri).replace('application://', '').replace('.desktop', '')), 'title': 'Загрузка или операция', 'percent': max(0, min(100, round(float(props.get('progress', previous.get('percent', 0) / 100)) * 100))), 'suspended': False}
        publish_launchers()

    def publish_launchers():
        print(json.dumps({'jobs': [job.data for job in monitor.jobs.values()] + list(launcher.values())}, ensure_ascii=False), flush=True)

    # Keep the throttled KDE publish and launcher updates in one snapshot.
    monitor.publish = lambda: (setattr(monitor, 'pending_emit', False), publish_launchers(), False)[-1]
    bus.add_signal_receiver(launcher_update, signal_name='Update', dbus_interface='com.canonical.Unity.LauncherEntry', sender_keyword='sender')
    def owner_gone(name, old, new):
        if old and not new:
            for key in list(launcher):
                if key.startswith('launcher:' + str(name) + ':'): launcher.pop(key)
            publish_launchers()
    bus.add_signal_receiver(owner_gone, signal_name='NameOwnerChanged', dbus_interface='org.freedesktop.DBus')
    print(json.dumps({'jobs': [], 'available': True, 'kdeServer': server is not None}), flush=True)
    loop = GLib.MainLoop()
    GLib.io_add_watch(sys.stdin, GLib.IO_HUP, lambda *_: loop.quit() or False)
    loop.run()


if __name__ == '__main__':
    main()
