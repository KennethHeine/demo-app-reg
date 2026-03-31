# JWT Example: customer-python

- Display name: demo-app-reg-customer-python
- Auth method: client-secret
- Client id: 3e82d5de-3cbe-44cf-afd4-242ff1d3fdb5
- Scope: api://kscloud.io/demo-app-reg-backend-api/.default
- Generated at (UTC): 2026-03-31T08:11:02.613181+00:00
- Issued at (UTC): 2026-03-31T08:06:02+00:00
- Expires at (UTC): 2026-03-31T09:11:02+00:00
- Audience: api://kscloud.io/demo-app-reg-backend-api
- Caller app id: 3e82d5de-3cbe-44cf-afd4-242ff1d3fdb5
- Roles: Customer.Data.Read

## Raw JWT

Wrapped for readability.

```text
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6IlFaZ045SHFOa0dORU00R2VLY3pEMDJQY1Z2NCIsImtpZCI6IlFaZ045SHFOa0dORU00R2VLY3pE
MDJQY1Z2NCJ9.eyJhdWQiOiJhcGk6Ly9rc2Nsb3VkLmlvL2RlbW8tYXBwLXJlZy1iYWNrZW5kLWFwaSIsImlzcyI6Imh0dHBzOi8vc3RzLndpbmRvd3MubmV
0LzE0YmMyZmY3LTVmZDEtNGNlMi1hMTEwLTRmNzFiOWEyY2U0MS8iLCJpYXQiOjE3NzQ5NDQzNjIsIm5iZiI6MTc3NDk0NDM2MiwiZXhwIjoxNzc0OTQ4MjY
yLCJhaW8iOiJrMlpnWUZnd3V6enMvSzhhcnU2VFlXcFJmOXNET3A4bEtLY1c5VVJhZlBxWXNYS0crRllBIiwiYXBwaWQiOiIzZTgyZDVkZS0zY2JlLTQ0Y2Y
tYWZkNC0yNDJmZjFkM2ZkYjUiLCJhcHBpZGFjciI6IjEiLCJpZHAiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC8xNGJjMmZmNy01ZmQxLTRjZTItYTExMC0
0ZjcxYjlhMmNlNDEvIiwib2lkIjoiMzM3YjMxMjItYjU3ZS00NDc2LTk1NmMtYTMyNzA2OTVkMTNmIiwicmgiOiIxLkFVRUI5eS04Rk5GZjRreWhFRTl4dWF
MT1FhNVFRa1I0NFJOTW1VTHNWazUybV9RQUFBQkJBUS4iLCJyb2xlcyI6WyJDdXN0b21lci5EYXRhLlJlYWQiXSwic3ViIjoiMzM3YjMxMjItYjU3ZS00NDc
2LTk1NmMtYTMyNzA2OTVkMTNmIiwidGlkIjoiMTRiYzJmZjctNWZkMS00Y2UyLWExMTAtNGY3MWI5YTJjZTQxIiwidXRpIjoiZGkxNzR1NmxoVWU0dkt5azN
hVXhBQSIsInZlciI6IjEuMCIsInhtc19mdGQiOiJPZWVoQXpVNFd4VmZrc0V2U2M2TXI3UUhyb09OeFByVUdRcmxNckI3c0JjQlpuSmhibU5sWXkxa2MyMXo
ifQ.MHDOt_HLKnlFHsKjBKwT45Wwj9eOnvDK4Vw_zC_gU2Cr1I3akX8L2K5SxC2L6CFD510mq9rwM76a-
BuZGYyUk6UdltcVSaj1aNYLECPnYmc2_vsG3FpU28ZxFO9UqsFQQZjCIxzokcAceWvjz7ClvH42jXKZm_0R_RxoYiZYACiJYWeGslPNbZp-
yj5LjTYCyh_cd6ugkxiGBv4LCOkEdL9rkwfvcSVUQuDd5tjXDJ8_04E-CnBBLFaK0lHsDSc-vwPWLAD99QtKXtqEWp6kHK99Mz-
SMUIiPtV8M0YbXjLnl5vp9KjUP1jgf7ZM72Hq-pUSkNy_RWNWBN0LoNP17w
```

## Header

```json
{
  "alg": "RS256",
  "kid": "QZgN9HqNkGNEM4GeKczD02PcVv4",
  "typ": "JWT",
  "x5t": "QZgN9HqNkGNEM4GeKczD02PcVv4"
}
```

## Payload

```json
{
  "aio": "k2ZgYFgwuzzs/K8aru6TYWpRf9sDOp8lKKcW9URafPqYsXKG+FYA",
  "appid": "3e82d5de-3cbe-44cf-afd4-242ff1d3fdb5",
  "appidacr": "1",
  "aud": "api://kscloud.io/demo-app-reg-backend-api",
  "exp": 1774948262,
  "iat": 1774944362,
  "idp": "https://sts.windows.net/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/",
  "iss": "https://sts.windows.net/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/",
  "nbf": 1774944362,
  "oid": "337b3122-b57e-4476-956c-a3270695d13f",
  "rh": "1.AUEB9y-8FNFf4kyhEE9xuaLOQa5QQkR44RNMmULsVk52m_QAAABBAQ.",
  "roles": [
    "Customer.Data.Read"
  ],
  "sub": "337b3122-b57e-4476-956c-a3270695d13f",
  "tid": "14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41",
  "uti": "di174u6lhUe4vKyk3aUxAA",
  "ver": "1.0",
  "xms_ftd": "OeehAzU4WxVfksEvSc6Mr7QHroONxPrUGQrlMrB7sBcBZnJhbmNlYy1kc21z"
}
```
