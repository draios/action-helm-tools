set -o errexit
set -o nounset
set -o pipefail

export SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")

source $SCRIPT_DIR/common.sh

install_yq
install_helm
install_artifactory_plugin
get_chart_version

set -x

case $INPUT_ACTION in
    "package")
        echo "==> Helm dependency build"
        helm dependency build ${CHART_DIR}

        echo "==> Linting"
        helm lint ${CHART_DIR}

        echo "==> Helm package"
        helm package ${CHART_DIR} --version v${CHART_VERSION} --app-version ${CHART_VERSION} --destination ${RUNNER_WORKSPACE}
        ;;
    "publish")
        echo "==> Push chart"
        helm push-artifactory ${CHART_DIR} ${ARTIFACTORY_URL} --username ${ARTIFACTORY_USERNAME} --password ${ARTIFACTORY_PASSWORD} --version "${CHART_VERSION}"
        ;;
esac
