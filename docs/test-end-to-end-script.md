# Test End-To-End Script

This document explains what `scripts/test-end-to-end.ps1` does when you run it.

## Purpose

The script is a local integration test for the full demo flow.

It verifies that:

- the backend API can start successfully
- the backend health endpoint reports `ok`
- every customer app defined in `customers.json` can get a token from Microsoft Entra ID
- every customer app can call the backend successfully
- the backend returns only that customer's data

In short, it tests the complete chain from app startup to token acquisition to backend authorization.

## What It Uses

The script depends on these local files and conventions:

- `.venv\Scripts\python.exe` for Python-based apps and the backend
- `customers.json` as the source of truth for which customer apps to run
- each customer's `runtime`, `entryPoint`, and `workingDirectory` fields in `customers.json`
- the generated local `.env` files that were created by `scripts/setup-entra.ps1`

If the Python virtual environment does not exist, the script stops immediately and tells you to run `scripts/bootstrap.ps1` first.

## Step By Step

### 1. Resolve local paths and ports

At the top, the script builds the paths it will need:

- the repo root
- the Python executable in `.venv`
- the backend URL, defaulting to `http://127.0.0.1:8000`
- two log files: `.backend.stdout.log` and `.backend.stderr.log`
- the customer manifest path `customers.json`

You can override the backend port with:

```powershell
.\scripts\test-end-to-end.ps1 -Port 8010
```

### 2. Start the backend API

The script launches the backend in a separate process with Uvicorn:

```powershell
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port <port>
```

Standard output and standard error are redirected into:

- `.backend.stdout.log`
- `.backend.stderr.log`

That matters because if startup fails, the script includes those log files in the error message.

### 3. Wait for the backend health check

The function `Wait-ForBackend` polls `GET /health` until the backend is ready.

Current behavior:

- up to 30 attempts
- 2 seconds between attempts
- 5 second timeout per HTTP call

If the backend never becomes healthy, the script throws an error and includes the captured backend logs.

### 4. Read the customer manifest

The function `Get-CustomerDefinitions` loads `customers.json` and reads the `customers` array.

If the file is missing or contains no customers, the script fails early.

This means the test automatically follows the current demo setup. If you add a new customer to `customers.json`, this script will include that customer the next time it runs.

### 5. Run each customer app

The function `Invoke-CustomerApplication` looks at the `runtime` field for each customer.

Supported runtimes today:

- `python`: runs the configured `entryPoint` with the repo virtual environment Python
- `typescript`: changes into the configured `workingDirectory` and runs `npm run --silent dev`

Each customer app is expected to do the following on its own:

- load its local `.env`
- acquire an access token for the backend API
- call `GET /customer-data`
- validate that the returned `customer_id` matches its expected customer id
- print the JSON payload to stdout

### 6. Retry each customer app if needed

Each customer execution is wrapped in `Invoke-Retry`.

Current retry behavior:

- up to 8 attempts
- 10 seconds between attempts

This is mainly there to make the test more stable after provisioning changes, especially when a fresh secret or certificate was just created and Entra needs a short time before token issuance is consistent.

If a customer still fails on the last attempt, the script stops and includes that app's output in the error.

### 7. Build a summary object

For every successful customer run, the script captures:

- `customerId`
- `recordCount`

It then returns one JSON summary that contains:

- the backend health payload
- the list of customer results

The output looks like this shape:

```json
{
  "backend": {
    "status": "ok",
    "tenant_id": "...",
    "accepted_audiences": ["..."],
    "registered_customers": 3
  },
  "customers": [
    {
      "customerId": "customer-python",
      "recordCount": 2
    }
  ]
}
```

## What The Script Is Really Verifying

This is not just a backend smoke test. It verifies several things at once:

- the backend can boot with the current local configuration
- the backend health endpoint is reachable
- the customer app credentials are usable
- Microsoft Entra token acquisition works for every configured customer
- backend token validation succeeds
- app role authorization succeeds
- app id to customer id mapping succeeds
- customer data isolation still works

## What It Does Not Do

The script does not:

- create or update app registrations
- create secrets or certificates
- inspect JWT claims in detail
- run unit tests
- verify production deployment behavior

Provisioning is handled by `scripts/setup-entra.ps1`. JWT inspection is handled by `scripts/export-jwt-examples.ps1` and the generated files in `token-examples`.

## Cleanup Behavior

The backend process is always stopped in the `finally` block, even if one of the customer apps fails.

That prevents the local backend process from being left running after a failed test.

## When To Run It

This script is the right check to run after:

- initial setup
- rerunning `scripts/setup-entra.ps1`
- changing backend auth logic
- changing customer app auth logic
- adding a new customer to `customers.json`

If it passes, the main demo path is working end to end.