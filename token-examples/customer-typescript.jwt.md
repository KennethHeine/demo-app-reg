# JWT Example: customer-typescript

- Display name: demo-app-reg-customer-typescript
- Auth method: client-secret
- Client id: cff3b563-5c46-4c74-85bf-c317cc9d5449
- Scope: api://kscloud.io/demo-app-reg-backend-api/.default
- Generated at (UTC): 2026-03-31T08:11:03.407198+00:00
- Issued at (UTC): 2026-03-31T08:06:02+00:00
- Expires at (UTC): 2026-03-31T09:11:02+00:00
- Audience: api://kscloud.io/demo-app-reg-backend-api
- Caller app id: cff3b563-5c46-4c74-85bf-c317cc9d5449
- Roles: Customer.Data.Read

## Raw JWT

Wrapped for readability.

```text
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6IlFaZ045SHFOa0dORU00R2VLY3pEMDJQY1Z2NCIsImtpZCI6IlFaZ045SHFOa0dORU00R2VLY3pE
MDJQY1Z2NCJ9.eyJhdWQiOiJhcGk6Ly9rc2Nsb3VkLmlvL2RlbW8tYXBwLXJlZy1iYWNrZW5kLWFwaSIsImlzcyI6Imh0dHBzOi8vc3RzLndpbmRvd3MubmV
0LzE0YmMyZmY3LTVmZDEtNGNlMi1hMTEwLTRmNzFiOWEyY2U0MS8iLCJpYXQiOjE3NzQ5NDQzNjIsIm5iZiI6MTc3NDk0NDM2MiwiZXhwIjoxNzc0OTQ4MjY
yLCJhaW8iOiJrMlpnWUZnZElXcTltbWYzTjI1UGsvazNmWGlMQ3YxWDM2bXJzUzQ5OTJ2QnZ0KytmUzhCIiwiYXBwaWQiOiJjZmYzYjU2My01YzQ2LTRjNzQ
tODViZi1jMzE3Y2M5ZDU0NDkiLCJhcHBpZGFjciI6IjEiLCJpZHAiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC8xNGJjMmZmNy01ZmQxLTRjZTItYTExMC0
0ZjcxYjlhMmNlNDEvIiwib2lkIjoiMzUxMzVmOGEtMzBmOC00ODMyLWEzMTctMjJmMWFjYTJiODIxIiwicmgiOiIxLkFVRUI5eS04Rk5GZjRreWhFRTl4dWF
MT1FhNVFRa1I0NFJOTW1VTHNWazUybV9RQUFBQkJBUS4iLCJyb2xlcyI6WyJDdXN0b21lci5EYXRhLlJlYWQiXSwic3ViIjoiMzUxMzVmOGEtMzBmOC00ODM
yLWEzMTctMjJmMWFjYTJiODIxIiwidGlkIjoiMTRiYzJmZjctNWZkMS00Y2UyLWExMTAtNGY3MWI5YTJjZTQxIiwidXRpIjoiWTNub2xkYkpsMEdNM2RTSWd
IY1FBQSIsInZlciI6IjEuMCIsInhtc19mdGQiOiJCcUZvQmtNMXdnWjJ3c21DaXRqRWdWNmtmUzE4Z09UWFMyRHBYalFKSHRnQlpYVnliM0JsYm05eWRHZ3R
aSE50Y3cifQ.EAm1iI8g9K8HAkQFUaKiYxyvsCB6Pn0Igpwp24Xhykpig_gPMyjgA8TsgW5wMFqrXmjy995P0xZq4uIQ_fjj3-
oiOiiEuX9kGO0DBDC14dHuZGdXMKNTVXK7LV197NUdSNmqd3pemUeO5BxGNTRgVu8SAS-
G4rK9vjkQmgQJxQQ3rBjTlG05ePSDNtyR7CXZe_EGqA29zDTWuDJR8dRqWLwYJ3efTk8_0CBaRGtJ0Kn45g-UNL6Jp-
ZbwkvHkykbpgE5ZpAUlbee4tnEmzhllw4Jzp65xwG1r3HIeuDpTitmn4qGh1eLldPkj4pIASfYKlhFhwQ-_7NCh_E-vYkIjw
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
  "aio": "k2ZgYFgdIWq9mmf3N25Pk/k3fXiLCv1X36mrsS4992vBvt++fS8B",
  "appid": "cff3b563-5c46-4c74-85bf-c317cc9d5449",
  "appidacr": "1",
  "aud": "api://kscloud.io/demo-app-reg-backend-api",
  "exp": 1774948262,
  "iat": 1774944362,
  "idp": "https://sts.windows.net/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/",
  "iss": "https://sts.windows.net/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/",
  "nbf": 1774944362,
  "oid": "35135f8a-30f8-4832-a317-22f1aca2b821",
  "rh": "1.AUEB9y-8FNFf4kyhEE9xuaLOQa5QQkR44RNMmULsVk52m_QAAABBAQ.",
  "roles": [
    "Customer.Data.Read"
  ],
  "sub": "35135f8a-30f8-4832-a317-22f1aca2b821",
  "tid": "14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41",
  "uti": "Y3noldbJl0GM3dSIgHcQAA",
  "ver": "1.0",
  "xms_ftd": "BqFoBkM1wgZ2wsmCitjEgV6kfS18gOTXS2DpXjQJHtgBZXVyb3Blbm9ydGgtZHNtcw"
}
```
