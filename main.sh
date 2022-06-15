#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail


SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")
export SCRIPT_DIR
source "$SCRIPT_DIR/common.sh"

install_helm
install_artifactory_plugin
get_chart_version

case "${ACTION}" in
    "package")
        print_title "Helm dependency build"
        helm dependency build "${CHART_DIR}"

        print_title "Linting"
        if [[ -f "${CHART_DIR}/linter_values.yaml" ]]; then
            # allow for the same yaml layout that is used by gruntwork-io/pre-commit helmlint.sh
            helm lint -f "${CHART_DIR}/values.yaml" -f "${CHART_DIR}/linter_values.yaml" "${CHART_DIR}"
        else
            helm lint "${CHART_DIR}"
        fi

        print_title "Helm package"
        helm package "${CHART_DIR}" --version v"${CHART_VERSION}" --app-version "${CHART_VERSION}" --destination "${RUNNER_WORKSPACE}"
        ;;
    "publish")
        print_title "Push chart"
        helm push-artifactory "${CHART_DIR}" "${ARTIFACTORY_URL}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}"
        ;;
esac

remove_helm
