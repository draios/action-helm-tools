#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")
export SCRIPT_DIR
source "$SCRIPT_DIR/common.sh"

# optional arguments
CHART_VERSION_EXT=${CHART_VERSION_EXT:-}
WAIT_FOR_CHART=${WAIT_FOR_CHART:-false}
HELM_REPO_URL=${HELM_REPO_URL:-}
ACTION=${ACTION:-all}
CHART_DIR=${CHART_DIR:-/chart}
CHART_OUTPUT_DIR=${CHART_OUTPUT_DIR:-/chart_output}
ARTIFACTORY_PUSH_URL=${ARTIFACTORY_PUSH_URL:-https://artifactory.internal.sysdig.com:443/artifactory/helm-local/}
ARTIFACTORY_USERNAME=${ARTIFACTORY_USERNAME:-}
ARTIFACTORY_PASSWORD=${ARTIFACTORY_PASSWORD:-}
ARTIFACTORY_PULL_URL=${ARTIFACTORY_PULL_URL:-https://artifactory.internal.sysdig.com/artifactory/helm/}
HELM_PULL_RETRIES=${HELM_PULL_RETRIES:-5}
CHART_NAME=${CHART_NAME:-}
PULL_SLEEP_TIME=${PULL_SLEEP_TIME:-10}
REPO_NAME=${REPO_NAME:-artifactory}
DEBUG=${DEBUG:-}

[[ -n "${DEBUG}" ]] && set -x


### main ##############
#install_helm
#install_artifactory_plugin
logit "INFO" "Starting"
if [[ -z "${CHART_VERSION_EXT}" ]]; then
    logit "ERROR" "CHART_VERSION_EXT is required"
    exit 1
else
    logit "INFO" "using CHART_VERSION: ${CHART_VERSION_EXT}"
    CHART_VERSION=${CHART_VERSION_EXT}
fi
if [[ -z "${ARTIFACTORY_USERNAME}" ]]; then
    logit "ERROR" "ARTIFACTORY_USERNAME is required"
    exit 1
fi
if [[ -z "${ARTIFACTORY_PASSWORD}" ]]; then
    logit "ERROR" "ARTIFACTORY_PASSWORD is required"
    exit 1
fi

logit "INFO" "action is all"
logit "INFO" "Helm dependency build"
get_chart_name
logit "INFO" "CHART_NAME: ${CHART_NAME}"
helm dependency build "${CHART_DIR}"
logit "INFO" "execute helm lint"
helm lint "${CHART_DIR}"
logit "INFO" "execute helm package"
helm package "${CHART_DIR}" --version v"${CHART_VERSION}" --app-version "${CHART_VERSION}" --destination "${CHART_OUTPUT_DIR}"
logit "INFO" "Push chart"
[[ ! -d "${CHART_OUTPUT_DIR}" ]] && mkdir -p "${CHART_OUTPUT_DIR}"
logit "DEBUG" "Pushing helm chart ${CHART_NAME} to repo ${ARTIFACTORY_PUSH_URL}"
helm push-artifactory "${CHART_DIR}" "${ARTIFACTORY_PUSH_URL}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}"
# pulling
#logit "INFO" "Adding ${ARTIFACTORY_PUSH_URL} as helm-repo"
#helm repo add helm-repo "${ARTIFACTORY_PULL_URL}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}"
#helm search repo 2>/dev/null
#helm search repo helm-repo 2>/dev/null
count=0
while [[ $count -lt ${HELM_PULL_RETRIES} ]]; do
    # where is the name of the chart?
    if helm pull --repo "${ARTIFACTORY_PULL_URL}" "${CHART_NAME}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}"; then
        logit "INFO" "helm pull is ok"
        break
    else
        logit "WARNING" "helm pull not ok, retry ${count} of ${HELM_PULL_RETRIES}"
    fi
    (( count=count+1 ))
    logit "DEBUG" "count: ${count}"
    sleep "${PULL_SLEEP_TIME}"
done
if [[ ${count} -eq ${HELM_PULL_RETRIES} ]]; then
    logit "ERROR" "could not pull chart: ${CHART_NAME} version: ${CHART_VERSION} from: ${ARTIFACTORY_PULL_URL} after ${HELM_PULL_RETRIES}"
    exit 1
else
    logit "INFO" "Done"
fi
