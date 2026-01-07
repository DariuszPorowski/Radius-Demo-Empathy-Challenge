[CmdletBinding()]
param(
    [Parameter()] [string] $WorkspaceName = 'demo',
    [Parameter()] [string] $KubeContext,
    [Parameter()] [ValidateSet('dev', 'test', 'prod')] [string] $Stage = 'dev',
    [Parameter()] [string] $SubscriptionId,
    [Parameter()] [string] $AciResourceGroupId,
    [Parameter()] [string] $AciResourceGroupName,
    [Parameter()] [string] $AzureScope,
    [Parameter()] [string] $PostgresRecipeTemplatePath,
    [Parameter()] [string] $PostgresLocation = 'eastus',
    [Parameter()] [bool] $PostgresAllowPublicAccess = $true,
    [Parameter()] [string] $Image = 'ghcr.io/radius-project/samples/demo:latest',
    [Parameter()] [int] $ContainerPort = 3000,
    [Parameter()] [string] $AzureClientId = $env:AZURE_CLIENT_ID,
    [Parameter()] [string] $AzureClientSecret = $env:AZURE_CLIENT_SECRET,
    [Parameter()] [string] $AzureTenantId = $env:AZURE_TENANT_ID,
    [Parameter()] [switch] $SkipInstallRadius,
    [Parameter()] [switch] $ReinstallRadius,
    [Parameter()] [switch] $SkipAzureCredential,
    [Parameter()] [switch] $SkipResourceType,
    [Parameter()] [switch] $SkipDeployEnvironment,
    [Parameter()] [switch] $SkipDeployApp,
    [Parameter()] [switch] $UseBicepParamFiles,
    [Parameter()] [string] $EnvParamFile,
    [Parameter()] [string] $AppParamFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$deploy = Join-Path $PSScriptRoot 'deploy.ps1'
if (-not (Test-Path $deploy)) {
    throw "Expected script not found: $deploy"
}

& $deploy -BusinessUnit operations -Stage $Stage -WorkspaceName $WorkspaceName -KubeContext $KubeContext -SubscriptionId $SubscriptionId `
    -AciResourceGroupId $AciResourceGroupId -AciResourceGroupName $AciResourceGroupName -AzureScope $AzureScope `
    -PostgresRecipeTemplatePath $PostgresRecipeTemplatePath -PostgresLocation $PostgresLocation -PostgresAllowPublicAccess $PostgresAllowPublicAccess `
    -Image $Image -ContainerPort $ContainerPort -AzureClientId $AzureClientId -AzureClientSecret $AzureClientSecret -AzureTenantId $AzureTenantId `
    -SkipInstallRadius:$SkipInstallRadius -ReinstallRadius:$ReinstallRadius -SkipAzureCredential:$SkipAzureCredential -SkipResourceType:$SkipResourceType `
    -SkipDeployEnvironment:$SkipDeployEnvironment -SkipDeployApp:$SkipDeployApp -UseBicepParamFiles:$UseBicepParamFiles -EnvParamFile $EnvParamFile -AppParamFile $AppParamFile
