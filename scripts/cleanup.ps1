[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('commercial', 'operations', 'retail')]
    [string] $BusinessUnit,

    [Parameter()] [string] $WorkspaceName = 'demo',
    [Parameter()] [string] $AppName = 'todo-app',

    [Parameter()] [switch] $DeleteApp,
    [Parameter()] [switch] $DeleteGroup,
    [Parameter()] [switch] $DeleteWorkspace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Command {
    param([Parameter(Mandatory = $true)] [string] $Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command '$Name'."
    }
}

function Invoke-Logged {
    param([Parameter(Mandatory = $true)] [string] $Command)
    Write-Host "> $Command" -ForegroundColor DarkGray
    Invoke-Expression $Command
}

Assert-Command -Name rad

$GroupName = $BusinessUnit

if (-not ($DeleteApp -or $DeleteGroup -or $DeleteWorkspace)) {
    $DeleteApp = $true
    $DeleteGroup = $true
    $DeleteWorkspace = $true
}

if ($DeleteApp) {
    Invoke-Logged "rad app delete $AppName --group $GroupName --workspace $WorkspaceName --yes"
}

if ($DeleteGroup) {
    Invoke-Logged "rad group delete $GroupName --workspace $WorkspaceName --yes"
}

if ($DeleteWorkspace) {
    Invoke-Logged "rad workspace delete $WorkspaceName --yes"
}

Write-Host 'Cleanup complete.' -ForegroundColor Green
