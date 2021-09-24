# Push helm charts to Artifactory - Docker Image

- a docker image to check and push Helm charts to Artifactory
- checks:
    - `helm lint`
    - `helm package`
    - `helm pull` (Artifactory has a delay between pushing a chart and it being available to pull)

## TODO

- GH action to build and push the image (on merge to `main`)
    - question: while developing and testing, the image will be needed on artifactory at `docker.internal.sysdig.com/helm-push-artifactory:TAG`
      if `TAG` is same as the one in [version](containers/version) then the `docker push` will fail.
      Only solution seems to be to use a special `TAG` during development.


## Arguments and defaults

```
ARTIFACTORY_PASSWORD=${ARTIFACTORY_PASSWORD:-}
ARTIFACTORY_USER=${ARTIFACTORY_USER:-}

ARTIFACTORY_PULL_URL=${ARTIFACTORY_PULL_URL:-https://artifactory.internal.sysdig.com/artifactory/helm/}
ARTIFACTORY_PUSH_URL=${ARTIFACTORY_PUSH_URL:-https://artifactory.internal.sysdig.com:443/artifactory/helm-local/}

CHART_NAME=${CHART_NAME:-}
CHART_DIR=${CHART_DIR:-/charts}
CHART_OUTPUT_DIR=${CHART_OUTPUT_DIR:-/chart_output}
CHART_VERSION=${CHART_VERSION:-}

HELM_PULL_RETRIES=${HELM_PULL_RETRIES:-12}
PULL_SLEEP_TIME=${PULL_SLEEP_TIME:-10}
REPO_NAME=${REPO_NAME:-artifactory}
WAIT_FOR_CHART=${WAIT_FOR_CHART:-false}
```

### Usage

- inventory of where this is used

- see https://sysdig.atlassian.net/wiki/spaces/~benedetto.logiudice/pages/2403860713/Installer+-+CICD+-+Harness+-+helm+push+to+artifactory+for+Sysdig+charts#Where-is-the-image-used

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
