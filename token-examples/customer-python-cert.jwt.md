# JWT Example: customer-python-cert

- Display name: demo-app-reg-customer-python-cert
- Auth method: certificate
- Client id: 97c446fd-6986-45ff-a0a7-681980a489db
- Scope: api://kscloud.io/demo-app-reg-backend-api/.default
- Generated at (UTC): 2026-03-31T19:21:47.535360+00:00
- Issued at (UTC): 2026-03-31T19:16:45+00:00
- Expires at (UTC): 2026-03-31T20:21:45+00:00
- Audience: api://kscloud.io/demo-app-reg-backend-api
- Caller app id: 97c446fd-6986-45ff-a0a7-681980a489db
- Roles: Customer.Data.Read

## Raw JWT

Wrapped for readability.

```text
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6IlFaZ045SHFOa0dORU00R2VLY3pEMDJQY1Z2NCIsImtpZCI6IlFaZ045SHFOa0dORU00R2VLY3pE
MDJQY1Z2NCJ9.eyJhdWQiOiJhcGk6Ly9rc2Nsb3VkLmlvL2RlbW8tYXBwLXJlZy1iYWNrZW5kLWFwaSIsImlzcyI6Imh0dHBzOi8vc3RzLndpbmRvd3MubmV
0LzE0YmMyZmY3LTVmZDEtNGNlMi1hMTEwLTRmNzFiOWEyY2U0MS8iLCJpYXQiOjE3NzQ5ODQ2MDUsIm5iZiI6MTc3NDk4NDYwNSwiZXhwIjoxNzc0OTg4NTA
1LCJhaW8iOiJrMlpnWU5oVDUzd3MybGg5OHdHVk9TZVoraU1ZdWlMZVB0ejFpZSszNzdUYkFUK0VLdk1CIiwiYXBwaWQiOiI5N2M0NDZmZC02OTg2LTQ1ZmY
tYTBhNy02ODE5ODBhNDg5ZGIiLCJhcHBpZGFjciI6IjIiLCJpZHAiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC8xNGJjMmZmNy01ZmQxLTRjZTItYTExMC0
0ZjcxYjlhMmNlNDEvIiwib2lkIjoiOTNhOTNlNDMtZmZmOC00MWMxLWE5MmYtYjBjNmI5MDM5YmFlIiwicmgiOiIxLkFVRUI5eS04Rk5GZjRreWhFRTl4dWF
MT1FhNVFRa1I0NFJOTW1VTHNWazUybV9RQUFBQkJBUS4iLCJyb2xlcyI6WyJDdXN0b21lci5EYXRhLlJlYWQiXSwic3ViIjoiOTNhOTNlNDMtZmZmOC00MWM
xLWE5MmYtYjBjNmI5MDM5YmFlIiwidGlkIjoiMTRiYzJmZjctNWZkMS00Y2UyLWExMTAtNGY3MWI5YTJjZTQxIiwidXRpIjoiazFEZm9Ocno2VWlOODc3VEd
ic0lBQSIsInZlciI6IjEuMCIsInhtc19mdGQiOiJGMlZuMTRTOHdZSERjblEwQk1YSC1GR252R09yZmkxVXFtZHl3cGYybDFBQlpYVnliM0JsYm05eWRHZ3R
aSE50Y3cifQ.KDbVyTwht0R3KEVFxbjEaCaNp0sFw1QL6FfvPW50cs8f5aGGrEX7RIqnwc3D_jmVGfp6xxg1SPBbi2fA0TNiRwQihaY9FSWjJgrjKZlJ2OqB
nhuoWJS62pu8xjFBdHVvBg5F71yHPCynfFpF6Ryo8_UrobcZWYp-YNo2HCq87V2YHZ_ZnkPqfY1wFLCJhSv4Y7Cpy1S2RnumMPCrJe_YPEtGRnqMycJT75v9
yZ3e9ogXR5F6cNXVNXSF0JxXtDaKBEtQfygrhh0F_oOjjiPDXlkRvZe8qtdMgsnLGErggS_HxVtGPAfMBWfS7ak5sikAyD_V1Sgd9VYEIjK2pOoCKA
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
  "aio": "k2ZgYNhT53ws2lh98wGVOSeZ+iMYuiLePtz1ie+377TbAT+EKvMB",
  "appid": "97c446fd-6986-45ff-a0a7-681980a489db",
  "appidacr": "2",
  "aud": "api://kscloud.io/demo-app-reg-backend-api",
  "exp": 1774988505,
  "iat": 1774984605,
  "idp": "https://sts.windows.net/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/",
  "iss": "https://sts.windows.net/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/",
  "nbf": 1774984605,
  "oid": "93a93e43-fff8-41c1-a92f-b0c6b9039bae",
  "rh": "1.AUEB9y-8FNFf4kyhEE9xuaLOQa5QQkR44RNMmULsVk52m_QAAABBAQ.",
  "roles": [
    "Customer.Data.Read"
  ],
  "sub": "93a93e43-fff8-41c1-a92f-b0c6b9039bae",
  "tid": "14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41",
  "uti": "k1DfoNrz6UiN877TGbsIAA",
  "ver": "1.0",
  "xms_ftd": "F2Vn14S8wYHDcnQ0BMXH-FGnvGOrfi1Uqmdywpf2l1ABZXVyb3Blbm9ydGgtZHNtcw"
}
```
