# Azure Kubernetes Service (AKS) and kubectl Demo

This demo uses **Azure CLI** and **PowerShell** to create an Azure Kubernetes Service (AKS) cluster, configure local `kubectl` access, and confirm that the cluster is reachable.

The accompanying script is [`aks.ps1`](aks.ps1). It is intended for a beginner-friendly presentation; it is **not** a production AKS deployment template.

The folder also includes [`hello-nginx.yaml`](hello-nginx.yaml), a sample web app to deploy once the cluster is running. See [hello-nginx.md](hello-nginx.md) for a full explanation.

## What the script does

1. Generates a random four-digit suffix for resource names.
2. Installs `kubectl` and `kubelogin` using `az aks install-cli`, then checks the `kubectl` client version.
3. Creates an Azure resource group in `eastus`, tagged `env=demo`.
4. Creates a **two-node** AKS cluster using the `Standard_D4s_v3` node VM size and a managed identity.
5. Downloads cluster credentials into the local Kubernetes configuration using `az aks get-credentials`.
6. Displays the active Kubernetes context and cluster information.
7. Prints the resource group cleanup command. **It does not automatically delete any resources.**

## Prerequisites

- An Azure subscription with permission to create resource groups and AKS clusters.
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed.
- PowerShell 7 or Windows PowerShell.
- Internet access and sufficient regional VM quota for **two `Standard_D4s_v3` nodes** (8 vCPUs in total), as well as any other required cluster resources.
- Permission to install `kubectl` and `kubelogin` locally. Depending on your machine and install path, you may need an elevated terminal.

Sign in to Azure and select the subscription you want to use:

```powershell
az login
az account show --output table

# Optional: select a different subscription
az account set --subscription "<subscription-id-or-name>"
```

## Run the demo

Open PowerShell in the directory containing `aks.ps1` and run:

```powershell
.\aks.ps1
```

The script starts with these settings:

```powershell
$randomString = Get-Random -Minimum 1000 -Maximum 9999
$location = "eastus"
$resourceGroup = "rg-aks-$randomString"
$aksName = "aks-$randomString"
$nodeVM = "Standard_D4s_v3"
```

You can change `$location` and `$nodeVM` before running the script. Resource names will be different each time because of the random suffix.

**Note:** The script creates the cluster using default AKS settings with Kubernetes RBAC. It does not enable Microsoft Entra ID integration or Azure RBAC for Kubernetes authorization.

## Useful kubectl commands after deployment

```powershell
# Confirm the current cluster context
kubectl config current-context

# Check cluster access
kubectl cluster-info

# List worker nodes
kubectl get nodes

# Explore namespaces
kubectl get namespaces

# Show pods across all namespaces
kubectl get pods --all-namespaces
```

### Optional: deploy the hello-nginx sample app

[`hello-nginx.yaml`](hello-nginx.yaml) creates a `demo` namespace, two nginx pods that show which pod served the page, and a public `LoadBalancer` Service. It is **not** applied by `aks.ps1`:

```powershell
kubectl apply -f hello-nginx.yaml
kubectl get pods -n demo
kubectl get service hello-nginx -n demo --watch   # wait for EXTERNAL-IP, then browse to http://<EXTERNAL-IP>

# Remove the sample app
kubectl delete -f hello-nginx.yaml
```

See [hello-nginx.md](hello-nginx.md) for an object-by-object walkthrough, demo ideas, and troubleshooting.

### Optional: deploy a sample application imperatively

The following commands are **not** executed by `aks.ps1`; they are optional exercises for the presentation:

```powershell
kubectl create deployment nginx-demo --image=nginx:stable
kubectl get deployments
kubectl get pods

# Scale the deployment
kubectl scale deployment nginx-demo --replicas=2
kubectl get pods

# Remove the sample application
kubectl delete deployment nginx-demo
```

## Troubleshooting

**VM size not allowed or unavailable:** VM-size availability varies by region, subscription, quota, and capacity. Check the available SKUs for your subscription:

```powershell
az vm list-skus --location eastus --resource-type virtualMachines --size Standard_D4s_v3 --output table
```

If that SKU is restricted, change `$nodeVM` to a permitted, AKS-supported system node pool size or choose another region. A SKU with no listed restriction is not a guarantee of deployable capacity. Also check your regional vCPU quota.

**`az aks install-cli` fails:** Check local installation permissions and ensure the installed `kubectl` location is on your `PATH`. You may need to restart your PowerShell session after installation.

**`kubectl` cannot connect:** Confirm that `az aks create` succeeded and run the following with your actual resource group and AKS names:

```powershell
az aks get-credentials --resource-group <resource-group-name> --name <aks-name>
kubectl config current-context
kubectl get nodes
```

**Subscription or authorization errors:** Verify the selected subscription with `az account show` and make sure your account has the necessary permissions and quotas.

## Cleanup — important

**AKS nodes and other Azure resources may incur charges while they exist.** The script only **prints** the cleanup command; you must execute it yourself when finished:

```powershell
az group delete --name <resource-group-name> --yes --no-wait
```

Replace `<resource-group-name>` with the name shown when the script created the resource group (for example, `rg-aks-1234`). The `--no-wait` option submits the deletion without waiting for it to finish.

If you are still in the **same PowerShell session** and ran the script using dot-sourcing (`. .\aks.ps1`), you can use `$resourceGroup` directly. Otherwise, use the actual resource group name printed during setup.

> **Warning:** Deleting the resource group permanently deletes **all resources inside it**, not just the AKS cluster. Confirm you selected the demo resource group.

You can check the status afterward:

```powershell
az group exists --name <resource-group-name>
```

A result of `false` indicates the resource group no longer exists.

## References

- [AKS quickstart using Azure CLI](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli)
- [Install kubectl and kubelogin for AKS](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli#connect-to-the-cluster)
- [Azure CLI `az aks` commands](https://learn.microsoft.com/en-us/cli/azure/aks)
- [Kubernetes kubectl reference](https://kubernetes.io/docs/reference/kubectl/)

