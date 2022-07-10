# argocd - deployment configuration for kubectl.me

## root kubernetes installation

## secrets

Secrets are managed via sealed-secrets. To generate them from bitwarden ([source](https://vault.bitwarden.com/#/vault?itemId=dd26182f-7391-453a-8948-aeba0142bc70)) to the apps/ directories, run `./pki/generate_sealed_secrets.py`.
