{
  "apiVersion": "argoproj.io/v1alpha1",
  "kind": "Application",
  "metadata": {
    "finalizers": [
      "resources-finalizer.argocd.argoproj.io"
    ],
    "labels": {
      "app.kubernetes.io/instance": "base-mx-lts",
      "app.kubernetes.io/managed-by": "ArgoCD",
      "app.kubernetes.io/name": "mx"
    },
    "name": "base-mx-lts",
    "namespace": "argo-cd-system"
  },
  "spec": {
    "destination": {
      "namespace": "base-mx-lts",
      "server": "https://kubernetes.default.svc"
    },
    "ignoreDifferences": [
      {
        "group": "networking.k8s.io",
        "jqPathExpressions": [
          ".spec.ingress[].from[] | select(.ipBlock.cidr == \"0.0.0.0/0\")"
        ],
        "kind": "NetworkPolicy"
      }
    ],
    "project": "base",
    "source": {
      "directory": {
        "jsonnet": {
          "tlas": [
            {
              "code": false,
              "name": "name",
              "value": "mx"
            },
            {
              "code": false,
              "name": "namespace",
              "value": "base-mx-lts"
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
      "path": "base/mx",
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
        "PrunePropagationPolicy=background",
        "RespectIgnoreDifferences=true"
      ]
    }
  }
}