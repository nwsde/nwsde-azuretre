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
  local PRIVATE_KEY_PEM_FILE="nexus-vm-ssh.key"
  local PUBLIC_KEY_OPENSSH_FILE="${PRIVATE_KEY_PEM_FILE}.pub"

  if ! az keyvault show --name "$KV_NAME" --output none; then
    echo "Keyvault $KV_NAME not found, exiting"
    exit 1
  fi

  #
  # prepare keyvault
  #
  echo -e "\nRunning nexus SSH keypair generation..."

  if does_secret_exist "$KV_NAME" "$PUBLIC_KEY_SECRET_NAME" && \
     does_secret_exist "$KV_NAME" "$PRIVATE_KEY_SECRET_NAME"; then

    echo -e "\nPublic and private key secrets are both present, no keys to generate, exiting"
    exit 0
  fi

  if is_secret_deleted "$KV_NAME" "$PUBLIC_KEY_SECRET_NAME"; then
    recover_secret "$KV_NAME" "$PUBLIC_KEY_SECRET_NAME"
  fi

  if is_secret_deleted "$KV_NAME" "$PRIVATE_KEY_SECRET_NAME"; then
    recover_secret "$KV_NAME" "$PRIVATE_KEY_SECRET_NAME"
  fi

  #
  # generate keypair
  #
  echo -e "\nOne or both secrets are not present, generating new SSH keypair...\n"

  rm -f "$PUBLIC_KEY_OPENSSH_FILE"
  rm -f "$PRIVATE_KEY_PEM_FILE"

  ssh-keygen -t rsa -m PKCS8 -b 2048 -f "$PRIVATE_KEY_PEM_FILE" -C "adminuser-nexus-vm" -N ""

  #
  # upload to keyvault
  #
  echo -e "\nUploading $PUBLIC_KEY_SECRET_NAME to vault"
  az keyvault secret set --vault-name "$KV_NAME" --name "$PUBLIC_KEY_SECRET_NAME" --file "$PUBLIC_KEY_OPENSSH_FILE"  --output none

  echo -e "\nUploading $PRIVATE_KEY_SECRET_NAME to vault"
  az keyvault secret set --vault-name "$KV_NAME" --name "$PRIVATE_KEY_SECRET_NAME" --file "$PRIVATE_KEY_PEM_FILE" --output none

  rm -f "$PUBLIC_KEY_OPENSSH_FILE"
  rm -f "$PRIVATE_KEY_PEM_FILE"

  echo -e "\nCompleted nexus SSH keypair generation"
}

function is_secret_deleted() {

  local KV_NAME=$1
  local SECRET_NAME=$2

  echo -e "\nChecking if $SECRET_NAME is deleted..."

  if az keyvault secret show-deleted --vault-name "$KV_NAME" --name "$SECRET_NAME" --output none > /dev/null 2>&1; then
    echo "  Deleted secret exists"
    return 0
  fi

  echo "  Deleted secret does not exist"
  return 1
}

function recover_secret() {

  local KV_NAME=$1
  local SECRET_NAME=$2

  echo -e "\nRecovering secret $SECRET_NAME..."

  az keyvault secret recover --vault-name "$KV_NAME" --name "$SECRET_NAME" --output none

  while true; do
    echo "  Secret is recovering..."

    if az keyvault secret show --vault-name "$KV_NAME" --name "$SECRET_NAME" --output none > /dev/null 2>&1; then
      echo "  Secret is now recovered"
      break
    fi

    sleep 5
  done
}

function does_secret_exist() {

  local KV_NAME=$1
  local SECRET_NAME=$2

  echo -e "\nChecking if $SECRET_NAME exists..."

  if ! az keyvault secret show --vault-name "$KV_NAME" --name "$SECRET_NAME" --output none > /dev/null 2>&1; then
    echo "  Secret does not exist"
    return 1
  fi

  echo -e "  Secret exists"
  return 0
}

main "$@"
