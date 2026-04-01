from __future__ import annotations

import base64
import json
import sys
import textwrap
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import msal
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.serialization import pkcs12
from dotenv import dotenv_values


ROOT = Path(__file__).resolve().parents[1]
CUSTOMERS_PATH = ROOT / "customers.json"
OUTPUT_DIR = ROOT / "token-examples"


def require_value(mapping: dict[str, str], name: str) -> str:
    value = str(mapping.get(name, "") or "").strip()
    if not value:
        raise RuntimeError(f"Missing required configuration value: {name}")
    return value


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


def resolve_env_relative_path(config: dict[str, str], env_path: Path, name: str) -> Path:
    configured_value = require_value(config, name)
    configured_path = Path(configured_value)
    if configured_path.is_absolute():
        return configured_path
    return (env_path.parent / configured_path).resolve()


def get_client_credential(config: dict[str, str], env_path: Path) -> str | dict[str, str]:
    auth_mode = str(config.get("CLIENT_AUTH_MODE", "secret") or "secret").strip().lower()
    if auth_mode == "certificate":
        certificate_path = resolve_env_relative_path(config, env_path, "CLIENT_CERTIFICATE_PATH")
        if not certificate_path.exists():
            raise RuntimeError(f"Certificate file not found: {certificate_path}")
        password = str(config.get("CLIENT_CERTIFICATE_PASSWORD", "") or "").strip()
        secret_value = base64.b64encode(certificate_path.read_bytes()).decode("utf-8")
        return load_certificate_credential_from_pkcs12(secret_value, password)

    direct_secret = str(config.get("CLIENT_SECRET", "") or "").strip()
    if direct_secret:
        return direct_secret

    raise RuntimeError("No local client credential source was configured.")


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


def get_role_assignment(customer: dict[str, Any]) -> str:
    value = str(customer.get("roleAssignment") or "assigned").strip().lower()
    if value not in {"assigned", "not-assigned"}:
        raise RuntimeError(
            f"Unsupported roleAssignment '{value}' for customer '{customer.get('customerId', '')}'."
        )
    return value


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


def build_expected_failure_markdown(
    customer: dict[str, Any],
    config: dict[str, str],
    token_result: dict[str, Any],
) -> str:
    customer_id = str(customer.get("customerId") or "")
    display_name = str(customer.get("displayName") or customer_id)
    error_codes = token_result.get("error_codes") or []

    return "\n".join(
        [
            f"# Token Request Failure: {customer_id}",
            "",
            f"- Display name: {display_name}",
            f"- Auth method: {customer.get('authMethod') or config.get('CLIENT_AUTH_MODE', 'secret')}",
            f"- Client id: {config.get('CLIENT_ID', '')}",
            f"- Scope: {config.get('API_SCOPE', '')}",
            "- Role assignment: not-assigned",
            f"- Generated at (UTC): {datetime.now(UTC).isoformat()}",
            "",
            "No JWT was issued for this customer because the backend enterprise application requires assignment and this client app is intentionally left unassigned for the demo.",
            "",
            f"- Error: {token_result.get('error', 'n/a')}",
            f"- Error codes: {', '.join(str(item) for item in error_codes) if error_codes else 'n/a'}",
            f"- Error description: {token_result.get('error_description', 'n/a')}",
            "",
            "## Raw Token Response",
            "",
            "```json",
            json.dumps(token_result, indent=2, sort_keys=True),
            "```",
            "",
        ]
    )


def is_expected_not_assigned_failure(token_result: dict[str, Any]) -> bool:
    error_codes = {str(item) for item in (token_result.get("error_codes") or [])}
    error_description = str(token_result.get("error_description") or "")
    return "501051" in error_codes or "not assigned to a role" in error_description.lower()


def export_tokens() -> list[dict[str, str]]:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    exports: list[dict[str, str]] = []

    for customer in load_customer_definitions():
        customer_id = str(customer.get("customerId") or "").strip()
        env_file_path = str(customer.get("envFilePath") or "").strip()
        role_assignment = get_role_assignment(customer)
        if not customer_id or not env_file_path:
            raise RuntimeError(f"Customer entry is missing customerId or envFilePath: {customer!r}")

        env_path = (ROOT / env_file_path).resolve()
        config = load_env_config(env_path)
        tenant_id = require_value(config, "TENANT_ID")
        client_id = require_value(config, "CLIENT_ID")
        api_scope = require_value(config, "API_SCOPE")

        application = msal.ConfidentialClientApplication(
            client_id=client_id,
            client_credential=get_client_credential(config, env_path),
            authority=f"https://login.microsoftonline.com/{tenant_id}",
        )

        token_result = application.acquire_token_for_client(scopes=[api_scope])
        access_token = token_result.get("access_token")
        if not access_token and role_assignment == "not-assigned" and is_expected_not_assigned_failure(token_result):
            output_path = OUTPUT_DIR / f"{customer_id}.jwt.md"
            output_path.write_text(
                build_expected_failure_markdown(customer, config, token_result),
                encoding="utf-8",
            )
            exports.append(
                {
                    "customerId": customer_id,
                    "path": str(output_path),
                    "result": "expected-token-denied",
                }
            )
            continue

        if not access_token:
            raise RuntimeError(json.dumps(token_result, indent=2))

        header, payload = decode_jwt(access_token)
        output_path = OUTPUT_DIR / f"{customer_id}.jwt.md"
        output_path.write_text(
            build_markdown(customer, config, access_token, header, payload),
            encoding="utf-8",
        )
        exports.append(
            {
                "customerId": customer_id,
                "path": str(output_path),
                "result": "token-issued",
            }
        )

    index_lines = [
        "# JWT Examples",
        "",
        "Explanation of the most important claims and how the backend uses them:",
        "",
        "- [../docs/token-claims-explained.md](../docs/token-claims-explained.md)",
        "",
        "Generated token example files:",
        "",
    ]
    index_lines.extend(
        f"- {item['customerId']}: {Path(item['path']).name} ({item['result']})" for item in exports
    )
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
                    "files": exports,
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
