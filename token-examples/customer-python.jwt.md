# JWT Example: customer-python

- Display name: demo-app-reg-customer-python
- Auth method: client-secret
- Client id: 3e82d5de-3cbe-44cf-afd4-242ff1d3fdb5
- Scope: api://kscloud.io/demo-app-reg-backend-api/.default
- Generated at (UTC): 2026-03-31T19:21:46.509608+00:00
- Issued at (UTC): 2026-03-31T19:16:44+00:00
- Expires at (UTC): 2026-03-31T20:21:44+00:00
- Audience: api://kscloud.io/demo-app-reg-backend-api
- Caller app id: 3e82d5de-3cbe-44cf-afd4-242ff1d3fdb5
- Roles: Customer.Data.Read

## Raw JWT

Wrapped for readability.

```text
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6IlFaZ045SHFOa0dORU00R2VLY3pEMDJQY1Z2NCIsImtpZCI6IlFaZ045SHFOa0dORU00R2VLY3pE
MDJQY1Z2NCJ9.eyJhdWQiOiJhcGk6Ly9rc2Nsb3VkLmlvL2RlbW8tYXBwLXJlZy1iYWNrZW5kLWFwaSIsImlzcyI6Imh0dHBzOi8vc3RzLndpbmRvd3MubmV
0LzE0YmMyZmY3LTVmZDEtNGNlMi1hMTEwLTRmNzFiOWEyY2U0MS8iLCJpYXQiOjE3NzQ5ODQ2MDQsIm5iZiI6MTc3NDk4NDYwNCwiZXhwIjoxNzc0OTg4NTA
0LCJhaW8iOiJrMlpnWVBoL2NmM1VFQjZmb2l4bkpidFQ2a3RPM0o2eHNGdlM5RHV6NmNROXJhWnA1NFFBIiwiYXBwaWQiOiIzZTgyZDVkZS0zY2JlLTQ0Y2Y
tYWZkNC0yNDJmZjFkM2ZkYjUiLCJhcHBpZGFjciI6IjEiLCJpZHAiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC8xNGJjMmZmNy01ZmQxLTRjZTItYTExMC0
0ZjcxYjlhMmNlNDEvIiwib2lkIjoiMzM3YjMxMjItYjU3ZS00NDc2LTk1NmMtYTMyNzA2OTVkMTNmIiwicmgiOiIxLkFVRUI5eS04Rk5GZjRreWhFRTl4dWF
MT1FhNVFRa1I0NFJOTW1VTHNWazUybV9RQUFBQkJBUS4iLCJyb2xlcyI6WyJDdXN0b21lci5EYXRhLlJlYWQiXSwic3ViIjoiMzM3YjMxMjItYjU3ZS00NDc
2LTk1NmMtYTMyNzA2OTVkMTNmIiwidGlkIjoiMTRiYzJmZjctNWZkMS00Y2UyLWExMTAtNGY3MWI5YTJjZTQxIiwidXRpIjoiYzBCR3hkXzhkMGVkTkpicEd
SNmtBQSIsInZlciI6IjEuMCIsInhtc19mdGQiOiJEMi1VQVAtczFKVUZPZ0RBRHFRSzl1V09CZC1OLWtFb1hWdDB2RVVQaW5RQlpYVnliM0JsZDJWemRDMWt
jMjF6In0.dbehqYtynaVrIuy2ia-3zM8s1mZS86iQdA-ct2W3Gv5UrB1fx2o6fdviAOSU7DQi2JQg37XmXbl19ebNs5ihFRhMWke1SrexFiLMmjXtyJbBn7S
MWReE9juhmOXpAv9G3OHR1aGmSbeUsKfNcTF2CHCRClOG5CJR0YlPuY8qf3vGYVFfXruROCtyJhmOEzXrpif7F0edWmBJBgjeGnyoM8m9gHFELHzBSr7o98G
GbtvWbUY4G2Jm1XU_hw-uMZGeUpRhYJOKJavn3p7MKxe-Ko1yz6rikGRIk2wXNNAcRwCi98wfjGbd39x0yXyltaalKaXg3TbMQMDozct12Q6JlQ
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
  "aio": "k2ZgYPh/cf3UEB6foixnJbtT6ktO3J6xsFvS9Duz6cQ9raZp54QA",
  "appid": "3e82d5de-3cbe-44cf-afd4-242ff1d3fdb5",
  "appidacr": "1",
  "aud": "api://kscloud.io/demo-app-reg-backend-api",
  "exp": 1774988504,
  "iat": 1774984604,
  "idp": "https://sts.windows.net/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/",
  "iss": "https://sts.windows.net/14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41/",
  "nbf": 1774984604,
  "oid": "337b3122-b57e-4476-956c-a3270695d13f",
  "rh": "1.AUEB9y-8FNFf4kyhEE9xuaLOQa5QQkR44RNMmULsVk52m_QAAABBAQ.",
  "roles": [
    "Customer.Data.Read"
  ],
  "sub": "337b3122-b57e-4476-956c-a3270695d13f",
  "tid": "14bc2ff7-5fd1-4ce2-a110-4f71b9a2ce41",
  "uti": "c0BGxd_8d0edNJbpGR6kAA",
  "ver": "1.0",
  "xms_ftd": "D2-UAP-s1JUFOgDADqQK9uWOBd-N-kEoXVt0vEUPinQBZXVyb3Bld2VzdC1kc21z"
}
```
