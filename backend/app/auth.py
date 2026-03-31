from __future__ import annotations

import json
import logging
import time
from dataclasses import dataclass
from typing import Any

import jwt
import requests
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import Settings, get_settings


logger = logging.getLogger(__name__)

bearer_scheme = HTTPBearer(auto_error=False)

_OPENID_CONFIG_TTL_SECONDS = 86400  # 24 hours
_JWKS_TTL_SECONDS = 3600  # 1 hour

_openid_config_cache: dict[str, tuple[float, dict[str, Any]]] = {}
_jwks_cache: dict[str, tuple[float, list[dict[str, Any]]]] = {}


@dataclass(frozen=True)
class AuthContext:
    customer_id: str
    caller_app_id: str
    claims: dict[str, Any]


def _build_http_error(status_code: int, detail: str) -> HTTPException:
    return HTTPException(status_code=status_code, detail=detail)


def _load_openid_configuration(tenant_id: str) -> dict[str, Any]:
    now = time.monotonic()
    cached = _openid_config_cache.get(tenant_id)
    if cached and (now - cached[0]) < _OPENID_CONFIG_TTL_SECONDS:
        return cached[1]

    metadata_url = (
        f"https://login.microsoftonline.com/{tenant_id}/v2.0/.well-known/openid-configuration"
    )
    response = requests.get(metadata_url, timeout=15)
    response.raise_for_status()
    data = response.json()
    _openid_config_cache[tenant_id] = (now, data)
    return data


def _get_expected_issuer(settings: Settings) -> str:
    return f"https://login.microsoftonline.com/{settings.tenant_id}/v2.0"


def _load_jwks(jwks_uri: str, *, force_refresh: bool = False) -> list[dict[str, Any]]:
    now = time.monotonic()
    if not force_refresh:
        cached = _jwks_cache.get(jwks_uri)
        if cached and (now - cached[0]) < _JWKS_TTL_SECONDS:
            return cached[1]

    response = requests.get(jwks_uri, timeout=15)
    response.raise_for_status()
    keys = response.json()["keys"]
    _jwks_cache[jwks_uri] = (now, keys)
    return keys


def _get_signing_key(kid: str, jwks_uri: str) -> dict[str, Any]:
    for key in _load_jwks(jwks_uri):
        if key.get("kid") == kid:
            return key

    for key in _load_jwks(jwks_uri, force_refresh=True):
        if key.get("kid") == kid:
            return key

    raise _build_http_error(
        status.HTTP_401_UNAUTHORIZED,
        "Unauthorized.",
    )


def validate_access_token(access_token: str, settings: Settings) -> AuthContext:
    configuration = _load_openid_configuration(settings.tenant_id)
    expected_issuer = _get_expected_issuer(settings)
    unverified_header = jwt.get_unverified_header(access_token)
    kid = str(unverified_header.get("kid") or "")
    if not kid:
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            "Unauthorized.",
        )

    signing_key = _get_signing_key(kid, configuration["jwks_uri"])

    try:
        claims = jwt.decode(
            access_token,
            key=jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(signing_key)),
            algorithms=["RS256"],
            audience=list(settings.expected_audiences),
            issuer=expected_issuer,
        )
    except jwt.PyJWTError as exc:
        logger.warning("Token validation failed: %s", exc)
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            "Unauthorized.",
        ) from exc

    if str(claims.get("tid") or "") != settings.tenant_id:
        logger.warning("Token tenant mismatch: got %s", claims.get("tid"))
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            "Unauthorized.",
        )

    roles = claims.get("roles") or []
    if settings.required_app_role not in roles:
        raise _build_http_error(
            status.HTTP_403_FORBIDDEN,
            "Forbidden.",
        )

    caller_app_id = str(claims.get("azp") or "").lower()
    if not caller_app_id:
        logger.warning("Token did not include an azp claim.")
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            "Unauthorized.",
        )

    customer_id = settings.customer_by_app_id.get(caller_app_id)
    if not customer_id:
        logger.warning("Caller app id %s is not mapped to a customer.", caller_app_id)
        raise _build_http_error(
            status.HTTP_403_FORBIDDEN,
            "Forbidden.",
        )

    return AuthContext(
        customer_id=customer_id,
        caller_app_id=caller_app_id,
        claims=claims,
    )


def get_auth_context(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    settings: Settings = Depends(get_settings),
) -> AuthContext:
    if credentials is None:
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            "Unauthorized.",
        )

    return validate_access_token(credentials.credentials, settings)
