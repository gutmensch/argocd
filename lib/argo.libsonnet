local kube = import 'kube.libsonnet';

{
  Project(name, namespaces, description, clusterResourceAllowList): kube._Object("argoproj.io/v1alpha1", "AppProject", name) {
    metadata: {
      namespace: 'argo-cd-system',
      name: name,
      finalizers: ['resources-finalizer.argocd.argoproj.io'],
      labels: {
	'app.kubernetes.io/managed-by': 'ArgoCD',
      },
    },
    spec: {
      description: description,
      sourceRepos: ['*'],
      destinations: [
        { namespace: ns, server: 'https://kubernetes.default.svc' }
	for ns in namespaces
      ],
      clusterResourceWhitelist: clusterResourceAllowList,
    }
  },

  Application(tenant, app): kube._Object("argoproj.io/v1alpha1", "Application", app.name) {
    local full_name = '%s-%s-%s' % [app.project, app.name, tenant],
    metadata: {
      namespace: 'argo-cd-system',
      name: full_name,
      finalizers: ['resources-finalizer.argocd.argoproj.io'],
      labels: {
        'app.kubernetes.io/name': app.name,
        'app.kubernetes.io/instance': full_name,
	'app.kubernetes.io/managed-by': 'ArgoCD',
      },
    },
    spec: {
      project: app.project,
      source: {
        repoURL: app.repoURL,
	targetRevision: app.targetRevision,
	path: std.join('/', [app.directory, app.path]),
        directory: {
          recurse: false,
          jsonnet: {
            tlas: std.prune([
              {code: false, name: 'name', value: app.name },
              {code: false, name: 'namespace', value: full_name },
              {code: false, name: 'project', value: app.project },
              {code: false, name: 'tenant', value: tenant },
              {code: false, name: 'region', value: app.region },
              if app.ingressDomain != null then {code: false, name: 'ingressDomain', value: app.ingressDomain } else null,
              if app.ingressRoot != null then {code: false, name: 'ingressRoot', value: app.ingressRoot } else null,
            ]),
            extVars:: [],
          },
	},
      },
      destination: {
        server: 'https://kubernetes.default.svc',
	namespace: full_name,
      },
      syncPolicy: {
        automated: {
          prune: true,
	  selfHeal: true,
	  allowEmpty: true,
	},
	retry: {
	  limit: 10,
	  backoff: {
	    duration: '5s',
            factor: 2,
            maxDuration: '10m',
	  },
	},
        syncOptions: ['Validate=true', 'CreateNamespace=true', 'PrunePropagationPolicy=background', 'PruneLast=true'],
      },
    },
  },
}
