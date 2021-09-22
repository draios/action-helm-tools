# Push helm charts to Artifactory

- a docker image to push Helm charts to Artifactory

## Arguments

- from the `environment`:

    `CHART_VERSION_EXT`: use this Chart version

    `WAIT_FOR_CHART`: poll the helm repo until the chart is available to download

    `HELM_REPO_URL`:

    `TIMEOUT`:

## Checks


## Notes

### Current usage

- who/what/where is using this right now? make a list

### pushing vs packaging vs linting etc

- right now the script only does a `push-artifactory` of the Chart

- can the extra feature of the host tool (`dependency build`, `lint`, `package`) be added?
    - what's the impact on existing users?



### UBI image

- the Docker base image must be one of the new UBI image

### Additional arguments

- add the following optional arguments

    - Chart version
    - Helm repo to pull the chart from

#### More on the additional arguments

- the script must have an optional argument for Chart version

    - this value takes precedence over the current extraction of the values from `Chart.yaml`

- after pushing the image, the script must start a retried attempt (with timeout) to pull the Chart from the Helm repo

    - the Helm repo used to pull can be passed as an optional argument

1) rename docker-image to containers

2) build the docker image using GH action

3) https://github.com/draios/infra-github-runner
use build: section
4)

add in tag and build solo quando cambia qualcosa in containers


precommit

taskfile
https://pre-commit.com/

https://taskfile.dev/#/

self-hosted

## For reference: how this image is executed in the secure-backend `Makefile`

```
	$(DOCKER) run -v `pwd`/.k8s:/charts -e ARTIFACTORY_USER=$(ARTIFACTORY_CREDENTIALS_USR) -e ARTIFACTORY_PASSWORD=$(ARTIFACTORY_CREDENTIALS_PSW) -e CHART_VERSION=$(CHART_VERSION) docker.internal.sysdig.com/helm-push-artifactory:1.0.0
```
