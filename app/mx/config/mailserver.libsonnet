{
  default: {
    imageRegistry: 'registry.lan:5000',
    storageClass: 'fast',
    ldapRoot: 'o=auth,dc=local',
  },

  staging: {
    ldapInitMailDomains: ['stg.kubectl.me'],
  },

  lts: {
    mailStorageSize: '150Gi',
    stateStorageSize: '5Gi',
    ldapEnable: true,
    publicFQDN: 'mx.bln.space',
    extraAnnotations: {
      'bln.space/podnat': std.manifestJsonMinified({
        entries: [
          // specially reserved for mx at robot.your-server.de
          { ifaceAuto: false, srcIP: '65.108.70.42', srcPort: 25, dstPort: 25 },
          { ifaceAuto: false, srcIP: '65.108.70.42', srcPort: 143, dstPort: 143 },
          { ifaceAuto: false, srcIP: '65.108.70.42', srcPort: 587, dstPort: 587 },
        ],
      }),
    },
  },
}
