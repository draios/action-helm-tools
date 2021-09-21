FROM docker.internal.sysdig.com/sysdig-mini-ubi:1.1.10

RUN microdnf --setopt=tsflags=nodocs --disableplugin=subscription-manager install openssl tar gzip which git && \     
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh && \
    helm plugin install https://github.com/belitre/helm-push-artifactory-plugin --version v1.0.2 && \
    rm -rf get_helm.sh

COPY main.sh common.sh /

ENTRYPOINT /main.sh
