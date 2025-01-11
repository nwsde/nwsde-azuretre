#!/bin/bash

# requires a privileged entra role to run, e.g. Global Administrator

BOLD="\e[1m"
NORMAL="\e[0m"

echo -e "${BOLD}Creating Azure SQL identity for use in NWSDE-Common-Services deployment${NORMAL}"
echo -e "${BOLD}-----------------------------------------------------------------------${NORMAL}\n"

CONFIG_YAML=../../../config.yaml

echo -e "${BOLD}Parsing values from ${CONFIG_YAML}...${NORMAL}\n"

if [[ ! -f "$CONFIG_YAML" ]]; then
  echo -e "config.yaml file not found"
  exit 1
fi

LOCATION=$(yq '.location' "$CONFIG_YAML")
TRE_ID=$(yq '.tre_id' "$CONFIG_YAML")
MGMT_RESOURCE_GROUP=$(yq '.management.mgmt_resource_group_name' "$CONFIG_YAML")

if [[ -z "$LOCATION" ]]; then
  echo "Value not found for LOCATION in config.yaml"
  exit 1
fi

if [[ -z "$TRE_ID" ]]; then
  echo "Value not found for TRE_ID in config.yaml"
  exit 1
fi

if [[ -z "$MGMT_RESOURCE_GROUP" ]]; then
  echo "Value not found for MGMT_RESOURCE_GROUP in config.yaml"
  exit 1
fi

IDENTITY_NAME="id-azuresql-$TRE_ID"

echo -e "Using values:\n"
echo -e " > TRE_ID              = ${TRE_ID}"
echo -e " > LOCATION            = ${LOCATION}"
echo -e " > MGMT_RESOURCE_GROUP = ${MGMT_RESOURCE_GROUP}"
echo -e "\nCreating identity:\n"
echo -e " > AZURESQL_IDENTITY   = ${IDENTITY_NAME}\n"

echo -e "${BOLD}Checking for resource group $MGMT_RESOURCE_GROUP (and creating if doesn't exist)...${NORMAL}\n"

az group create --name "$MGMT_RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output table

echo -e "\n${BOLD}Creating identity $IDENTITY_NAME...${NORMAL}\n"

az identity create --name "$IDENTITY_NAME" \
  --resource-group "$MGMT_RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags "manually-created=true" \
  --output table

echo -e "\n${BOLD}Waiting 30s for Entra service principal to be created...${NORMAL}\n"

sleep 30

echo -e "\n${BOLD}Granting directory read permissions to identity $IDENTITY_NAME...${NORMAL}\n"

MSGRAPH_APP_ID="00000003-0000-0000-c000-000000000000"
MSGRAPH_APP_PERMISSION="Directory.Read.All"
MSGRAPH_SP_ID=$(az ad sp show --id "$MSGRAPH_APP_ID" --query id --output tsv)
MSGRAPH_APP_PERMISSION_ID=$(az ad sp show --id "$MSGRAPH_APP_ID" --query "appRoles[?value=='$MSGRAPH_APP_PERMISSION'].id" --output tsv)
IDENTITY_SP_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$MGMT_RESOURCE_GROUP" --query principalId --output tsv)

az rest --method POST \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$IDENTITY_SP_ID/appRoleAssignments" \
  --body @- << EOF
{
  "principalId": "$IDENTITY_SP_ID",
  "resourceId": "$MSGRAPH_SP_ID",
  "appRoleId": "$MSGRAPH_APP_PERMISSION_ID"
}
EOF

echo -e "\n${BOLD}Now set the azuresql_identity attribute in RP_BUNDLE_VALUES (in deploy.env or GitHub Secrets) to the resource ID below${NORMAL}"
echo -e "${BOLD}----------------------------------------------------------------------------------------------------------------------${NORMAL}\n"

RESOURCE_ID=$(az identity show --name "$IDENTITY_NAME" \
  --resource-group "$MGMT_RESOURCE_GROUP" \
  --query id \
  --output tsv)

echo -e "{\"azuresql_identity\":\"${RESOURCE_ID}\"}\n"
