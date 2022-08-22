#!/usr/bin/env python3
"""Executable script to remove managed resources from Helm releases.

This script was created for resources of "Kind: CustomResourceDefinition" and
Helm charts which used to manage these CRDs as templates but then removed the
templates from future versions of the Helm chart. Typically, only Helm 2 charts
managed CRDs as templates while the corresponding Helm 3 chart packages should
normally not include CRDs as templates. This was causing the CRDs to be purged
when upgrading releases from Helm 2 chart versions to Helm 3 chart versions.

If this script is run before "helm upgrade" (or "helm uninstall") the orphaned
CRDs will then remain in the cluster, as would be the case for CRDs which had
been initially installed by Helm 3's new mechanism for handling CRDs.

For further usage instructions, run this script with the "--help" option.

This work is licensed under a Creative Commons Public Domain Mark 1.0 License;
see https://creativecommons.org/publicdomain/mark/1.0/ for details.
"""

import base64
import copy
import gzip
import json
import re
import uuid

from subprocess import check_output, run
from tempfile import NamedTemporaryFile
from argparse import ArgumentParser, Action, SUPPRESS


def patch_release_manifest(
        namespace,
        release,
        resource_kind,
        revision=None,
        dry_run=False,
        quiet=False
):
    """Remove resources of the specified "Kind" from the specified Helm release
    revision and return whether the release was patched or not. If not otherwise
    specified, the current revision of the release will be patched.

    Examples:
        First, we perform a dry-run to show what would have been done.

        >>> patch_release_manifest(
        ...   namespace='default',
        ...   release=SelfTestAction.example_release,
        ...   resource_kind='Secret',
        ...   dry_run=True,
        ...   quiet=True
        ... )
        True

        Next, we actually remove matching resources from the release.

        >>> patch_release_manifest(
        ...   namespace='default',
        ...   release=SelfTestAction.example_release,
        ...   resource_kind='Secret',
        ...   quiet=True
        ... )
        True
        >>> patch_release_manifest(
        ...   namespace='default',
        ...   release=SelfTestAction.example_release,
        ...   resource_kind='Secret'
        ... )
        False

        Note that specifying a non-matching resource kind is not an error.

        >>> patch_release_manifest(
        ...   namespace='default',
        ...   release=SelfTestAction.example_release,
        ...   resource_kind='DoesNotExist'
        ... )
        False

        After removing the matching "Secret" resources from the release,
        we can now uninstall the Helm chart while the "Secret" resource
        will remain in the cluster.

        >>> run(['helm', 'uninstall', SelfTestAction.example_release],
        ...      capture_output=True).returncode
        0
        >>> run(['kubectl', 'get', 'secret', SelfTestAction.example_secret],
        ...      capture_output=True).returncode
        0
    """
    if not revision:
        revision = get_current_release_revision(namespace, release)

    release_secret = f'sh.helm.release.v1.{release}.v{revision}'

    release_data = check_output([
        'kubectl', 'get', 'secret', '-n', namespace, release_secret, '-o',
        'jsonpath={.data.release}'])

    release_data = base64.b64decode(release_data)
    release_data = base64.b64decode(release_data)
    release_data = gzip.decompress(release_data)
    release_data = json.loads(release_data)

    release_manifest = release_data['manifest']

    new_release_manifest_lines = []
    document_lines = []
    for line in release_manifest.split('\n'):
        if line == '---':
            if document_lines:
                new_release_manifest_lines += document_lines
            document_lines = [line]
        elif document_lines and \
                re.match(f'^\\s*kind:\\s*{resource_kind}\\s*$', line):
            # Discard the current document
            document_lines = []
        elif document_lines:
            document_lines.append(line)
    new_release_manifest_lines += document_lines
    new_release_manifest = '\n'.join(new_release_manifest_lines)

    new_release_data = copy.deepcopy(release_data)
    new_release_data['manifest'] = new_release_manifest

    if new_release_data == release_data:
        return False

    new_release_data = json.dumps(new_release_data)
    new_release_data = new_release_data.encode('utf-8')
    new_release_data = gzip.compress(new_release_data)
    new_release_data = base64.b64encode(new_release_data)
    new_release_data = base64.b64encode(new_release_data)

    with NamedTemporaryFile() as patch_file:
        patch = f'{{"data":{{"release":"{new_release_data.decode("utf-8")}"}}}}'
        patch = patch.encode('utf-8')
        patch_file.write(patch)
        patch_file.flush()

        if dry_run:
            dry_run = 'server'
        else:
            dry_run = 'none'

        run(['kubectl', 'patch', 'secret', '-n', namespace, release_secret,
             f'--patch-file={patch_file.name}', f'--dry-run={dry_run}'],
            capture_output=quiet, check=True)
        return True


def get_current_release_revision(namespace, release):
    """Return the current revision of the specified Helm release.

    >>> get_current_release_revision('default', SelfTestAction.example_release)
    1
    """
    output = check_output([
        'helm', 'status', '-n', namespace, release, '-o', 'json'])
    status = json.loads(output)
    return status['version']


class SelfTestAction(Action):
    unique_id = str(uuid.uuid4()).split('-')[0]
    example_release = f'example-{unique_id}'
    example_repo_name = f'{example_release}-bitnami'
    example_repo_url = 'https://charts.bitnami.com/bitnami'
    example_chart = 'mariadb'
    example_secret = f'{example_release}-{example_chart}'
    example_pvc = f'data-{example_release}-0'

    def __init__(self,
                 option_strings,
                 dest=SUPPRESS,
                 default=SUPPRESS,
                 help=None):
        super(SelfTestAction, self).__init__(
            option_strings=option_strings,
            dest=dest,
            default=default,
            nargs=0,
            help=help)

    def __call__(self, parser, namespace, values, option_string=None):
        import doctest

        failed = 1

        try:
            check_output(['helm', 'repo', 'add', self.example_repo_name,
                          self.example_repo_url])
            check_output(['helm', 'install', self.example_release,
                          f'{self.example_repo_name}/{self.example_chart}'])

            failed, _ = doctest.testmod(optionflags=doctest.FAIL_FAST)
        finally:
            run(['kubectl', 'delete', 'secret', self.example_secret],
                capture_output=True)
            run(['kubectl', 'delete', 'pvc', self.example_pvc],
                capture_output=True)
            run(['helm', 'uninstall', self.example_release],
                capture_output=True)
            run(['helm', 'repo', 'remove', self.example_repo_name],
                capture_output=True)

            parser.exit(failed)


parser = ArgumentParser(
    description='Remove resources from Helm release revision manifests.')
parser.add_argument('release', metavar='RELEASE',
                    help='release name to patch')
parser.add_argument('revision', metavar='REVISION', type=int, nargs='?',
                    help='release revision to patch (default: current)')
parser.add_argument('-n', '--namespace', metavar='string', dest='namespace',
                    default='default',
                    help='release namespace scope (default: "default")')
parser.add_argument('-k', '--resource-kind', metavar='string',
                    dest='resource_kind', default='CustomResourceDefinition',
                    help='resource kind to remove from release (default: "CustomResourceDefinition")')
parser.add_argument('--dry-run', action='store_true',
                    help='skip actual "kubectl patch" command')
parser.add_argument('--self-test', action=SelfTestAction,
                    help='run embedded test suite and exit')

args = parser.parse_args()

# Shows output of "kubectl" command if the release changed; otherwise, nothing.
patch_release_manifest(
    namespace=args.namespace,
    release=args.release,
    revision=args.revision,
    resource_kind=args.resource_kind,
    dry_run=args.dry_run)
