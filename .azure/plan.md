# Azure Deployment Plan

> **Status:** Deployed

Generated: 2026-03-31T22:01:54.4004698+02:00

---

## 1. Project Overview

**Goal:** Deploy the existing FastAPI backend to Azure Container Apps in the existing `demo-app-reg` resource group, configure Easy Auth for the online backend, and make the end-to-end customer flows work against the deployed endpoint.

**Path:** Modernize Existing

---

## 2. Requirements

| Attribute | Value |
|-----------|-------|
| Classification | POC |
| Scale | Small |
| Budget | Cost-Optimized |
| **Subscription** | Azure subscription 1 (`bb732a02-2579-488d-8337-a159f8b1c0a9`) ⚠️ MUST confirm with user |
| **Location** | `westeurope` ⚠️ MUST confirm with user |

---

## 3. Components Detected

| Component | Type | Technology | Path |
|-----------|------|------------|------|
| backend | API | Python / FastAPI | `backend` |
| customer-python | Client | Python / MSAL confidential client | `customer-python` |
| customer-typescript | Client | TypeScript / Node.js / MSAL confidential client | `customer-typescript` |
| customer-python-cert | Client | Python / MSAL confidential client with certificate auth | `customer-python-cert` |
| provisioning scripts | Automation | PowerShell / Azure CLI / Microsoft Graph | `scripts` |

---

## 4. Recipe Selection

**Selected:** Bicep

**Rationale:** The workspace has no existing Azure deployment scaffold, and the user explicitly asked for reusable deployment code instead of an imperative-only Container Apps deployment. Bicep will own the Azure resources under source control, while PowerShell will orchestrate image build/push and the Entra/Easy Auth configuration that must reuse the current app registrations.

---

## 5. Architecture

**Stack:** Containers

### Service Mapping

| Component | Azure Service | SKU |
|-----------|---------------|-----|
| backend API | Azure Container App | Consumption |
| backend image storage | Azure Container Registry | Basic |
| backend runtime environment | Azure Container Apps Managed Environment | Consumption |
| backend diagnostics | Log Analytics Workspace | PerGB2018 |

### Supporting Services

| Service | Purpose |
|---------|---------|
| Azure Key Vault (`demoappregkvbb732a02`) | Reuse the existing vault for Easy Auth client secret storage and current demo credential backup flow |
| User-assigned managed identity | Let the Container App resolve ACR image pulls and Key Vault secret references without embedding secrets in code or parameters |
| Existing backend Entra app registration (`444250ae-e178-4c13-9942-ec564e769bf4`) | Reuse the current API app registration for Easy Auth redirect/callback and allowed audience configuration |

**Deployment Notes:**

- Keep the existing `demo-app-reg` resource group and existing Key Vault.
- Add a resource-group-scoped Bicep deployment under `infra/`.
- Use a deployment script to build and push the backend image to ACR, deploy Bicep, update the backend app registration redirect URI, create/store the Easy Auth client secret, assign Key Vault access to the Container App identity, and apply Container Apps auth settings.
- Update the backend and e2e scripts so local execution still works while remote e2e can target the deployed Container App hostname.

---

## 6. Provisioning Limit Checklist

**Purpose:** Validate that the selected subscription and region have sufficient quota/capacity for all resources to be deployed.

> **⚠️ REQUIRED:** This is a **TWO-PHASE** process. Complete both phases before proceeding.

### Phase 1: Prepare Resource Inventory

| Resource Type | Number to Deploy | Total After Deployment | Limit/Quota | Notes |
|---------------|------------------|------------------------|-------------|-------|
| Microsoft.App/managedEnvironments | 1 | 1 | 20 | Fetched from: azure-quotas (`ManagedEnvironmentCount`); current usage in `westeurope` is 0 |
| Microsoft.App/containerApps | 1 | 1 | 800 per resource group per resource type | Fetched from: Azure Resource Group limits; current count in `demo-app-reg` is 0 |
| Microsoft.ContainerRegistry/registries | 1 | 1 | 800 per resource group per resource type | Fetched from: Azure Resource Group limits; current count in `demo-app-reg` is 0 |
| Microsoft.OperationalInsights/workspaces | 1 | 1 | No subscription limit for non-legacy tiers; effectively bounded by 800 per resource group per resource type | Fetched from: Azure Monitor service limits + Azure Resource Group limits; current count in `demo-app-reg` is 0 |

### Phase 2: Fetch Quotas and Validate Capacity

