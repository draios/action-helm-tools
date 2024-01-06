#!/bin/bash -l
set -eo pipefail

export HELM_VERSION=${HELM_VERSION:="v3.13.3"}
export KUBECTL_VERSION=${KUBECTL_VERSION:="v1.28.0"}
export HELM_ARTIFACTORY_PLUGIN_VERSION=${HELM_ARTIFACTORY_PLUGIN_VERSION:="v1.0.2"}
export HELM_CHARTMUSEUM_PLUGIN_VERSION=${HELM_CHARTMUSEUM_PLUGIN_VERSION:="0.10.3"}
export CHART_VERSION=${CHART_VERSION:=""}
export CHART_APP_VERSION=${CHART_APP_VERSION:=""}
export DYFF_VERSION=${DYFF_VERSION:="1.6.0"}
export YQ_VERSION=${YQ_VERSION:="v4.40.5"}
export POLARIS_VERSION=${POLARIS_VERSION:="8.5.3"}
export KUBE_SCORE_VERSION=${KUBE_SCORE_VERSION:="1.17.0"}

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

    value=$(helm show chart "$dir" | grep "$property:" | sed "s#$property:##g" | tr -d '[:space:]')

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
    print_title "Installing helm:${HELM_VERSION}"
    ark get helm --version "${HELM_VERSION}" --quiet
    helm version --short -c
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

install_cmpush_plugin(){
    print_title "Install helm cm-push plugin"
    if ! (helm plugin list  | grep -q cm-push); then
	helm plugin install https://github.com/chartmuseum/helm-push --version ${HELM_CHARTMUSEUM_PLUGIN_VERSION}
    fi
}

remove_helm(){
    helm plugin uninstall push-artifactory
    helm plugin uninstall cm-push
    # sudo rm -rf /usr/local/bin/helm
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

install_dyff() {
    if ! command -v dyff; then
        echo "dyff is missing"
        get_dyff
    elif ! [[ $(dyff version) == *${DYFF_VERSION}* ]]; then
        echo "dyfff $(dyff version) is not desired version"
        get_dyff
    fi
}

get_dyff() {
    print_title "Installing dyff:${DYFF_VERSION}"
    curl -L "https://github.com/homeport/dyff/releases/download/v${DYFF_VERSION}/dyff_${DYFF_VERSION}_linux_amd64.tar.gz" | tar xvz
    chmod +x dyff
    sudo mv dyff /usr/local/bin/dyff
}

install_polaris() {
    if ! command -v polaris; then
        print_title "Installing polaris:${POLARIS_VERSION}"
        ark get polaris  --version "${POLARIS_VERSION}" --quiet
    fi
    polaris version
    if ! command -v kube-score; then
        print_title "Installing kube-score:${POLARIS_VERSION}"
        curl -L "https://github.com/zegl/kube-score/releases/download/v${KUBE_SCORE_VERSION}/kube-score_${KUBE_SCORE_VERSION}_linux_amd64.tar.gz" | tar xvz
        chmod +x kube-score
        sudo mv kube-score /usr/local/bin/kube-score
    fi
    kube-score version
}

install_yq() {
    if ! command -v yq; then
        print_title "Installing yq:${YQ_VERSION}"
        ark get yq  --version "${YQ_VERSION}" --quiet
    fi
    yq --version
}

install_ark() {
    if ! command -v ark; then
        echo "ark is missing"
        curl -sLS https://get.arkade.dev | sudo sh
    fi 
    export PATH=$PATH:$HOME/.arkade/bin/
}

remove_ark() {
    rm -f $HOME/.arkade/bin/*
}

safe_exec(){
    start=$(date +%s)
    $@
    end=$(date +%s)
    echo "Elapsed time for executing $@: $(($end-$start)) seconds"
}

send_github_comments() {
    if [[ -z "${2}" ]]; then
        printf "No data passed. Skipping posting comments"
        exit 0
    fi
    COMMENT="#### $1 Output
<details>
<summary>Details</summary>

$2
</details>"

        PAYLOAD=$(echo '{}' | jq --arg body "$COMMENT" '.body = $body')
        COMMENTS_URL=$(cat "$GITHUB_EVENT_PATH" | jq -r .pull_request.comments_url)
        echo "Commenting on PR $COMMENTS_URL"
        curl --silent -X POST \
          --header 'content-type: application/json' \
          --header  "Authorization: token $GITHUB_TOKEN" \
          --data "$PAYLOAD" "$COMMENTS_URL" > /dev/null
        exit 0 
}