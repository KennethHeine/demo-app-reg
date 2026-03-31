# Goal And Intent

This setup is intended to demonstrate a practical customer-to-platform API pattern using Microsoft Entra ID.

## Primary Goal

Show how multiple customer applications can call the same backend API while only receiving their own data.

## What The Demo Proves

- A shared API can validate Microsoft Entra access tokens reliably.
- Customer applications can authenticate as confidential clients with either a client secret or a certificate.
- The backend can combine coarse-grained authorization and fine-grained tenant-specific routing.
- Credentials can be pulled from Azure Key Vault instead of being stored directly in local configuration.
- Customer onboarding can scale through a manifest-driven provisioning model instead of code changes and one-off manual setup.

## Why The Design Uses Both Role And App Id Mapping

The role and the app id solve different problems.

- The app role answers: is this caller allowed to call the backend API at all?
- The caller app id mapping answers: which customer dataset should this caller receive?

If the backend only used the app role, every authorized customer would be equally allowed but not separated. If it only used the app id mapping, there would be no explicit permission boundary on the API itself.

## Why Key Vault Was Added

The first version stored credentials directly in local `.env` files. That works for a very small demo, but it does not scale well and it encourages weak secret hygiene.

Key Vault improves the setup by:

- Removing raw secret values from committed configuration examples.
- Allowing the same client code to resolve credentials at runtime.
- Supporting a clean path to certificate-based auth.
- Creating a more realistic model for future deployment work.

## Intended Audience

This repo is useful for:

- Learning Entra app-to-app authentication.
- Demonstrating customer isolation in a shared backend.
- Exploring secret-based versus certificate-based confidential client authentication.
- Prototyping a customer onboarding flow before moving to production infrastructure.

## Non-Goals

This repo is not trying to be a production-ready SaaS platform. It does not yet include:

- A persistent customer registry database.
- Automated customer lifecycle management.
- Managed identities for deployed workloads.
- Production RBAC modeling for each customer runtime.
- Operational dashboards, monitoring, or incident handling.

## Recommended Next Steps

1. Move the customer registry from a generated local file into a real data store.
2. Replace local developer authentication for Key Vault with workload identities or managed identities.
3. Add onboarding and cleanup scripts for customer lifecycle operations.
4. Add token inspection and troubleshooting docs for support workflows.
