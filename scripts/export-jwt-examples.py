from __future__ import annotations

import base64
import json
import os
import re
import sys
import textwrap
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import msal
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.serialization import pkcs12
from dotenv import dotenv_values


ROOT = Path(__file__).resolve().parents[1]
CUSTOMERS_PATH = ROOT / "customers.json"
OUTPUT_DIR = ROOT / "token-examples"

_credential: DefaultAzureCredential | None = None
_secret_clients: dict[str, SecretClient] = {}


def require_value(mapping: dict[str, str], name: str) -> str:
    value = str(mapping.get(name, "") or "").strip()
    if not value:
        raise RuntimeError(f"Missing required configuration value: {name}")
    return value


def get_azure_credential() -> DefaultAzureCredential:
    global _credential
    if _credential is None:
        _credential = DefaultAzureCredential(exclude_interactive_browser_credential=False)
    return _credential


def get_secret_client(vault_url: str) -> SecretClient:
    client = _secret_clients.get(vault_url)
    if client is None:
        client = SecretClient(vault_url=vault_url, credential=get_azure_credential())
        _secret_clients[vault_url] = client
    return client


def get_key_vault_secret(config: dict[str, str], secret_env_name: str) -> tuple[str, str]:
    vault_url = require_value(config, "KEY_VAULT_URL")
    secret_name = require_value(config, secret_env_name)
    secret_bundle = get_secret_client(vault_url).get_secret(secret_name)
    if not secret_bundle.value:
        raise RuntimeError(f"Key Vault secret '{secret_name}' did not contain a value.")
    return secret_bundle.value, str(secret_bundle.properties.content_type or "")


def extract_pem_block(pem_bytes: bytes, labels: tuple[bytes, ...]) -> bytes:
    for label in labels:
        matches = re.findall(
            rb"-----BEGIN " + label + rb"-----.*?-----END " + label + rb"-----",
            pem_bytes,
            re.DOTALL,
        )
        if matches:
            return matches[0]

    raise RuntimeError("The certificate secret did not contain a supported PEM private key block.")


def load_certificate_credential_from_pem(secret_value: str, password: str) -> dict[str, str]:
    pem_bytes = secret_value.encode("utf-8")
    private_key_bytes = extract_pem_block(
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


def load_certificate_credential_from_pkcs12(secret_value: str, password: str) -> dict[str, str]:
    raw_bytes = base64.b64decode(secret_value)
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


def get_client_credential(config: dict[str, str]) -> str | dict[str, str]:
    auth_mode = str(config.get("CLIENT_AUTH_MODE", "secret") or "secret").strip().lower()
    if auth_mode == "certificate":
        secret_value, content_type = get_key_vault_secret(config, "CLIENT_CERTIFICATE_SECRET_NAME")
        password = str(config.get("CLIENT_CERTIFICATE_PASSWORD", "") or "").strip()
        normalized_content_type = content_type.lower()
        if "pkcs12" in normalized_content_type or normalized_content_type.endswith("pfx"):
            return load_certificate_credential_from_pkcs12(secret_value, password)
        return load_certificate_credential_from_pem(secret_value, password)

    configured_secret_name = str(config.get("CLIENT_SECRET_NAME", "") or "").strip()
    if configured_secret_name:
        secret_value, _ = get_key_vault_secret(config, "CLIENT_SECRET_NAME")
        return secret_value

    direct_secret = str(config.get("CLIENT_SECRET", "") or "").strip()
    if direct_secret:
        return direct_secret

    raise RuntimeError("No client credential source was configured.")


def decode_segment(segment: str) -> dict[str, Any]:
    padded = segment + "=" * (-len(segment) % 4)
    return json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))


def decode_jwt(token: str) -> tuple[dict[str, Any], dict[str, Any]]:
    parts = token.split(".")
    if len(parts) != 3:
        raise RuntimeError("Token is not in JWT format.")
    return decode_segment(parts[0]), decode_segment(parts[1])


def load_customer_definitions() -> list[dict[str, Any]]:
    payload = json.loads(CUSTOMERS_PATH.read_text(encoding="utf-8"))
    customers = payload.get("customers") or []
    if not customers:
        raise RuntimeError(f"Customer definitions file did not contain any customers: {CUSTOMERS_PATH}")
    return list(customers)


