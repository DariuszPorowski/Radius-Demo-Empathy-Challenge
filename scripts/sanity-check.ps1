[CmdletBinding()]
param(
    [Parameter()] [switch] $SkipTerraform,
    [Parameter()] [switch] $SkipBicep,
    [Parameter()] [switch] $SkipPowerShellParse
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Command {
    param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter()] [string] $Hint
    )
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        $msg = "Missing required command '$Name'."
        if ($Hint) { $msg += " $Hint" }
        throw $msg
    }
}

function Write-Step([string] $Message) {
    Write-Host "\n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

if (-not $SkipPowerShellParse) {
    Write-Step 'PowerShell parse check'
    $nullRef = $null
    $errors = $null

    $files = @(
        (Join-Path $repoRoot 'scripts\deploy.ps1'),
        (Join-Path $repoRoot 'scripts\deploy-aci.ps1'),
        (Join-Path $repoRoot 'scripts\cleanup.ps1'),
        (Join-Path $repoRoot 'scripts\cleanup-aci.ps1'),
        (Join-Path $repoRoot 'scripts\azure-bootstrap.ps1'),
        (Join-Path $repoRoot 'scripts\sanity-check.ps1')
    )

    foreach ($file in $files) {
        if (-not (Test-Path $file)) {
            throw "Expected script not found: $file"
        }
        [void][System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$nullRef, [ref]$errors)
        if ($errors -and $errors.Count -gt 0) {
            throw ($errors | Format-List | Out-String)
        }
    }
    Write-Host 'OK' -ForegroundColor Green
}

if (-not $SkipBicep) {
    Write-Step 'Bicep compile check'
    Assert-Command -Name bicep -Hint 'Install the Bicep CLI.'

    bicep build (Join-Path $repoRoot 'radius\bicep\modules\env-kubernetes-azure.bicep') --stdout | Out-Null
    bicep build (Join-Path $repoRoot 'radius\bicep\modules\env-aci.bicep') --stdout | Out-Null
    bicep build (Join-Path $repoRoot 'radius\bicep\modules\app-kubernetes.bicep') --stdout | Out-Null
    bicep build (Join-Path $repoRoot 'radius\bicep\modules\app-aci.bicep') --stdout | Out-Null

    Write-Host 'OK' -ForegroundColor Green
}

if (-not $SkipTerraform) {
    Write-Step 'Terraform fmt/init/validate check'
    Assert-Command -Name terraform -Hint 'Install Terraform.'

    $tfDir = (Resolve-Path (Join-Path $repoRoot 'radius\recipes\azure\postgresql-flex\terraform')).Path

    terraform "-chdir=$tfDir" fmt -check -recursive

    # Note: validate requires providers. We use backend=false to avoid touching any state.
    terraform "-chdir=$tfDir" init -backend=false -input=false -no-color
    if ($LASTEXITCODE -ne 0) {
        throw "terraform init failed with exit code $LASTEXITCODE"
    }

    terraform "-chdir=$tfDir" validate -no-color
    if ($LASTEXITCODE -ne 0) {
        throw "terraform validate failed with exit code $LASTEXITCODE"
    }

    Write-Host 'OK' -ForegroundColor Green
}

Write-Host "\nSanity checks complete." -ForegroundColor Green
