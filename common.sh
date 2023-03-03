#!/bin/bash -l
set -eo pipefail

export HELM_VERSION=${HELM_VERSION:="3.5.1"}
export KUBECTL_VERSION=${KUBECTL_VERSION:="1.21.0"}
export HELM_ARTIFACTORY_PLUGIN_VERSION=${HELM_ARTIFACTORY_PLUGIN_VERSION:="v1.0.2"}
export CHART_VERSION=${CHART_VERSION:=""}
export CHART_APP_VERSION=${CHART_APP_VERSION:=""}

export GCLOUD_PROJECT_CHECK=${GCLOUD_PROJECT_CHECK:="true"}

print_title(){
    echo "#####################################################"
    echo "$1"
    echo "#####################################################"
}

function helm_show(){
    local dir="$1"
    local property="$2"

    local value=""

    value=$(helm show chart "$dir" | grep -E "^$property:" | head -1 | sed "s#$property:##g" | tr -d '[:space:]')

    [[ -n "$value" ]] && echo "$value" || echo "UNSET"
}

get_chart_version(){
    if [ -n "$CHART_VERSION" ]; then
        echo "CHART_VERSION variable is already set (value: $CHART_VERSION), will override Chart.yaml"
        return
    fi
    print_title "Calculating chart version"
	echo "Installing prerequisites"
	pip3 install PyYAML
    pushd "$CHART_DIR"
    CANDIDATE_VERSION=$(python3 -c "import yaml; f=open('Chart.yaml','r');  p=yaml.safe_load(f.read()); print(p['version']); f.close()" )
    popd
    echo "${GITHUB_EVENT_NAME}"
    if [ "${GITHUB_EVENT_NAME}" == "pull_request" ]; then
        CHART_VERSION="${CANDIDATE_VERSION}-$(git rev-parse --short "$GITHUB_SHA")"
    else
        CHART_VERSION="${CANDIDATE_VERSION}"
    fi
    export CHART_VERSION
}

get_helm() {
    print_title "Get helm:${HELM_VERSION}"
    curl -L "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar xvz
    chmod +x linux-amd64/helm
    sudo mv linux-amd64/helm /usr/local/bin/helm
}

install_helm() {
    if ! command -v helm; then
        echo "Helm is missing"
        get_helm
    elif ! [[ $(helm version --short -c) == *${HELM_VERSION}* ]]; then
        echo "Helm $(helm version --short -c) is not desired version"
        get_helm
    fi
}

install_kubeval_plugin(){
    print_title "Install kubeval plugin"
    if ! (helm plugin list  | grep -q kubeval); then
        helm plugin install https://github.com/instrumenta/helm-kubeval
    fi
}

install_artifactory_plugin(){
    print_title "Install helm artifactory plugin"
    if ! (helm plugin list  | grep -q push-artifactory); then
        helm plugin install https://github.com/belitre/helm-push-artifactory-plugin --version ${HELM_ARTIFACTORY_PLUGIN_VERSION}
    fi
}

remove_helm(){
    helm plugin uninstall push-artifactory
    sudo rm -rf /usr/local/bin/helm
}

function version {
    echo "$@" | tr -cd '[:digit:].' | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}

check_helm_version_gte_3_8(){
    current_helm_version=$(helm version --short -c | cut -d '+' -f1)
    if [[ $(version "$current_helm_version") -lt $(version "3.8.0") ]]; then
        echo "Required helm version a least 3.8.0 currently running '${current_helm_version}'."
        exit 1
    fi
}
