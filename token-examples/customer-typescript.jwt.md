# JWT Example: customer-typescript

- Display name: demo-app-reg-customer-typescript
- Auth method: client-secret
- Client id: cff3b563-5c46-4c74-85bf-c317cc9d5449
- Scope: api://kscloud.io/demo-app-reg-backend-api/.default
- Generated at (UTC): 2026-04-01T05:36:24.511072+00:00
- Issued at (UTC): 2026-04-01T05:31:22+00:00
- Expires at (UTC): 2026-04-01T06:36:22+00:00
- Audience: 444250ae-e178-4c13-9942-ec564e769bf4
- Caller app id: cff3b563-5c46-4c74-85bf-c317cc9d5449
- Roles: Customer.Data.Read

## Raw JWT

Wrapped for readability.

```text
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6IlFaZ045SHFOa0dORU00R2VLY3pEMDJQY1Z2NCJ9.eyJhdWQiOiI0NDQyNTBhZS1lMTc4LTRjMTM
tOTk0Mi1lYzU2NGU3NjliZjQiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vMTRiYzJmZjctNWZkMS00Y2UyLWExMTAtNGY3MWI
5YTJjZTQxL3YyLjAiLCJpYXQiOjE3NzUwMjE0ODIsIm5iZiI6MTc3NTAyMTQ4MiwiZXhwIjoxNzc1MDI1MzgyLCJhaW8iOiJrMlpnWU5oVDUzd3MybGg5OHd
HVk9TZVoraU1ZdWlMZVB0ejFpZSszNzdUYkFUK0VLdk1CIiwiYXpwIjoiY2ZmM2I1NjMtNWM0Ni00Yzc0LTg1YmYtYzMxN2NjOWQ1NDQ5IiwiYXpwYWNyIjo
iMSIsIm9pZCI6IjM1MTM1ZjhhLTMwZjgtNDgzMi1hMzE3LTIyZjFhY2EyYjgyMSIsInJoIjoiMS5BVUVCOXktOEZORmY0a3loRUU5eHVhTE9RYTVRUWtSNDR
STk1tVUxzVms1Mm1fUUFBQUJCQVEuIiwicm9sZXMiOlsiQ3VzdG9tZXIuRGF0YS5SZWFkIl0sInN1YiI6IjM1MTM1ZjhhLTMwZjgtNDgzMi1hMzE3LTIyZjF
hY2EyYjgyMSIsInRpZCI6IjE0YmMyZmY3LTVmZDEtNGNlMi1hMTEwLTRmNzFiOWEyY2U0MSIsInV0aSI6IkhxWVY2Q1RWZWtHQVRiQ2o0ZEEwQUEiLCJ2ZXI
iOiIyLjAiLCJ4bXNfZnRkIjoiTTBtM09rVk5wS3JqLTJLZ1FhdkFfbms3SWxJR0FMQ0x5UmhhWGo3UEdBc0JjM2RsWkdWdVl5MWtjMjF6In0.HqoTCRguimk
byWggPfhDR4CGUaeTjf-QlJieAeCsnUqcmRiEPjPqFDIzar-
8bo0s5vdaRwTOWbwvueY9zvyUFzRHFvDGr47CuSLFfmFxYbuOx8aEdjCMCmp6A2UAbjrQ_4WoBB_WEYmRvS0nmYq1xQdM9RRPieZXj8C6hw_FyKdAHkuHsz5
jPrVG2vQjkbJra6khXtyJ0p4FvRPA0YhBbqR29-
lNf0_YyTJ7S84FVTdRcu2MuRalqoaDOCxaVgEWIQ3CeX1kmfWIzZOynE9R0F1gdeWXaYrbV9MgqUXoEmBUDI7gE7rJcyWJRgye3gDtYPmCZy4e7vsa3e363M
LMMQ
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
  "aio": "k2ZgYNhT53ws2lh98wGVOSeZ+iMYuiLePtz1ie+377TbAT+EKvMB",
  "aud": "444250ae-e178-4c13-9942-ec564e769bf4",
  "azp": "cff3b563-5c46-4c74-85bf-c317cc9d5449",
  "azpacr": "1",
  "exp": 1775025382,
  "iat": 1775021482,
  "iss": "https://login.microsoftonline.com/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/v2.0",
  "nbf": 1775021482,
  "oid": "35135f8a-30f8-4832-a317-22f1aca2b821",
  "rh": "1.AUEB9y-8FNFf4kyhEE9xuaLOQa5QQkR44RNMmULsVk52m_QAAABBAQ.",
  "roles": [
    "Customer.Data.Read"
  ],
  "sub": "35135f8a-30f8-4832-a317-22f1aca2b821",
  "tid": "14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41",
  "uti": "HqYV6CTVekGATbCj4dA0AA",
  "ver": "2.0",
  "xms_ftd": "M0m3OkVNpKrj-2KgQavA_nk7IlIGALCLyRhaXj7PGAsBc3dlZGVuYy1kc21z"
}
```