def load_env_config(env_path: Path) -> dict[str, str]:
    values = dotenv_values(env_path)
    return {key: str(value) for key, value in values.items() if value is not None}


def format_timestamp(timestamp: int | None) -> str:
    if timestamp is None:
        return "n/a"
    return datetime.fromtimestamp(timestamp, UTC).isoformat()


def build_markdown(
    customer: dict[str, Any],
    config: dict[str, str],
    token: str,
    header: dict[str, Any],
    payload: dict[str, Any],
) -> str:
    wrapped_token = textwrap.fill(token, width=120)
    customer_id = str(customer.get("customerId") or "")
    display_name = str(customer.get("displayName") or customer_id)
    auth_method = str(customer.get("authMethod") or config.get("CLIENT_AUTH_MODE", "secret"))
    issued_at = format_timestamp(payload.get("iat")) if isinstance(payload.get("iat"), int) else "n/a"
    expires_at = format_timestamp(payload.get("exp")) if isinstance(payload.get("exp"), int) else "n/a"

    return "\n".join(
        [
            f"# JWT Example: {customer_id}",
            "",
            f"- Display name: {display_name}",
            f"- Auth method: {auth_method}",
            f"- Client id: {config.get('CLIENT_ID', '')}",
            f"- Scope: {config.get('API_SCOPE', '')}",
            f"- Generated at (UTC): {datetime.now(UTC).isoformat()}",
            f"- Issued at (UTC): {issued_at}",
            f"- Expires at (UTC): {expires_at}",
            f"- Audience: {payload.get('aud', 'n/a')}",
            f"- Caller app id: {payload.get('azp') or payload.get('appid') or 'n/a'}",
            f"- Roles: {', '.join(payload.get('roles', [])) if isinstance(payload.get('roles'), list) else 'n/a'}",
            "",
            "## Raw JWT",
            "",
            "Wrapped for readability.",
            "",
            "```text",
            wrapped_token,
            "```",
            "",
            "## Header",
            "",
            "```json",
            json.dumps(header, indent=2, sort_keys=True),
            "```",
            "",
            "## Payload",
            "",
            "```json",
            json.dumps(payload, indent=2, sort_keys=True),
            "```",
            "",
        ]
    )


def export_tokens() -> list[tuple[str, Path]]:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    exports: list[tuple[str, Path]] = []

    for customer in load_customer_definitions():
        customer_id = str(customer.get("customerId") or "").strip()
        env_file_path = str(customer.get("envFilePath") or "").strip()
        if not customer_id or not env_file_path:
            raise RuntimeError(f"Customer entry is missing customerId or envFilePath: {customer!r}")

        env_path = (ROOT / env_file_path).resolve()
        config = load_env_config(env_path)
        tenant_id = require_value(config, "TENANT_ID")
        client_id = require_value(config, "CLIENT_ID")
        api_scope = require_value(config, "API_SCOPE")

        application = msal.ConfidentialClientApplication(
            client_id=client_id,
            client_credential=get_client_credential(config),
            authority=f"https://login.microsoftonline.com/{tenant_id}",
        )

        token_result = application.acquire_token_for_client(scopes=[api_scope])
        access_token = token_result.get("access_token")
        if not access_token:
            raise RuntimeError(json.dumps(token_result, indent=2))

        header, payload = decode_jwt(access_token)
        output_path = OUTPUT_DIR / f"{customer_id}.jwt.md"
        output_path.write_text(
            build_markdown(customer, config, access_token, header, payload),
            encoding="utf-8",
        )
        exports.append((customer_id, output_path))

    index_lines = ["# JWT Examples", "", "Generated token example files:", ""]
    index_lines.extend(f"- {customer_id}: {path.name}" for customer_id, path in exports)
    index_lines.append("")
    (OUTPUT_DIR / "README.md").write_text("\n".join(index_lines), encoding="utf-8")
    return exports


def main() -> int:
    try:
        exports = export_tokens()
        print(
            json.dumps(
                {
                    "outputDirectory": str(OUTPUT_DIR),
                    "files": [{"customerId": customer_id, "path": str(path)} for customer_id, path in exports],
                },
                indent=2,
            )
        )
        return 0
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
