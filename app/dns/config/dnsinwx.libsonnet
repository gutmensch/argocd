{
  default: {
    imageRegistry: 'registry.lan:5000',
  },

  staging: {
  },

  lts: {
    domains: {
      local dkimKeys = {
        'bln.space': 'v=DKIM1; k=rsa; t=s; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC4YO+qEk/W9pyh9TwNfLzewPkuR9kkLgpCvrr/xdMnyuAF9vFKJ4wgtGJ8HCr3VVVX509BqmtWdPGSCkDA04wGuVNFKGXrfweEmG3XGIEKtuO+TYmvgD+yXwwiI+P9lNXm5/ZaYYhwPYK4T4RjCzuR6gyVBIxPOOz1VzI0N483gwIDAQAB',
        'n-os.org': 'v=DKIM1; k=rsa; t=s; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCs/pR5d9u+w/pGRCVPI/+7UtLY7ebBLWuQEBR01renwZWQGkbncfnbwzawXr0Wk4JRhATusbHW/6HblfsIj8OTTLo/XZ8Ux/bV0oOvjmroBsLwvJtuuix6H62x9IoTN6QS0X4BVGyHLqDsFUteOVzvLli6dcpNS1U662Rih+jhGQIDAQAB',
        'remembrance.de': 'v=DKIM1; k=rsa; t=s; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDoIAapvRBTXqrzxZDXJp7GrmCl+v2sepSuLHzstH++g4VzKq5LYYFFmRie8G3ww/UTkvji7mQD+bsQFaqdHjyX13TzEB/PhIwgjOCFkm68CLJZuXaX0li3XnWTdkVLdyaRz1vSoQPjCEgGIxSy+evDk+3hzvmRRn+SaPQbzKR9SQIDAQAB',
        'schumann.link': 'v=DKIM1; k=rsa; t=s; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDDzjUlYJUjanlp8azoHaXLmppSsjTdZqlRwld/zVMA2b48Drc0EwpygFaVSBCjuxl6srQ5RZInMWSQstRUcyCNEaxUh9c/Ta7sBYHjxd2yqeovnqkmtoXgo6pTJpJtWCdjXX7rfPHVZg1UjHr2e3xgSqQdqzL6SAfBhXSaGen+4QIDAQAB',
        rsa2022: 'v=DKIM1; k=rsa; t=s; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvjemEA4vQ70RA2e7ENPDSM40NOGvUFUwAYtxJvVEWbImHGb7CaByR7TNmBV2mYNvke9/V7VOLYKbBcnZyP6N9GeSJW0zEO/XC4vWvz3Dk6rAJkMK10IqbW8wwlq7g794KIX6TJOmRfZvf9v0MfktOLcm1XKmtd/+TW2dc1+YhgoGU3OSpjiiSOPUWx04KzVm0+O9py+iozVtYBXwKjGHzfWm2TZo4qdQAq0+xh87cuBfVL02nIrOiodigP9uJ1AVVAZlxjprt2014p34M3mR5CAbosD3Mt5m6BycfiE9FdYJ9ayrkT4N6MrzaW4lH/wQwdo7Dl/WbHiOWJVPiI6wJwIDAQAB',
      },
      // XXX: OpenDKIM filters on selector name only and not domain, so we need
      // unique selectors per domain for LDAP integration to work :-/
      local dkimSelectors = {
        'bln.space': 'rsa2022a',
        'kubectl.me': 'rsa2022b',
        'n-os.org': 'rsa2022c',
        'remembrance.de': 'rsa2022d',
        'robattix.com': 'rsa2022e',
        'robattix.de': 'rsa2022f',
        'robattix.gmbh': 'rsa2022g',
        'schumann.link': 'rsa2022h',
        'stairbud.com': 'rsa2022i',
        'stairbud.de': 'rsa2022j',
      },
      local defaultRecords = [
        { rtype: 'A', content: '176.9.37.138' },
        { rtype: 'AAAA', content: '2a01:4f8:161:3442::1' },
        { rtype: 'MX', prio: 10, content: 'mx.bln.space' },
        { rtype: 'TXT', content: 'v=spf1 mx -all' },
        { name: '_dmarc', rtype: 'TXT', content: 'v=DMARC1; p=quarantine; fo=1; rua=mailto:dmarc@bln.space; ruf=mailto:dmarc@bln.space; adkim=s; aspf=s;' },
        { rtype: 'CAA', content: '0 issue "letsencrypt.org"' },
        { rtype: 'CAA', content: '0 issuewild ";"' },
        { rtype: 'CAA', content: '0 iodef "mailto:letsencrypt@bln.space"' },
      ],
      // 'bln.space': [
      //   { name: 'survey' },
      //   { name: 'txl' },
      //   { name: 'jenkins' },
      //   { name: 'wiki' },
      //   { name: 'dmarc' },
      //   { name: 'mx', rtype: 'A', content: '65.108.70.42' },
      //   { name: 'mx', rtype: 'AAAA', content: '2a01:4f9:6b:4629::42' },
      //   { rtype: 'TXT', content: 'google-site-verification=y9wrEwtXYONHU-nfyth5bOXSK4GyIO34v5XhLImUVkI' },
      //   //{ name: 'mail._domainkey', rtype: 'TXT', content: dkimKeys['bln.space'] },
      //   { name: '%s._domainkey' % [dkimSelectors['bln.space']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      // ] + defaultRecords,
      // 'n-os.org': [
      //   { name: 'stack', rtype: 'A', content: '176.9.37.138' },
      //   { name: 'stack', rtype: 'AAAA', content: '2a01:4f8:161:3442::1' },
      //   { name: 'registry', rtype: 'A', content: '192.168.2.1' }
      //   { name: 'grafana' }
      //   //{ name: 'mail._domainkey', rtype: 'TXT', content: dkimKeys['n-os.org'] },
      //   { name: '%s._domainkey' % [dkimSelectors['n-os.org']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      // ] + defaultRecords,
      // 'remembrance.de': [
      //   //{ name: 'mail._domainkey', rtype: 'TXT', content: dkimKeys['remembrance.de'] },
      //   { name: '%s._domainkey' % [dkimSelectors['remembrance.de']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      // ] + defaultRecords,
      // 'schumann.link': [
      //   { name: 'mail', rtype: 'A', content: '176.9.37.138' },
      //   { name: 'mail', rtype: 'AAAA', content: '2a01:4f8:161:3442::1' },
      //   { rtype: 'TXT', content: 'google-site-verification=-choszrnJbbcG2sVcfIN4994p30u-jTRdN3iBl_dfj4' },
      //   //{ name: 'mail._domainkey', rtype: 'TXT', content: dkimKeys['schumann.link'] },
      //   { name: '%s._domainkey' % [dkimSelectors['schumann.link']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      // ] + defaultRecords,
      'kubectl.me': [
        { name: '*', rtype: 'A', content: '65.108.70.29' },
        { name: '*', rtype: 'AAAA', content: '2a01:4f9:6b:4629::2' },
        { name: 'queen1.borg', rtype: 'A', content: '65.108.70.29' },
        { name: 'queen1.borg', rtype: 'AAAA', content: '2a01:4f9:6b:4629::2' },
        { name: 'drone1.borg', rtype: 'A', content: '46.4.71.17' },
        { name: 'drone1.borg', rtype: 'AAAA', content: '2a01:4f8:140:31da::2' },
        { name: '%s._domainkey' % [dkimSelectors['kubectl.me']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      ] + defaultRecords,
      'robattix.com': [
        { name: '%s._domainkey' % [dkimSelectors['robattix.com']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      ] + defaultRecords,
      'robattix.de': [
        { name: '%s._domainkey' % [dkimSelectors['robattix.de']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      ] + defaultRecords,
      'robattix.gmbh': [
        { name: '%s._domainkey' % [dkimSelectors['robattix.gmbh']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      ] + defaultRecords,
      'stairbud.com': [
        { name: 'testname', state: 'absent' },
        { name: 'project' },
        { name: '%s._domainkey' % [dkimSelectors['stairbud.com']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      ] + defaultRecords,
      'stairbud.de': [
        { name: '%s._domainkey' % [dkimSelectors['stairbud.de']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      ] + defaultRecords,
    },
  },
}
