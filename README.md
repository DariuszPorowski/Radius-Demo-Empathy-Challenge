# Radius Demo Empathy Challenge (Demo Runner)

This repo contains a Radius demo that deploys:

- The Todo List app (container + HTTP gateway)
- A PostgreSQL database via a custom Radius Resource Type backed by a Terraform Recipe (Azure PostgreSQL Flexible Server)

It is organized to match the enterprise matrix in [CHALLENGE.md](CHALLENGE.md).

## What gets deployed

- **Commercial Banking**: Radius environment(s) with **Kubernetes compute** + Azure provider; app deployed into Kubernetes namespace matching the environment
- **Operations** (extra credit): Radius environment(s) with **ACI compute** + Azure provider; app deployed to ACI
- **Retail Banking**: Radius environment(s) with **Kubernetes compute** (intended for local k8s) + Azure provider **for the PostgreSQL recipe**

Note: This demo provisions PostgreSQL in Azure for all BUs via the Terraform recipe, so Azure credentials are required.

## Prerequisites

You need:

- A working Kubernetes cluster/context (for Commercial + Retail)
- Azure subscription + an Azure Service Principal for Radius to provision Azure resources
- Tools:
  - `rad` (Radius CLI)
  - `kubectl`
  - `az` (Azure CLI)
  - `terraform`
  - `bicep` (optional, only for `sanity-check.ps1`)
  - PowerShell:
    - Windows: built-in PowerShell 7+ recommended
    - macOS/Linux: `pwsh` (PowerShell)

## One-time inputs you must provide

### 1) Azure Service Principal env vars

The deployment script reads these from environment variables by default:

- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_TENANT_ID`

Windows PowerShell:

```powershell
$env:AZURE_CLIENT_ID = "<appId>"
$env:AZURE_CLIENT_SECRET = "<password>"
$env:AZURE_TENANT_ID = "<tenantId>"
```

macOS/Linux (bash/zsh):

```bash
export AZURE_CLIENT_ID="<appId>"
export AZURE_CLIENT_SECRET="<password>"
export AZURE_TENANT_ID="<tenantId>"
```

### 2) PostgreSQL Terraform recipe template path

The script requires `-PostgresRecipeTemplatePath` and passes it into the Radius environment Bicep.

Recommended options:

- **Option A (best for demos from your local checkout): local path**
  - Windows example: `.\radius\recipes\azure\postgresql-flex\terraform`
  - macOS/Linux example: `./radius/recipes/azure/postgresql-flex/terraform`

- **Option B (best for sharing): git module source**
  - Example shape:
    - `git::https://github.com/<org>/<repo>//radius/recipes/azure/postgresql-flex/terraform?ref=<tag-or-branch>`

See [radius/recipes/azure/postgresql-flex/terraform/README.md](radius/recipes/azure/postgresql-flex/terraform/README.md).

### 3) Azure scope / resource group IDs

You will need Azure Resource Group IDs:

- `-AzureScope` (required for **commercial** and **retail**)
- `-AciResourceGroupId` or `-AciResourceGroupName` (required for **operations/ACI**)

Resource group ID format:

- `/subscriptions/<subId>/resourceGroups/<rgName>`

## Quick sanity check (optional, but recommended)

Windows PowerShell:

```powershell
.\scripts\sanity-check.ps1
```

macOS/Linux:

```bash
pwsh -File ./scripts/sanity-check.ps1
```

## Demo: Deploy a single environment + app

All deployments use the same entrypoint:

- [scripts/deploy.ps1](scripts/deploy.ps1)

It will (by default):

- Ensure `az login` is present
- Create a Radius workspace on Kubernetes (`rad workspace create kubernetes`)
- Install Radius into the cluster (`rad install kubernetes`) unless you skip it
- Register Azure SP credentials into Radius (`rad credential register azure sp`)
- Register the custom resource type from [radius/resource-types/postgreSqlDatabases.yaml](radius/resource-types/postgreSqlDatabases.yaml)
- Deploy the target BU environment Bicep
- Deploy the target BU app Bicep

### Commercial Banking (AKS / Kubernetes)

Requires:

- Kubernetes cluster/context
- `-AzureScope` (Azure resource group ID)

Windows PowerShell:

```powershell
$azureScope = "/subscriptions/<subId>/resourceGroups/commercial"
$recipePath = ".\radius\recipes\azure\postgresql-flex\terraform"

.\scripts\deploy.ps1 -BusinessUnit commercial -Stage dev -WorkspaceName demo `
  -AzureScope $azureScope `
  -PostgresRecipeTemplatePath $recipePath

rad app status --workspace demo --group commercial
```

macOS/Linux:

