#!/usr/bin/env python3
"""Read public network metadata only; never request saved secrets."""
import json
import subprocess
import sys


def split_nmcli(line):
    result, value, escaped = [], '', False
    for char in line:
        if escaped:
            value += char
            escaped = False
        elif char == '\\':
            escaped = True
        elif char == ':':
            result.append(value)
            value = ''
        else:
            value += char
    result.append(value)
    return result


def run(args):
    return subprocess.run(['nmcli', '--colors', 'no', *args], capture_output=True, text=True, timeout=6, env=None)


def details(interface):
    fields = ['GENERAL.DEVICE', 'GENERAL.HWADDR', 'IP4.ADDRESS', 'IP4.GATEWAY', 'IP4.DNS', 'IP6.ADDRESS']
    data = run(['-t', '-f', ','.join(fields), 'device', 'show', interface])
    if data.returncode:
        return {'error': 'Не удалось прочитать параметры NetworkManager.'}
    result = {}
    for line in data.stdout.splitlines():
        parts = split_nmcli(line)
        if len(parts) > 1:
            key = parts[0].split('[')[0]
            result.setdefault(key, []).append(':'.join(parts[1:]))
    aps = run(['-t', '-f', 'SSID,CHAN,FREQ,RATE,SIGNAL,SECURITY', 'device', 'wifi', 'list', 'ifname', interface, '--rescan', 'no'])
    networks = {}
    if not aps.returncode:
        for line in aps.stdout.splitlines():
            row = split_nmcli(line)
            if len(row) == 6:
                previous = networks.get(row[0])
                if not previous or int(row[4] or 0) > int(previous['signal'] or 0):
                    networks[row[0]] = dict(zip(['channel', 'frequency', 'rate', 'signal', 'security'], row[1:]))
    return {'device': result, 'networks': networks, 'error': ''}


if __name__ == '__main__':
    try:
        print(json.dumps(details(sys.argv[1]), ensure_ascii=False))
    except (subprocess.SubprocessError, OSError, IndexError, ValueError):
        print(json.dumps({'error': 'Сведения о сети временно недоступны.'}))
