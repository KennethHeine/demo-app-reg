from __future__ import annotations

import base64
import json
import os
import re
import sys
from pathlib import Path

import msal
import requests
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.serialization import pkcs12
from dotenv import load_dotenv


load_dotenv(Path(__file__).resolve().with_name(".env"), override=True)

_credential: DefaultAzureCredential | None = None
_secret_clients: dict[str, SecretClient] = {}


def _require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def _get_azure_credential() -> DefaultAzureCredential:
    global _credential
    if _credential is None:
        _credential = DefaultAzureCredential(exclude_interactive_browser_credential=False)
    return _credential


def _get_secret_client(vault_url: str) -> SecretClient:
    client = _secret_clients.get(vault_url)
    if client is None:
        client = SecretClient(vault_url=vault_url, credential=_get_azure_credential())
        _secret_clients[vault_url] = client
    return client


def _get_key_vault_secret(secret_env_name: str) -> tuple[str, str]:
    vault_url = _require_env("KEY_VAULT_URL")
    secret_name = _require_env(secret_env_name)
    secret_bundle = _get_secret_client(vault_url).get_secret(secret_name)
    if not secret_bundle.value:
        raise RuntimeError(f"Key Vault secret '{secret_name}' did not contain a value.")
    return secret_bundle.value, str(secret_bundle.properties.content_type or "")


def _extract_pem_block(pem_bytes: bytes, labels: tuple[bytes, ...]) -> bytes:
    for label in labels:
        matches = re.findall(
            rb"-----BEGIN " + label + rb"-----.*?-----END " + label + rb"-----",
            pem_bytes,
            re.DOTALL,
        )
        if matches:
            return matches[0]

    raise RuntimeError("The certificate secret did not contain a supported PEM private key block.")


def _load_certificate_credential_from_pem(secret_value: str) -> dict[str, str]:
    pem_bytes = secret_value.encode("utf-8")
    private_key_bytes = _extract_pem_block(
        pem_bytes,
        (b"PRIVATE KEY", b"RSA PRIVATE KEY", b"EC PRIVATE KEY", b"ENCRYPTED PRIVATE KEY"),
    )
    certificate_matches = re.findall(
        rb"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----",
        pem_bytes,
        re.DOTALL,
    )
    if not certificate_matches:
        raise RuntimeError("The certificate secret did not contain a PEM certificate block.")

    certificate = x509.load_pem_x509_certificate(certificate_matches[0])
    password = os.getenv("CLIENT_CERTIFICATE_PASSWORD", "").strip()
    private_key = serialization.load_pem_private_key(
        private_key_bytes,
        password=password.encode("utf-8") if password else None,
    )

    return {
        "private_key": private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        ).decode("utf-8"),
        "thumbprint": certificate.fingerprint(hashes.SHA1()).hex(),
        "public_certificate": b"".join(certificate_matches).decode("utf-8"),
    }


def _load_certificate_credential_from_pkcs12(secret_value: str) -> dict[str, str]:
    raw_bytes = base64.b64decode(secret_value)
    password = os.getenv("CLIENT_CERTIFICATE_PASSWORD", "").strip()
    private_key, certificate, additional_certificates = pkcs12.load_key_and_certificates(
        raw_bytes,
        password.encode("utf-8") if password else None,
    )
    if private_key is None or certificate is None:
        raise RuntimeError("The PKCS#12 certificate secret did not contain both a private key and a certificate.")

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


def _build_certificate_client_credential() -> dict[str, str]:
    secret_value, content_type = _get_key_vault_secret("CLIENT_CERTIFICATE_SECRET_NAME")
    normalized_content_type = content_type.lower()
    if "pkcs12" in normalized_content_type or normalized_content_type.endswith("pfx"):
        return _load_certificate_credential_from_pkcs12(secret_value)
    return _load_certificate_credential_from_pem(secret_value)


def main() -> int:
    try:
        tenant_id = _require_env("TENANT_ID")
        client_id = _require_env("CLIENT_ID")
        api_scope = _require_env("API_SCOPE")
        api_base_url = os.getenv("API_BASE_URL", "http://127.0.0.1:8000").rstrip("/")
        expected_customer_id = os.getenv("EXPECTED_CUSTOMER_ID", "customer-python-cert").strip()

        application = msal.ConfidentialClientApplication(
            client_id=client_id,
            client_credential=_build_certificate_client_credential(),
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