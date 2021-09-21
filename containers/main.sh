#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")
export SCRIPT_DIR
source "$SCRIPT_DIR/common.sh"

# optional arguments
CHART_VERSION_EXT=${CHART_VERSION_EXT:-}
WAIT_FOR_CHART=${WAIT_FOR_CHART:-"false"}
HELM_REPO_URL=${HELM_REPO_URL:-}
ACTION=${ACTION:-"all"}

### main ##############
install_helm
install_artifactory_plugin
if [[ -z "${CHART_VERSION_EXT}" ]]; then
    get_chart_version
else
    logit "INFO" "using CHART_VERSION: ${CHART_VERSION_EXT}"
    CHART_VERSION=${CHART_VERSION_EXT}
fi

case "${ACTION}" in
    "all")
        logit "INFO" "action is all"
        print_title "Helm dependency build"
        helm dependency build "${CHART_DIR}"
        print_title "Linting"
        helm lint "${CHART_DIR}"
        print_title "Helm package"
        helm package "${CHART_DIR}" --version v"${CHART_VERSION}" --app-version "${CHART_VERSION}" --destination "${RUNNER_WORKSPACE}"
        print_title "Push chart"
        helm push-artifactory "${CHART_DIR}" "${ARTIFACTORY_URL}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}"
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

remove_helm
