from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import msal
import requests
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.serialization import pkcs12
from dotenv import load_dotenv


load_dotenv(Path(__file__).resolve().with_name(".env"), override=True)
APP_DIR = Path(__file__).resolve().parent


def _require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def _resolve_local_path(name: str) -> Path:
    configured_path = Path(_require_env(name))
    if configured_path.is_absolute():
        return configured_path
    return (APP_DIR / configured_path).resolve()


def _load_certificate_credential() -> dict[str, str]:
    certificate_path = _resolve_local_path("CLIENT_CERTIFICATE_PATH")
    if not certificate_path.exists():
        raise RuntimeError(f"Certificate file not found: {certificate_path}")

    password = os.getenv("CLIENT_CERTIFICATE_PASSWORD", "").strip()
    raw_bytes = certificate_path.read_bytes()
    private_key, certificate, additional_certificates = pkcs12.load_key_and_certificates(
        raw_bytes,
        password.encode("utf-8") if password else None,
    )
    if private_key is None or certificate is None:
        raise RuntimeError("The PKCS#12 certificate file did not contain both a private key and a certificate.")

    certificate_chain = [certificate.public_bytes(serialization.Encoding.PEM)]
    certificate_chain.extend(
        item.public_bytes(serialization.Encoding.PEM) for item in (additional_certificates or [])
    )

    return {
        "private_key": private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        ).decode("utf-8"),
        "thumbprint": certificate.fingerprint(hashes.SHA1()).hex(),
        "public_certificate": b"".join(certificate_chain).decode("utf-8"),
    }


def main() -> int:
    try:
        tenant_id = _require_env("TENANT_ID")
        client_id = _require_env("CLIENT_ID")
        api_scope = _require_env("API_SCOPE")
        api_base_url = os.getenv(
            "API_BASE_URL_OVERRIDE",
            os.getenv("API_BASE_URL", "http://127.0.0.1:8000"),
        ).rstrip("/")
        expected_customer_id = os.getenv("EXPECTED_CUSTOMER_ID", "customer-python-cert").strip()

        application = msal.ConfidentialClientApplication(
            client_id=client_id,
            client_credential=_load_certificate_credential(),
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