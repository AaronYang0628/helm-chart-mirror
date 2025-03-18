# helm chart mirror

Suffered from slow downloading helm chart, I build this repo to speed it up

## Before you begin

### Prerequisites

- Kubernetes 1.23+
- Helm 3.8.0+

### Setup a Kubernetes Cluster

The quickest way to set up a Kubernetes cluster to install Bitnami Charts is by following the "Bitnami Get Started" guides for the different services:

- [Get Started with Aaron Image Mirror using Minikube](https://aaronyang2333.gitlab.io/docs/kubernetes/cluster/minikube/index.html)

### Install Helm

Helm is a tool for managing Kubernetes charts. Charts are packages of pre-configured Kubernetes resources.

To install Helm, refer to the [Helm install guide](https://github.com/helm/helm#install) and ensure that the `helm` binary is in the `PATH` of your shell.

### Using Helm

Once you have installed the Helm client, you can deploy a Bitnami Helm Chart into a Kubernetes cluster.

Please refer to the [Quick Start guide](https://helm.sh/docs/intro/quickstart/) if you wish to get running in just a few commands, otherwise, the [Using Helm Guide](https://helm.sh/docs/intro/using_helm/) provides detailed instructions on how to use the Helm client to manage packages on your Kubernetes cluster.

Useful Helm Client Commands:

- Search a chart:
  ```shell
  helm repo add ay-helm-mirror https://aaronyang0628.github.io/helm-chart-mirror/charts
  helm repo update
  helm search repo nginx
  ```
- Download a chart: 
  ```shell
  helm pull --version 4.11.3 --repo https://aaronyang0628.github.io/helm-chart-mirror/charts/k8s ingress-nginx
  ```
- Install a chart: 
  ```shell
  helm repo add ay-helm-mirror https://aaronyang0628.github.io/helm-chart-mirror/charts
  helm install ingress-nginx ay-helm-mirror/k8s/ingress-nginx --version 4.11.3
  ```
- Upgrade your application: 
  ```shell
  helm upgrade ingress-nginx ay-helm-mirror/k8s/ingress-nginx
  ```
### Update mirror
1. upload `xxx.tgz` file to `charts` dir
2. run `helm repo index charts`