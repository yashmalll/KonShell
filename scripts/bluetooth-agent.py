#!/usr/bin/env python3
"""BlueZ agent and asynchronous device operations; JSON lines over owned stdio."""
import codecs
import json
import os
import re
import sys
import time
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

AGENT = 'org.bluez.Agent1'
DEVICE = 'org.bluez.Device1'
PROPS = 'org.freedesktop.DBus.Properties'


def emit(**data):
    print(json.dumps(data, ensure_ascii=False), flush=True)


def error_text(error):
    name = str(getattr(error, 'get_dbus_name', lambda: '')())
    text = str(error)
    reasons = {
        'AuthenticationFailed': 'Не удалось проверить код или PIN. Повторите сопряжение.',
        'AuthenticationCanceled': 'Сопряжение отменено.',
        'AuthenticationRejected': 'Устройство отклонило сопряжение. Проверьте подтверждение на устройстве.',
        'AuthenticationTimeout': 'Устройство не ответило. Включите на нём режим сопряжения.',
        'ConnectionAttemptFailed': 'Устройство недоступно. Проверьте расстояние и подключение к другому компьютеру.',
        'NotReady': 'Адаптер не готов. Проверьте питание и аппаратную блокировку Bluetooth.',
        'InProgress': 'На устройстве уже выполняется операция. Дождитесь завершения.',
        'NotAvailable': 'Сервис устройства недоступен. Переведите устройство в режим подключения.',
        'NotConnected': 'Устройство уже отключено.',
        'DoesNotExist': 'Устройство больше не найдено. Обновите поиск.',
    }
    for key, value in reasons.items():
        if name.endswith('.' + key):
            return value
    if 'br-connection-profile-unavailable' in text:
        return 'Аудиопрофиль недоступен. Проверьте, что запущены PipeWire и WirePlumber.'
    return 'Не удалось выполнить операцию: ' + text[:300]


class Rejected(dbus.DBusException):
    _dbus_error_name = 'org.bluez.Error.Rejected'


