local global = import '../../../../config/global.libsonnet';

{
  default: {
    inboundDomainPolicyMap: {
      'bln.space': {},
      'schumann.link': {},
      'kubectl.me': {},
      'n-os.org': {},
      'remembrance.de': {},
    },
    defaultPolicy: {
      version: 'STSv1',
      mode: 'testing',
      mx: global.lts.mxPublicHost,
      max_age: 604800,
    },
  },

  staging: {},

  lts: {},
}
