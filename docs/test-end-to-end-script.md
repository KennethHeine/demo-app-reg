# Test End-To-End Script

This document explains what `scripts/test-end-to-end.ps1` does when you run it.

## Purpose

The script is an integration test for the full demo flow.

By default, it runs against the live deployed backend. If you pass `-UseLocalBackend`, it starts a local backend instead. If you pass `-ApiBaseUrl`, it targets that remote URL explicitly instead of resolving the current live Container App URL from Azure.

That remote mode is the full live verification for the deployed Azure Container Apps backend.

It verifies that:

- the backend API can start successfully
- the backend health endpoint reports `ok`
- unauthenticated access to `GET /customer-data` is rejected with `401`
- unauthenticated access to `GET /.auth/me` is rejected with `401` when running against the live deployment
- every customer with `roleAssignment: assigned` in `customers.json` can get a token from Microsoft Entra ID
- every assigned customer can call the backend successfully
- the intentionally unassigned demo customer fails during token acquisition and shows the assignment-required behavior
- the backend returns only each assigned customer's data

In short, it tests the complete chain from app startup to unauthenticated rejection to token acquisition to backend authorization, while also demonstrating the Entra denial path for an unassigned caller.

## What It Uses

The script depends on these local files and conventions:

- `.venv\Scripts\python.exe` for Python-based apps and the backend
- `customers.json` as the source of truth for which customer apps to run
- each customer's `runtime`, `entryPoint`, and `workingDirectory` fields in `customers.json`
- the generated local `.env` files that were created by `scripts/setup-entra.ps1`

When you use the default live mode without `-ApiBaseUrl`, it also depends on Azure CLI being installed and signed in so it can resolve the current Container App ingress FQDN from the `demo-app-reg` resource group.

If the Python virtual environment does not exist, the script stops immediately and tells you to run `scripts/bootstrap.ps1` first.

During execution, the script prints a line for each test step so you can follow the run interactively.

## Step By Step

### 1. Resolve paths, target mode, and backend URL

At the top, the script builds the paths it will need:

- the repo root
- the Python executable in `.venv`
- the backend URL, defaulting to the live Container App URL resolved from Azure
- two log files: `.backend.stdout.log` and `.backend.stderr.log`
- the customer manifest path `customers.json`

The local mode switch is:

```powershell
.\scripts\test-end-to-end.ps1 -UseLocalBackend
```

You can then override the local backend port with:

```powershell
.\scripts\test-end-to-end.ps1 -UseLocalBackend -Port 8010
```

You can target a specific deployed backend instead of the default Azure-resolved URL with:

```powershell
.\scripts\test-end-to-end.ps1 -ApiBaseUrl https://<your-container-app-fqdn>
```

### 2. Start the backend API only when running locally

If `-UseLocalBackend` is provided, the script launches the backend in a separate process with Uvicorn:

```powershell
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port <port>
```

Standard output and standard error are redirected into:

- `.backend.stdout.log`
- `.backend.stderr.log`

That matters because if startup fails, the script includes those log files in the error message.

If `-UseLocalBackend` is not provided, this entire startup step is skipped and the script talks to the live backend URL directly.

### 3. Wait for the backend health check

The function `Wait-ForBackend` polls `GET /health` until the selected backend URL is ready.

Current behavior:

- up to 30 attempts
- 2 seconds between attempts
- 5 second timeout per HTTP call

If the backend never becomes healthy, the script throws an error and includes the captured backend logs.

### 4. Read the customer manifest

The function `Get-CustomerDefinitions` loads `customers.json` and reads the `customers` array.

If the file is missing or contains no customers, the script fails early.

This means the test automatically follows the current demo setup. If you add a new customer to `customers.json`, this script will include that customer the next time it runs, including whatever `roleAssignment` expectation you define there.

### 5. Run unauthenticated checks

Before it runs any customer application, the script verifies that protected endpoints reject requests without authentication.

Current behavior:

- `GET /customer-data` must return `401` in both local and remote mode
- `GET /.auth/me` must return `401` in remote mode

That gives one place to verify both the backend's local auth gate and the live Easy Auth gate.