**Action:** `az quota` was used first for `Microsoft.App`, and Azure official limits were used as fallback for unsupported providers or services without a direct quota API path.

| Resource Type | Number to Deploy | Total After Deployment | Limit/Quota | Notes |
|---------------|------------------|------------------------|-------------|-------|
| Microsoft.App/managedEnvironments | 1 | 1 | 20 | Fetched from: azure-quotas (`ManagedEnvironmentCount`) via `az quota list` and `az quota usage show` |
| Microsoft.App/containerApps | 1 | 1 | 800 per resource group per resource type | Fetched from: Azure Resource Group limits + current RG count from `az resource list` |
| Microsoft.ContainerRegistry/registries | 1 | 1 | 800 per resource group per resource type | Fetched from: Azure Resource Group limits + current RG count from `az resource list` |
| Microsoft.OperationalInsights/workspaces | 1 | 1 | No subscription limit for non-legacy tiers; effectively bounded by 800 per resource group per resource type | Fetched from: Azure Monitor service limits + Azure Resource Group limits + current RG count from `az resource list` |

**Status:** ✅ All resources within limits

**Notes:**

- `Microsoft.Quota` is now registered on the subscription and `az quota` returned the regional managed environment quota successfully.
- `Microsoft.ContainerRegistry` and `Microsoft.OperationalInsights` did not provide a usable quota API result for this planning step, so the fallback used official Microsoft limits plus current target resource group counts.
- The target resource group currently contains only the existing Key Vault, so the planned resource counts above start from zero for all new deployment resource types.

---

## 7. Execution Checklist

### Phase 1: Planning
- [x] Analyze workspace
- [x] Gather requirements
- [x] Confirm subscription and location with user
- [x] Prepare resource inventory (Step 6 Phase 1: list resource types and deployment quantities)
- [x] Fetch quotas and validate capacity (Step 6 Phase 2: invoke azure-quotas skill to use quota CLI)
- [x] Scan codebase
- [x] Select recipe
- [x] Plan architecture
- [x] **User approved this plan**

### Phase 2: Execution
- [x] Research components (load references, invoke skills)
- [ ] **⛔ For Azure Functions: Load composition rules** (`services/functions/templates/selection.md` → `services/functions/templates/recipes/composition.md`) and use `azd init -t <template>` — NEVER hand-write Bicep/Terraform
- [x] For other services: Generate infrastructure files following service-specific guidance
- [x] Apply recipes for integrations (if needed)
- [x] Generate application configuration
- [x] Generate Dockerfiles (if containerized)
- [x] **⛔ Update plan status to "Ready for Validation"** — Use the `edit` tool to change the Status line in `.azure/plan.md`. This step is MANDATORY before invoking azure-validate.

### Phase 3: Validation
- [ ] **PREREQUISITE:** Plan status MUST be "Ready for Validation" (Phase 2 last step)
- [x] Invoke azure-validate skill
- [x] All validation checks pass
  - [x] `az bicep build --file .\infra\main.bicep`
  - [x] Validate deployment parameters and secret references
  - [x] Build-time app changes compile locally
  - [x] Dry-run or preflight the resource-group deployment
  - [x] Verify remote e2e scripts point to the deployed hostname without breaking local mode
- [x] Update plan status to "Validated"
- [x] Record validation proof below

### Phase 4: Deployment
- [x] Deployment executed via `./scripts/deploy-backend-bicep.ps1 -RunRemoteE2E`
- [x] Deployment successful
- [x] Report deployed endpoint URLs
- [x] Update plan status to "Deployed"

---

## 7. Validation Proof

> **⛔ REQUIRED**: The azure-validate skill MUST populate this section before setting status to `Validated`. If this section is empty and status is `Validated`, the validation was bypassed improperly.

| Check | Command Run | Result | Timestamp |
|-------|-------------|--------|-----------|
| Bicep compilation | `az bicep build --file .\infra\main.bicep` | ✅ Pass (non-blocking warnings only) | 2026-03-31T22:10:00+02:00 |
| Local end-to-end verification | `.\scripts\test-end-to-end.ps1` | ✅ Pass | 2026-03-31T22:11:00+02:00 |
| Azure resource-group preflight | `az deployment group validate --resource-group demo-app-reg --template-file .\infra\main.bicep --parameters @<generated-temp-parameters>` | ✅ Pass | 2026-03-31T22:13:24+02:00 |

**Validated by:** Manual validation workflow following azure-validate guidance
**Validation timestamp:** 2026-03-31T22:13:24+02:00

---

## 8. Deployment Proof

