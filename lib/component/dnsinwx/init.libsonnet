local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';

{
  generate(
    name,
    namespace,
    region,
    tenant,
    appConfig,
    // override below values in the specific app/$name/config/, app/$name/secret or app/$name/cd
    // directories app instantiation and configuration and pass as appConfig parameter above
    defaultConfig={
      imageRegistry: '',
      imageRef: 'willhallonline/ansible',
      imageVersion: '2.13-alpine-3.16',
      inwxUsername: 'admin',
      inwxPassword: 'changeme',
      inwxOTP: 'changeme',
      domains: {},
    }
  ):: {

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    // assert config.inwxPassword != 'changeme' && config.inwxOTP != 'changeme' : error '"changeme" is an invalid password and OTP',

    local appName = name,
    local componentName = 'dnsinwx',

    // new simple job will be created when content of zone changes
    jobs: {
      ['job-%s' % [domain]]: kube.Job('job-%s-%s' % [std.strReplace(std.strReplace(domain, '.', ''), '-', ''), std.substr(std.md5(std.toString(config.domains[domain])), 15, 16)]) {
        metadata+: {
          namespace: namespace,
          labels+: config.labels,
        },
        spec+: {
          template+: {
            metadata+: {
              annotations+: {
              },
              labels: config.labels,
            },
            spec+: {
              containers: [
                {
                  args: [
                    'ansible-playbook',
                    '-vv',
                    'playbook.yml',
                  ],
                  env: [],
                  envFrom: [
                    {
                      secretRef: {
                        name: componentName,
                      },
                    },
                  ],
                  image: helper.getImage(config.mirrorImageRegistry, config.imageRegistry, config.imageRef, config.imageVersion),
                  imagePullPolicy: 'Always',
                  name: componentName,
                  volumeMounts: [
                    {
                      mountPath: '/ansible/playbook.yml',
                      name: '%s-config' % [componentName],
                      subPath: 'playbook.yml',
                    },
                    {
                      mountPath: '/ansible/library/dns_inwx.py',
                      name: '%s-config' % [componentName],
                      subPath: 'dns_inwx.py',
                    },
                    {
                      mountPath: '/ansible/domainData.yml',
                      name: '%s-domaindata' % [componentName],
                      subPath: 'domainData.yml',
                    },
                  ],
                },

              ],
              volumes: [
                {
                  configMap: {
                    name: '%s-config' % [componentName],
                  },
                  name: '%s-config' % [componentName],
                },
                {
                  configMap: {
                    name: '%s-cfg-%s' % [componentName, std.strReplace(std.strReplace(domain, '.', ''), '-', '')],
                  },
                  name: '%s-domaindata' % [componentName],
                },
              ],
            },
          },
        },
      }
      for domain in std.objectFields(config.domains)
    },

    configmapjobs: {
      ['configmap-%s' % [domain]]: kube.ConfigMap('%s-cfg-%s' % [componentName, std.strReplace(std.strReplace(domain, '.', ''), '-', '')]) {
        metadata+: {
          namespace: namespace,
          labels+: config.labels,
        },
        data: {
          // XXX: search base is not configurable per filter, so we need to use the root here
          'domainData.yml': std.manifestYamlDoc(
            { records: [
              std.mergePatch({ domain: domain }, entry)
              for entry in std.get(config.domains, domain)
            ] },
          ),
        },
      }
      for domain in std.objectFields(config.domains)
    },

    configmaps: {
      generic: kube.ConfigMap('%s-config' % [componentName]) {
        data: {
          'playbook.yml': importstr 'playbook.yml',
          'dns_inwx.py': importstr 'dns_inwx.py',
        },
      },
    },

    secrets: {
      inwx: kube.Secret(componentName) {
        metadata+: {
          namespace: namespace,
          labels: config.labels,
        },
        stringData: {
          INWX_USERNAME: config.inwxUsername,
          INWX_PASSWORD: config.inwxPassword,
        },
      },
    },
  },
}
