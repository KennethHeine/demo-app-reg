from __future__ import annotations

import json
import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

from dotenv import load_dotenv


BACKEND_DIR = Path(__file__).resolve().parents[1]


load_dotenv(BACKEND_DIR / ".env")


def _require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def _resolve_backend_path(name: str, default_file_name: str) -> Path:
    configured_value = os.getenv(name, "").strip()
    resolved_path = Path(configured_value) if configured_value else BACKEND_DIR / default_file_name
    if not resolved_path.is_absolute():
        resolved_path = BACKEND_DIR / resolved_path
    return resolved_path.resolve()


def _load_customer_registry(path: Path) -> dict[str, str]:
    if not path.exists():
        raise RuntimeError(f"Customer registry file not found: {path}")

    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Customer registry file is not valid JSON: {path}") from exc

    customers = payload.get("customers")
    if not isinstance(customers, list) or not customers:
        raise RuntimeError(f"Customer registry file did not contain any customers: {path}")

    customer_by_app_id: dict[str, str] = {}

    for customer_entry in customers:
        if not isinstance(customer_entry, dict):
            raise RuntimeError(f"Customer registry entry is invalid: {customer_entry!r}")

        customer_id = str(customer_entry.get("customerId") or "").strip()
        app_id = str(customer_entry.get("appId") or "").strip().lower()
        if not customer_id or not app_id:
            raise RuntimeError(f"Customer registry entry is missing customerId or appId: {customer_entry!r}")

        existing_customer_id = customer_by_app_id.get(app_id)
        if existing_customer_id and existing_customer_id != customer_id:
            raise RuntimeError(f"Customer registry contains duplicate appId mapping for {app_id}")

        customer_by_app_id[app_id] = customer_id

    return customer_by_app_id


@dataclass(frozen=True)
class Settings:
    tenant_id: str
    backend_client_id: str
    backend_app_id_uri: str
    required_app_role: str
    customer_registry_path: Path
    customer_by_app_id: dict[str, str]

    @property
    def authority(self) -> str:
        return f"https://login.microsoftonline.com/{self.tenant_id}"

    @property
    def expected_audiences(self) -> tuple[str, str]:
        return tuple({self.backend_client_id, self.backend_app_id_uri})


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    customer_registry_path = _resolve_backend_path("CUSTOMER_REGISTRY_PATH", "customer-registry.local.json")
    return Settings(
        tenant_id=_require_env("TENANT_ID"),
        backend_client_id=_require_env("BACKEND_CLIENT_ID"),
        backend_app_id_uri=_require_env("BACKEND_APP_ID_URI"),
        required_app_role=os.getenv("REQUIRED_APP_ROLE", "Customer.Data.Read").strip()
        or "Customer.Data.Read",
        customer_registry_path=customer_registry_path,
        customer_by_app_id=_load_customer_registry(customer_registry_path),
    )
