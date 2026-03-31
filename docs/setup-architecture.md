# Setup Architecture

This demo is a tenant-local reference setup for machine-to-machine access from customer-owned applications into a shared backend API.

## Components

- Backend API: Python FastAPI application that validates Microsoft Entra access tokens.
- Customer apps: two secret-based confidential clients and one certificate-based confidential client.
- Microsoft Entra ID: identity store for app registrations, service principals, application roles, and token issuance.
- Azure Key Vault: internal backup store for customer credentials and certificate creation source for certificate-based customers.
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

- Secret-based customers keep their own local client secret inside their generated `.env` file.
- The certificate-based customer keeps a local `.pfx` file generated into its app folder.
- Azure Key Vault still stores an internal backup of secret-based customer credentials.
- Azure Key Vault is also used to create and retain the certificate material that is exported into the certificate-based customer app folder.

## Provisioning Flow

`scripts/setup-entra.ps1` performs the following:

1. Connects to Microsoft Graph through Azure CLI, device code, or an existing Graph PowerShell context.
2. Ensures the backend app registration exists and has the expected application role.
3. Ensures a Key Vault exists in the `demo-app-reg` resource group.
4. Grants the signed-in user access to that Key Vault.
5. Reads `customers.json` and provisions each customer app registration.
6. Assigns the backend application role to each customer service principal.
7. Creates a secret or certificate credential per customer based on the configured auth mode.
8. Stores secret credentials in Key Vault as internal backup.
9. Exports certificate credentials into a local customer app file when the customer uses certificate auth.
10. Writes local `.env` files for the customer apps with the secret value or local certificate path.
11. Regenerates `backend/customer-registry.local.json` for backend authorization.

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

## Production Considerations

### Hosting on Azure Container Apps

For production, deploy the backend API as an Azure Container App. Container Apps provides most of what you would otherwise need a separate API gateway for:

- **Rate limiting**: built-in IP-based rate limiting on the ingress layer without additional infrastructure.
- **Authentication**: Easy Auth can validate Entra ID tokens at the platform level before requests reach the backend. The backend can still perform its own fine-grained authorization (role and customer mapping).
- **Revisions and traffic splitting**: deploy new versions alongside the current one, then shift traffic gradually or use blue-green deployment.
- **Autoscaling**: scale to zero when idle (cost savings) and scale out based on HTTP concurrency or custom metrics.
- **Observability**: built-in integration with Azure Monitor and Application Insights for request tracing, logging, and metrics.
- **Dapr integration**: optional sidecar for service-to-service calls, secret management, and pub/sub if the platform grows beyond a single API.
- **Custom domains and TLS**: managed certificates for HTTPS without manual cert provisioning.

This avoids the operational overhead and cost of a dedicated API Management instance while still covering rate limiting, auth offloading, versioning, and monitoring for a customer-facing API.
