#!/bin/bash
set -e

# This script is not used and is left here for you to debug the creation of the workspace
# at a Terraform level without having to interact with Porter

# This script assumes you have created an .env from the sample and the variables
# will come from there.
# shellcheck disable=SC2154
terraform init -reconfigure -input=false -backend=true \
    -backend-config="resource_group_name=rg-nwsdedev-mgmt" \
    -backend-config="storage_account_name=nwsdedevmgmtstore" \
    -backend-config="container_name=tfstate" \
    -backend-config="key=mike-terra-test"

terraform plan
#terraform apply -auto-approve
