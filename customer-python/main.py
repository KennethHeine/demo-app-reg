from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import msal
import requests
from dotenv import load_dotenv


load_dotenv(Path(__file__).resolve().with_name(".env"), override=True)


def _require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def main() -> int:
    try:
        tenant_id = _require_env("TENANT_ID")
        client_id = _require_env("CLIENT_ID")
        client_secret = _require_env("CLIENT_SECRET")
        api_scope = _require_env("API_SCOPE")
        api_base_url = os.getenv("API_BASE_URL", "http://127.0.0.1:8000").rstrip("/")
        expected_customer_id = os.getenv("EXPECTED_CUSTOMER_ID", "customer-python").strip()

        application = msal.ConfidentialClientApplication(
            client_id=client_id,
            client_credential=client_secret,
            authority=f"https://login.microsoftonline.com/{tenant_id}",
        )

        token_result = application.acquire_token_for_client(scopes=[api_scope])
        access_token = token_result.get("access_token")
        if not access_token:
            raise RuntimeError(json.dumps(token_result, indent=2))

        response = requests.get(
            f"{api_base_url}/customer-data",
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=30,
        )
        response.raise_for_status()
        payload = response.json()

        if payload.get("customer_id") != expected_customer_id:
            raise RuntimeError(
                "Backend returned data for the wrong customer. "
                f"Expected {expected_customer_id}, got {payload.get('customer_id')}."
            )

        print(json.dumps(payload, indent=2))
        return 0
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
