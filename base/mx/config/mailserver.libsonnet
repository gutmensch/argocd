{
  default: {
    imageRegistry: 'registry.lan:5000',
    storageClass: 'zfs-fast-xfs',
  },

  staging: {
  },

  lts: {
    mailStorageSize: '150Gi',
    stateStorageSize: '5Gi',
    accountProvisioner: 'LDAP',
    publicFQDN: 'mx.bln.space',
    publicHostnames: ['imap.bln.space', 'smtp.bln.space'],
    trustedPublicNetworks: ['65.108.70.42/32', '65.108.70.29/32', '46.4.71.17/32', '[2a01:4f9:6b:4629::]/64', '[2a01:4f8:140:31da::]/64'],
    reportEnable: true,
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