class Agent(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, '/org/konshell/agent')
        self.bus = bus
        self.pending = None
        self.pending_device = None
        self.timeout = None
        self.display_device = None
        self.serial = 0
        self.operations = {}

    def verify(self, sender):
        if sender != self.bus.get_name_owner('org.bluez'):
            raise Rejected('Only BlueZ may request authentication')

    def ask(self, kind, device, reply, fail, **extra):
        self.reject_pending()
        self.serial += 1
        self.pending_device = str(device)
        self.pending = (self.serial, kind, reply, fail)
        emit(event='prompt', id=self.serial, kind=kind, device=str(device), **extra)
        self.timeout = GLib.timeout_add_seconds(60, self.reject_pending)

    def reject_pending(self):
        if self.timeout:
            GLib.source_remove(self.timeout)
            self.timeout = None
        if self.pending:
            _, _, _, fail = self.pending
            self.pending = None
            fail(Rejected('Cancelled or timed out'))
        self.pending_device = None
        self.display_device = None
        emit(event='promptClosed')
        return False

    def respond(self, data):
        if not self.pending or data.get('id') != self.pending[0]:
            return
        _, kind, reply, fail = self.pending
        value = str(data.get('value', ''))
        if data.get('accept') and ((kind == 'passkey' and not re.fullmatch(r'\d{1,6}', value))
                                  or (kind == 'pin' and not 1 <= len(value) <= 16)):
            emit(event='inputError', message='Введите PIN (1–16 символов) или числовой код (до 6 цифр).')
            return
        if self.timeout:
            GLib.source_remove(self.timeout)
            self.timeout = None
        self.pending = None
        self.pending_device = None
        if not data.get('accept'):
            fail(Rejected('Rejected by user'))
        elif kind == 'pin':
            reply(value)
        elif kind == 'passkey':
            reply(dbus.UInt32(value))
        else:
            reply()
        emit(event='promptClosed')

    @dbus.service.method(AGENT, in_signature='', out_signature='', sender_keyword='sender')
    def Release(self, sender=None):
        self.verify(sender)
        self.reject_pending()
        emit(event='ready', ready=False, error='Bluetooth-агент отключён системой.')

    @dbus.service.method(AGENT, in_signature='o', out_signature='s', async_callbacks=('reply', 'fail'), sender_keyword='sender')
    def RequestPinCode(self, device, reply, fail, sender=None):
        self.verify(sender)
        self.ask('pin', device, reply, fail)

    @dbus.service.method(AGENT, in_signature='o', out_signature='u', async_callbacks=('reply', 'fail'), sender_keyword='sender')
    def RequestPasskey(self, device, reply, fail, sender=None):
        self.verify(sender)
        self.ask('passkey', device, reply, fail)

    @dbus.service.method(AGENT, in_signature='ou', out_signature='', async_callbacks=('reply', 'fail'), sender_keyword='sender')
    def RequestConfirmation(self, device, passkey, reply, fail, sender=None):
        self.verify(sender)
        self.ask('confirm', device, reply, fail, code=f'{int(passkey):06d}')

    @dbus.service.method(AGENT, in_signature='o', out_signature='', async_callbacks=('reply', 'fail'), sender_keyword='sender')
    def RequestAuthorization(self, device, reply, fail, sender=None):
        self.verify(sender)
        self.ask('authorize', device, reply, fail)

    @dbus.service.method(AGENT, in_signature='os', out_signature='', async_callbacks=('reply', 'fail'), sender_keyword='sender')
    def AuthorizeService(self, device, uuid, reply, fail, sender=None):
        self.verify(sender)
        self.ask('authorize', device, reply, fail, service=str(uuid))

    @dbus.service.method(AGENT, in_signature='os', out_signature='', sender_keyword='sender')
    def DisplayPinCode(self, device, pincode, sender=None):
        self.verify(sender)
        self.display_device = str(device)
        if self.timeout:
            GLib.source_remove(self.timeout)
        self.timeout = GLib.timeout_add_seconds(75, self.reject_pending)
        emit(event='display', device=str(device), code=str(pincode))

    @dbus.service.method(AGENT, in_signature='ouq', out_signature='', sender_keyword='sender')
    def DisplayPasskey(self, device, passkey, entered, sender=None):
        self.verify(sender)
        self.display_device = str(device)
        if self.timeout:
            GLib.source_remove(self.timeout)
        self.timeout = GLib.timeout_add_seconds(75, self.reject_pending)
        emit(event='display', device=str(device), code=f'{int(passkey):06d}', entered=int(entered))

    @dbus.service.method(AGENT, in_signature='', out_signature='', sender_keyword='sender')
    def Cancel(self, sender=None):
        self.verify(sender)
        self.reject_pending()

    def operation(self, data):
        path, action = data.get('device', ''), data.get('action', '')
        if not re.fullmatch(r'/org/bluez/hci\d+/dev_(?:[0-9A-Fa-f]{2}_){5}[0-9A-Fa-f]{2}', path):
            return
        if action not in ('connect', 'disconnect', 'forget', 'cancel', 'trust', 'untrust', 'unblock'):
            return
        device = dbus.Interface(self.bus.get_object('org.bluez', path), DEVICE)
        props = dbus.Interface(self.bus.get_object('org.bluez', path), PROPS)
        if action == 'cancel':
            self.reject_pending()
            self.operations.pop(path, None)
            device.CancelPairing(reply_handler=lambda: None, error_handler=lambda e: None)
            device.Disconnect(reply_handler=lambda: None, error_handler=lambda e: None)
            emit(event='operation', device=path, stage='', error='Операция отменена.')
            return
        if path in self.operations:
            return
        token = time.monotonic_ns()
        self.operations[path] = token

        def current():
            return self.operations.get(path) == token

        def failed(error):
            if current():
                self.operations.pop(path, None)
                emit(event='operation', device=path, stage='', error=error_text(error))
                if self.display_device == path or self.pending_device == path:
                    self.reject_pending()

        def done(*_):
            if current():
                self.operations.pop(path, None)
                emit(event='operation', device=path, stage='', error='')
                if self.display_device == path:
                    self.reject_pending()

        def connect(*_):
            if not current():
                return
            emit(event='operation', device=path, stage='Подключение…', error='')
            device.Connect(reply_handler=done, error_handler=failed, timeout=40)

        def trust_and_connect(*_):
            if current():
                props.Set(DEVICE, 'Trusted', dbus.Boolean(True), reply_handler=connect, error_handler=failed)

        emit(event='operation', device=path, stage='Выполняется…', error='')
        try:
            if action == 'connect':
                state = props.GetAll(DEVICE)
                if state.get('Blocked'):
                    failed(Exception('Устройство заблокировано. Сначала нажмите «Разблокировать».'))
                elif state.get('Paired'):
                    connect()
                else:
                    emit(event='operation', device=path, stage='Сопряжение…', error='')
                    device.Pair(reply_handler=trust_and_connect, error_handler=failed, timeout=75)
            elif action == 'disconnect':
                device.Disconnect(reply_handler=done, error_handler=failed, timeout=20)
            elif action == 'forget':
                adapter = dbus.Interface(self.bus.get_object('org.bluez', path.rsplit('/', 1)[0]), 'org.bluez.Adapter1')
                adapter.RemoveDevice(dbus.ObjectPath(path), reply_handler=done, error_handler=failed)
            else:
                key, value = ('Blocked', False) if action == 'unblock' else ('Trusted', action == 'trust')
                props.Set(DEVICE, key, dbus.Boolean(value), reply_handler=done, error_handler=failed)
        except Exception as error:
            failed(error)


