local kube = import 'kube.libsonnet';

{
  Project(name, namespaces, description): kube._Object("argoproj.io/v1alpha1", "AppProject", name) {
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
      clusterResourceWhitelist: [
        { group: '', kind: 'Namespace' },
      ],
    }
  },

  Application(tenant, app): kube._Object("argoproj.io/v1alpha1", "Application", app.name) {
    local full_name = if tenant == 'lts' then '%s-%s' % [app.project, app.name] else '%s-%s-%s' % [app.project, app.name, tenant],
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
      },
      destination: {
        server: 'https://kubernetes.default.svc',
	namespace: full_name,
      },
      directory: {
        recurse: false,
	jsonnet: {
	  tlas: [
	    {code: false, name: 'name', value: app.name },
	    {code: false, name: 'namespace', value: full_name },
	    {code: false, name: 'region', value: app.region },
	    {code: false, name: 'tenant', value: tenant },
	    {code: false, name: 'project', value: app.project },
	    {code: false, name: 'ingressRoot', value: app.ingressRoot },
	  ],
	  extVars:: [],
        },
      },
      syncPolicy: {
        automated: {
          prune: true,
	},
        syncOptions: ['CreateNamespace=true'],
      },
    },
  },
}
