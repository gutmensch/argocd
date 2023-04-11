// cronjob which runs a command in existing pods via k8s api exec
// program logic implemented in toolbox image with python
// https://github.com/remembrance/toolbox

local helper = import '../../helper.libsonnet';
local kube = import '../../kube.libsonnet';

{
  generate(
    name, namespace, region, tenant, appConfig, defaultConfig={
      imageRegistryMirror: '',
      imageRegistry: '',
      imageRef: 'gutmensch/toolbox',
      imageVersion: '0.0.16',
      cronjobInstance: null,
      cronjobInstanceEnvConfig: {},
      cronjobCommand: ['/usr/bin/container_command.py'],
      cronjobTargetPodSelector: {},
      cronjobTargetContainerName: null,
      cronjobTargetContainerCommand: null,
      cronjobInterval: '*/5 * * * *',
      cronjobBackoffLimit: 3,
      cronjobCompletions: 1,
    }
  ):: helper.uniquify({

    local this = self,

    local config = std.mergePatch(defaultConfig, appConfig),

    local appName = name,
    local componentName = 'container-cronjob',

    assert std.length(std.objectFields(config.cronjobTargetPodSelector)) > 0 : error 'pod selector for cronjob is empty',
    assert config.cronjobTargetContainerName != null : error 'target container name is null',
    assert config.cronjobInstance != null : error 'container cronjob instance suffix is null',

    cronjob_service_account: kube.ServiceAccount('%s-%s' % [componentName, config.cronjobInstance]) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
    },

    cronjob_secret: kube.Secret('%s-%s' % [componentName, config.cronjobInstance]) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      stringData: {
        CONTAINER_NAME: config.cronjobTargetContainerName,
        POD_SELECTOR: std.join(',', ['%s=%s' % [k, config.cronjobTargetPodSelector[k]] for k in std.objectFields(config.cronjobTargetPodSelector)]),
        [if config.cronjobTargetContainerCommand != null then 'CONTAINER_COMMAND']: config.cronjobTargetContainerCommand,
      } + config.cronjobInstanceEnvConfig,
    },

    cronjob: kube.CronJob('%s-%s' % [componentName, config.cronjobInstance]) {
      metadata+: {
        namespace: namespace,
        labels: config.labels,
      },
      spec+: {
        schedule: config.cronjobInterval,
        jobTemplate+: {
          metadata+: {
            labels: config.labels,
          },
          spec+: {
            backoffLimit: config.cronjobBackoffLimit,
            completions: config.cronjobCompletions,
            template+: {
              spec+: {
                serviceAccountName: '%s-%s' % [componentName, config.cronjobInstance],
                containers_+: {
                  cronjob: {
                    args: config.cronjobCommand,
                    env: [
                      {
                        name: 'K8S_NAMESPACE',
                        valueFrom: {
                          fieldRef: {
                            fieldPath: 'metadata.namespace',
                          },
                        },
                      },
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: this.cronjob_secret.metadata.name,
                        },
                      },
                    ],
                    image: helper.getImage(config.imageRegistryMirror, config.imageRegistry, config.imageRef, config.imageVersion),
                    imagePullPolicy: 'Always',
                    name: 'cronjob',
                  },
                },
              },
            },
          },
        },
      },
    },

    cronjob_role: kube.Role('%s-%s' % [componentName, config.cronjobInstance]) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      rules: [
        {
          apiGroups: [''],
          resources: ['pods'],
          verbs: ['get', 'list'],
        },
        {
          apiGroups: [''],
          resources: ['pods/exec'],
          verbs: ['create', 'get'],
        },
      ],
    },

    cronjob_role_binding: kube.RoleBinding('%s-%s' % [componentName, config.cronjobInstance]) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
      subjects_:: [
        this.cronjob_service_account,
      ],
      roleRef_:: this.cronjob_role,
    },

  }),
}
