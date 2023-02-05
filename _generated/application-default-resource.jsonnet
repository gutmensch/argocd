{
  "apiVersion": "argoproj.io/v1alpha1",
  "kind": "Application",
  "metadata": {
    "labels": {
      "app.kubernetes.io/instance": "default-resource",
      "app.kubernetes.io/managed-by": "ArgoCD",
      "app.kubernetes.io/name": "default-resource"
    },
    "name": "default-resource",
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
        "include": "{storage-class-zfs-fast-xfs.yaml,storage-class-zfs-slow-xfs.yaml}",
        "recurse": false
      },
      "path": "resource",
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