# demo-app-reg

End-to-end Entra ID demo with three applications:

- A Python backend API that validates Microsoft Entra access tokens and returns customer-specific mock data.
- A Python customer app that uses MSAL to get an access token and call the backend API.
- A TypeScript customer app that does the same from Node.js.

The demo uses three app registrations in the same Entra tenant:

- One app registration for the backend API.
- One app registration for the Python customer app.
- One app registration for the TypeScript customer app.

The backend accepts tokens only from customer apps that have the API app role and maps the caller app id through a generated customer registry, so each customer app only receives its own data.

## Architecture

1. The backend app registration exposes an application role named `Customer.Data.Read`.
2. Each customer app registration is granted that application permission to the backend API.
3. Each customer app uses MSAL confidential client flow to request `api://kscloud.io/demo-app-reg-backend-api/.default`.
4. The backend validates issuer, audience, signature, tenant, and the required app role.
5. The provisioning script writes `backend/customer-registry.local.json`, and the backend maps the caller app id claim through that registry.
6. The backend returns only that customer's mock data.

## Project Layout

- `backend`: FastAPI backend API.
- `backend/customer-registry.example.json`: Example shape for the generated customer registry.
- `customer-python`: Python MSAL client.
- `customer-typescript`: TypeScript MSAL client.
- `customers.json`: Customer onboarding manifest used by the provisioning script.
- `scripts/setup-entra.ps1`: Creates or reuses app registrations and service principals, grants app permissions, and writes local `.env` files.
- `scripts/bootstrap.ps1`: Creates `.venv` and installs Python and Node dependencies.
- `scripts/run-backend.ps1`: Runs the backend API locally.
- `scripts/test-end-to-end.ps1`: Starts the backend, runs both clients, and verifies the returned data.

## Prerequisites

- Python 3.13+
- Node.js 22+
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

The provisioning script reads customer definitions from `customers.json`. That keeps the backend configuration flat even as the number of customers grows, because the backend only needs one registry file instead of one env var per app id.

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
cd .\customer-typescript
npm run dev
```

## Local Configuration

The provisioning script writes these local files:

- `backend/.env`
- `backend/customer-registry.local.json`
- `customer-python/.env`
- `customer-typescript/.env`
- `entra-config.local.json`

These files are git-ignored because they contain tenant-specific ids and secrets.