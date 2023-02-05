{
  "apiVersion": "argoproj.io/v1alpha1",
  "kind": "Application",
  "metadata": {
    "labels": {
      "app.kubernetes.io/instance": "default-crd",
      "app.kubernetes.io/managed-by": "ArgoCD",
      "app.kubernetes.io/name": "default-crd"
    },
    "name": "default-crd",
    "namespace": "argo-cd-system"
  },
  "spec": {
    "destination": {
      "namespace": "default",
      "server": "https://kubernetes.default.svc"
    },
    "project": "default",
    "source": {
      "directory": {
        "include": "{}",
        "recurse": false
      },
      "path": "lib/crds",
      "repoURL": "https://github.com/gutmensch/argocd.git",
      "targetRevision": "HEAD"
    },
    "syncPolicy": {
      "automated": {
        "allowEmpty": true,
        "prune": true,
        "selfHeal": true
      },
      "retry": {
        "backoff": {
          "duration": "5s",
          "factor": 2,
          "maxDuration": "5m"
        },
        "limit": 5
      },
      "syncOptions": [
        "Validate=true",
        "CreateNamespace=true",
        "PrunePropagationPolicy=foreground"
      ]
    }
  }
}