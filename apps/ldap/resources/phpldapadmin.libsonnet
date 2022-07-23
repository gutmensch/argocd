{
  'configmap-63a43': {
    apiVersion: 'v1',
    data: {
      PHPLDAPADMIN_HTTPS: 'false',
      PHPLDAPADMIN_LDAP_CLIENT_TLS_REQCERT: 'never',
      PHPLDAPADMIN_LDAP_HOSTS: "#PYTHON2BASH:[{ 'ldap.default'  : [{'server': [{'tls': True},{'port':389}]},{'login': [{'bind_id': 'cn=admin,dc=dc=ldap,dc=local'  }]}]}]",
      PHPLDAPADMIN_TRUST_PROXY_SSL: 'true',
    },
    kind: 'ConfigMap',
    metadata: {
      labels: {
        app: 'phpldapadmin',
        chart: 'phpldapadmin-0.1.2',
        heritage: 'Helm',
        release: 'ldap',
      },
      name: 'ldap-phpldapadmin',
    },
  },
  'deployment-2bb28': {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      labels: {
        app: 'phpldapadmin',
        chart: 'phpldapadmin-0.1.2',
        heritage: 'Helm',
        release: 'ldap',
      },
      name: 'ldap-phpldapadmin',
    },
    spec: {
      replicas: 1,
      selector: {
        matchLabels: {
          app: 'phpldapadmin',
          release: 'ldap',
        },
      },
      template: {
        metadata: {
          labels: {
            app: 'phpldapadmin',
            release: 'ldap',
          },
        },
        spec: {
          containers: [
            {
              envFrom: [
                {
                  configMapRef: {
                    name: 'ldap-phpldapadmin',
                  },
                },
              ],
              image: 'osixia/phpldapadmin:0.9.0',
              imagePullPolicy: 'IfNotPresent',
              livenessProbe: {
                httpGet: {
                  path: '/',
                  port: 'http',
                },
              },
              name: 'phpldapadmin',
              ports: [
                {
                  containerPort: 80,
                  name: 'http',
                  protocol: 'TCP',
                },
              ],
              readinessProbe: {
                httpGet: {
                  path: '/',
                  port: 'http',
                },
              },
              resources: {},
            },
          ],
        },
      },
    },
  },
  'service-86239': {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      labels: {
        app: 'phpldapadmin',
        chart: 'phpldapadmin-0.1.2',
        heritage: 'Helm',
        release: 'ldap',
      },
      name: 'ldap-phpldapadmin',
    },
    spec: {
      ports: [
        {
          name: 'http',
          port: 80,
          protocol: 'TCP',
          targetPort: 'http',
        },
      ],
      selector: {
        app: 'phpldapadmin',
        release: 'ldap',
      },
      type: 'ClusterIP',
    },
  },
  'ingress-41748': {
    apiVersion: 'networking.k8s.io/v1',
    kind: 'Ingress',
    metadata: {
      annotations: {

// TODO
//   Create htpasswd file¶
//   
//   $ htpasswd -c auth foo
//   New password: <bar>
//   New password:
//   Re-type new password:
//   Adding password for user foo
//   Convert htpasswd into a secret¶
//   
//   $ kubectl create secret generic basic-auth --from-file=auth
//   secret "basic-auth" created
//   Examine secret¶
//   
//   $ kubectl get secret basic-auth -o yaml
//   apiVersion: v1
//   data:
//     auth: Zm9vOiRhcHIxJE9GRzNYeWJwJGNrTDBGSERBa29YWUlsSDkuY3lzVDAK
//   kind: Secret
//   metadata:
//     name: basic-auth
//     namespace: default
//   type: Opaque

        // type of authentication
        'nginx.ingress.kubernetes.io/auth-type': 'basic',
        // name of the secret that contains the user/password definitions
        'nginx.ingress.kubernetes.io/auth-secret': 'basic-auth',
        // message to display with an appropriate context why the authentication is required
        'nginx.ingress.kubernetes.io/auth-realm': 'Authentication Required - foo',
      },
      labels: {
        app: 'phpldapadmin',
        chart: 'phpldapadmin-0.1.2',
        heritage: 'Helm',
        release: 'ldap',
      },
      name: 'ldap-phpldapadmin',
    },
    spec: {
      rules: [
        {
          host: 'phpldapadmin.kubectl.me',
          http: {
            paths: [
              {
                backend: {
                  service: {
                    name: 'ldap-phpldapadmin',
                    port: {
                      name: 'http',
                    },
                  },
                },
                path: '/',
                pathType: 'Prefix',
              },
            ],
          },
        },
      ],
    },
  },
}