def main():
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    agent = Agent(bus)
    loop = GLib.MainLoop()

    def register(*_):
        if not bus.name_has_owner('org.bluez'):
            emit(event='ready', ready=False, error='Служба Bluetooth не запущена.')
            return
        try:
            manager = dbus.Interface(bus.get_object('org.bluez', '/org/bluez'), 'org.bluez.AgentManager1')
            try:
                manager.RegisterAgent('/org/konshell/agent', 'KeyboardDisplay')
            except dbus.DBusException as error:
                if error.get_dbus_name() != 'org.bluez.Error.AlreadyExists':
                    raise
            manager.RequestDefaultAgent('/org/konshell/agent')
            emit(event='ready', ready=True, error='')
        except dbus.DBusException as error:
            emit(event='ready', ready=False, error=error_text(error))

    def bluez_changed(name, old, new):
        if new:
            register()
        else:
            agent.reject_pending()
            agent.operations.clear()
            emit(event='ready', ready=False, error='Служба Bluetooth остановлена.')
    bus.add_signal_receiver(bluez_changed, signal_name='NameOwnerChanged', dbus_interface='org.freedesktop.DBus', arg0='org.bluez')

    buffer = ""
    decoder = codecs.getincrementaldecoder("utf-8")()
    def read_input(fd, condition):
        nonlocal buffer
        if condition & GLib.IO_HUP:
            agent.reject_pending()
            loop.quit()
            return False
        chunk = os.read(sys.stdin.fileno(), 65536)
        if not chunk:
            loop.quit()
            return False
        buffer += decoder.decode(chunk)
        while '\n' in buffer:
            line, buffer = buffer.split('\n', 1)
            try:
                data = json.loads(line)
                if data.get('action') == 'respond':
                    agent.respond(data)
                elif data.get('action') == 'register':
                    register()
                else:
                    agent.operation(data)
            except Exception as error:
                emit(event='error', error=error_text(error))
        return True

    GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, read_input)
    register()
    loop.run()


if __name__ == '__main__':
    main()
