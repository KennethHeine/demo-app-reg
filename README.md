# demo-app-reg

Additional documentation:

- [docs/goal-and-intent.md](docs/goal-and-intent.md)
- [docs/setup-architecture.md](docs/setup-architecture.md)
- [docs/test-end-to-end-script.md](docs/test-end-to-end-script.md)
- [docs/token-claims-explained.md](docs/token-claims-explained.md)

End-to-end Entra ID demo with three applications:

- A Python backend API that validates Microsoft Entra access tokens and returns customer-specific mock data.
- A Python customer app that is intentionally left unassigned to the backend role so the demo can show the token issuance failure path.
- A TypeScript customer app that uses MSAL to get an access token and call the backend API successfully.
- A second Python customer app that uses a local certificate file instead of a client secret and also succeeds.

The demo uses four app registrations in the same Entra tenant:

- One app registration for the backend API.
- One app registration for the Python customer app.
- One app registration for the TypeScript customer app.
- One app registration for the certificate-based Python customer app.

The customer demo apps keep their own local secret or certificate material, while Azure Key Vault is used as an internal backup store for secrets and as the certificate creation source for certificate-based customers. The backend enterprise application requires assignment, so only explicitly assigned customer apps can obtain tokens for the API. The manifest intentionally leaves `customer-python` unassigned to demonstrate the Entra failure path, while the assigned apps can still call the backend and only receive their own data.

## Architecture

1. The backend app registration exposes an application role named `Customer.Data.Read`.
2. The backend enterprise application has `Assignment required? = Yes` so only assigned callers can get tokens for it.
3. `customer-typescript` and `customer-python-cert` are assigned the `Customer.Data.Read` application permission, while `customer-python` is intentionally left unassigned.
4. Each customer app uses MSAL confidential client flow to request `api://kscloud.io/demo-app-reg-backend-api/.default`.
5. Secret-based customers authenticate with their own local client secret stored in the app's `.env` file.
6. The certificate-based customer authenticates with a local certificate file stored in its app folder.
7. The backend validates issuer, audience, signature, tenant, and the required app role.
8. The provisioning script writes `backend/customer-registry.local.json`, and the backend maps the caller app id claim through that registry.
9. Assigned callers receive only their own mock data, while the unassigned caller fails before any JWT is issued.

## Project Layout

- `backend`: FastAPI backend API.
- `backend/customer-registry.example.json`: Example shape for the generated customer registry.
- `customer-python`: Python MSAL client.
- `customer-python-cert`: Python MSAL client that authenticates with a local certificate file.
- `customer-typescript`: TypeScript MSAL client.
- `customers.json`: Customer onboarding manifest used by the provisioning script.
- `scripts/setup-entra.ps1`: Creates or reuses app registrations and service principals, enforces backend assignment-required plus per-customer role assignment from `customers.json`, and writes local `.env` files.
- `scripts/bootstrap.ps1`: Creates `.venv` and installs Python and Node dependencies.
- `scripts/export-jwt-examples.ps1`: Acquires tokens for every customer and writes readable JWT example files into `token-examples`.
- `scripts/run-backend.ps1`: Runs the backend API locally.
- `scripts/test-end-to-end.ps1`: Defaults to the live Container App, or starts a local backend with `-UseLocalBackend`, then runs unauthenticated checks plus the assigned and not-assigned customer flows.

## Prerequisites

- Python 3.13+
- Node.js 22+
- Azure CLI login for provisioning and internal Key Vault backup operations
- Microsoft Graph PowerShell SDK
- A signed-in Microsoft Graph PowerShell session with permissions to create applications and assign app roles

Recommended Graph connection:

```powershell
Connect-MgGraph -Scopes "Application.ReadWrite.All","AppRoleAssignment.ReadWrite.All","Directory.ReadWrite.All"
```

If you already have Azure CLI logged in, the provisioning script can reuse that session instead:

```powershell
.\scripts\setup-entra.ps1 -UseAzureCli
```

By default, the provisioning script configures the backend API identifier URI as `api://kscloud.io/demo-app-reg-backend-api`. You can override the domain with `-ApiDomain` if needed.

