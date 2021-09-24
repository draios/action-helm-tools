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

############################ main ############################################
logit "INFO" "Starting"
check_arguments

# extract the chart name to CHART_NAME
get_chart_name

logit "INFO" "execute helm dependency build CHART_NAME: ${CHART_NAME}"
helm dependency build "${CHART_DIR}"

logit "INFO" "execute helm lint with CHART_DIR: ${CHART_DIR}"
helm lint "${CHART_DIR}"

[[ ! -d "${CHART_OUTPUT_DIR}" ]] && mkdir -p "${CHART_OUTPUT_DIR}"
logit "INFO" "execute helm package with CHART_DIR: ${CHART_DIR} CHART_VERSION: ${CHART_VERSION}  CHART_OUTPUT_DIR: ${CHART_OUTPUT_DIR}"
helm package "${CHART_DIR}" --version "${CHART_VERSION}" --app-version "${CHART_VERSION}" --destination "${CHART_OUTPUT_DIR}"

logit "INFO" "Pushing helm chart ${CHART_NAME} to repo ${ARTIFACTORY_PUSH_URL}"
helm push-artifactory "${CHART_DIR}" "${ARTIFACTORY_PUSH_URL}" --username "${ARTIFACTORY_USER}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}"

if [[ -n "${WAIT_FOR_CHART}" && "${WAIT_FOR_CHART}" == "no" ]]; then
    logit "WARNING" "skipping pull chart check because WAIT_FOR_CHART = no"
    exit 0
fi

logit "INFO" "Pulling helm chart ${CHART_NAME} from repo ${ARTIFACTORY_PULL_URL} with CHART_VERSION: ${CHART_VERSION}"
count=0
while [[ $count -lt ${HELM_PULL_RETRIES} ]]; do
    if helm pull --repo "${ARTIFACTORY_PULL_URL}" "${CHART_NAME}" --username "${ARTIFACTORY_USER}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}"; then
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
