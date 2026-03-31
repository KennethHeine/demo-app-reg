# demo-app-reg

Additional documentation:

- [docs/goal-and-intent.md](docs/goal-and-intent.md)
- [docs/setup-architecture.md](docs/setup-architecture.md)
- [docs/test-end-to-end-script.md](docs/test-end-to-end-script.md)
- [docs/token-claims-explained.md](docs/token-claims-explained.md)

End-to-end Entra ID demo with three applications:

- A Python backend API that validates Microsoft Entra access tokens and returns customer-specific mock data.
- A Python customer app that uses MSAL to get an access token and call the backend API.
- A TypeScript customer app that does the same from Node.js.
- A second Python customer app that uses a local certificate file instead of a client secret.

The demo uses four app registrations in the same Entra tenant:

- One app registration for the backend API.
- One app registration for the Python customer app.
- One app registration for the TypeScript customer app.
- One app registration for the certificate-based Python customer app.

The customer demo apps keep their own local secret or certificate material, while Azure Key Vault is used as an internal backup store for secrets and as the certificate creation source for certificate-based customers. The backend accepts tokens only from customer apps that have the API app role and maps the caller app id through a generated customer registry, so each customer app only receives its own data.

## Architecture

1. The backend app registration exposes an application role named `Customer.Data.Read`.
2. Each customer app registration is granted that application permission to the backend API.
3. Each customer app uses MSAL confidential client flow to request `api://kscloud.io/demo-app-reg-backend-api/.default`.
4. Secret-based customers authenticate with their own local client secret stored in the app's `.env` file.
5. The certificate-based customer authenticates with a local certificate file stored in its app folder.
6. The backend validates issuer, audience, signature, tenant, and the required app role.
7. The provisioning script writes `backend/customer-registry.local.json`, and the backend maps the caller app id claim through that registry.
8. The backend returns only that customer's mock data.

## Project Layout

- `backend`: FastAPI backend API.
- `backend/customer-registry.example.json`: Example shape for the generated customer registry.
- `customer-python`: Python MSAL client.
- `customer-python-cert`: Python MSAL client that authenticates with a local certificate file.
- `customer-typescript`: TypeScript MSAL client.
- `customers.json`: Customer onboarding manifest used by the provisioning script.
- `scripts/setup-entra.ps1`: Creates or reuses app registrations and service principals, grants app permissions, and writes local `.env` files.
- `scripts/bootstrap.ps1`: Creates `.venv` and installs Python and Node dependencies.
- `scripts/export-jwt-examples.ps1`: Acquires tokens for every customer and writes readable JWT example files into `token-examples`.
- `scripts/run-backend.ps1`: Runs the backend API locally.
- `scripts/test-end-to-end.ps1`: Starts the backend, runs every configured customer app, and verifies the returned data.

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

The provisioning script reads customer definitions from `customers.json`. That keeps the backend configuration flat even as the number of customers grows, because the backend only needs one registry file instead of one env var per app id. The same manifest now also carries the auth mode and Key Vault secret or certificate names for each customer.

## Quick Start

1. Create the app registrations and local environment files:

```powershell
.\scripts\setup-entra.ps1 -UseAzureCli
```

If Azure CLI is not logged in, use device code authentication:

```powershell
.\scripts\setup-entra.ps1 -UseDeviceCode
```

To onboard more customers, add entries to `customers.json` and rerun the provisioning script. It will rotate the local demo secret for each managed customer app, refresh the client `.env` files, and regenerate `backend/customer-registry.local.json`.

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