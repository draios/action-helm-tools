#!/bin/bash -l
set -eo pipefail

export HELM_VERSION=${HELM_VERSION:="3.5.1"}
export KUBECTL_VERSION=${KUBECTL_VERSION:="1.21.0"}
export HELM_ARTIFACTORY_PLUGIN_VERSION=${HELM_ARTIFACTORY_PLUGIN_VERSION:="v1.0.2"}

print_title(){
    echo "#####################################################"
    echo "$1"
    echo "#####################################################"
}

logit(){
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") - ${1} - ${2}"
}

get_chart_version(){
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

get_chart_name(){
    logit "INFO" "Calculating chart version"
	logit "INFO" "Installing prerequisites"
	pip3 install PyYAML
    pushd "$CHART_DIR"
    CHART_NAME=$(python3 -c "import yaml; f=open('Chart.yaml','r');  p=yaml.safe_load(f.read()); print(p['name']); f.close()" )
    popd
    export CHART_NAME
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
