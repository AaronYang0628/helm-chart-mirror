Suffered from slow downloading helm chart, I build this repo to speed it up

### Install Helm

Helm is a tool for managing Kubernetes charts. Charts are packages of pre-configured Kubernetes resources.

To install Helm, refer to the [Helm install guide](https://github.com/helm/helm#install) and ensure that the `helm` binary is in the `PATH` of your shell.

### Usage Helm Mirror

Once you have installed the Helm client, you can deploy a Helm Chart into a Kubernetes cluster.

Please refer to the [Quick Start guide](https://helm.sh/docs/intro/quickstart/) if you wish to get running in just a few commands, otherwise, the [Using Helm Guide](https://helm.sh/docs/intro/using_helm/) provides detailed instructions on how to use the Helm client to manage packages on your Kubernetes cluster.

Useful Helm Client Commands:

- Search a chart:
  ```shell
  helm repo add ay-helm-mirror https://aaronyang0628.github.io/helm-chart-mirror/charts
  helm repo update

  # helm search repo ay-helm-mirror
  # helm search repo nginx
  ```
- Download a chart: 
  ```shell
  helm pull --version 4.11.3 --repo https://aaronyang0628.github.io/helm-chart-mirror/charts ingress-nginx
  
  # you might wanna unzip chart file
  # tar -xvf ingress-nginx-4.11.3.tgz
  ```
- Install or update a chart: 
  ```shell
  helm upgrade  --create-namespace -n <$namespace> --install -f ./values.yaml ingress-nginx ay-helm-mirror/ingress-nginx --version=4.11.3
  ```

### Available Charts
- Argo
  - **argo-cd** version: `5.46.7`, `7.8.14`
- CnSRC
  - **gatekeeper** version: `0.2.0`
- K8s
  - bitnami
    - **common** version: `2.22.0`
    - **mariadb** version: `19.0.6`
  - **ingress-nginx** version: `4.11.3`
- Slurm
  - **slurm** version: `1.0.4`,`1.0.5`