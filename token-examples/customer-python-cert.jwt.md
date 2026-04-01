# JWT Example: customer-python-cert

- Display name: demo-app-reg-customer-python-cert
- Auth method: certificate
- Client id: 97c446fd-6986-45ff-a0a7-681980a489db
- Scope: api://kscloud.io/demo-app-reg-backend-api/.default
- Generated at (UTC): 2026-04-01T05:36:25.098054+00:00
- Issued at (UTC): 2026-04-01T05:31:22+00:00
- Expires at (UTC): 2026-04-01T06:36:22+00:00
- Audience: 444250ae-e178-4c13-9942-ec564e769bf4
- Caller app id: 97c446fd-6986-45ff-a0a7-681980a489db
- Roles: Customer.Data.Read

## Raw JWT

Wrapped for readability.

```text
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6IlFaZ045SHFOa0dORU00R2VLY3pEMDJQY1Z2NCJ9.eyJhdWQiOiI0NDQyNTBhZS1lMTc4LTRjMTM
tOTk0Mi1lYzU2NGU3NjliZjQiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vMTRiYzJmZjctNWZkMS00Y2UyLWExMTAtNGY3MWI
5YTJjZTQxL3YyLjAiLCJpYXQiOjE3NzUwMjE0ODIsIm5iZiI6MTc3NTAyMTQ4MiwiZXhwIjoxNzc1MDI1MzgyLCJhaW8iOiJBU1FBMi84YkFBQUFUYk9RNXZ
uM2E5K3VSdWxTKzgzb0hVU01TMkJSL3p1VVIzWXJtNENiMVNZPSIsImF6cCI6Ijk3YzQ0NmZkLTY5ODYtNDVmZi1hMGE3LTY4MTk4MGE0ODlkYiIsImF6cGF
jciI6IjIiLCJvaWQiOiI5M2E5M2U0My1mZmY4LTQxYzEtYTkyZi1iMGM2YjkwMzliYWUiLCJyaCI6IjEuQVVFQjl5LThGTkZmNGt5aEVFOXh1YUxPUWE1UVF
rUjQ0Uk5NbVVMc1ZrNTJtX1FBQUFCQkFRLiIsInJvbGVzIjpbIkN1c3RvbWVyLkRhdGEuUmVhZCJdLCJzdWIiOiI5M2E5M2U0My1mZmY4LTQxYzEtYTkyZi1
iMGM2YjkwMzliYWUiLCJ0aWQiOiIxNGJjMmZmNy01ZmQxLTRjZTItYTExMC00ZjcxYjlhMmNlNDEiLCJ1dGkiOiIyb1dLS2NaVk5FeUFnaWxOeDNOVUFBIiw
idmVyIjoiMi4wIiwieG1zX2Z0ZCI6IlZFOHN6eWZDNlprbUM3TDE5YVEwaWNHN2NXd0h6S28zc0NZTUxiWWZvWjBCWlhWeWIzQmxkMlZ6ZEMxa2MyMXoifQ.
fBGftsoV5HMnZMqC4-vrkKdhZRySav8rg7RspXmN6jTibZK74GMe-B-
QQgw8Fo9gAScpQCXhSuI6ZDv7EeDGDh38gmqDNqzSK7b-vsNkluEsgC3oWerDiGwnXZpx-
ZOpNRJ4cijhe-1bD7FDO846blNzxanHvq_SR7xlVdQNGU2LXmFuDVR1VNgcSMJDvQDdCHlNDg3Nx6H1u-fcWkNZrgwIAj2lxespdAMq-
msGjt41nnhC8fYuKEYvWj5GrHGKv2nfO5h6cURcRaROtaNYDhAGKCIbOmSfesj9_9UKsb5ch9KFvD6HDW79B6d3qEJecie-XoSiTVf_pwf2tb5gNg
```

## Header

```json
{
  "alg": "RS256",
  "kid": "QZgN9HqNkGNEM4GeKczD02PcVv4",
  "typ": "JWT"
}
```

## Payload

```json
{
  "aio": "ASQA2/8bAAAATbOQ5vn3a9+uRulS+83oHUSMS2BR/zuUR3Yrm4Cb1SY=",
  "aud": "444250ae-e178-4c13-9942-ec564e769bf4",
  "azp": "97c446fd-6986-45ff-a0a7-681980a489db",
  "azpacr": "2",
  "exp": 1775025382,
  "iat": 1775021482,
  "iss": "https://login.microsoftonline.com/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/v2.0",
  "nbf": 1775021482,
  "oid": "93a93e43-fff8-41c1-a92f-b0c6b9039bae",
  "rh": "1.AUEB9y-8FNFf4kyhEE9xuaLOQa5QQkR44RNMmULsVk52m_QAAABBAQ.",
  "roles": [
    "Customer.Data.Read"
  ],
  "sub": "93a93e43-fff8-41c1-a92f-b0c6b9039bae",
  "tid": "14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41",
  "uti": "2oWKKcZVNEyAgilNx3NUAA",
  "ver": "2.0",
  "xms_ftd": "VE8szyfC6ZkmC7L19aQ0icG7cWwHzKo3sCYMLbYfoZ0BZXVyb3Bld2VzdC1kc21z"
}
```
