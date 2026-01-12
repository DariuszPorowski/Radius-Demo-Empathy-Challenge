[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('commercial', 'operations', 'retail')]
    [string] $BusinessUnit,

    [Parameter()]
    [ValidateSet('dev', 'test', 'prod')]
    [string] $Stage = 'dev',

    [Parameter()] [string] $WorkspaceName = 'demo',
    [Parameter()] [string] $KubeContext,

    [Parameter()] [string] $SubscriptionId,

    # Operations/ACI only
    [Parameter()] [string] $AciResourceGroupId,
    [Parameter()] [string] $AciResourceGroupName,

    # Commercial+Retail (and optionally Operations) - used for the Radius Azure provider scope
    [Parameter()] [string] $AzureScope,

    # Required: Terraform recipe module path for Postgres flexible server
    [Parameter()] [string] $PostgresRecipeTemplatePath,
    [Parameter()] [string] $PostgresLocation = 'eastus',
    [Parameter()] [bool] $PostgresAllowPublicAccess = $true,

    [Parameter()] [string] $Image = 'ghcr.io/radius-project/samples/demo:latest',
    [Parameter()] [int] $ContainerPort = 3000,

    # Azure service principal used by Radius to deploy Azure resources.
    [Parameter()] [string] $AzureClientId = $env:AZURE_CLIENT_ID,
    [Parameter()] [string] $AzureClientSecret = $env:AZURE_CLIENT_SECRET,
    [Parameter()] [string] $AzureTenantId = $env:AZURE_TENANT_ID,

    [Parameter()] [switch] $SkipInstallRadius,
    [Parameter()] [switch] $ReinstallRadius,
    [Parameter()] [switch] $SkipAzureCredential,
    [Parameter()] [switch] $SkipResourceType,
    [Parameter()] [switch] $SkipDeployEnvironment,
    [Parameter()] [switch] $SkipDeployApp
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
        [Parameter(Mandatory = $true)] [string] $Command,
        [Parameter()] [switch] $Redact
    )

    $toPrint = $Command
    if ($Redact) {
        $toPrint = $toPrint -replace '(--client-secret\s+)([^\s]+)', '$1***'
    }

    Write-Host "> $toPrint" -ForegroundColor DarkGray
    Invoke-Expression $Command
}

function Format-RadParameterArg {
    param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [bool]) {
        return "--parameters $Name=$($Value.ToString().ToLower())"
    }

    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double]) {
        return "--parameters $Name=$Value"
    }

    if ($Value -is [string]) {
        # Quote strings to avoid issues with ':' '/' '?' '&' etc.
        return "--parameters $Name='$Value'"
    }

    # Arrays/objects: pass as compact JSON (single-quoted so quotes inside JSON survive).
    $json = $Value | ConvertTo-Json -Compress -Depth 50
    return "--parameters $Name='$json'"
}

function Ensure-AzureLogin {
    Assert-Command -Name az -InstallHint 'Install Azure CLI and sign in (az login).'

    try {
        $null = az account show -o none
    }
    catch {
        throw "Azure CLI is not signed in. Run 'az login' then re-run this script."
    }

    if ($SubscriptionId) {
        Invoke-Logged "az account set --subscription $SubscriptionId"
    }
}

function Ensure-RadiusWorkspace {
    Assert-Command -Name rad -InstallHint 'Install the Radius CLI (rad).'

    $contextArg = ''
    if ($KubeContext) {
        $contextArg = " --context $KubeContext"
    }

    Invoke-Logged "rad workspace create kubernetes $WorkspaceName --force$contextArg"
}

function Ensure-RadiusInstalled {
    if ($SkipInstallRadius) {
        return
    }

    Assert-Command -Name kubectl -InstallHint 'Install kubectl and ensure a Kubernetes cluster/context is available.'

    if ($KubeContext) {
        Invoke-Logged "kubectl config use-context $KubeContext"
    }

    try {
        $null = kubectl cluster-info 2>$null
    }
    catch {
        throw 'Kubernetes cluster is not reachable for the current context. Configure kubectl to point at a working cluster.'
    }

    $reinstallArg = ''
    if ($ReinstallRadius) {
        $reinstallArg = ' --reinstall'
    }

    Invoke-Logged "rad install kubernetes$reinstallArg"
}

function Ensure-RadiusAzureCredential {
    if ($SkipAzureCredential) {
        return
    }

    if (-not $AzureClientId -or -not $AzureClientSecret -or -not $AzureTenantId) {
        throw 'Missing Azure SP credentials. Provide -AzureClientId/-AzureClientSecret/-AzureTenantId or set AZURE_CLIENT_ID/AZURE_CLIENT_SECRET/AZURE_TENANT_ID.'
    }

    Invoke-Logged "rad credential register azure sp --client-id $AzureClientId --client-secret $AzureClientSecret --tenant-id $AzureTenantId --workspace $WorkspaceName" -Redact
}

function Ensure-RadiusGroup([string] $GroupName) {
    Invoke-Logged "rad group create $GroupName --workspace $WorkspaceName"
}

