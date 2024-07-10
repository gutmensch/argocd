{
  default: {},

  staging: {},

  lts: {
    domains: {
      local this = self,
      ips:: {
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
      dkimKeys:: {
        rsa2022: 'v=DKIM1; k=rsa; t=s; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvjemEA4vQ70RA2e7ENPDSM40NOGvUFUwAYtxJvVEWbImHGb7CaByR7TNmBV2mYNvke9/V7VOLYKbBcnZyP6N9GeSJW0zEO/XC4vWvz3Dk6rAJkMK10IqbW8wwlq7g794KIX6TJOmRfZvf9v0MfktOLcm1XKmtd/+TW2dc1+YhgoGU3OSpjiiSOPUWx04KzVm0+O9py+iozVtYBXwKjGHzfWm2TZo4qdQAq0+xh87cuBfVL02nIrOiodigP9uJ1AVVAZlxjprt2014p34M3mR5CAbosD3Mt5m6BycfiE9FdYJ9ayrkT4N6MrzaW4lH/wQwdo7Dl/WbHiOWJVPiI6wJwIDAQAB',
      },
      // XXX: OpenDKIM filters on selector name only and not domain, so we need
      // unique selectors per domain for LDAP integration to work :-/
      dkimSelectors:: {
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
      defaultRecords:: [
        { rtype: 'A', content: this.ips.hetznerQueen1v4 },
        { rtype: 'AAAA', content: this.ips.hetznerQueen1v6 },
        { rtype: 'MX', prio: 10, content: 'mx.bln.space' },
        { rtype: 'TXT', content: 'v=spf1 mx -all' },
        { name: '_dmarc', rtype: 'TXT', content: 'v=DMARC1; p=reject; fo=1; rua=mailto:dmarc@bln.space; ruf=mailto:dmarc@bln.space; adkim=s; aspf=s;' },
        { rtype: 'CAA', content: '0 issue "letsencrypt.org"' },
        { rtype: 'CAA', content: '0 issuewild ";"' },
        { rtype: 'CAA', content: '0 iodef "mailto:letsencrypt@bln.space"' },
        { name: 'mta-sts', rtype: 'A', content: this.ips.hetznerDrone1v4 },
        // XXX: id is generated automatically from policy content in init.jsonnet
        // { name: '_mta-sts', rtype: 'TXT', content: 'v=STSv1; id=20240710T000000;' },
        { name: '_smtp._tls', rtype: 'TXT', content: 'v=TLSRPTv1; rua=mailto:tlsrpt@bln.space;' },
      ],
      'bln.space': [
        { name: '*', rtype: 'A', content: this.ips.hetznerDrone1v4 },
        { name: '*', rtype: 'AAAA', content: this.ips.hetznerDrone1v6 },
        //   { name: 'survey' },
        //   { name: 'txl' },
        //   { name: 'jenkins' },
        //   { name: 'wiki' },
        //   { name: 'dmarc' },
        { rtype: 'TXT', content: 'google-site-verification=y9wrEwtXYONHU-nfyth5bOXSK4GyIO34v5XhLImUVkI' },
        { name: '%s._domainkey' % [this.dkimSelectors['bln.space']], rtype: 'TXT', content: this.dkimKeys.rsa2022 },
      ] + this.defaultRecords,
      'n-os.org': [
        { name: 'stack', rtype: 'A', content: this.ips.hetznerStackv4, status: 'absent' },
        { name: 'stack', rtype: 'AAAA', content: this.ips.hetznerStackv6, status: 'absent' },
        { name: 'registry', rtype: 'A', content: '192.168.2.1', status: 'absent' }
        { name: 'grafana', status: 'absent' }
        { name: '%s._domainkey' % [this.dkimSelectors['n-os.org']], rtype: 'TXT', content: this.dkimKeys.rsa2022 },
      ] + this.defaultRecords,
      'remembrance.de': [
        { name: '%s._domainkey' % [this.dkimSelectors['remembrance.de']], rtype: 'TXT', content: this.dkimKeys.rsa2022 },
      ] + this.defaultRecords,
      'schumann.link': [
        { name: 'mail', rtype: 'A', content: '176.9.37.138', status: 'absent' },
        { name: 'mail', rtype: 'AAAA', content: '2a01:4f8:161:3442::1', status: 'absent' },
        { rtype: 'TXT', content: 'google-site-verification=-choszrnJbbcG2sVcfIN4994p30u-jTRdN3iBl_dfj4' },
        { name: '%s._domainkey' % [this.dkimSelectors['schumann.link']], rtype: 'TXT', content: this.dkimKeys.rsa2022 },
      ] + this.defaultRecords,
      'kubectl.me': [
        { name: '*', rtype: 'A', content: this.ips.hetznerQueen1v4 },
        { name: '*', rtype: 'AAAA', content: this.ips.hetznerQueen1v6 },
        { name: 'queen1.borg', rtype: 'A', content: this.ips.hetznerQueen1v4 },
        { name: 'queen1.borg', rtype: 'AAAA', content: this.ips.hetznerQueen1v6 },
        { name: 'drone1.borg', rtype: 'A', content: this.ips.hetznerDrone1v4 },
        { name: 'drone1.borg', rtype: 'AAAA', content: this.ips.hetznerDrone1v6 },
        { name: '%s._domainkey' % [this.dkimSelectors['kubectl.me']], rtype: 'TXT', content: this.dkimKeys.rsa2022 },
      ] + [
        // delegation for service domain to google
        { name: 'svc', rtype: 'NS', content: 'ns-cloud-%s.googledomains.com' % [shard] }
        for shard in ['c1', 'c2', 'c3', 'c4']
      ] + this.defaultRecords,
      'robattix.com': [
        { name: '%s._domainkey' % [this.dkimSelectors['robattix.com']], rtype: 'TXT', content: this.dkimKeys.rsa2022 },
      ] + this.defaultRecords,
      'robattix.de': [
        { name: '%s._domainkey' % [this.dkimSelectors['robattix.de']], rtype: 'TXT', content: this.dkimKeys.rsa2022 },
      ] + this.defaultRecords,
      'robattix.gmbh': [
        { name: '%s._domainkey' % [this.dkimSelectors['robattix.gmbh']], rtype: 'TXT', content: this.dkimKeys.rsa2022 },
      ] + this.defaultRecords,
      'stairbud.com': [
        { name: 'project' },
        { name: '%s._domainkey' % [this.dkimSelectors['stairbud.com']], rtype: 'TXT', content: this.dkimKeys.rsa2022 },
      ] + this.defaultRecords,
      'stairbud.de': [
        { name: '%s._domainkey' % [this.dkimSelectors['stairbud.de']], rtype: 'TXT', content: this.dkimKeys.rsa2022 },
      ] + this.defaultRecords,
    },
  },
}
