# Token Request Failure: customer-python

- Display name: demo-app-reg-customer-python
- Auth method: client-secret
- Client id: 3e82d5de-3cbe-44cf-afd4-242ff1d3fdb5
- Scope: api://kscloud.io/demo-app-reg-backend-api/.default
- Role assignment: not-assigned
- Generated at (UTC): 2026-04-01T05:36:23.937453+00:00

No JWT was issued for this customer because the backend enterprise application requires assignment and this client app is intentionally left unassigned for the demo.

- Error: invalid_grant
- Error codes: 501051
- Error description: AADSTS501051: Application '3e82d5de-3cbe-44cf-afd4-242ff1d3fdb5'(demo-app-reg-customer-python) is not assigned to a role for the application 'api://kscloud.io/demo-app-reg-backend-api'(demo-app-reg-backend-api). Trace ID: b373e12e-6d38-4cab-b1dd-6db8dee52a00 Correlation ID: 78fccf30-86c9-4522-b537-42f5e1030748 Timestamp: 2026-04-01 05:36:21Z

## Raw Token Response

```json
{
  "correlation_id": "78fccf30-86c9-4522-b537-42f5e1030748",
  "error": "invalid_grant",
  "error_codes": [
    501051
  ],
  "error_description": "AADSTS501051: Application '3e82d5de-3cbe-44cf-afd4-242ff1d3fdb5'(demo-app-reg-customer-python) is not assigned to a role for the application 'api://kscloud.io/demo-app-reg-backend-api'(demo-app-reg-backend-api). Trace ID: b373e12e-6d38-4cab-b1dd-6db8dee52a00 Correlation ID: 78fccf30-86c9-4522-b537-42f5e1030748 Timestamp: 2026-04-01 05:36:21Z",
  "error_uri": "https://login.microsoftonline.com/error?code=501051",
  "timestamp": "2026-04-01 05:36:21Z",
  "trace_id": "b373e12e-6d38-4cab-b1dd-6db8dee52a00"
}
```
