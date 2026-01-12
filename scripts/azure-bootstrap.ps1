[CmdletBinding()]
param(
    # Azure subscription to create resource groups and role assignments in.
    [Parameter()] [string] $SubscriptionId,

    # Azure region used when creating new resource groups (not the Postgres location; that's passed at deploy time).
    [Parameter()] [string] $ResourceGroupLocation = 'eastus',

    # Resource group names used by this demo.
    [Parameter()] [string] $CommercialResourceGroupName = 'commercial',
    [Parameter()] [string] $RetailResourceGroupName = 'retail',
    [Parameter()] [string] $OperationsResourceGroupName = 'operations',

    # Service principal name to create for Radius.
    [Parameter()] [string] $ServicePrincipalName = 'radius-demo-sp',

    # Role assigned to the service principal at each RG scope.
    [Parameter()] [string] $Role = 'Contributor',

    # Optional: create a basic AKS cluster for the Kubernetes-on-Azure scenario.
    [Parameter()] [switch] $CreateAks,
    [Parameter()] [string] $AksClusterName = 'radius-demo-aks',
    [Parameter()] [string] $AksResourceGroupName,
    [Parameter()] [string] $AksLocation,
    [Parameter()] [int] $AksNodeCount = 1,
    [Parameter()] [string] $AksNodeVmSize = 'Standard_DS2_v2',
    [Parameter()] [switch] $GetAksCredentials,

    # If set, skip creating the service principal (still creates RGs and registers providers).
    [Parameter()] [switch] $SkipServicePrincipal,

    # If set, skip Azure resource provider registration.
    [Parameter()] [switch] $SkipProviderRegistration
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Command {
    param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter()] [string] $InstallHint
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        $msg = "Missing required command '$Name'."
        if ($InstallHint) { $msg += " $InstallHint" }
        throw $msg
    }
}

function Invoke-Logged {
    param(
        [Parameter(Mandatory = $true)] [string] $Command
    )

    Write-Host "> $Command" -ForegroundColor DarkGray
    Invoke-Expression $Command
}

function Ensure-AzureLogin {
    Assert-Command -Name az -InstallHint 'Install Azure CLI (az) and sign in (az login).'

    try {
        $null = az account show -o none
    }
    catch {
        throw "Azure CLI is not signed in. Run 'az login' then re-run this script."
    }
}

function Ensure-Subscription([string] $SubId) {
    if ($SubId) {
        Invoke-Logged "az account set --subscription $SubId"
    }

    $current = (az account show --query id -o tsv)
    if (-not $current) {
        throw 'Unable to determine Azure subscription ID. Provide -SubscriptionId or run az login.'
    }

    return $current
}

function Ensure-ProviderRegistered([string] $Namespace) {
    $state = (az provider show --namespace $Namespace --query registrationState -o tsv 2>$null)
    if ($state -ne 'Registered') {
        Invoke-Logged "az provider register --namespace $Namespace"
    }
}

function Ensure-AksCluster {
    param(
        [Parameter(Mandatory = $true)] [string] $ClusterName,
        [Parameter(Mandatory = $true)] [string] $ResourceGroupName,
        [Parameter(Mandatory = $true)] [string] $Location,
        [Parameter(Mandatory = $true)] [int] $NodeCount,
        [Parameter(Mandatory = $true)] [string] $NodeVmSize
    )

    # If cluster exists, skip creation.
    $existing = $null
    try {
        $existing = az aks show --name $ClusterName --resource-group $ResourceGroupName -o json 2>$null
    }
    catch {
        $existing = $null
    }

    if ($existing) {
        return
    }

    # Minimal, demo-friendly cluster. Uses a system-assigned managed identity.
    # Note: this is not production-hardened.
    Invoke-Logged "az aks create --name $ClusterName --resource-group $ResourceGroupName --location $Location --node-count $NodeCount --node-vm-size $NodeVmSize --generate-ssh-keys --enable-managed-identity -o none"
}

function Ensure-ResourceGroup([string] $Name, [string] $Location) {
    $exists = (az group exists --name $Name) | ConvertFrom-Json
    if (-not $exists) {
        Invoke-Logged "az group create --name $Name --location $Location -o none"
    }
}

function Get-ResourceGroupId([string] $SubId, [string] $RgName) {
    return "/subscriptions/$SubId/resourceGroups/$RgName"
}

Ensure-AzureLogin
$subId = Ensure-Subscription -SubId $SubscriptionId

