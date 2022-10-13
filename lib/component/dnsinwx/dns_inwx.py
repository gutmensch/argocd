#!/usr/bin/python

# classes for domrobot and prettyprint are taken from
# inwx.com XML-RPC Python 2.7 Client (MIT license)
# unfortunately no author to mention here could be found
# wrapper for ansible module by <robert@schumann.link>

# CAUTION: currently this module only handles simple creation and deletion
#          of A, AAAA and PTR records

ANSIBLE_METADATA = {
    'metadata_version': '1.1',
    'status': ['preview'],
    'supported_by': 'community'
}

DOCUMENTATION = '''
---
module: dns_inwx

short_description: inwx (InterNetWorX) DNS API module

version_added: "2.2"

description:
    - "This module allows creating, changing and deleting of DNS records against the inwx domain API."

options:
    api_url:
        description:
            - This is the endpoint for the inwx API as defined here https://www.inwx.de/de/help/apidoc
        required: false
    username:
        description:
            - INWX username
        required: true
    password:
        description:
            - INWX password
        required: true
    shared_secret:
        description:
            - INWX shared secret for OTP function
        required: false
    domain:
        description:
            - root domain for this request, e.g. "example.com"
        required: true
    name:
        description:
            - DNS entry name (e.g. "test", if desired record is "test.example.com")
        required: false
    rtype:
        description:
            - The DNS record type, one of: A, AAAA, CNAME, MX, TXT or PTR
        required: true
    content:
        description:
            - Result for name lookup (e.g. IPv4 or IPv6)
        required: true
    ttl:
        description:
            - TTL for DNS record, default 3600
        required: false
    prio:
        description:
            - Record priority, default 0
        required: false


author:
    - Robert Schumann <rs@n-os.org>
'''

EXAMPLES = '''
# Create a simple DNS record
- name: Create A record for my IP
  dns_inwx:
    username: inwx_user
    password: inwx_password
    domain: example.com
    name: test
    rtype: A
    content: 1.2.3.4
'''

RETURN = '''
state:
    description: state of the dns entry
    returned: success
    type: string
    sample: present
name:
    description: name of the dns entry
    returned: success
    type: string
    sample: test
domain:
    description: domain belonging to the new name record
    returned: success
    type: str
    sample: example.com
rtype:
    description: dns record type
    returned: success
    type: str
    sample: A
content:
    description: content of the dns record
    returned: success
    type: str
    sample: 1.2.3.4
ttl:
    description: dns record type
    returned: success
    type: str
    sample: A
prio:
    description: content of the dns record
    returned: success
    type: str
    sample: 1.2.3.4
api_url:
    description: api url for the inwx domain robot
    returned: success
    type: str
    sample: https://api.domrobot.com/xmlrpc/
username:
    description: your inwx username
    returned: success
    type: str
    sample: user123
password:
    description: your inwx password
    returned: success
    type: string
    sample: pass123
shared_secret:
    description: the shared secret used by the inwx code
    returned: success
    type: string
    sample: ItsAllTheSame
'''


import sys
import fcntl

if sys.version_info.major == 3:
    import xmlrpc.client
    from xmlrpc.client import _Method
    import urllib.request, urllib.error, urllib.parse
else:
    import xmlrpclib
    from xmlrpclib import _Method
    import urllib2

import base64
import struct
import time
import hmac
import hashlib
from ansible.module_utils.basic import *

