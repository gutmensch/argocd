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

def read_file(file):
    resources = {}
    if file:
        try:
            with open(file, 'r') as source:
                data = source.read()
                for doc in yaml.load_all(data, Loader=yaml.SafeLoader):
                    if doc:
                        key = hashlib.md5(str(doc).encode('utf-8')).hexdigest()[10:15]
                        doc_id = '{}-{}'.format(str.lower(doc['kind']), key)
                        resources[doc_id] = doc
        except IOError:
            log.error('error reading {file}')
    return resources

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

def main(argv):
    check_tools()

    try:
        _from, _to = argv[1], argv[2]
        if os.path.exists(_from) and not os.path.exists(_to):
            write_file(_to, jsonnet(read_file(_from)))
            log.info(f'destination file written: {_to}')
        else:
            log.error(f'source file {_from} does not exist or dest file {_to} does exist (no overwriting).')
    except IndexError:
        log.error(f'usage: {argv[0]} src.yaml dest.libsonnet')
    except IOError as e:
        log.error(f'could not read/write files: {e}')


if __name__ == '__main__':
    main(sys.argv)
