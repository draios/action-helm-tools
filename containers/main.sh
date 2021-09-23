#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")
export SCRIPT_DIR
source "$SCRIPT_DIR/common.sh"

# debugging is always useful
DEBUG=${DEBUG:-}
[[ -n "${DEBUG}" ]] && set -x

# arguments
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

# used in the secure-backend repo - to avoid having to make any change
ARTIFACTORY_CREDENTIALS_PSW=${ARTIFACTORY_CREDENTIALS_PSW:-}
ARTIFACTORY_CREDENTIALS_USR=${ARTIFACTORY_CREDENTIALS_USR:-}
if [[ -n "${ARTIFACTORY_CREDENTIALS_USR}" ]]; then
    ARTIFACTORY_USERNAME=${ARTIFACTORY_CREDENTIALS_USR}
fi
if [[ -n "${ARTIFACTORY_CREDENTIALS_PSW}" ]]; then
    ARTIFACTORY_PASSWORD=${ARTIFACTORY_CREDENTIALS_PSW}
fi
####################################################################



### main ##############
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

# extract the chat name to CHART_NAME
get_chart_name

logit "INFO" "execute helm dependency build CHART_NAME: ${CHART_NAME}"
helm dependency build "${CHART_DIR}"

logit "INFO" "execute helm lint with CHART_DIR: ${CHART_DIR}"
helm lint "${CHART_DIR}"

[[ ! -d "${CHART_OUTPUT_DIR}" ]] && mkdir -p "${CHART_OUTPUT_DIR}"
logit "INFO" "execute helm package with CHART_DIR: ${CHART_DIR} CHART_VERSION: ${CHART_VERSION}  CHART_OUTPUT_DIR: ${CHART_OUTPUT_DIR}"
helm package "${CHART_DIR}" --version "${CHART_VERSION}" --app-version "${CHART_VERSION}" --destination "${CHART_OUTPUT_DIR}"

logit "INFO" "Pushing helm chart ${CHART_NAME} to repo ${ARTIFACTORY_PUSH_URL}"
helm push-artifactory "${CHART_DIR}" "${ARTIFACTORY_PUSH_URL}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}"

logit "DEBUG" "Pulling helm chart ${CHART_NAME} from repo ${ARTIFACTORY_PULL_URL} with CHART_VERSION: ${CHART_VERSION}"
count=0
while [[ $count -lt ${HELM_PULL_RETRIES} ]]; do
    if helm pull --repo "${ARTIFACTORY_PULL_URL}" "${CHART_NAME}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}"; then
        logit "INFO" "helm pull is ok"
        break
    else
        logit "WARNING" "helm pull not ok, retrying ($(( count+1))/${HELM_PULL_RETRIES})"
    fi
    (( count=count+1 ))
    sleep "${PULL_SLEEP_TIME}"
done
if [[ ${count} -eq ${HELM_PULL_RETRIES} ]]; then
    logit "ERROR" "could not pull chart: ${CHART_NAME} version: ${CHART_VERSION} from: ${ARTIFACTORY_PULL_URL} after ${HELM_PULL_RETRIES}"
    exit 1
else
    logit "INFO" "Done"
fi
