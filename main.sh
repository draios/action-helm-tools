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
    "lint")
        print_title "Helm dependency build"
        helm dependency build "${CHART_DIR}"

        print_title "Helm Linting"
        if [[ -f "${CHART_DIR}/linter_values.yaml" ]]; then
            # allow for the same yaml layout that is used by gruntwork-io/pre-commit helmlint.sh
            helm lint -f "${CHART_DIR}/values.yaml" -f "${CHART_DIR}/linter_values.yaml" "${CHART_DIR}"
        else
            helm lint "${CHART_DIR}"
        fi
        ;;
    "diff")
        print_title "Helm dependency build"
        helm dependency build "${CHART_DIR}"
        print_title "Computing Helm diff"
        git fetch -a
        
        if [[ -f "${CHART_DIR}/Chart.yaml" ]]; then
            helm template "${CHART_DIR}" > /tmp/current_values.yaml
        else
            ls "${CHART_DIR}" || true
            touch /tmp/current_values.yaml
            printf "\x1B[31m ChartFileDoesNotExists: Will create empty template\n"
        fi

        # checkout upstream
        echo git checkout -b upstream_branch origin/"${UPSTREAM_BRANCH}"
        git checkout -b upstream_branch origin/"${UPSTREAM_BRANCH}"
        if [[ -f "${CHART_DIR}/Chart.yaml" ]]; then
            # chart does not exists
            helm template "${CHART_DIR}" > /tmp/upstream_values.yaml
        else
            ls "${CHART_DIR}" || true
            touch /tmp/upstream_values.yaml
            printf "\x1B[31m ChartFileDoesNotExists: Will create empty template\n"
        fi
        
        # Compute diff between two releases
        set +e
        OUTPUT=$(sh -c "dyff between /tmp/upstream_values.yaml /tmp/current_values.yaml -c on" 2>&1)
        OUTPUT1=$(sh -c "dyff between /tmp/upstream_values.yaml /tmp/current_values.yaml" 2>&1)
        if [ $? -ge 2 ]; then
            OUTPUT=$(sh -c "diff --color /tmp/upstream_values.yaml /tmp/current_values.yaml" 2>&1)
            OUTPUT1=$(sh -c "diff /tmp/ upstream_values.yaml /tmp/current_values.yaml" 2>&1)
        fi
        SUCCESS=$?
        set -e

        echo -e '\033[1mComputed Helm Diff\033[0m'
        printf "$OUTPUT\n"

        # COMMENT STRUCTURE
        COMMENT="#### \`Computed Helm Diff\` Output
        <details>
        <summary>Details</summary>
        $OUTPUT1
        </details>"
        PAYLOAD=$(echo '{}' | jq --arg body "$COMMENT" '.body = $body')

        COMMENTS_URL=$(cat "$GITHUB_EVENT_PATH" | jq -r .pull_request.comments_url)
        echo "Commenting on PR $COMMENTS_URL"
        curl --silent -X POST \
          --header 'content-type: application/json' \
          --header  "Authorization: token $GITHUB_TOKEN" \
          --data "$PAYLOAD" "$COMMENTS_URL"
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