The provisioning script reads customer definitions from `customers.json`. That keeps the backend configuration flat even as the number of customers grows, because the backend only needs one registry file instead of one env var per app id. The same manifest now also carries the auth mode, Key Vault secret or certificate names, and the intended role-assignment state for each customer.

## Quick Start

1. Create the app registrations and local environment files:

```powershell
.\scripts\setup-entra.ps1 -UseAzureCli
```

If Azure CLI is not logged in, use device code authentication:

```powershell
.\scripts\setup-entra.ps1 -UseDeviceCode
```

To onboard more customers, add entries to `customers.json` and rerun the provisioning script. It will rotate the local demo secret for each managed customer app, apply the requested role-assignment state for each customer, refresh the client `.env` files, and regenerate `backend/customer-registry.local.json`.

The same run also creates a Key Vault in the `demo-app-reg` resource group if one does not already exist, stores secret-based client credentials there as backup, provisions the certificate credential for the certificate-based customer, and exports the local customer certificate file into the app folder.

To export readable JWT example files for all customers:

```powershell
.\scripts\export-jwt-examples.ps1
```

2. Install dependencies:

```powershell
.\scripts\bootstrap.ps1
```

3. Run the full end-to-end test:

```powershell
.\scripts\test-end-to-end.ps1
```

The default setup now produces a mixed result on purpose:

- `customer-python` fails during token acquisition because it is not assigned to the backend enterprise app role
- `customer-typescript` succeeds
- `customer-python-cert` succeeds

4. Or run the backend manually and invoke the clients separately:

```powershell
.\scripts\run-backend.ps1
```

```powershell
.\.venv\Scripts\python.exe .\customer-python\main.py
```

```powershell
.\.venv\Scripts\python.exe .\customer-python-cert\main.py
```

```powershell
cd .\customer-typescript
npm run dev
```

## Azure Deployment

The backend can be deployed to Azure Container Apps with reusable infrastructure code and a deployment script.

Generated deployment assets:

- `infra/main.bicep`
- `infra/main.parameters.json`
- `infra/modules/*.bicep`
- `backend/Dockerfile`
- `scripts/deploy-backend-bicep.ps1`

The deployment script reuses the existing `demo-app-reg` resource group and Key Vault, builds the backend image into ACR, deploys the Container Apps infrastructure, creates or rotates the Easy Auth client secret, and updates the backend app registration with the Container Apps callback URI.

The checked-in Container Apps defaults are tuned for a low-cost demo deployment:

- `minReplicas = 0`
- `maxReplicas = 2`

That keeps idle cost down by allowing the backend to scale to zero, with the expected tradeoff that the first request after an idle period can take longer because of cold start.

Deploy the backend:

```powershell
.\scripts\deploy-backend-bicep.ps1
```

Deploy and immediately run the remote end-to-end verification:

```powershell
.\scripts\deploy-backend-bicep.ps1 -RunRemoteE2E
```

The end-to-end test script now defaults to the live deployed backend and resolves the Container App URL from Azure automatically:

```powershell
.\scripts\test-end-to-end.ps1
```

If you want to target a specific remote URL instead of the current Container App, pass it explicitly:

```powershell
.\scripts\test-end-to-end.ps1 -ApiBaseUrl https://<your-container-app-fqdn>
```

If you want to run the same script against a local backend instead, opt into local mode:

```powershell
.\scripts\test-end-to-end.ps1 -UseLocalBackend
```

That single script now does both:

- unauthenticated checks first
- assigned customer success flows after that
- the expected token-denied demo flow for the intentionally unassigned customer

It also prints each test step as it runs so you can see exactly which customer or unauthenticated check is in progress.

The live deployment URL, callback URL, and latest deployment proof are tracked in `.azure/plan.md`.

## Local Configuration

The provisioning script writes these local files:

- `backend/.env`
- `backend/customer-registry.local.json`
- `customer-python/.env`
- `customer-python-cert/.env`
- `customer-typescript/.env`
- `entra-config.local.json`
- `token-examples/*.jwt.md`

The local `.env` files and `entra-config.local.json` are git-ignored because they contain tenant-specific ids and secret references. The `token-examples` files are generated examples intended for inspection.