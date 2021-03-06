#!/usr/bin/env python3

# stupid yaml to jsonnet converter

from subprocess import run, CalledProcessError, check_output, DEVNULL, PIPE
from shutil import which
from sys import exit
import sys
from os import getenv
import json
import hashlib
import os.path
from base64 import b64decode

import logging as log
log.basicConfig(encoding='utf-8', level=log.DEBUG)

try:
    import yaml
except ModuleNotFoundError:
    log.error('please install PyYAML, exiting.')
    exit(1)

def check_tools():
    tools = ['jsonnetfmt']
    if None in [which(x) for x in tools]:
        log.error(f'please install required tools {tools}, exiting.')
        exit(1)

def sanitize_obj(doc):
    # manipulating doc for use as jsonnet object
    kind = doc['kind']
    doc_id = '{}_{}: kube.{}(\'{}\')'.format(
            str.lower(kind), doc['metadata']['name'].replace('-', '_'),
            kind, doc['metadata']['name'])
    doc['metadata'].pop('name', None)
    doc['metadata']['labels'].pop('chart', None)
    doc['metadata']['labels'].pop('heritage', None)

    try:
        if doc['spec']['template']['metadata']['labels']:
            doc['spec']['template']['metadata']['labels'].pop('chart', None)
            doc['spec']['template']['metadata']['labels'].pop('heritage', None)
    except KeyError:
        pass

    try:
        if doc['spec']['volumeClaimTemplates']:
            for i, _ in enumerate(doc['spec']['volumeClaimTemplates']):
                doc['spec']['volumeClaimTemplates'][i]['metadata']['labels'].pop('chart', None)
                doc['spec']['volumeClaimTemplates'][i]['metadata']['labels'].pop('heritage', None)
    except KeyError:
        pass

    doc.pop('apiVersion', None)
    doc.pop('kind', None)
    doc['metadata']['namespace'] = '__NAMESPACE__'

    if kind == 'Secret':
        doc['stringData'] = {}
        if doc['data']:
            for k in doc['data'].keys():
                decoded = b64decode(doc['data'][k]).decode('utf-8')
                doc['stringData'][k] = decoded
        doc.pop('data')

    return kind, doc_id, doc

def read_file(file):
    resources = {}
    secrets = {}
    try:
        with open(file, 'r') as source:
            data = source.read()
            for doc in yaml.load_all(data, Loader=yaml.SafeLoader):
                if doc:
                    kind, _id, sanitized = sanitize_obj(doc)
                    if kind == 'Secret':
                        secrets[_id] = doc
                    else:
                        resources[_id] = doc
    except IOError:
        log.error('error reading {file}')

    return resources, secrets

def jsonnet(data):
    jsonnetfmt = ['jsonnetfmt', '-']
    jsondata = json.dumps(data, sort_keys=True, indent=2)
    form = run(jsonnetfmt, stderr=PIPE, stdout=PIPE, input=jsondata.encode('utf-8'))
    if form.returncode != 0:
        log.error(form.stderr.decode('utf-8'))
        exit(1)
    return form.stdout.decode('utf-8')

# hacky function to modify object key to object key + function call
def convert(data):
    lines = ["local kube = import 'kube.libsonnet';"]
    for line in data.splitlines():
        if ': kube.' in line:
            lines.append(line.replace('"',''))
        elif '__NAMESPACE__' in line:
            lines.append(line.replace("'__NAMESPACE__'", "namespace"))
        else:
            lines.append(line)
    return '\n'.join(lines)

def write_file(path, data):
    with open(path, 'w') as f:
        f.write(data)

def main(argv):
    check_tools()

    try:
        _from, _to_res, _to_sec = argv[1], argv[2], argv[3]
        if os.path.exists(_from) and not os.path.exists(_to_res) and not os.path.exists(_to_sec):
            resources, secrets = read_file(_from)
            write_file(_to_res, convert(jsonnet(resources)))
            write_file(_to_sec, convert(jsonnet(secrets)))
            log.info(f'destination files written: {_to_res}, {_to_sec}')
        else:
            log.error(f'source file {_from} does not exist or dest file(s) {_to_res}, {_to_sec} does exist (no overwriting).')
    except IndexError:
        log.error(f'usage: {argv[0]} src.yaml dest_res.libsonnet dest_sec.libsonnet')
    except IOError as e:
        log.error(f'could not read/write files: {e}')


if __name__ == '__main__':
    main(sys.argv)
