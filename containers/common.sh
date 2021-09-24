#!/bin/bash -l
set -eo pipefail

logit(){
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") - ${1} - ${2}"
}

get_chart_name(){
    logit "INFO" "Extracting chart name from Chart.yaml CHART_DIR=${CHART_DIR} PWD=${PWD}"
    pushd "${CHART_DIR}" >/dev/null
    CHART_NAME=$(python3 -c "import yaml; f=open('Chart.yaml','r');  p=yaml.safe_load(f.read()); print(p['name']); f.close()" )
    popd > /dev/null
    export CHART_NAME
}

check_arguments(){
    if [[ -z "${CHART_VERSION}" ]]; then
        logit "ERROR" "CHART_VERSION is required"
        exit 1
    fi
    if [[ -z "${ARTIFACTORY_USER}" ]]; then
        logit "ERROR" "ARTIFACTORY_USER is required"
        exit 1
    fi
    if [[ -z "${ARTIFACTORY_PASSWORD}" ]]; then
        logit "ERROR" "ARTIFACTORY_PASSWORD is required"
        exit 1
    fi
    if [[ -z "${ARTIFACTORY_PUSH_URL}" ]]; then
        logit "ERROR" "ARTIFACTORY_PUSH_URL is required"
        exit 1
    fi
    if [[ -z "${ARTIFACTORY_PULL_URL}" ]]; then
        logit "ERROR" "ARTIFACTORY_PULL_URL is required"
        exit 1
    fi
}