function Ensure-ResourceType {
    if ($SkipResourceType) {
        return
    }

    $rtFile = Join-Path $PSScriptRoot '..\radius\resource-types\postgreSqlDatabases.yaml'
    $rtFile = (Resolve-Path $rtFile).Path

    Invoke-Logged "rad resource-type create postgreSqlDatabases --from-file `"$rtFile`" --workspace $WorkspaceName"
}

function Get-AciResourceGroupId {
    if ($AciResourceGroupId) {
        return $AciResourceGroupId
    }

    if (-not $AciResourceGroupName) {
        throw 'Provide either -AciResourceGroupId or -AciResourceGroupName for operations/ACI.'
    }

    $sub = $SubscriptionId
    if (-not $sub) {
        $sub = (az account show --query id -o tsv)
    }

    if (-not $sub) {
        throw 'Unable to determine Azure subscription. Provide -SubscriptionId or run az login.'
    }

    return "/subscriptions/$sub/resourceGroups/$AciResourceGroupName"
}

function Deploy-Environment([string] $GroupName, [string] $EnvName, [string] $EnvBicepPath, [hashtable] $EnvParams) {
    if ($SkipDeployEnvironment) {
        return
    }

    $envBicep = Resolve-Path $EnvBicepPath

    $paramArgs = @()
    foreach ($key in $EnvParams.Keys) {
        $arg = Format-RadParameterArg -Name $key -Value $EnvParams[$key]
        if ($arg) { $paramArgs += $arg }
    }

    Invoke-Logged ("rad deploy `"$($envBicep.Path)`" --workspace $WorkspaceName --group $GroupName " + ($paramArgs -join ' '))
}

function Deploy-App([string] $GroupName, [string] $AppBicepPath, [hashtable] $AppParams) {
    if ($SkipDeployApp) {
        return
    }

    $appBicep = Resolve-Path $AppBicepPath

    $paramArgs = @()
    foreach ($key in $AppParams.Keys) {
        $arg = Format-RadParameterArg -Name $key -Value $AppParams[$key]
        if ($arg) { $paramArgs += $arg }
    }

    Invoke-Logged ("rad deploy `"$($appBicep.Path)`" --workspace $WorkspaceName --group $GroupName " + ($paramArgs -join ' '))
}

# --- Compute derived names ---
$GroupName = $BusinessUnit
$EnvName = "$BusinessUnit-$Stage"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

if (-not $PostgresRecipeTemplatePath) {
    throw 'Missing -PostgresRecipeTemplatePath. Provide the Terraform module source/path for the PostgreSQL recipe.'
}

# --- Execution ---
Ensure-AzureLogin
Ensure-RadiusWorkspace
Ensure-RadiusInstalled
Ensure-RadiusAzureCredential
Ensure-RadiusGroup -GroupName $GroupName
Ensure-ResourceType

switch ($BusinessUnit) {
    'operations' {
        $aciRgId = Get-AciResourceGroupId
        $scope = $AzureScope
        if (-not $scope) { $scope = $aciRgId }

        Deploy-Environment -GroupName $GroupName -EnvName $EnvName -EnvBicepPath (Join-Path $repoRoot 'radius\bicep\modules\env-aci.bicep') -EnvParams @{
            environmentNames = @("operations-dev","operations-test","operations-prod")
            aciResourceGroupId = $aciRgId
            azureScope = $scope
            postgresRecipeTemplatePath = $PostgresRecipeTemplatePath
            postgresLocation = $PostgresLocation
            postgresAllowPublicAccess = $PostgresAllowPublicAccess
        }

        Deploy-App -GroupName $GroupName -AppBicepPath (Join-Path $repoRoot 'radius\bicep\modules\app-aci.bicep') -AppParams @{
            environment = $EnvName
            image = $Image
            containerPort = $ContainerPort
        }
    }

    'commercial' {
        if (-not $AzureScope) {
            throw 'Commercial requires -AzureScope (resource group ID) for Azure provider scope.'
        }

        Deploy-Environment -GroupName $GroupName -EnvName $EnvName -EnvBicepPath (Join-Path $repoRoot 'radius\bicep\modules\env-kubernetes-azure.bicep') -EnvParams @{
            environmentNames = @("commercial-dev","commercial-test","commercial-prod")
            azureScope = $AzureScope
            postgresRecipeTemplatePath = $PostgresRecipeTemplatePath
            postgresLocation = $PostgresLocation
            postgresAllowPublicAccess = $PostgresAllowPublicAccess
        }

        Deploy-App -GroupName $GroupName -AppBicepPath (Join-Path $repoRoot 'radius\bicep\modules\app-kubernetes.bicep') -AppParams @{
            environment = $EnvName
            kubernetesNamespace = $EnvName
            image = $Image
            containerPort = $ContainerPort
        }
    }

    'retail' {
        if (-not $AzureScope) {
            throw 'Retail requires -AzureScope (resource group ID) for Azure provider scope (used by the PostgreSQL Terraform recipe).'
        }

        Deploy-Environment -GroupName $GroupName -EnvName $EnvName -EnvBicepPath (Join-Path $repoRoot 'radius\bicep\modules\env-kubernetes-azure.bicep') -EnvParams @{
            environmentNames = @("retail-dev","retail-test","retail-prod")
            azureScope = $AzureScope
            postgresRecipeTemplatePath = $PostgresRecipeTemplatePath
            postgresLocation = $PostgresLocation
            postgresAllowPublicAccess = $PostgresAllowPublicAccess
        }

        Deploy-App -GroupName $GroupName -AppBicepPath (Join-Path $repoRoot 'radius\bicep\modules\app-kubernetes.bicep') -AppParams @{
            environment = $EnvName
            kubernetesNamespace = $EnvName
            image = $Image
            containerPort = $ContainerPort
        }
    }
}

Write-Host "`nDeployed $BusinessUnit ($EnvName)." -ForegroundColor Green
Write-Host "Next: 'rad app status --workspace $WorkspaceName --group $GroupName' then look for gateway endpoint." -ForegroundColor Green
