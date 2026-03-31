from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache
from typing import Any

import jwt
import requests
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import Settings, get_settings


bearer_scheme = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class AuthContext:
    customer_id: str
    caller_app_id: str
    claims: dict[str, Any]


def _build_http_error(status_code: int, detail: str) -> HTTPException:
    return HTTPException(status_code=status_code, detail=detail)


@lru_cache(maxsize=1)
def _load_openid_configuration(tenant_id: str) -> dict[str, Any]:
    metadata_url = (
        f"https://login.microsoftonline.com/{tenant_id}/v2.0/.well-known/openid-configuration"
    )
    response = requests.get(metadata_url, timeout=15)
    response.raise_for_status()
    return response.json()


def _get_allowed_issuers(settings: Settings, configuration: dict[str, Any]) -> set[str]:
    return {
        configuration["issuer"],
        f"https://sts.windows.net/{settings.tenant_id}/",
        f"https://login.microsoftonline.com/{settings.tenant_id}/v2.0",
    }


@lru_cache(maxsize=1)
def _load_jwks(jwks_uri: str) -> list[dict[str, Any]]:
    response = requests.get(jwks_uri, timeout=15)
    response.raise_for_status()
    return response.json()["keys"]


def _get_signing_key(kid: str, jwks_uri: str) -> dict[str, Any]:
    for key in _load_jwks(jwks_uri):
        if key.get("kid") == kid:
            return key

    _load_jwks.cache_clear()

    for key in _load_jwks(jwks_uri):
        if key.get("kid") == kid:
            return key

    raise _build_http_error(
        status.HTTP_401_UNAUTHORIZED,
        "Unable to resolve the token signing key.",
    )


def validate_access_token(access_token: str, settings: Settings) -> AuthContext:
    configuration = _load_openid_configuration(settings.tenant_id)
    allowed_issuers = _get_allowed_issuers(settings, configuration)
    unverified_header = jwt.get_unverified_header(access_token)
    kid = str(unverified_header.get("kid") or "")
    if not kid:
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            "Token header did not include a signing key identifier.",
        )

    signing_key = _get_signing_key(kid, configuration["jwks_uri"])

    try:
        claims = jwt.decode(
            access_token,
            key=jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(signing_key)),
            algorithms=["RS256"],
            audience=list(settings.expected_audiences),
            options={"verify_iss": False},
        )
    except jwt.PyJWTError as exc:
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            f"Token validation failed: {exc}",
        ) from exc

    issuer = str(claims.get("iss") or "")
    if issuer not in allowed_issuers:
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            f"Token issuer was not allowed: {issuer}",
        )

    if str(claims.get("tid") or "") != settings.tenant_id:
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            "Token tenant did not match the expected tenant.",
        )

    roles = claims.get("roles") or []
    if settings.required_app_role not in roles:
        raise _build_http_error(
            status.HTTP_403_FORBIDDEN,
            f"Token is missing the required role '{settings.required_app_role}'.",
        )

    caller_app_id = str(claims.get("azp") or claims.get("appid") or "").lower()
    if not caller_app_id:
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            "Token did not include a caller application id.",
        )

    customer_id = settings.customer_by_app_id.get(caller_app_id)
    if not customer_id:
        raise _build_http_error(
            status.HTTP_403_FORBIDDEN,
            "Caller application is not mapped to an allowed customer.",
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
            "A bearer token is required.",
        )

    return validate_access_token(credentials.credentials, settings)