def getOTP(shared_secret):
    key = base64.b32decode(shared_secret, True)
    msg = struct.pack(">Q", int(time.time())//30)
    h = hmac.new(key, msg, hashlib.sha1).digest()
    if sys.version_info.major == 3:
        o = h[19] & 15
    else:
        o = ord(h[19]) & 15
    h = (struct.unpack(">I", h[o:o+4])[0] & 0x7fffffff) % 1000000
    return h

class domrobot ():
    def __init__ (self, address, debug = False):
        self.url = address
        self.debug = debug
        self.cookie = None
        self.version = "1.0"

    def __getattr__(self, name):
        return _Method(self.__request, name)

    def __request (self, methodname, params):
        tuple_params = tuple([params[0]])
        if sys.version_info.major == 3:
            requestContent = xmlrpc.client.dumps(tuple_params, methodname)
        else:
            requestContent = xmlrpclib.dumps(tuple_params, methodname)
        if(self.debug == True):
            print(("Request: "+str(requestContent).replace("\n", "")))
        headers = { 'User-Agent' : 'DomRobot/'+self.version+' Ansible/Python-v3.10', 'Content-Type': 'text/xml','content-length': str(len(requestContent))}
        if(self.cookie!=None):
            headers['Cookie'] = self.cookie

        if sys.version_info.major == 3:
            req = urllib.request.Request(self.url, bytearray(requestContent, 'ascii'), headers)
            response = urllib.request.urlopen(req)
        else:
            req = urllib2.Request(self.url, bytearray(requestContent, 'ascii'), headers)
            response = urllib2.urlopen(req)

        responseContent = response.read()

        if sys.version_info.major == 3:
            cookies = response.getheader('Set-Cookie')
        else:
            cookies = response.info().getheader('Set-Cookie')

        if(self.debug == True):
            print(("Answer: "+str(responseContent).replace("\n", "")))
        if sys.version_info.major == 3:
            apiReturn = xmlrpc.client.loads(responseContent)
        else:
            apiReturn = xmlrpclib.loads(responseContent)
        apiReturn = apiReturn[0][0]
        if(apiReturn["code"]!=1000):
            raise NameError('There was a problem: %s (Error code %s)' % (apiReturn['msg'], apiReturn['code']), apiReturn)
            return False

        if(cookies!=None):
                if sys.version_info.major == 3:
                    cookies = response.getheader('Set-Cookie')
                else:
                    cookies = response.info().getheader('Set-Cookie')
                self.cookie = cookies
                if(self.debug == True):
                    print(("Cookie:" + self.cookie))
        return apiReturn


def acquire_lock(wait_for_seconds=10):
    lock_file = '/tmp/.dns_inwx.lock'
    i = 0
    f = open(lock_file, 'w+')
    while i < wait_for_seconds:
        try:
            fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return True
        except IOError:
            i += 1
            time.sleep(1)


def valid(data):
    return (data is not None and len(data) > 0)


def delete_record(**kwargs):
    qdict = { 'domain': kwargs.get("domain"), 'type': kwargs.get("rtype") }
    if valid(kwargs.get("name")):
        qdict['name'] = kwargs.get("name")
    if valid(kwargs.get("content")):
        qdict['content'] = kwargs.get("content")

    # we need either of both
    if 'name' not in qdict and 'content' not in qdict:
        return None

    query_result = kwargs.get("conn").nameserver.info(qdict)

    if 'record' in query_result['resData']:
        for r in query_result['resData']['record']:
            delete_result = kwargs.get("conn").nameserver.deleteRecord({'id': r['id']})
        if delete_result['msg'] == 'Command completed successfully':
            return True


def create_record(**kwargs):
    qdict = { 'domain': kwargs.get("domain"), 'type': kwargs.get("rtype"), 'content': kwargs.get("content") }
    if valid(kwargs.get("name")):
        qdict['name'] = kwargs.get("name")
    if valid(kwargs.get("ttl")):
        qdict['ttl'] = kwargs.get("ttl")
    if valid(kwargs.get("prio")):
        qdict['prio'] = kwargs.get("prio")

    # we are mimicking some silent update feature here
    # *if* the to-be-created record already exists, but with other values (content, ttl, prio) we
    # will delete it first and then create the new one. however, for records without name (e.g. TXT) that's not
    # possible and we have to rely on the user to properly remove and add records.
    if 'name' in qdict:
        check_qdict = { 'domain': qdict['domain'], 'type': qdict['type'], 'name': qdict['name'] }
        query_result = kwargs.get("conn").nameserver.info(check_qdict)
        if 'record' in query_result['resData']:
            for r in query_result['resData']['record']:
                delete_record(conn=kwargs.get("conn"), domain=qdict['domain'], name=qdict['name'], rtype=qdict['type'])

    create_result = kwargs.get("conn").nameserver.createRecord(qdict)

    if create_result['msg'] == 'Command completed successfully':
        return True


def verify_record(**kwargs):
    qdict = { 'domain': kwargs.get("domain"), 'type': kwargs.get("rtype"), 'content': kwargs.get("content") }
    if valid(kwargs.get("name")):
        qdict['name'] = kwargs.get("name")
    if valid(kwargs.get("ttl")):
        qdict['ttl'] = kwargs.get("ttl")
    if valid(kwargs.get("prio")):
        qdict['prio'] = kwargs.get("prio")

    query_result = kwargs.get("conn").nameserver.info(qdict)

    if 'record' in query_result['resData']:
        return True


def main():

    module_args = {
        "api_url": {"default": "https://api.domrobot.com/xmlrpc/", "type": "str"},
        "username": {"required": True, "type": "str", "no_log": True },
        "password": {"required": True, "type": "str", "no_log": True },
        "shared_secret": {"default": "ItsAllTheSame", "type": "str", "no_log": True },
        "domain": {"required": True, "type": "str" },
        "name": {"default": None, "type": "str" },
        "rtype": {"required": True, "type": "str" },
        "content": {"required": True, "type": "str" },
        "ttl": {"default": "3600", "type": "str" },
        "prio": {"default": "0", "type": "str" },
        "state": {
            "default": "present", 
            "choices": ['present', 'absent'],  
            "type": 'str' 
        }
    }

    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True
    )

    result = {
        "changed": False,
        "original_message": '',
        "message": ''
    }

    # inwx service parameters
    api_url = module.params['api_url']
    username = module.params['username']
    password = module.params['password']
    shared_secret = module.params['shared_secret']

    # mandatory parameters
    check_mode = module.check_mode
    state = module.params['state']
    domain = module.params['domain']
    rtype = module.params['rtype']
    content = module.params['content']

    # optional parameters
    name = module.params['name']
    ttl = module.params['ttl']
    prio = module.params['prio']

    # TODO: the domrobot supports attribute "testing"
    if check_mode:
        return result

    if acquire_lock() is None:
        module.fail_json(msg='Could not acquire lock, maybe another instance of this module is already running', **result)

    inwx = domrobot(api_url, False)
    login_ret = inwx.account.login({'lang': 'en', 'user': username, 'pass': password})
    if 'tfa' in login_ret and login_ret['tfa'] == 'GOOGLE-AUTH':
        login_ret = inwx.account.unlock({'tan': getOTP(shared_secret)})

    if verify_record(conn=inwx, domain=domain, name=name, rtype=rtype, content=content, ttl=ttl, prio=prio) is None:
        if state == 'present':
            if create_record(conn=inwx, domain=domain, name=name, rtype=rtype, content=content, ttl=ttl, prio=prio):
                result['changed'] = True
            else:
                module.fail_json(msg='Could not create DNS record %s.%s' % (name, domain), **result)

    else:
        if state == 'absent':
            if delete_record(conn=inwx, domain=domain, name=name, rtype=rtype, content=content):
                result['changed'] = True
            else:
                module.fail_json(msg='Could not delete DNS record %s.%s' % (name, domain), **result)

    module.exit_json(**result)


if __name__ == '__main__':  
    main()

