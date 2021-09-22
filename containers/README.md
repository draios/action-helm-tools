# Push helm charts to Artifactory - Docker Image

- a docker image to check and push Helm charts to Artifactory
- checks:
    - `helm lint`
    - `helm package`
    - `helm pull` (Artifactory has a delay between pushing a chart and it being available to pull)

## Arguments

### Required
- from the `environment`:

    `CHART_VERSION_EXT`: use this Chart version

### Optional


### Current usage

- see https://sysdig.atlassian.net/wiki/spaces/~benedetto.logiudice/pages/2403860713/Installer+-+CICD+-+Harness+-+helm+push+to+artifactory+for+Sysdig+charts#Where-is-the-image-used

#### For reference: how this image is executed in the secure-backend `Makefile`

```
	$(DOCKER) run -v `pwd`/.k8s:/charts -e ARTIFACTORY_USER=$(ARTIFACTORY_CREDENTIALS_USR) -e ARTIFACTORY_PASSWORD=$(ARTIFACTORY_CREDENTIALS_PSW) -e CHART_VERSION=$(CHART_VERSION) docker.internal.sysdig.com/helm-push-artifactory:1.0.0
```

### UBI image

- the Docker base image must be one of the new UBI image

## TODO:

- build the docker image using GH action when the PR is merged
    - see https://github.com/draios/infra-github-runner
    - see `use build` section
    - this image should be built in `tag and build` only when the content of `containers` has changed

## pre-commit tooling for sanityc checks

- using `git hooks` the code is checked when committing:

- tools:

    - https://pre-commit.com/
    - https://taskfile.dev/#/

### installing the tooling to take advantage of the git hooks and sanity checks

- the repo comes with some `git hooks` which are executed on GitHub via actions

- these checks can be executed also locally provided the required tools are installed

#### MacOS

```
brew install go-task/tap/go-task
```

and then:

```
brew install shellcheck
brew install pre-commit (don't be surprise if it takes a long time and if it installs and updates a lot of packages)
```


or

```
task setup
```

- you can then execute:


```
task
task: Available tasks for this project:
* check: 	Run pre-commit hooks
* setup: 	Bootstrap dev environment
* test: 	Run tests
```

and

```
task check
task: [check] pre-commit run -a
Trim Trailing Whitespace.................................................Passed
Fix End of Files.........................................................Passed
Check for added large files..............................................Passed
Check for merge conflicts................................................Passed
Check for broken symlinks............................(no files to check)Skipped
Check Yaml...............................................................Passed
Detect Private Key.......................................................Passed
Test shell scripts with shellcheck.......................................Passed
Lint Dockerfiles.........................................................Passed
Validate GitHub Workflows................................................Passed
```

- the checks are executed at every commit

```
git commit -m "Run task check"
git puTrim Trailing Whitespace.................................................Passed
Fix End of Files.........................................................sPassed
Check for added large files..............................................hPassed
Check for merge conflicts................................................Passed
Check for broken symlinks............................(no files to check)Skipped
Check Yaml...........................................(no files to check)Skipped
Detect Private Key.......................................................Passed
Test shell scripts with shellcheck.......................................Passed
Lint Dockerfiles.........................................................Passed
Validate GitHub Workflows............................(no files to check)Skipped
[INSTALL-1388-helm-push-docker-image 47138d7] Run task check
 5 files changed, 6 insertions(+), 8 deletions(-)
 ```
