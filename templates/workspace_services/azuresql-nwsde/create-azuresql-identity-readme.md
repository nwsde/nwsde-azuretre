# Entra manual configuration for `azuresql-nwsde` 

## Background

In order for the Azure SQL instance to communicate with Entra
and validate Entra users/groups being added, it requires
a managed identity with MS Graph permissions of
`Directory.Read.All`.

When the resource processor deploys `azuresql-nwsde`
component it can create the identity, however it does does not
have the permissions to grant another identity MS Graph
admin permissions.

Therefore a managed identity for the Azure SQL instance
must be created manually in advance of using this template and
passed as an `RP_BUNDLE_VALUES` element. Only one identity
is required per TRE - the identity is re-used across Azure SQL
instances.

## Create an identity for NWSDE Azure SQL

1. Ensure your TRE's config.yaml file is created and populated.

2. Run the `create-azuresql-identity.sh` script, with a user that has Directory granting permissions such as Global Administrator.

3. Add the resulting identity resource ID to a `azuresql_identity` attribute of the `RP_BUNDLE_VALUES` variable in `config.yaml` or
GitHub secrets, depending on your deployment method.

The `RP_BUNDLE_VALUES` variable is a JSON object, and the `azuresql_identity` property within it identifies the image gallery that contains the images specified by `source_image_name`:

```bash
RP_BUNDLE_VALUES='{"azuresql_identity":"/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/<mgmt-rg>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-azuresql-<tre_id>"}'
```

4. Once added you will need either re-run a full deployment, or re-run `make deploy-core`.
