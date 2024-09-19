{
  default: {
    storageClass: 'zfs-fast-xfs',
    // 432000 seconds = 5 days
    cronjobTargetContainerCommand: 'openssl s_client -starttls smtp -connect localhost:25 -servername mx.bln.space -showcerts < /dev/null 2>/dev/null | openssl x509 -noout -checkend 43200000 || { dovecot reload; postfix reload; }',
    cronjobTargetContainerName: 'mailserver',
    cronjobInstance: 'mailserver-cert-reload-check',
    //cronjobInterval: '10 */12 * * *',
    cronjobInterval: '*/10 * * * *',
    cronjobTargetPodSelector: {
      'app.kubernetes.io/project': 'base',
      'app.kubernetes.io/name': 'mx',
      'app.kubernetes.io/component': 'mailserver',
    },

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
