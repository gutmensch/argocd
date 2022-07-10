#!/usr/bin/env python3

# ugly conversion from bitwaren item data to sealedSecrets
# (c) 2022 rs@n-os.org

from subprocess import run, CalledProcessError, check_output, DEVNULL, PIPE
from getpass import getpass
from shutil import which
from sys import exit
import sys
from os import getenv
from textwrap import indent
import json
import hashlib
import os.path

import logging as log
log.basicConfig(encoding='utf-8', level=log.DEBUG)

try:
    import yaml
except ModuleNotFoundError:
    log.error('please install PyYAML, exiting.')
    exit(1)

bw_session = None

def check_tools():
    tools = ['jsonnetfmt', 'kubeseal', 'bw']
    if None in [which(x) for x in tools]:
        log.error(f'please install required tools {tools}, exiting.')
        exit(1)

def bitwarden_ensure_session():
    global bw_session
    
    if bw_session:
        return

    # we need to enforce getting session id
    if 0 == run(['bw', 'login', '--check'], stderr=DEVNULL, stdout=DEVNULL).returncode:
         bitwarden_logout()

    u = input('bw user: ')
    p = getpass('bw pass: ')
    # 2fa code
    c = input('bw code (opt): ')

    try:
        cmd = [which('bw'), 'login', u, p, '--raw']
        # method doc: https://bitwarden.com/help/cli/#enums
        cmd += ['--method', '0', '--code', c] if c != '' else []
        env = { 'HOME': getenv('HOME') }

        bw_session = run(cmd, env=env, capture_output=True).stdout

        log.info('BW_SESSION={}'.format(bw_session.decode('utf-8')))
    except CalledProcessError:
        log.error('bitwarden: login failed.')
        exit(1)

def bitwarden_item(item, bwtype='notes'):
    bitwarden_ensure_session()
    global bw_session
    value = None

    try:
        env = { 'BW_SESSION': bw_session, 'HOME': getenv('HOME') }
        res = run([which('bw'), 'get', bwtype, item], env=env, capture_output=True)
        if res.stderr:
            log.error(res.stderr)
        res.check_returncode()
        value = res.stdout 
    except CalledProcessError:
        log.error(f'bitwarden: fetching item {item} failed.')

    return value

def bitwarden_logout():
    try:
        env = { 'HOME': getenv('HOME') }
        run([which('bw'), 'logout'], env=env, stderr=DEVNULL, stdout=DEVNULL).check_returncode()
    except CalledProcessError:
        log.error('bitwarden: logout failed.')
        exit(1)

def parse(data):
    if data is None:
        log.error('bitwarden: data invalid')
        exit(1)
    return yaml.safe_load(data)

def sealed_secret(name, namespace, kv):
    res = { 'apiVersion': 'v1', 'kind': 'Secret', 'metadata': { 'name': name, 'namespace': namespace, 'creationTimestamp': None }, 'stringData': kv }

    kubeseal = ['kubeseal', '--controller-namespace', 'sealed-secrets-system', '--controller-name', 'sealed-secrets', '--format', 'json']
    gen = run(kubeseal, stderr=PIPE, stdout=PIPE, input=yaml.safe_dump(res).encode('utf-8'))
    if gen.returncode != 0:
        log.error(gen.stderr.decode('utf-8'))
        exit(1)

    return json.loads(gen.stdout)

def jsonnet(data):
    jsonnetfmt = ['jsonnetfmt', '-']
    jsondata = json.dumps(data, sort_keys=True, indent=2)
    form = run(jsonnetfmt, stderr=PIPE, stdout=PIPE, input=jsondata.encode('utf-8'))
    if form.returncode != 0:
        log.error(form.stderr.decode('utf-8'))
        exit(1)
    return form.stdout.decode('utf-8')

def write_file(path, data):
    with open(path, 'w') as f:
        f.write(data)

def generate_resources(path, secret_data_structure):
    for proj, apps in secret_data_structure.items():
        for app, data in apps.items():
            out = {}
            for tenant in ['staging', 'lts']:
                out[tenant] = {}
                try:
                    log.debug(f'generating secrets for project:{proj}, app {app} and env:{tenant}')
                    for sec, kv in data[tenant].items():
                        ns = f'{proj}-{app}-{tenant}'
                        key = hashlib.md5(f'sealed-secret-{ns}-{sec}'.encode('utf-8')).hexdigest()
                        out[tenant][key] = sealed_secret(sec, ns, kv)
                except KeyError:
                    pass
                if not os.path.isdir(os.path.join(getenv('PWD'), path)):
                    log.error('path {path} does not exist from PWD')
                    continue

            dst = os.path.join(getenv('PWD'), path, app, 'resources', 'sealedSecrets.libsonnet')
            log.debug(f'writing file {dst}')
            write_file(dst, jsonnet(out))

def main():
    check_tools()
    bitwarden_secrets = parse(bitwarden_item('argocd.kubectl.me'))
    # usable test data
    # bitwarden_secrets = {'base': {'jenkins': {'staging': { 'jenkins': {'jenkins-admin-user': 'admin', 'jenkins-admin-password': 'foobar'}}}}}
    generate_resources('apps', bitwarden_secrets)


if __name__ == '__main__':
    main()
