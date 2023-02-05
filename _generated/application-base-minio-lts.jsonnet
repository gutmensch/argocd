{
  "apiVersion": "argoproj.io/v1alpha1",
  "kind": "Application",
  "metadata": {
    "finalizers": [
      "resources-finalizer.argocd.argoproj.io"
    ],
    "labels": {
      "app.kubernetes.io/instance": "base-minio-lts",
      "app.kubernetes.io/managed-by": "ArgoCD",
      "app.kubernetes.io/name": "minio"
    },
    "name": "base-minio-lts",
    "namespace": "argo-cd-system"
  },
  "spec": {
    "destination": {
      "namespace": "base-minio-lts",
      "server": "https://kubernetes.default.svc"
    },
    "project": "base",
    "source": {
      "directory": {
        "jsonnet": {
          "tlas": [
            {
              "code": false,
              "name": "name",
              "value": "minio"
            },
            {
              "code": false,
              "name": "namespace",
              "value": "base-minio-lts"
            },
            {
              "code": false,
              "name": "project",
              "value": "base"
            },
            {
              "code": false,
              "name": "tenant",
              "value": "lts"
            },
            {
              "code": false,
              "name": "region",
              "value": "helsinki"
            }
          ]
        },
        "recurse": false
      },
      "path": "base/minio",
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
        "PrunePropagationPolicy=background"
      ]
    }
  }
}