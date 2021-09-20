FROM alpine/helm:3.5.3

RUN apk add --no-cache git 
RUN helm plugin install https://github.com/belitre/helm-push-artifactory-plugin --version v1.0.2

COPY push_to_artifactory.sh /

ENTRYPOINT /push_to_artifactory.sh
