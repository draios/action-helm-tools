#!/bin/bash

helm push-artifactory /charts/helm/ https://artifactory.internal.sysdig.com:443/artifactory/helm-local/ --username "${ARTIFACTORY_USER}" --password "${ARTIFACTORY_PASSWORD}" --version "${CHART_VERSION}"
