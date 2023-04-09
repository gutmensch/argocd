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
      imageVersion: '0.0.13',
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
    assert config.cronjobTargetContainerCommand != null : error 'target container command is null',

    cronjob_service_account: kube.ServiceAccount('%s-%s' % [appName, componentName]) {
      metadata+: {
        labels: config.labels,
        namespace: namespace,
      },
    },

    cronjob: kube.CronJob('%s-%s' % [appName, componentName]) {
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
                serviceAccountName: '%s-%s' % [appName, componentName],
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
                      {
                        name: 'CONTAINER_NAME',
                        value: config.cronjobTargetContainerName,
                      },
                      {
                        name: 'CONTAINER_COMMAND',
                        value: config.cronjobTargetContainerCommand,
                      },
                      {
                        name: 'POD_SELECTOR',
                        value: std.join(',', ['%s=%s' % [k, config.cronjobTargetPodSelector[k]] for k in std.objectFields(config.cronjobTargetPodSelector)]),
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

    cronjob_role: kube.Role('%s-%s' % [appName, componentName]) {
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

    cronjob_role_binding: kube.RoleBinding('%s-%s' % [appName, componentName]) {
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
