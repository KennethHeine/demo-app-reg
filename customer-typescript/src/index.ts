import { DefaultAzureCredential } from "@azure/identity";
import { SecretClient } from "@azure/keyvault-secrets";
import { ConfidentialClientApplication } from "@azure/msal-node";
import { config as loadDotEnv } from "dotenv";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

interface CustomerRecord {
  [key: string]: string | number;
}

interface CustomerPayload {
  customer_id: string;
  caller_app_id: string;
  roles: string[];
  records: CustomerRecord[];
}

const currentFile = fileURLToPath(import.meta.url);
const currentDirectory = dirname(currentFile);
loadDotEnv({ path: resolve(currentDirectory, "../.env"), override: true });
let credential: DefaultAzureCredential | undefined;
const secretClients = new Map<string, SecretClient>();

function requireEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

function getAzureCredential(): DefaultAzureCredential {
  if (!credential) {
    credential = new DefaultAzureCredential();
  }

  return credential;
}

function getSecretClient(vaultUrl: string): SecretClient {
  let client = secretClients.get(vaultUrl);
  if (!client) {
    client = new SecretClient(vaultUrl, getAzureCredential());
    secretClients.set(vaultUrl, client);
  }

  return client;
}

async function getClientSecret(): Promise<string> {
  const configuredSecretName = process.env.CLIENT_SECRET_NAME?.trim();
  if (configuredSecretName) {
    const vaultUrl = requireEnv("KEY_VAULT_URL");
    const secret = await getSecretClient(vaultUrl).getSecret(configuredSecretName);
    if (!secret.value) {
      throw new Error(`Key Vault secret '${configuredSecretName}' did not contain a value.`);
    }

    return secret.value;
  }

  const directSecret = process.env.CLIENT_SECRET?.trim();
  if (directSecret) {
    return directSecret;
  }

  throw new Error("No client secret source was configured. Set CLIENT_SECRET_NAME or CLIENT_SECRET.");
}

async function main(): Promise<void> {
  const tenantId = requireEnv("TENANT_ID");
  const clientId = requireEnv("CLIENT_ID");
  const clientSecret = await getClientSecret();
  const apiScope = requireEnv("API_SCOPE");
  const apiBaseUrl = (process.env.API_BASE_URL ?? "http://127.0.0.1:8000").replace(/\/$/, "");
  const expectedCustomerId = (process.env.EXPECTED_CUSTOMER_ID ?? "customer-typescript").trim();

  const application = new ConfidentialClientApplication({
    auth: {
      clientId,
      clientSecret,
      authority: `https://login.microsoftonline.com/${tenantId}`,
    },
  });

  const tokenResult = await application.acquireTokenByClientCredential({
    scopes: [apiScope],
  });

  const accessToken = tokenResult?.accessToken;
  if (!accessToken) {
    throw new Error("MSAL did not return an access token.");
  }

  const response = await fetch(`${apiBaseUrl}/customer-data`, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  });

  const responseText = await response.text();
  if (!response.ok) {
    throw new Error(`Backend call failed with ${response.status}: ${responseText}`);
  }

  const payload = JSON.parse(responseText) as CustomerPayload;
  if (payload.customer_id !== expectedCustomerId) {
    throw new Error(
      `Backend returned data for the wrong customer. Expected ${expectedCustomerId}, got ${payload.customer_id}.`,
    );
  }

  console.log(JSON.stringify(payload, null, 2));
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});
