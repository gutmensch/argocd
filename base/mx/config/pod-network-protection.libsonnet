{
  common: {},
  staging: {},
  lts: {
    portsInternal: [25, 143, 587, 4190],
    portsExternal: [25, 143, 587],
    // XXX: some debian mirrors still on port 80
    outboundPorts: [25, 80, 110, 143, 443, 993, 995, 9000],
    outboundNetworks: ['0.0.0.0/0'],
    filterRegexes: {
      dovecotLoginBruteForce: '^.*dovecot: auth: ldap\\(.*,([0-9\\.]+)\\): unknown user \\(SHA1 of given password: [a-f0-9]{6}\\)$',
    },
  },
}
