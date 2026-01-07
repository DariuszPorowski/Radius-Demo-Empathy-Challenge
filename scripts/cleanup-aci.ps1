[CmdletBinding()]
param(
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

$cleanup = Join-Path $PSScriptRoot 'cleanup.ps1'
if (-not (Test-Path $cleanup)) {
    throw "Expected script not found: $cleanup"
}

if (-not ($DeleteApp -or $DeleteGroup -or $DeleteWorkspace)) {
    $DeleteApp = $true
    $DeleteGroup = $true
    $DeleteWorkspace = $true
}

& $cleanup -BusinessUnit operations -WorkspaceName $WorkspaceName -AppName $AppName -DeleteApp:$DeleteApp -DeleteGroup:$DeleteGroup -DeleteWorkspace:$DeleteWorkspace
