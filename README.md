# action-helm-tools

GitHub Action for packaging, testing helm charts and publishing to Artifactory helm repo

_Note this action is written to specifically work with Helm repos in Artifactory_

## Inputs

### Required

`action` - `[package, test, publish]`

- `package` - Involves helm client only and does dependency build, lint and package chart
- `publish` - Uses helm artifactory plugin to uploads the chart

## Required Environment variables

```yaml
CHART_DIR: manifests/charts/mycomponent # chart path
ARTIFACTORY_URL: # Artifactory registry https://<company>.jfrog.io/<company>
ARTIFACTORY_USERNAME: ${{ secrets.ARTIFACTORY_USERNAME }} # ARTIFACTORY_USERNAME (Artifactory username) must be set in GitHub Repo secrets
ARTIFACTORY_PASSWORD: ${{ secrets.ARTIFACTORY_PASSWORD }} # ARTIFACTORY_PASSWORD (Artifactory api key) must be set in GitHub Repo secrets
```

## Optional Environment variables

```yaml
HELM_VERSION: # Override helm version. Default "2.14.3"
KUBECTL_VERSION: # Override kubectl version. Default "1.15.4"
HELM_ARTIFACTORY_PLUGIN_VERSION: # Override helm artifactory plugin version. Default "v1.0.2"
```


# Example workflow

Never use `main` branch in your github workflows!

```yaml
name: Helm lint, test, package and publish

on: pull_request

jobs:
  helm-suite:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2

    # - name: myOtherJob1
    #   run:

      - name: "Helm publish"
        uses: draios/action-helm-tools@v1.0.1
        with:
          action: "package"
        env:
          CHART_DIR: resources/helm/sdcadminoper
          ARTIFACTORY_URL: https://artifactory.internal.sysdig.com:443/artifactory/helm-local/
          ARTIFACTORY_USERNAME: ${{ secrets.ARTIFACTORY_HELM_USERNAME }}
          ARTIFACTORY_PASSWORD: ${{ secrets.ARTIFACTORY_HELM_PASSWORD }}

      - name: "Helm publish"
        uses: draios/action-helm-tools@v1.0.1
        with:
          action: "publish"
        env:
          CHART_DIR: resources/helm/sdcadminoper
          ARTIFACTORY_URL: https://artifactory.internal.sysdig.com:443/artifactory/helm-local/
          ARTIFACTORY_USERNAME: ${{ secrets.ARTIFACTORY_HELM_USERNAME }}
          ARTIFACTORY_PASSWORD: ${{ secrets.ARTIFACTORY_HELM_PASSWORD }}

```