if (-not $AksResourceGroupName) {
    $AksResourceGroupName = $CommercialResourceGroupName
}
if (-not $AksLocation) {
    $AksLocation = $ResourceGroupLocation
}
if (-not $GetAksCredentials) {
    $GetAksCredentials = $CreateAks
}

if (-not $SkipProviderRegistration) {
    Write-Host "Registering required Azure resource providers (idempotent)..." -ForegroundColor Cyan
    Ensure-ProviderRegistered -Namespace 'Microsoft.DBforPostgreSQL'
    Ensure-ProviderRegistered -Namespace 'Microsoft.ContainerInstance'
    if ($CreateAks) {
        Ensure-ProviderRegistered -Namespace 'Microsoft.ContainerService'
    }
}

Write-Host "Ensuring resource groups exist (idempotent)..." -ForegroundColor Cyan
Ensure-ResourceGroup -Name $CommercialResourceGroupName -Location $ResourceGroupLocation
Ensure-ResourceGroup -Name $RetailResourceGroupName -Location $ResourceGroupLocation
Ensure-ResourceGroup -Name $OperationsResourceGroupName -Location $ResourceGroupLocation

if ($CreateAks) {
    Write-Host "Ensuring AKS resource group exists (idempotent)..." -ForegroundColor Cyan
    Ensure-ResourceGroup -Name $AksResourceGroupName -Location $AksLocation

    Write-Host "Ensuring AKS cluster exists (idempotent)..." -ForegroundColor Cyan
    Ensure-AksCluster -ClusterName $AksClusterName -ResourceGroupName $AksResourceGroupName -Location $AksLocation -NodeCount $AksNodeCount -NodeVmSize $AksNodeVmSize

    if ($GetAksCredentials) {
        Assert-Command -Name kubectl -InstallHint 'Install kubectl to fetch AKS credentials and interact with the cluster.'
        Invoke-Logged "az aks get-credentials --name $AksClusterName --resource-group $AksResourceGroupName --overwrite-existing"
        Write-Host "\nAKS context is now configured. Verify with: kubectl get nodes" -ForegroundColor Green
    }
}

$commercialRgId = Get-ResourceGroupId -SubId $subId -RgName $CommercialResourceGroupName
$retailRgId = Get-ResourceGroupId -SubId $subId -RgName $RetailResourceGroupName
$operationsRgId = Get-ResourceGroupId -SubId $subId -RgName $OperationsResourceGroupName

Write-Host "\nAzure scopes (resource group IDs) for README/script inputs:" -ForegroundColor Green
Write-Host "  Commercial AzureScope:     $commercialRgId" -ForegroundColor Green
Write-Host "  Retail AzureScope:         $retailRgId" -ForegroundColor Green
Write-Host "  Operations AciResourceGroupId: $operationsRgId" -ForegroundColor Green

if (-not $SkipServicePrincipal) {
    Write-Host "\nCreating service principal '$ServicePrincipalName' and assigning '$Role' to each RG..." -ForegroundColor Cyan
    Write-Host "Note: this requires AAD permissions to create app registrations + RBAC permissions to assign roles." -ForegroundColor DarkYellow

    # Create the SP with a single initial scope to get credentials.
    # We'll then apply role assignments to the other scopes.
    $spJson = az ad sp create-for-rbac --name $ServicePrincipalName --role $Role --scopes $commercialRgId -o json
    $sp = $spJson | ConvertFrom-Json

    Invoke-Logged "az role assignment create --assignee $($sp.appId) --role $Role --scope $retailRgId -o none"
    Invoke-Logged "az role assignment create --assignee $($sp.appId) --role $Role --scope $operationsRgId -o none"

    Write-Host "\nSet these env vars for subsequent deployments:" -ForegroundColor Green
    Write-Host "  `$env:AZURE_CLIENT_ID     = '$($sp.appId)'" -ForegroundColor Green
    Write-Host "  `$env:AZURE_CLIENT_SECRET = '<generated once>'" -ForegroundColor Green
    Write-Host "  `$env:AZURE_TENANT_ID     = '$($sp.tenant)'" -ForegroundColor Green

    Write-Host "\nIMPORTANT: Azure CLI returns the client secret only once. Capture it now:" -ForegroundColor Yellow
    Write-Host ($spJson) -ForegroundColor Yellow
}

Write-Host "\nOne-time Azure bootstrap complete." -ForegroundColor Green
