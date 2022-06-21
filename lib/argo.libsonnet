local kube = import 'kube.libsonnet';

{
  Project(name, description): kube._Object("argoproj.io/v1alpha1", "AppProject", name) {
    metadata: {
      namespace: 'argo-cd-system',
      name: name,
      finalizers: ['resources-finalizer.argocd.argoproj.io'],
    },
    spec: {
      description: description,
      sourceRepos: ['*'],
      destinations: [
        { namespace: 'foobar', server: 'https://kubernetes.default.svc' },
      ],
      clusterResourceWhitelist: [
        { group: '', kind: 'Namespace' },
      ],
    }
  },

  Application(name, project, path): kube._Object("argoproj.io/v1alpha1", "Application", name) {
    metadata: {
      namespace: 'argo-cd-system',
      name: name,
      finalizers: ['resources-finalizer.argocd.argoproj.io'],
      labels: {
        name: name,
      },
    },
    spec: {
      project: project,
      source: {
        repoURL: 'https://github.com/gutmensch/argocd.git',
	targetRevision: 'HEAD',
	path: path,
      },
      destination: {
        server: 'https://kubernetes.default.svc',
	namespace: name,
      },
    },
  },
}