```bash
azureScope="/subscriptions/<subId>/resourceGroups/commercial"
recipePath="./radius/recipes/azure/postgresql-flex/terraform"

pwsh -File ./scripts/deploy.ps1 -BusinessUnit commercial -Stage dev -WorkspaceName demo \
  -AzureScope "$azureScope" \
  -PostgresRecipeTemplatePath "$recipePath"

rad app status --workspace demo --group commercial
```

### Operations (ACI) — extra credit

Requires:

- Kubernetes cluster/context (Radius workspace is created on Kubernetes)
- `-AciResourceGroupId` or `-AciResourceGroupName`
- Azure credentials (SP env vars)

Minimum required flags:

- `-BusinessUnit operations`
- `-AciResourceGroupId` (or `-AciResourceGroupName`)
- `-PostgresRecipeTemplatePath`

Windows PowerShell:

```powershell
$aciRgId = "/subscriptions/<subId>/resourceGroups/operations"
$recipePath = ".\radius\recipes\azure\postgresql-flex\terraform"

# Stage defaults to 'dev' and WorkspaceName defaults to 'demo'
.\scripts\deploy.ps1 -BusinessUnit operations `
  -AciResourceGroupId $aciRgId `
  -PostgresRecipeTemplatePath $recipePath

rad app status --workspace demo --group operations
```

macOS/Linux:

```bash
aciRgId="/subscriptions/<subId>/resourceGroups/operations"
recipePath="./radius/recipes/azure/postgresql-flex/terraform"

pwsh -File ./scripts/deploy.ps1 -BusinessUnit operations \
  -AciResourceGroupId "$aciRgId" \
  -PostgresRecipeTemplatePath "$recipePath"

rad app status --workspace demo --group operations
```

Shortcut wrapper (Operations only): [scripts/deploy-aci.ps1](scripts/deploy-aci.ps1)

Windows PowerShell:

```powershell
# Stage defaults to 'dev' and WorkspaceName defaults to 'demo'
.\scripts\deploy-aci.ps1 -AciResourceGroupId "/subscriptions/<subId>/resourceGroups/operations" -PostgresRecipeTemplatePath "X:\...\terraform"
```

### Retail Banking (local Kubernetes)

Requires:

- Kubernetes cluster/context (can be local: kind/minikube/docker-desktop)
- `-AzureScope` (because the PostgreSQL recipe is Azure-backed)

Minimum required flags:

- `-BusinessUnit retail`
- `-AzureScope`
- `-PostgresRecipeTemplatePath`

Windows PowerShell:

```powershell
$azureScope = "/subscriptions/<subId>/resourceGroups/retail"
$recipePath = ".\radius\recipes\azure\postgresql-flex\terraform"

# Stage defaults to 'dev' and WorkspaceName defaults to 'demo'
.\scripts\deploy.ps1 -BusinessUnit retail `
  -AzureScope $azureScope `
  -PostgresRecipeTemplatePath $recipePath

rad app status --workspace demo --group retail
```

macOS/Linux:

```bash
azureScope="/subscriptions/<subId>/resourceGroups/retail"
recipePath="./radius/recipes/azure/postgresql-flex/terraform"

pwsh -File ./scripts/deploy.ps1 -BusinessUnit retail \
  -AzureScope "$azureScope" \
  -PostgresRecipeTemplatePath "$recipePath"

rad app status --workspace demo --group retail
```

## Switching stages (test/prod)

Just change `-Stage`:

- `-Stage test` deploys `*-test`
- `-Stage prod` deploys `*-prod`

Example:

```powershell
.\scripts\deploy.ps1 -BusinessUnit commercial -Stage test -WorkspaceName demo -AzureScope "/subscriptions/<subId>/resourceGroups/commercial" -PostgresRecipeTemplatePath "X:\...\terraform"
```

## Finding the gateway endpoint

After deployment:

```bash
rad app status --workspace demo --group <commercial|operations|retail>
```

The status output should include the gateway endpoint URL for the `gateway` resource.

## Cleanup

Cleanup deletes (by default): app, group, and workspace.

Windows PowerShell:

```powershell
# Commercial
.\scripts\cleanup.ps1 -BusinessUnit commercial -WorkspaceName demo

# Retail
.\scripts\cleanup.ps1 -BusinessUnit retail -WorkspaceName demo

# Operations (ACI)
.\scripts\cleanup-aci.ps1 -WorkspaceName demo
```

macOS/Linux:

```bash
pwsh -File ./scripts/cleanup.ps1 -BusinessUnit commercial -WorkspaceName demo
pwsh -File ./scripts/cleanup.ps1 -BusinessUnit retail -WorkspaceName demo
pwsh -File ./scripts/cleanup-aci.ps1 -WorkspaceName demo
```
