# JWT Example: customer-typescript

- Display name: demo-app-reg-customer-typescript
- Auth method: client-secret
- Client id: cff3b563-5c46-4c74-85bf-c317cc9d5449
- Scope: api://kscloud.io/demo-app-reg-backend-api/.default
- Generated at (UTC): 2026-03-31T19:21:46.977739+00:00
- Issued at (UTC): 2026-03-31T19:16:45+00:00
- Expires at (UTC): 2026-03-31T20:21:45+00:00
- Audience: api://kscloud.io/demo-app-reg-backend-api
- Caller app id: cff3b563-5c46-4c74-85bf-c317cc9d5449
- Roles: Customer.Data.Read

## Raw JWT

Wrapped for readability.

```text
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6IlFaZ045SHFOa0dORU00R2VLY3pEMDJQY1Z2NCIsImtpZCI6IlFaZ045SHFOa0dORU00R2VLY3pE
MDJQY1Z2NCJ9.eyJhdWQiOiJhcGk6Ly9rc2Nsb3VkLmlvL2RlbW8tYXBwLXJlZy1iYWNrZW5kLWFwaSIsImlzcyI6Imh0dHBzOi8vc3RzLndpbmRvd3MubmV
0LzE0YmMyZmY3LTVmZDEtNGNlMi1hMTEwLTRmNzFiOWEyY2U0MS8iLCJpYXQiOjE3NzQ5ODQ2MDUsIm5iZiI6MTc3NDk4NDYwNSwiZXhwIjoxNzc0OTg4NTA
1LCJhaW8iOiJrMlpnWUtnSVp2OVIycG9xNHl4c0loaSszKzJUMitGeVJhTTdTbHR1bGovN2V5aEtOeG9BIiwiYXBwaWQiOiJjZmYzYjU2My01YzQ2LTRjNzQ
tODViZi1jMzE3Y2M5ZDU0NDkiLCJhcHBpZGFjciI6IjEiLCJpZHAiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC8xNGJjMmZmNy01ZmQxLTRjZTItYTExMC0
0ZjcxYjlhMmNlNDEvIiwib2lkIjoiMzUxMzVmOGEtMzBmOC00ODMyLWEzMTctMjJmMWFjYTJiODIxIiwicmgiOiIxLkFVRUI5eS04Rk5GZjRreWhFRTl4dWF
MT1FhNVFRa1I0NFJOTW1VTHNWazUybV9RQUFBQkJBUS4iLCJyb2xlcyI6WyJDdXN0b21lci5EYXRhLlJlYWQiXSwic3ViIjoiMzUxMzVmOGEtMzBmOC00ODM
yLWEzMTctMjJmMWFjYTJiODIxIiwidGlkIjoiMTRiYzJmZjctNWZkMS00Y2UyLWExMTAtNGY3MWI5YTJjZTQxIiwidXRpIjoidnVpSVZjZDFWa2FsVHNRb1E
zNGxBQSIsInZlciI6IjEuMCIsInhtc19mdGQiOiJVdDd0UmF5UUo4VjhBUE9ZMGZncEp1WXRRYVdjbmZNS2VMRlkxQ3NySEswQmMzZGxaR1Z1WXkxa2MyMXo
ifQ.QOKp83cIAWQ0uEtFxoYkovge8-4aapn_ThezMi7ZqoGs-_vfl1FAeUbkzvoqzZE41YlscDJfV7js297dDWN-E7fUzSw0ZRdKrs0KdP2-
DY8StKaCyvL9fnCp7oIXfew2uQKkI9XVleMwPjFctGqm7YbShtDIsXFeqX7b3hN1L9TP5lXwJPJ0yYxEaujH_Whv6ssPg0-WqeH8hDXMeTav-cnYSawcz6C3
uZwTiFRii8mMzUNq082ZfpgVsNbJKGEzKrCdnRmIUdHGLeag74zOaqZyVScS7G5-ekkoKmr39KaS9cAXULcmv4rqBMmT_Gqy6h8JEfiTvvNXIH24JrL0Ng
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
  "aio": "k2ZgYKgIZv9R2poq4yxsIhi+3+2T2+FyRaM7Sltulj/7eyhKNxoA",
  "appid": "cff3b563-5c46-4c74-85bf-c317cc9d5449",
  "appidacr": "1",
  "aud": "api://kscloud.io/demo-app-reg-backend-api",
  "exp": 1774988505,
  "iat": 1774984605,
  "idp": "https://sts.windows.net/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/",
  "iss": "https://sts.windows.net/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/",
  "nbf": 1774984605,
  "oid": "35135f8a-30f8-4832-a317-22f1aca2b821",
  "rh": "1.AUEB9y-8FNFf4kyhEE9xuaLOQa5QQkR44RNMmULsVk52m_QAAABBAQ.",
  "roles": [
    "Customer.Data.Read"
  ],
  "sub": "35135f8a-30f8-4832-a317-22f1aca2b821",
  "tid": "14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41",
  "uti": "vuiIVcd1VkalTsQoQ34lAA",
  "ver": "1.0",
  "xms_ftd": "Ut7tRayQJ8V8APOY0fgpJuYtQaWcnfMKeLFY1CsrHK0Bc3dlZGVuYy1kc21z"
}
```
