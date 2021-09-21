#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail
set -x

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
ARTIFACTORY_URL=${ARTIFACTORY_URL:-https://artifactory.internal.sysdig.com:443/artifactory/helm-local/}
ARTIFACTORY_USERNAME=${ARTIFACTORY_USERNAME:-}
ARTIFACTORY_PASSWORD=${ARTIFACTORY_PASSWORD:-}
ARTIFACTORY_PULL_URL=${ARTIFACTORY_PULL_URL:-https://artifactory.internal.sysdig.com:443/artifactory/helm-local/}
TIMEOUT_PULL=${TIMEOUT_PULL:-5}
CHART_NAME=${CHART_NAME:-}

### main ##############
#install_helm
#install_artifactory_plugin
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

case "${ACTION}" in
    "all")
        logit "INFO" "action is all"
        logit "INFO" "Helm dependency build"
        get_chart_name
        logit "INFO" "CHART_NAME: ${CHART_NAME}"
        helm dependency build "${CHART_DIR}"
        logit "INFO" "Linting"
        helm lint "${CHART_DIR}"
        logit "INFO" "Helm package"
        helm package "${CHART_DIR}" --version v"${CHART_VERSION}" --app-version "${CHART_VERSION}" --destination "${CHART_OUTPUT_DIR}"
        logit "INFO" "Push chart"
        [[ ! -d "${CHART_OUTPUT_DIR}" ]] && mkdir -p "${CHART_OUTPUT_DIR}"
        echo helm push-artifactory "${CHART_DIR}" "${ARTIFACTORY_URL}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}"
        # pulling
        logit "INFO" "Adding ${ARTIFACTORY_URL} as helm-repo"
        helm repo add helm-repo "${ARTIFACTORY_URL}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}"
        helm search repo
        helm search repo helm-repo
        count=0
        while [[ $count -lt ${TIMEOUT_PULL} ]]; do
            # where is the name of the chart?
            if helm pull helm-repo/${CHART_NAME} --version "${CHART_VERSION}"; then
                logit "INFO" "helm pull is ok"
            else
                logit "WARNING" "helm pull not ok"
            fi
            (( count=count+1 ))
            logit "DEBUG" "count: ${count}"
            sleep 10
        done
        ;;
    "package")
        print_title "Helm dependency build"
        helm dependency build "${CHART_DIR}"

        print_title "Linting"
        helm lint "${CHART_DIR}"

        print_title "Helm package"
        helm package "${CHART_DIR}" --version v"${CHART_VERSION}" --app-version "${CHART_VERSION}" --destination "${RUNNER_WORKSPACE}"
        ;;
    "publish")
        print_title "Push chart"
        helm push-artifactory "${CHART_DIR}" "${ARTIFACTORY_URL}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}"
        ;;
esac

#remove_helm
