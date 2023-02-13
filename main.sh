#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail


SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")
export SCRIPT_DIR
source "$SCRIPT_DIR/common.sh"

install_helm
install_kubeval_plugin
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

        print_title "Helm kubeval"
        helm kubeval "${CHART_DIR}" --ignore-missing-schemas

        print_title "Helm package"
        helm package "${CHART_DIR}" --version v"${CHART_VERSION}" --app-version "${CHART_VERSION}" --destination "${RUNNER_WORKSPACE}"
        ;;
    "publish")
        print_title "Push chart"
        helm push-artifactory "${CHART_DIR}" "${ARTIFACTORY_URL}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}"
        ;;
    "publish-gar")
        print_title "Push chart on OCI registry"
        check_helm_version_gte_3_8

        # Check all google cloud related env variable have been provided
        [[ -z "$GAR_URL" ]] && (echo "GAR_URL env var is empty!"; exit 1)
        [[ -z "$GCLOUD_PROJECT" ]] && (echo "GCLOUD_PROJECT env var is empty!"; exit 1)
        [[ -z "$GAR_JSON_KEY" ]] && (echo "GAR_JSON_KEY env var is empty!"; exit 1)

        # check GCLOUD_PROJECT naming convention
        if [[ "$GCLOUD_PROJECT_CHECK" == "true" ]]; then
            if [[ ! "$GCLOUD_PROJECT" =~ gar-charts ]]; then
                echo "'$GCLOUD_PROJECT' is not a valid value for GCLOUD_PROJECT, expected a gar-charts suffix."
                exit 1
            fi
        fi

        # GAR_JSON_KEY <-- secrets.GAR_DEV_RW_JSON_KEY == "{\"foo\":\"bar\"}"
        echo "$GAR_JSON_KEY" \
            | helm registry login -u _json_key --password-stdin "https://${GAR_URL}"

        output=$(helm package "${CHART_DIR}" --destination /tmp)
        # shellcheck disable=SC2181
        if [[ "$?" -ne "0" ]]; then
            echo "Failed to package chart located at dir $CHART_DIR"
            exit 1
        fi
        CHART_LOCATION=$(echo "$output" | cut -d':' -f2 | tr -d '[:space:]')
        helm push "${CHART_LOCATION}" "oci://${GAR_URL}/${GCLOUD_PROJECT}/${CHART_PREFIX}"
        ;;
esac

remove_helm
