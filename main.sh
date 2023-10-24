#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

DEBUG=${DEBUG:-}
[[ -n "${DEBUG}" ]] && set -x

SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")
export SCRIPT_DIR
source "$SCRIPT_DIR/common.sh"

install_helm
install_artifactory_plugin
install_cmpush_plugin
get_chart_version
install_dyff

case "${ACTION}" in
    "pre-commit")
        print_title "Helm dependency build"
        helm dependency build "${CHART_DIR}"

        print_title "Linting"
        if [[ -f "${CHART_DIR}/linter_values.yaml" ]]; then
            # allow for the same yaml layout that is used by gruntwork-io/pre-commit helmlint.sh
            helm lint -f "${CHART_DIR}/values.yaml" -f "${CHART_DIR}/linter_values.yaml" "${CHART_DIR}"
        else
            helm lint "${CHART_DIR}"
        fi

        print_title "Helm diff"
        git fetch -a
        # checkout upstream
        echo git checkout -b upstream_branch origin/"${UPSTREAM_BRANCH}"
        git checkout -b upstream_branch origin/"${UPSTREAM_BRANCH}"
        if [[ -f "${CHART_DIR}/chart.yaml" ]]; then
            # chart does not exists
            helm template "${CHART_DIR}" > /tmp/upstream_values.yaml
        else
            touch /tmp/upstream_values.yaml
        fi
        print_title "upstream values"
        cat /tmp/upstream_values.yaml

        # checkout current
        echo git checkout -b current_branch origin/"${CURRENT_BRANCH}"
        git checkout -b current_branch origin/"${CURRENT_BRANCH}"
        if [[ -f "${CHART_DIR}/chart.yaml" ]]; then
            # chart does not exists
            echo foo
            helm template "${CHART_DIR}" > /tmp/current_values.yaml
        else
            touch /tmp/current_values.yaml
        fi
        print_title "Current values"
        cat /tmp/currernt_values.yaml
        # Compute diff between two releases
        set +e
        OUTPUT=$(sh -c "dyff between /tmp/upstream_values.yaml /tmp/current_values.yaml" 2>&1)
        if [ $? -ge 2 ]; then
            diff /tmp/upstream_values.yaml /tmp/current_values.yaml
        fi
        SUCCESS=$?
        echo "$OUTPUT"
        set -e

        # COMMENT STRUCTURE
        COMMENT="#### \`helm diff \` Output
        <details>
        <summary>Details</summary>
        \`\`\`
        $OUTPUT
        \`\`\`
        </details>"

        set -x
        cat << EOM > body.json
        {
          "body": "${COMMENT}"
        }
        EOM
        cat body.json
        ls -R /github

        curl --silent -X POST \
          --header 'content-type: application/json' \
          --header 'Authorization: Bearer ${{ secrets.GITHUB_TOKEN }}' \
          "https://api.github.com/repos/${{ github.repository }}/issues/${GITHUB_PR_NUMBER}/comments" \
          --data "@body.json"
        exit $SUCCESS
        ;;
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
    "publish-artifactory")
        print_title "Push chart to artifactory"
        helm push-artifactory "${CHART_DIR}" "${ARTIFACTORY_URL}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}"
        ;;
    "publish-chartmuseum")
        print_title "Push chart to chartmuseum"
        helm repo add amagi-charts "${ARTIFACTORY_URL}" --username "${ARTIFACTORY_USERNAME}" --password "${ARTIFACTORY_PASSWORD}"
        helm cm-push "${CHART_DIR}" amagi-charts || true
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

        SHOW_CHART_VERSION=$(helm_show "${CHART_DIR}" "version")
        SHOW_CHART_APP_VERSION=$(helm_show "${CHART_DIR}" "appVersion")

        if [[ -n "$CHART_VERSION" ]]; then
            echo "CHART_VERSION has been provided, packaging with this version: '${CHART_VERSION}'."
        else
            echo "CHART_VERSION was empty, packaging with version defined in Chart.yaml: '${SHOW_CHART_VERSION}'."
            CHART_VERSION="$SHOW_CHART_VERSION"
        fi

        if [[ -n "$CHART_APP_VERSION" ]]; then
            echo "CHART_APP_VERSION has been provided, packaging with this version: '${CHART_APP_VERSION}'."
        else
            if [[ "$SHOW_CHART_APP_VERSION" == "UNSET" ]]; then
                echo "SHOW_CHART_APP_VERSION was empty as well, packaging with default appVersion: '0.1.0'."
                CHART_APP_VERSION="0.1.0"
            else
                echo "CHART_APP_VERSION was empty, packaging with version defined in Chart.yaml: '${SHOW_CHART_APP_VERSION}'."
                CHART_APP_VERSION="$SHOW_CHART_APP_VERSION"
            fi
        fi

        echo "Started Packaging..."
        output=$( \
            helm package "${CHART_DIR}" \
                --destination /tmp \
                --version "$CHART_VERSION" \
                --app-version "$CHART_APP_VERSION")
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
