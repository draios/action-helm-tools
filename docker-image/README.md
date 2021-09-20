# Push helm charts to Artifactory

- a docker image to push Helm charts to Artifactory

## Arguments


## Checks


## Notes

### Current usage

- who/what/where is using this right now? make a list

### pushing vs packaging vs linting etc

- right now the script only does a `push-artifactory` of the Chart

- can the extra feature of the host tool (`dependency build`, `lint`, `package`) be added? 
    - what's the impact on existing users?



### UBI image

- the Docker base image must be one of the new UBI image

### Additional arguments

- add the following optional arguments

    - Chart version
    - Helm repo to pull the chart from

#### More on the additional arguments

- the script must have an optional argument for Chart version

    - this value takes precedence over the current extraction of the values from `Chart.yaml`

- after pushing the image, the script must start a retried attempt (with timeout) to pull the Chart from the Helm repo

    - the Helm repo used to pull can be passed as an optional argument

