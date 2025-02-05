#!/bin/bash

function main {

  #
  # parse parameters
  #
  if [[ $1 != "--tre_id" || -z $2 ]]; then
    echo "--tre-id argument not set"
    exit 1
  fi

  local TRE_ID=$2

  local KV_NAME="kv-$TRE_ID"
  local PUBLIC_KEY_SECRET_NAME="nexus-vm-ssh-public-key"
  local PRIVATE_KEY_SECRET_NAME="nexus-vm-ssh-private-key"

  if ! az keyvault show --name "$KV_NAME" --output none; then
    echo "Keyvault $KV_NAME not found, exiting"
    exit 1
  fi

  #
  # remove from keyvault
  #
  echo -e "\Removing nexus SSH keypair from Key Vault $KV_NAME..."

  echo "Deleting secret $PUBLIC_KEY_SECRET_NAME..."

  az keyvault secret delete --vault-name "$KV_NAME" --name "$PUBLIC_KEY_SECRET_NAME" --output none

  echo "Deleting secret $PRIVATE_KEY_SECRET_NAME..."

  az keyvault secret delete --vault-name "$KV_NAME" --name "$PRIVATE_KEY_SECRET_NAME" --output none

  echo -e "\Completed SSH keypair removal..."
}

main "$@"
