{
  common: {},
  staging: {},
  lts: {
    portsInternal: [25, 143, 587, 4190],
    portsExternal: [25, 143, 587],
    outboundPorts: [25, 110, 143, 443, 993, 995],
    outboundNetworks: ['0.0.0.0/0'],
    filterRegexes: {
      dovecotLoginBruteForce: '^.*dovecot: auth: ldap\\(.*,([0-9\\.]+)\\): unknown user \\(SHA1 of given password: [a-f0-9]{6}\\)$',
    },
  },
}
