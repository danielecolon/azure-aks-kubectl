# 1. Set variables
$randomString = Get-Random -Minimum 1000 -Maximum 9999
$location = "eastus"
$resourceGroup = "rg-aks-$randomString"
$aksName = "aks-$randomString"
$nodeVM = "Standard_D4s_v3"

# The default AKS configuration uses Kubernetes RBAC. This example does not enable Microsoft Entra ID authentication or Azure RBAC for Kubernetes authorization.
# 0. Install kubectl
# Install kubectl and kubelogin using Azure CLI.
az aks install-cli
Write-Host ""

# Verify installation:
kubectl version --client
Write-Host ""

# 1. Create resource group
az group create --name $resourceGroup --location $location --tags env=demo --query "name" --output tsv
Write-Host ""

# 2. Create AKS cluster
# This creates a two-node AKS cluster with managed identity and Azure RBAC integration disabled for simplicity.
az aks create --resource-group $resourceGroup --name $aksName --node-count 2 --node-vm-size $nodeVM --enable-managed-identity --generate-ssh-keys --query "name" --output tsv
Write-Host ""

# 3. Configure kubectl access to AKS
# Download the cluster credentials and merge them into your local kubeconfig file (~/.kube/config).
az aks get-credentials --resource-group $resourceGroup --name $aksName
Write-Host ""

# Verify the active Kubernetes context:
kubectl config current-context
Write-Host ""

# 4. Verify cluster connectivity
# Display cluster information:
kubectl cluster-info
Write-Host ""

Write-Host ""
Write-Host "`nMake sure to delete your resource group when you are done with this demo so you don't continue to be charged." -ForegroundColor Yellow
Write-Host "Run this command:" -ForegroundColor Cyan
Write-Host "az group delete --name $resourceGroup --yes --no-wait" -ForegroundColor Green