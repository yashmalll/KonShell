"""Run under dbus-run-session; no real files are downloaded or copied."""
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import time
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
DBusGMainLoop(set_as_default=True)

class Launcher(dbus.service.Object):
    @dbus.service.signal('com.canonical.Unity.LauncherEntry', signature='sa{sv}')
    def Update(self, uri, properties): pass

root = Path(__file__).parents[1]
process = subprocess.Popen([sys.executable, '-u', str(root / 'scripts/job-monitor.py')], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
try:
    bus = dbus.SessionBus()
    deadline = time.monotonic() + 5
    while not bus.name_has_owner('org.kde.JobViewServer') and time.monotonic() < deadline:
        time.sleep(.05)
    obj = bus.get_object('org.kde.JobViewServer', '/JobViewServer')
    old = dbus.Interface(obj, 'org.kde.JobViewServer')
    path = old.requestView('Test copy', 'folder', dbus.Int32(0))
    job = dbus.Interface(bus.get_object('org.kde.JobViewServer', path), 'org.kde.JobViewV2')
    job.setInfoMessage('Copying test metadata')
    job.setPercent(dbus.UInt32(37))
    modern = dbus.Interface(obj, 'org.kde.JobViewServerV2')
    path2 = modern.requestView('Test download', dbus.Int32(0), dbus.Dictionary({}, signature='sv'))
    job2 = dbus.Interface(bus.get_object('org.kde.JobViewServer', path2), 'org.kde.JobViewV3')
    job2.update(dbus.Dictionary({'percent': dbus.UInt32(62), 'infoMessage': 'Download test metadata'}, signature='sv'))
    launcher = Launcher(bus, '/com/canonical/Unity/LauncherEntry/test')
    launcher.Update('application://test.desktop', dbus.Dictionary({'progress-visible': True, 'progress': .42}, signature='sv'))
    # Wait until the process has emitted its coalesced snapshot.
    time.sleep(.3)
    launcher.Update('application://test.desktop', dbus.Dictionary({'progress-visible': False}, signature='sv'))
    job.terminate('')
    job2.terminate(dbus.UInt32(0), '', dbus.Dictionary({}, signature='sv'))
    time.sleep(.3)
finally:
    process.stdin.close()
    process.wait(timeout=5)
    out, err = process.stdout.read(), process.stderr.read()
    if process.returncode:
        raise RuntimeError(err)
    snapshots = [json.loads(line)['jobs'] for line in out.splitlines() if line.startswith('{')]
    assert any({37, 62}.issubset({j['percent'] for j in s}) for s in snapshots), (out, err)
    assert any(any(j['id'].startswith('launcher:') and j['percent'] == 42 for j in s) for s in snapshots), (out, err)
    assert snapshots[-1] == [], (out, err)
    print('KDE JobView V2/V3 and Unity creation, progress and cleanup over isolated D-Bus: OK')
