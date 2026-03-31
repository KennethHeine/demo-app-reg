# Setup Architecture

This demo is a tenant-local reference setup for machine-to-machine access from customer-owned applications into a shared backend API.

## Components

- Backend API: Python FastAPI application that validates Microsoft Entra access tokens.
- Customer apps: two secret-based confidential clients and one certificate-based confidential client.
- Microsoft Entra ID: identity store for app registrations, service principals, application roles, and token issuance.
- Azure Key Vault: storage for secret-based customer credentials and the certificate used by the certificate-based customer.
- Customer manifest: `customers.json` is the onboarding source of truth for local demo customers.
- Customer registry: `backend/customer-registry.local.json` is generated from the manifest and used by the backend to map caller app ids to customer ids.

## Authentication Model

1. The backend app registration exposes the application role `Customer.Data.Read`.
2. Each customer app registration is granted that role on the backend API.
3. Each customer acquires a token for `api://kscloud.io/demo-app-reg-backend-api/.default`.
4. The backend validates signature, issuer, audience, tenant, and required role.
5. The backend reads the caller app id claim and resolves it through the generated customer registry.
6. The backend returns only the records for that customer id.

## Credential Storage

- Secret-based customers do not keep the secret value in `.env`.
- Their `.env` files contain the Key Vault URL and secret name.
- The client loads the secret from Key Vault at runtime through `DefaultAzureCredential`.
- The certificate-based customer reads the certificate secret from Key Vault and passes the private key, thumbprint, and public certificate into MSAL.

## Provisioning Flow

`scripts/setup-entra.ps1` performs the following:

1. Connects to Microsoft Graph through Azure CLI, device code, or an existing Graph PowerShell context.
2. Ensures the backend app registration exists and has the expected application role.
3. Ensures a Key Vault exists in the `demo-app-reg` resource group.
4. Grants the signed-in user access to that Key Vault.
5. Reads `customers.json` and provisions each customer app registration.
6. Assigns the backend application role to each customer service principal.
7. Creates a secret or certificate credential per customer based on the configured auth mode.
8. Stores secret credentials in Key Vault and writes `.env` files that reference Key Vault.
9. Regenerates `backend/customer-registry.local.json` for backend authorization.

## Scaling Pattern

The important scaling change is that the backend no longer requires one environment variable per customer app id.

- New customers are added to `customers.json`.
- Provisioning regenerates the backend registry file.
- The backend authorization code stays unchanged.
- Secret or certificate settings are expressed in the manifest rather than in backend code.

This is enough for tens or low hundreds of customers in a demo or controlled environment. For larger or production-grade setups, the next step is to move customer registry data into a persistent store instead of a generated local file.

## Local Execution

- `scripts/bootstrap.ps1` installs Python and Node dependencies.
- `scripts/test-end-to-end.ps1` starts the backend and runs every customer defined in `customers.json`.
- `scripts/export-jwt-examples.ps1` acquires tokens for every customer and writes readable JWT example files into `token-examples`.
