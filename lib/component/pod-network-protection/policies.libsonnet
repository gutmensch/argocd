{
  servicePortsInternal:: error 'please provide internal service ports if using pod network protection',
  servicePortsExternal:: error 'please provide external service ports if using pod network protection',
  outboundPorts:: error 'please provide outbound enabled ports if using pod network protection',
  outboundNetworks:: error 'please provide outbound enabled network if using pod network protection',
  dnsServiceNamespace:: 'kube-system',
  ldapServiceNamespace:: null,
  minioServiceNamespace:: null,

  local this = self,

  assert std.length(this.servicePortsInternal) > 0 : 'internal service ports list must not be empty',
  assert std.length(this.servicePortsExternal) > 0 : 'internal service ports list must not be empty',

  ingress: {
    serviceInternal: {
      from: [
        { namespaceSelector: {} },
        { podSelector: {} },
      ],
      ports: [
        { protocol: 'TCP', port: port }
        for port in this.servicePortsInternal
      ],
    },
    serviceExternal: {
      from: [
        { ipBlock: { cidr: '0.0.0.0/0' } },
      ],
      ports: [
        { protocol: 'TCP', port: port }
        for port in this.servicePortsExternal
      ],
    },
  },

  egress: {
    all: {
      to: [
        { ipBlock: { cidr: network } }
        for network in this.outboundNetworks
      ],
      ports: [
        { protocol: 'TCP', port: port }
        for port in this.outboundPorts
      ],
    },

    coreDNS: {
      to: [
        { namespaceSelector: { matchLabels: { 'kubernetes.io/metadata.name': this.dnsServiceNamespace } } },
      ],
      ports: [
        { protocol: 'UDP', port: 53 },
        { protocol: 'TCP', port: 53 },
        { protocol: 'TCP', port: 9153 },
      ],
    },

    [if this.ldapServiceNamespace != null then 'ldap']: {
      to: [
        { namespaceSelector: { matchLabels: { 'kubernetes.io/metadata.name': this.ldapServiceNamespace } } },
      ],
      ports: [
        // XXX: this needs the actual pod service ports and uses
        // unprivileged high ports on pod level and normal ports on service level!
        { protocol: 'TCP', port: 1389 },
        { protocol: 'TCP', port: 1636 },
      ],
    },

    [if this.minioServiceNamespace != null then 'minio']: {
      to: [
        { namespaceSelector: { matchLabels: { 'kubernetes.io/metadata.name': this.minioServiceNamespace } } },
      ],
      ports: [
        { protocol: 'TCP', port: 9000 },
        // exclude minio console port for now, because not needed
        // { protocol: 'TCP', port: 9001 },
      ],
    },

  },
}
