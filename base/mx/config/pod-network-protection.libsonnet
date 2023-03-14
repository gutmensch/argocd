{
  common: {
    imageRegistry: 'registry.lan:5000',
  },
  staging: {},
  lts: {
    portsInternal: [25, 143, 587, 4190],
    portsExternal: [25, 143, 587],
    outboundPorts: [25, 110, 143, 443, 993, 995],
    outboundNetworks: ['0.0.0.0/0'],
    filterRegexes: {
      dovecotLoginBruteForce: '.*dovecot:\\s*auth:\\s*ldap\\(.*,([0-9\\.]+)\\):\\s*unknown user \\(SHA1 of given password:.*',
    },
  },
}