Earlier proof rows below capture the original all-assigned happy-path deployment state. The latest row captures the current intentional mixed-result demo state where `customer-python` is left unassigned on purpose.

| Check | Command Run | Result | Timestamp |
|-------|-------------|--------|-----------|
| Backend deployment and remote e2e | `./scripts/deploy-backend-bicep.ps1 -RunRemoteE2E` | ✅ Pass. Deployed `https://demo-app-reg-backend.victoriousdesert-edb2f999.westeurope.azurecontainerapps.io`; remote e2e returned 2 records for all three customers. | 2026-03-31T22:28:00+02:00 |
| Live Easy Auth verification | `az rest --method get --uri "https://management.azure.com/subscriptions/bb732a02-2579-488d-8337-a159f8b1c0a9/resourceGroups/demo-app-reg/providers/Microsoft.App/containerApps/demo-app-reg-backend/authConfigs/current?api-version=2025-10-02-preview" --query "{enabled:properties.platform.enabled, unauthenticatedAction:properties.globalValidation.unauthenticatedClientAction, excludedPaths:properties.globalValidation.excludedPaths, audiences:properties.identityProviders.azureActiveDirectory.validation.allowedAudiences, allowedApplications:properties.identityProviders.azureActiveDirectory.validation.jwtClaimChecks.allowedClientApplications}" -o json` | ✅ Pass. Easy Auth enabled, `Return401`, `/health` excluded, expected audiences and client apps present. | 2026-03-31T22:31:00+02:00 |
| Scale-to-zero redeploy and live happy path | `./scripts/deploy-backend-bicep.ps1 -SkipBuild -ImageTag 20260331221423 -RunRemoteE2E` | ✅ Pass. Reused the current image, applied `minReplicas = 0`, kept `maxReplicas = 2`, and remote e2e still returned 2 records for all three customers. | 2026-03-31T22:45:53+02:00 |
| Live unauthenticated route checks | `./scripts/test-end-to-end.ps1 -ApiBaseUrl https://demo-app-reg-backend.victoriousdesert-edb2f999.westeurope.azurecontainerapps.io` | ✅ Pass. `/.auth/me` and `/customer-data` returned `401` before the customer success-path tests ran. | 2026-03-31T22:45:53+02:00 |
| Current live mixed-result e2e | `./scripts/test-end-to-end.ps1` | ✅ Pass. Default live mode resolved the deployed Container App URL, `/customer-data` and `/.auth/me` returned `401`, `customer-python` was denied during token acquisition with `AADSTS501051`, and `customer-typescript` plus `customer-python-cert` each returned 2 records. | 2026-04-01T07:39:53+02:00 |

**Deployed endpoint:** `https://demo-app-reg-backend.victoriousdesert-edb2f999.westeurope.azurecontainerapps.io`
**Easy Auth callback URL:** `https://demo-app-reg-backend.victoriousdesert-edb2f999.westeurope.azurecontainerapps.io/.auth/login/aad/callback`
**Verified live scale:** `minReplicas = 0`, `maxReplicas = 2`
**Current Entra assignment model:** backend enterprise app requires assignment; `customers.json` intentionally leaves `customer-python` unassigned for the denial-path demo while the other two customers remain assigned

---

## 9. Files to Generate

| File | Purpose | Status |
|------|---------|--------|
| `.azure/plan.md` | This plan | ✅ |
| `infra/main.bicep` | Resource-group-scoped infrastructure entry point | ✅ |
| `infra/main.parameters.json` | Default Bicep parameter values for the demo deployment | ✅ |
| `infra/modules/container-environment.bicep` | Container Apps environment and diagnostics resources | ✅ |
| `infra/modules/container-registry.bicep` | Azure Container Registry resource | ✅ |
| `infra/modules/container-app.bicep` | Container App, identity, ingress, and auth child-resource scaffolding | ✅ |
| `backend/Dockerfile` | Backend container image definition | ✅ |
| `scripts/deploy-backend-bicep.ps1` | Build, push, Bicep deploy, Easy Auth, and post-deploy wiring | ✅ |
| `scripts/test-end-to-end.ps1` | Local + remote e2e path support, including unauthenticated checks | ✅ |

---

## 10. Next Steps

> Current: Deployed

1. Re-run `./scripts/deploy-backend-bicep.ps1 -RunRemoteE2E` when you need to publish a new backend build with the same infrastructure pattern.
2. If you want stricter production hardening next, add a custom domain/TLS and lock ingress to expected origins or front the app with Azure Front Door/Application Gateway.