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
  - `task` (Taskfile runner) (recommended)
  - `rad` (Radius CLI)
  - `kubectl`
  - `az` (Azure CLI)
  - `terraform`
  - `bicep` (optional)
  - PowerShell:
    - Windows: built-in PowerShell 7+ recommended
    - macOS/Linux: `pwsh` (PowerShell)

## One-time inputs you must provide

## Recommended runner: Taskfile

This repo includes a cross-platform [Taskfile.yml](Taskfile.yml) so you can run common operations consistently on Windows/macOS/Linux.

Quick start:

- Copy [.env.example](.env.example) to `.env` and fill in values (optional but recommended)
- List tasks: `task --list`
- Run a task: `task <task-name>`

## One-time Azure bootstrap (recommended)

This demo requires Azure resource groups and a Service Principal with permission to create:

- Azure PostgreSQL Flexible Server (via the Terraform recipe)
- Azure Container Instances (for the Operations/ACI extra credit)

Recommended one-time setup (Taskfile):

```bash
task azure:bootstrap SUBSCRIPTION_ID=<subId>
```

Optional: also create a simple AKS cluster for the Commercial (Kubernetes on Azure) scenario:

```bash
task azure:bootstrap SUBSCRIPTION_ID=<subId> CREATE_AKS=true
```

This will (idempotently):

- Register required resource providers: `Microsoft.DBforPostgreSQL`, `Microsoft.ContainerInstance`
- Create resource groups: `commercial`, `retail`, `operations`

Create the Service Principal separately (recommended so you intentionally capture the secret output):

```bash
task azure:sp:create SUBSCRIPTION_ID=<subId>
```

When `CREATE_AKS=true` is set, it also:

- Registers `Microsoft.ContainerService`
- Creates an AKS cluster (default name `radius-demo-aks` in the `commercial` RG)
- Fetches kubeconfig via `az aks get-credentials` (can be disabled with `GET_AKS_CREDENTIALS=false`)

If you can’t create service principals or role assignments in your tenant, ask an admin to provide you:

- `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`
- Contributor (or equivalent) permissions on the required resource groups

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

## Demo: Deploy a single environment + app

Deployments are run directly via Taskfile (no wrapper scripts). Tasks will:

- Create a Radius workspace on Kubernetes (`rad workspace create kubernetes`)
- Optionally install Radius (`rad install kubernetes`)
- Register Azure SP credentials into Radius (`rad credential register azure sp`)
- Register the custom resource type from [radius/resource-types/postgreSqlDatabases.yaml](radius/resource-types/postgreSqlDatabases.yaml)
- Deploy the target BU environment Bicep
- Deploy the target BU app Bicep

### Commercial Banking (AKS / Kubernetes)

Requires:

- Kubernetes cluster/context
- `-AzureScope` (Azure resource group ID)

Using Taskfile (recommended):

```bash
task deploy:commercial \
  COMMERCIAL_AZURE_SCOPE="/subscriptions/<subId>/resourceGroups/commercial" \
  POSTGRES_RECIPE_TEMPLATE_PATH="./radius/recipes/azure/postgresql-flex/terraform"

task status:commercial
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

Using Taskfile (recommended):

```bash
task deploy:operations \
  OPERATIONS_ACI_RG_ID="/subscriptions/<subId>/resourceGroups/operations" \
  POSTGRES_RECIPE_TEMPLATE_PATH="./radius/recipes/azure/postgresql-flex/terraform"

task status:operations
```

### Retail Banking (local Kubernetes)

Requires:

- Kubernetes cluster/context (can be local: kind/minikube/docker-desktop)
- `-AzureScope` (because the PostgreSQL recipe is Azure-backed)

Minimum required flags:

- `-BusinessUnit retail`
- `-AzureScope`
- `-PostgresRecipeTemplatePath`

Using Taskfile (recommended):

```bash
task deploy:retail \
  RETAIL_AZURE_SCOPE="/subscriptions/<subId>/resourceGroups/retail" \
  POSTGRES_RECIPE_TEMPLATE_PATH="./radius/recipes/azure/postgresql-flex/terraform"

task status:retail
```

## Switching stages (test/prod)

Use either `STAGE=<dev|test|prod>` or the convenience tasks:

- `task deploy:commercial:test`
- `task deploy:commercial:prod`

Example:

```bash
task deploy:commercial STAGE=test \
  COMMERCIAL_AZURE_SCOPE="/subscriptions/<subId>/resourceGroups/commercial" \
  POSTGRES_RECIPE_TEMPLATE_PATH="./radius/recipes/azure/postgresql-flex/terraform"
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

Using Taskfile (recommended):

```bash
task cleanup:commercial
task cleanup:retail
task cleanup:operations
```