### 6. Run each customer app

The function `Invoke-CustomerApplication` looks at the `runtime` field for each customer.

Supported runtimes today:

- `python`: runs the configured `entryPoint` with the repo virtual environment Python
- `typescript`: changes into the configured `workingDirectory` and runs `npm run --silent dev`

Each customer app is expected to do the following on its own:

- load its local `.env`
- optionally honor the process-level `API_BASE_URL_OVERRIDE` when the test script points them to a remote backend
- acquire an access token for the backend API
- call `GET /customer-data`
- validate that the returned `customer_id` matches its expected customer id
- print the JSON payload to stdout

The test script then decides whether that customer should succeed or fail based on the manifest:

- `roleAssignment: assigned` means the customer should get a token and complete the backend call successfully
- `roleAssignment: not-assigned` means the customer should fail during token acquisition with the Entra assignment-required behavior

### 7. Retry each customer app if needed

Each customer execution is wrapped in `Invoke-Retry`.

Current retry behavior:

- up to 8 attempts
- 10 seconds between attempts

This is mainly there to make the test more stable after provisioning changes, especially when a fresh secret, certificate, or role-assignment change was just applied and Entra needs a short time before token behavior is consistent.

If a customer still fails on the last attempt, the script stops and includes that app's output in the error.

### 8. Build a summary object

For every customer run, the script captures:

- `customerId`
- `roleAssignment`
- `result`
- either `recordCount` for successful customers or the Entra failure details for the intentionally unassigned customer

It then returns one JSON summary that contains:

- the backend mode (`local` or `remote`)
- the backend URL under test
- the backend health payload nested under `backend.health`
- the unauthenticated HTTP checks that ran before the customer flows
- the list of customer results

The output looks like this shape:

```json
{
  "backend": {
    "mode": "remote",
    "url": "https://<your-container-app-fqdn>",
    "health": {
      "status": "ok"
    }
  },
  "unauthenticatedChecks": [
    {
      "path": "/customer-data",
      "statusCode": 401,
      "expectedStatusCode": 401,
      "body": ""
    }
  ],
  "customers": [
    {
      "customerId": "customer-python",
      "roleAssignment": "not-assigned",
      "result": "expected-token-denied",
      "error": "invalid_grant",
      "errorCode": "501051"
    },
    {
      "customerId": "customer-typescript",
      "roleAssignment": "assigned",
      "result": "success",
      "recordCount": 2
    }
  ]
}
```

## What The Script Is Really Verifying

This is not just a backend smoke test. It verifies several things at once:

- the backend can boot with the current local configuration
- the backend health endpoint is reachable locally or on the deployed URL
- protected endpoints reject unauthenticated callers before the positive-path tests run
- the customer app credentials are usable
- Microsoft Entra token acquisition works for assigned customers
- Microsoft Entra assignment-required denial is working for the intentionally unassigned customer
- backend token validation succeeds in local mode or through Easy Auth plus backend authorization in remote mode
- app role authorization succeeds
- app id to customer id mapping succeeds
- customer data isolation still works

## What It Does Not Do

The script does not:

- create or update app registrations
- create secrets or certificates
- inspect JWT claims in detail
- run unit tests
- deploy Azure resources

Provisioning is handled by `scripts/setup-entra.ps1`. Deployment is handled by `scripts/deploy-backend-bicep.ps1`. JWT inspection is handled by `scripts/export-jwt-examples.ps1` and the generated files in `token-examples`.

## Cleanup Behavior

When the script starts a local backend, that backend process is always stopped in the `finally` block, even if one of the customer apps fails.

That prevents the local backend process from being left running after a failed test.

## When To Run It

This script is the right check to run after:

- initial setup
- rerunning `scripts/setup-entra.ps1`
- changing backend auth logic
- changing customer app auth logic
- adding a new customer to `customers.json`
- redeploying the live Container App and wanting to confirm both unauthenticated rejection and customer success remotely

If it passes, the main demo path is working end to end, the negative-path unauthenticated checks are still behaving as expected, and the not-assigned Entra denial case is still reproducible.