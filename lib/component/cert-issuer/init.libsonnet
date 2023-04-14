// cert manager is installed by ansible bootstrapping
local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';

{
  generate(
    name,
    namespace,
    region,
    tenant,
    appConfig,
    defaultConfig={
      acmeEmail: 'changeme@example.com',
      privateKeySecretRefName: 'google-credentials',
      issuerOrg: 'letsencrypt',
      environment: 'prod',
      server: 'https://acme-v02.api.letsencrypt.org/directory',
      // dns provider related information, currently only google dns
      provider: 'google',
      googleProjectID: null,
      googleServiceAccount: {},
    },
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'cert-issuer',
    local instance = '%s-%s-%s' % [config.issuerOrg, config.environment, config.provider],

    assert config.googleProjectID != null : error 'google project ID must not be null',
    assert config.acmeEmail != 'changeme@example.com' : error 'email address must be valid',

    secret: kube.Secret('%s-credentials' % [instance]) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      stringData: {
        'key.json': std.toString(config.googleServiceAccount),
      },
    },

    certIssuer: kube._Object('cert-manager.io/v1', 'ClusterIssuer', instance) {
      metadata+: {
        namespace: namespace,
        labels+: config.labels,
      },
      spec+: {
        acme: {
          server: config.server,
          email: config.acmeEmail,
          privateKeySecretRef: {
            name: instance,
          },
          solvers: [
            {
              dns01: {
                cloudDNS: {
                  project: config.googleProjectID,
                  serviceAccountSecretRef: {
                    name: this.secret.metadata.name,
                    key: std.objectFields(this.secret.stringData)[0],
                  },
                },
              },
            },
          ],
        },
      },
    },
  }),
}
