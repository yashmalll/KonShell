import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('bt_agent', Path(__file__).parents[1] / 'scripts/bluetooth-agent.py')
bt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bt)
PATH = '/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF'


class FakeDevice:
    def __init__(self, paired=False):
        self.calls = []
        self.paired = paired
        self.pair_reply = None
        self.pair_fail = None
    def GetAll(self, interface): return {'Paired': self.paired, 'Blocked': False}
    def Pair(self, **kw):
        self.calls.append('pair')
        self.pair_reply, self.pair_fail = kw['reply_handler'], kw['error_handler']
    def Set(self, interface, key, value, **kw):
        self.calls.append((key, bool(value)))
        kw['reply_handler']()
    def Connect(self, **kw):
        self.calls.append('connect')
        kw['reply_handler']()
    def CancelPairing(self, **kw): self.calls.append('cancel')
    def Disconnect(self, **kw):
        self.calls.append('disconnect')
        kw['reply_handler']()


class FakeBus:
    def __init__(self, device): self.device = device
    def get_object(self, *args): return self.device
    def get_name_owner(self, name): return ':bluez'


class BluetoothTests(unittest.TestCase):
    def setUp(self):
        self.device = FakeDevice()
        self.agent = bt.Agent.__new__(bt.Agent)
        self.agent.bus = FakeBus(self.device)
        self.agent.operations = {}
        self.agent.display_device = None
        self.agent.pending = None
        self.agent.pending_device = None
        self.agent.timeout = None
        self.events = []
        self.patch_interface = patch.object(bt.dbus, 'Interface', lambda obj, iface: obj)
        self.patch_emit = patch.object(bt, 'emit', lambda **data: self.events.append(data))
        self.patch_interface.start(); self.patch_emit.start()
    def tearDown(self):
        self.patch_interface.stop(); self.patch_emit.stop()
    def test_pair_then_trust_then_connect(self):
        self.agent.operation({'device': PATH, 'action': 'connect'})
        self.assertEqual(self.device.calls, ['pair'])
        self.device.pair_reply()
        self.assertEqual(self.device.calls, ['pair', ('Trusted', True), 'connect'])
        self.assertFalse(self.agent.operations)
    def test_paired_skips_pairing(self):
        self.device.paired = True
        self.agent.operation({'device': PATH, 'action': 'connect'})
        self.assertEqual(self.device.calls, ['connect'])
    def test_failed_pair_never_connects_or_trusts(self):
        self.agent.operation({'device': PATH, 'action': 'connect'})
        self.device.pair_fail(bt.Rejected('Wrong PIN'))
        self.assertEqual(self.device.calls, ['pair'])
        self.assertTrue(self.events[-1]['error'])
        self.assertFalse(self.agent.operations)
    def test_duplicate_and_stale_callback(self):
        self.agent.operation({'device': PATH, 'action': 'connect'})
        self.agent.operation({'device': PATH, 'action': 'connect'})
        self.assertEqual(self.device.calls, ['pair'])
        self.agent.operation({'device': PATH, 'action': 'cancel'})
        self.device.pair_reply()
        self.assertNotIn('connect', self.device.calls)
    def test_invalid_path_rejected(self):
        self.agent.operation({'device': '/other/device', 'action': 'connect'})
        self.assertEqual(self.device.calls, [])
    def test_authentication_only_from_bluez(self):
        self.agent.verify(':bluez')
        with self.assertRaises(bt.Rejected): self.agent.verify(':untrusted')
    def test_invalid_passkey_keeps_prompt_pending(self):
        self.agent.pending = (7, 'passkey', lambda *_: self.fail('Must not accept'), lambda *_: None)
        self.agent.respond({'id': 7, 'accept': True, 'value': '1234567'})
        self.assertIsNotNone(self.agent.pending)
        self.assertEqual(self.events[-1]['event'], 'inputError')
    def test_stale_response_ignored(self):
        self.agent.pending = (7, 'confirm', lambda *_: self.fail('Stale response'), lambda *_: None)
        self.agent.respond({'id': 6, 'accept': True})
        self.assertIsNotNone(self.agent.pending)


if __name__ == '__main__': unittest.main()
