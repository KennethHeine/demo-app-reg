from __future__ import annotations

import base64
import json
import logging
import time
from dataclasses import dataclass
from typing import Any

import jwt
import requests
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import Settings, get_settings


logger = logging.getLogger(__name__)

bearer_scheme = HTTPBearer(auto_error=False)

_OPENID_CONFIG_TTL_SECONDS = 86400  # 24 hours
_JWKS_TTL_SECONDS = 3600  # 1 hour
_EASY_AUTH_ACCESS_TOKEN_HEADER = 'x-ms-token-aad-access-token'
_EASY_AUTH_PRINCIPAL_HEADER = 'x-ms-client-principal'

_openid_config_cache: dict[str, tuple[float, dict[str, Any]]] = {}
_jwks_cache: dict[str, tuple[float, list[dict[str, Any]]]] = {}


@dataclass(frozen=True)
class AuthContext:
    customer_id: str
    caller_app_id: str
    claims: dict[str, Any]


def _build_http_error(status_code: int, detail: str) -> HTTPException:
    return HTTPException(status_code=status_code, detail=detail)


def _get_claim_values(claims: dict[str, Any], names: tuple[str, ...]) -> list[str]:
    values: list[str] = []
    for name in names:
        raw_value = claims.get(name)
        if raw_value is None:
            continue

        if isinstance(raw_value, list):
            candidates = raw_value
        else:
            candidates = [raw_value]

        for candidate in candidates:
            candidate_value = str(candidate or '').strip()
            if candidate_value and candidate_value not in values:
                values.append(candidate_value)

    return values


def _get_first_claim(claims: dict[str, Any], names: tuple[str, ...]) -> str:
    values = _get_claim_values(claims, names)
    return values[0] if values else ''


def _build_auth_context_from_claims(claims: dict[str, Any], settings: Settings) -> AuthContext:
    tenant_id = _get_first_claim(
        claims,
        (
            'tid',
            'http://schemas.microsoft.com/identity/claims/tenantid',
        ),
    )
    if tenant_id and tenant_id != settings.tenant_id:
        logger.warning('Token tenant mismatch: got %s', tenant_id)
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            'Unauthorized.',
        )

    roles = _get_claim_values(
        claims,
        (
            'roles',
            'role',
            'http://schemas.microsoft.com/ws/2008/06/identity/claims/role',
        ),
    )
    if settings.required_app_role not in roles:
        raise _build_http_error(
            status.HTTP_403_FORBIDDEN,
            'Forbidden.',
        )

    caller_app_id = _get_first_claim(
        claims,
        (
            'azp',
            'appid',
            'client_id',
            'http://schemas.microsoft.com/identity/claims/clientid',
        ),
    ).lower()
    if not caller_app_id:
        logger.warning('Token did not include a caller application identifier.')
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            'Unauthorized.',
        )

    customer_id = settings.customer_by_app_id.get(caller_app_id)
    if not customer_id:
        logger.warning('Caller app id %s is not mapped to a customer.', caller_app_id)
        raise _build_http_error(
            status.HTTP_403_FORBIDDEN,
            'Forbidden.',
        )

    normalized_claims = dict(claims)
    normalized_claims['roles'] = roles
    normalized_claims['azp'] = caller_app_id
    if tenant_id:
        normalized_claims['tid'] = tenant_id

    return AuthContext(
        customer_id=customer_id,
        caller_app_id=caller_app_id,
        claims=normalized_claims,
    )


def _decode_easy_auth_principal(encoded_principal: str) -> dict[str, Any]:
    try:
        padded_value = encoded_principal + ('=' * ((4 - (len(encoded_principal) % 4)) % 4))
        payload = json.loads(base64.b64decode(padded_value).decode('utf-8'))
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        logger.warning('Failed to decode Easy Auth principal header: %s', exc)
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            'Unauthorized.',
        ) from exc

    grouped_claims: dict[str, list[str]] = {}
    for claim in payload.get('claims') or []:
        if not isinstance(claim, dict):
            continue

        claim_type = str(claim.get('typ') or '').strip()
        claim_value = str(claim.get('val') or '').strip()
        if not claim_type or not claim_value:
            continue

        grouped_claims.setdefault(claim_type, []).append(claim_value)

    claims: dict[str, Any] = {
        claim_type: values[0] if len(values) == 1 else values
        for claim_type, values in grouped_claims.items()
    }

    role_claim_type = str(payload.get('role_typ') or '').strip()
    if role_claim_type and role_claim_type in grouped_claims:
        claims['roles'] = grouped_claims[role_claim_type]

    return claims


def _try_get_easy_auth_context(request: Request, settings: Settings) -> AuthContext | None:
    forwarded_access_token = request.headers.get(_EASY_AUTH_ACCESS_TOKEN_HEADER)
    if forwarded_access_token:
        return validate_access_token(forwarded_access_token, settings)

    encoded_principal = request.headers.get(_EASY_AUTH_PRINCIPAL_HEADER)
    if encoded_principal:
        claims = _decode_easy_auth_principal(encoded_principal)
        return _build_auth_context_from_claims(claims, settings)

    return None


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

    return _build_auth_context_from_claims(claims, settings)


def get_auth_context(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    settings: Settings = Depends(get_settings),
) -> AuthContext:
    easy_auth_context = _try_get_easy_auth_context(request, settings)
    if easy_auth_context is not None:
        return easy_auth_context

    if credentials is None:
        raise _build_http_error(
            status.HTTP_401_UNAUTHORIZED,
            "Unauthorized.",
        )

    return validate_access_token(credentials.credentials, settings)
