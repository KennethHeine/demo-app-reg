# JWT Example: customer-python-cert

- Display name: demo-app-reg-customer-python-cert
- Auth method: certificate
- Client id: 97c446fd-6986-45ff-a0a7-681980a489db
- Scope: api://kscloud.io/demo-app-reg-backend-api/.default
- Generated at (UTC): 2026-03-31T08:11:04.536142+00:00
- Issued at (UTC): 2026-03-31T08:06:04+00:00
- Expires at (UTC): 2026-03-31T09:11:04+00:00
- Audience: api://kscloud.io/demo-app-reg-backend-api
- Caller app id: 97c446fd-6986-45ff-a0a7-681980a489db
- Roles: Customer.Data.Read

## Raw JWT

Wrapped for readability.

```text
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6IlFaZ045SHFOa0dORU00R2VLY3pEMDJQY1Z2NCIsImtpZCI6IlFaZ045SHFOa0dORU00R2VLY3pE
MDJQY1Z2NCJ9.eyJhdWQiOiJhcGk6Ly9rc2Nsb3VkLmlvL2RlbW8tYXBwLXJlZy1iYWNrZW5kLWFwaSIsImlzcyI6Imh0dHBzOi8vc3RzLndpbmRvd3MubmV
0LzE0YmMyZmY3LTVmZDEtNGNlMi1hMTEwLTRmNzFiOWEyY2U0MS8iLCJpYXQiOjE3NzQ5NDQzNjQsIm5iZiI6MTc3NDk0NDM2NCwiZXhwIjoxNzc0OTQ4MjY
0LCJhaW8iOiJBU1FBMi84YkFBQUE0N1ZXK3h0RjNNeXNnS0dVdTRCZzVXb3FvWDFCNlVkYVhnYmtCTTZaMXFJPSIsImFwcGlkIjoiOTdjNDQ2ZmQtNjk4Ni0
0NWZmLWEwYTctNjgxOTgwYTQ4OWRiIiwiYXBwaWRhY3IiOiIyIiwiaWRwIjoiaHR0cHM6Ly9zdHMud2luZG93cy5uZXQvMTRiYzJmZjctNWZkMS00Y2UyLWE
xMTAtNGY3MWI5YTJjZTQxLyIsIm9pZCI6IjkzYTkzZTQzLWZmZjgtNDFjMS1hOTJmLWIwYzZiOTAzOWJhZSIsInJoIjoiMS5BVUVCOXktOEZORmY0a3loRUU
5eHVhTE9RYTVRUWtSNDRSTk1tVUxzVms1Mm1fUUFBQUJCQVEuIiwicm9sZXMiOlsiQ3VzdG9tZXIuRGF0YS5SZWFkIl0sInN1YiI6IjkzYTkzZTQzLWZmZjg
tNDFjMS1hOTJmLWIwYzZiOTAzOWJhZSIsInRpZCI6IjE0YmMyZmY3LTVmZDEtNGNlMi1hMTEwLTRmNzFiOWEyY2U0MSIsInV0aSI6IkpicS1WenhfbVUybHN
fQXJpMnBLQUEiLCJ2ZXIiOiIxLjAiLCJ4bXNfZnRkIjoiaHc4VEs4aUJTaEhfMEQ1QS1qVjJWQkszd0NCU2pfalV3SGVaVGZwUEltVUJaWFZ5YjNCbGQyVnp
kQzFrYzIxeiJ9.iLNMXARBgBOn_RYBOqFkV922emT0zQREi2QxnCrqvNO69SOez0RFui-NcbQUFUG9oOo2DxoHm9E6Vh4nNRdWg8bOxSES6t8f8iZcuZ_hcT
W4Xjvf_KYTJDGQa38LCGS1XJXWqmkRCHJZSWo5vDWexzaWkMPsr3nKEJ5Z9xkLPYntUN0HyVkLh0Opqahf_wrOSXv4eHilOttIftwf4lzuPqktZDHaNgPLxD
Lw_1oNMpUoMjw5a3f7mAsSQNr5BOOLtfVBC9FMWLec-p4KVmre-hznUzgi48B47ehBXLanmut_2CqRcjJnqwO2kMf-lCozbS-qHHuXuq8IB23WFXLbCQ
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
  "aio": "ASQA2/8bAAAA47VW+xtF3MysgKGUu4Bg5WoqoX1B6UdaXgbkBM6Z1qI=",
  "appid": "97c446fd-6986-45ff-a0a7-681980a489db",
  "appidacr": "2",
  "aud": "api://kscloud.io/demo-app-reg-backend-api",
  "exp": 1774948264,
  "iat": 1774944364,
  "idp": "https://sts.windows.net/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/",
  "iss": "https://sts.windows.net/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/",
  "nbf": 1774944364,
  "oid": "93a93e43-fff8-41c1-a92f-b0c6b9039bae",
  "rh": "1.AUEB9y-8FNFf4kyhEE9xuaLOQa5QQkR44RNMmULsVk52m_QAAABBAQ.",
  "roles": [
    "Customer.Data.Read"
  ],
  "sub": "93a93e43-fff8-41c1-a92f-b0c6b9039bae",
  "tid": "14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41",
  "uti": "Jbq-Vzx_mU2ls_Ari2pKAA",
  "ver": "1.0",
  "xms_ftd": "hw8TK8iBShH_0D5A-jV2VBK3wCBSj_jUwHeZTfpPImUBZXVyb3Bld2VzdC1kc21z"
}
```
