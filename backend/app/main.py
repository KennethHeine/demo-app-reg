from __future__ import annotations

from typing import Any

from fastapi import Depends, FastAPI

from .auth import AuthContext, get_auth_context
from .data import MOCK_CUSTOMER_DATA


app = FastAPI(title="Customer Data API", version="1.0.0")


@app.get("/")
def read_root() -> dict[str, Any]:
    return {
        "service": "customer-data-api",
        "message": "Send a bearer token issued to one of the customer applications to fetch customer data.",
    }


@app.get("/health")
def read_health() -> dict[str, Any]:
    return {"status": "ok"}


@app.get("/customer-data")
def read_customer_data(auth_context: AuthContext = Depends(get_auth_context)) -> dict[str, Any]:
    records = MOCK_CUSTOMER_DATA.get(auth_context.customer_id, [])
    roles = sorted(auth_context.claims.get("roles") or [])
    return {
        "customer_id": auth_context.customer_id,
        "caller_app_id": auth_context.caller_app_id,
        "roles": roles,
        "records": records,
    }
