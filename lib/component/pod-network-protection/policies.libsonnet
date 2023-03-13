{
  servicePortsInternal:: error 'please provide internal service ports if using pod network protection',
  servicePortsExternal:: error 'please provide external service ports if using pod network protection',
  dnsServiceNamespace:: 'kube-system',
  ldapServiceNamespace:: null,

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
        { ipBlock: { cidr: '0.0.0.0/0' } },
      ],
    },

    coreDNS: {
      to: [
        { namespaceSelector: { matchLabels: { 'kubernetes.io/metadata.name': this.dnsServiceNamespace } } },
      ],
      ports: [
        { protocol: 'UDP', port: 53 },
      ],
    },

    [if this.ldapServiceNamespace != null then 'ldap']: {
      to: [
        //{ namespaceSelector: { matchLabels: { 'kubernetes.io/metadata.name': this.ldapServiceNamespace } } },
        { namespaceSelector: {} },
        { podSelector: {} },
      ],
      ports: [
        { protocol: 'TCP', port: 389 },
        { protocol: 'TCP', port: 636 },
      ],
    },
  },

}
