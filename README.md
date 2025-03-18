# helm chart mirror


## Vulnerabilities scanner

Each Helm chart contains one or more containers. Those containers use images provided by Aaron through its test & release pipeline and whose source code can be found at [aaron/containers](https://github.com/bitnami/containers).

As part of the container releases, the images are scanned for vulnerabilities, [here](https://github.com/bitnami/containers#vulnerability-scan-in-bitnami-container-images) you can find more info about this topic.

Since the container image is an immutable artifact that is already analyzed, as part of the Helm chart release process we are not looking for vulnerabilities in the containers but running different verifications to ensure the Helm charts work as expected, see the testing strategy defined at [_TESTING.md_](https://github.com/AaronYang0628/charts/blob/main/TESTING.md).

## Before you begin

### Prerequisites

- Kubernetes 1.23+
- Helm 3.8.0+

### Setup a Kubernetes Cluster

The quickest way to set up a Kubernetes cluster to install Bitnami Charts is by following the "Bitnami Get Started" guides for the different services:

- [Get Started with Aaron Charts using Minikube](https://docs.bitnami.com/kubernetes/get-started-tkg/)

For setting up Kubernetes on other cloud platforms or bare-metal servers refer to the Kubernetes [getting started guide](https://kubernetes.io/docs/getting-started-guides/).

### Install Helm

Helm is a tool for managing Kubernetes charts. Charts are packages of pre-configured Kubernetes resources.

To install Helm, refer to the [Helm install guide](https://github.com/helm/helm#install) and ensure that the `helm` binary is in the `PATH` of your shell.

### Using Helm

Once you have installed the Helm client, you can deploy a Bitnami Helm Chart into a Kubernetes cluster.

Please refer to the [Quick Start guide](https://helm.sh/docs/intro/quickstart/) if you wish to get running in just a few commands, otherwise, the [Using Helm Guide](https://helm.sh/docs/intro/using_helm/) provides detailed instructions on how to use the Helm client to manage packages on your Kubernetes cluster.

Useful Helm Client Commands:

- Install a chart: `helm install my-release oci://registry-1.docker.io/aaronyang0628/<chart>`
- Upgrade your application: `helm upgrade my-release oci://registry-1.docker.io/aaronyang0628/<chart>`

## usage

1. pull charts
    * ```shell
      helm pull --version 4.11.3 --repo https://aaronyang0628.github.io/helm-chart-mirror/charts ingress-nginx
      ```
2. search for charts
    * ```shell
      helm repo add ay-helm-mirror https://aaronyang0628.github.io/helm-chart-mirror/charts
      helm search repo nginx
      ```
    * reference: https://helm.sh/docs/helm/helm_search_repo