{
  default: {},

  staging: {},

  lts: {
    domains: {
      local ips = {
        inwxDefault: '185.181.104.242',
        hetznerStackv4: '176.9.37.138',
        hetznerStackv6: '2a01:4f8:161:3442::1',
        hetznerQueen1v4: '65.108.70.29',
        hetznerQueen1v6: '2a01:4f9:6b:4629::2',
        hetznerDrone1v4: '46.4.71.17',
        hetznerDrone1v6: '2a01:4f8:140:31da::2',
        hetznerMXv4: '65.108.70.42',
        hetznerMXv6: '2a01:4f9:6b:4629::42',
      },
      local dkimKeys = {
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
        { rtype: 'A', content: ips.hetznerQueen1v4 },
        { rtype: 'AAAA', content: ips.hetznerQueen1v6 },
        { rtype: 'MX', prio: 10, content: 'mx.bln.space' },
        { rtype: 'TXT', content: 'v=spf1 mx -all' },
        { name: '_dmarc', rtype: 'TXT', content: 'v=DMARC1; p=reject; fo=1; rua=mailto:dmarc@bln.space; ruf=mailto:dmarc@bln.space; adkim=s; aspf=s;' },
        { rtype: 'CAA', content: '0 issue "letsencrypt.org"' },
        { rtype: 'CAA', content: '0 issuewild ";"' },
        { rtype: 'CAA', content: '0 iodef "mailto:letsencrypt@bln.space"' },
        // deprecated - entries from stack.n-os.org
        { rtype: 'A', content: ips.hetznerStackv4, state: 'absent' },
        { rtype: 'AAAA', content: ips.hetznerStackv6, state: 'absent' },
        { rtype: 'MX', prio: 10, content: 'mail.schumann.link', state: 'absent' },
        { rtype: 'CAA', content: '0 iodef "mailto:letsencrypt@n-os.org"', state: 'absent' },
      ],
      'bln.space': [
        { name: '*', rtype: 'A', content: ips.hetznerDrone1v4 },
        { name: '*', rtype: 'AAAA', content: ips.hetznerDrone1v6 },
        //   { name: 'survey' },
        //   { name: 'txl' },
        //   { name: 'jenkins' },
        //   { name: 'wiki' },
        //   { name: 'dmarc' },
        { rtype: 'TXT', content: 'google-site-verification=y9wrEwtXYONHU-nfyth5bOXSK4GyIO34v5XhLImUVkI' },
        { name: '%s._domainkey' % [dkimSelectors['bln.space']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      ] + defaultRecords,
      'n-os.org': [
        { name: 'stack', rtype: 'A', content: ips.hetznerStackv4 },
        { name: 'stack', rtype: 'AAAA', content: ips.hetznerStackv6 },
        { name: 'registry', rtype: 'A', content: '192.168.2.1' }
        { name: 'grafana' }
        { name: '%s._domainkey' % [dkimSelectors['n-os.org']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      ] + defaultRecords,
      'remembrance.de': [
        { name: '%s._domainkey' % [dkimSelectors['remembrance.de']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      ] + defaultRecords,
      'schumann.link': [
        { name: 'mail', rtype: 'A', content: '176.9.37.138' },
        { name: 'mail', rtype: 'AAAA', content: '2a01:4f8:161:3442::1' },
        { rtype: 'TXT', content: 'google-site-verification=-choszrnJbbcG2sVcfIN4994p30u-jTRdN3iBl_dfj4' },
        { name: '%s._domainkey' % [dkimSelectors['schumann.link']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      ] + defaultRecords,
      'kubectl.me': [
        { name: '*', rtype: 'A', content: ips.hetznerQueen1v4 },
        { name: '*', rtype: 'AAAA', content: ips.hetznerQueen1v6 },
        { name: 'queen1.borg', rtype: 'A', content: ips.hetznerQueen1v4 },
        { name: 'queen1.borg', rtype: 'AAAA', content: ips.hetznerQueen1v6 },
        { name: 'drone1.borg', rtype: 'A', content: ips.hetznerDrone1v4 },
        { name: 'drone1.borg', rtype: 'AAAA', content: ips.hetznerDrone1v6 },
        { name: '%s._domainkey' % [dkimSelectors['kubectl.me']], rtype: 'TXT', content: dkimKeys.rsa2022 },
        { name: 'svc', rtype: 'NS', content: ['ns-cloud-c%d.googledomains.com' % id for id in [1, 2, 3, 4]] },
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
        { name: 'project' },
        { name: '%s._domainkey' % [dkimSelectors['stairbud.com']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      ] + defaultRecords,
      'stairbud.de': [
        { name: '%s._domainkey' % [dkimSelectors['stairbud.de']], rtype: 'TXT', content: dkimKeys.rsa2022 },
      ] + defaultRecords,
    },
  },
}
