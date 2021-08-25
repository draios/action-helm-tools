#!/bin/bash -l
set -eo pipefail

export HELM_VERSION=${HELM_VERSION:="3.5.1"}
export KUBECTL_VERSION=${KUBECTL_VERSION:="1.21.0"}
export HELM_ARTIFACTORY_PLUGIN_VERSION=${HELM_ARTIFACTORY_PLUGIN_VERSION:="v1.0.2"}
export K3S_VERSION=${K3S_VERSION:="v0.9.1"}
export K3D_WAIT=${K3D_WAIT:="90"}
export K3D_NAME=${K3D_NAME:="test"}

print_title(){
    echo "#####################################################"
    echo "$1"
    echo "#####################################################"
}

install_yq(){
    print_title "Install yq"
    sudo apt-get install jq
    pip3 install yq
}

get_chart_version(){
    print_title "Calculating chart version"
    CANDIDATE_VERSION=$(yq -r '.version' $CHART_DIR/Chart.yaml)
    echo "${GITHUB_EVENT_NAME}"
    if [ "${GITHUB_EVENT_NAME}" == "pull_request" ]; then
        export CHART_VERSION="${CANDIDATE_VERSION}-$(git rev-parse --short "$GITHUB_SHA")"
    else
        export CHART_VERSION="${CANDIDATE_VERSION}"
    fi
}

install_k3d(){
    print_title "Get k3d"
    curl -s https://raw.githubusercontent.com/rancher/k3d/master/install.sh | bash
}

install_kubectl() {
    print_title "Get kubectl:${KUBECTL_VERSION}"
    curl -LO https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
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

install_jfrog() {
    if ! command -v jfrog; then
        print_title "Installing jfrog cli"
        curl -Lo ./jfrog https://api.bintray.com/content/jfrog/jfrog-cli-go/\$latest/jfrog-cli-linux-amd64/jfrog?bt_package=jfrog-cli-linux-amd64
        chmod +x ./jfrog
        sudo mv ./jfrog /usr/local/bin/jfrog
    fi
}

install_artifactory_plugin(){
    print_title "Install helm artifactory plugin"
    helm plugin install https://github.com/belitre/helm-push-artifactory-plugin --version ${HELM_ARTIFACTORY_PLUGIN_VERSION}
}

create_k3d_cluster() {
    print_title "create K3s cluster"
    k3d create --name $K3D_NAME --image rancher/k3s:$K3S_VERSION --wait $K3D_WAIT
    export KUBECONFIG="$(k3d get-kubeconfig --name=$K3D_NAME)"
}
