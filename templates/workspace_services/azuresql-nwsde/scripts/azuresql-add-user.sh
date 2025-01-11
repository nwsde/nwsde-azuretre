#!/bin/bash

set -e  # exit on error

echo -e "\n------------------------------------------------------------"
echo -e "-- Azure SQL add user starting..."
echo -e "------------------------------------------------------------\n"


#
# scripts
#

CURRENT_DIR=$(dirname "${BASH_SOURCE[0]}")
ADD_DATABASE_USER_SCRIPT="$CURRENT_DIR/add-database-user.sql"
ADD_DATABASE_ROLES_SCRIPT="$CURRENT_DIR/add-database-roles.sql"
ADD_DATABASE_PERMISSIONS_SCRIPT="$CURRENT_DIR/add-database-permissions.sql"
GET_USER_SID_SCRIPT="$CURRENT_DIR/get-user-sid.sql"


#
# print expected env vars
#

echo -e "> Found environment variables...\n"

echo "AZ_ENVIRONMENT         = $AZ_ENVIRONMENT"
echo "AZ_SP_CLIENT_ID        = $AZ_SP_CLIENT_ID"
echo "AZ_SP_CLIENT_SECRET    = (suppressed)"
echo "AZ_SP_TENANT_ID        = $AZ_SP_TENANT_ID"
echo "AZ_MI_CLIENT_ID        = $AZ_MI_CLIENT_ID"
echo "RG_NAME                = $RG_NAME"
echo "SERVER_NAME            = $SERVER_NAME"
echo "SERVER_FQDN            = $SERVER_FQDN"
echo "SERVER_IP              = $SERVER_IP"
echo "DATABASE_NAME          = $DATABASE_NAME"
echo "ENTRA_SQL_USERS_GROUP  = $ENTRA_SQL_USERS_GROUP"
echo "ENTRA_SQL_ADMINS_GROUP = $ENTRA_SQL_ADMINS_GROUP"
echo "CLOUD_ADMIN_USER       = $CLOUD_ADMIN_USER"


#
# test private DNS resolution
#

echo -e "\n> Testing private link DNS resolution to $SERVER_FQDN...\n"

MAX_ATTEMPTS=30
ATTEMPT=0
STABLE_COUNT=0
STABLE_REQUIRED=5
RESOLVED_IP=""

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do

  RESOLVED_IP=$(nslookup "$SERVER_FQDN" | tail -n +4 | grep "Address:" | awk '{print $2}' | head -n 1)

  echo -e "Attempt $((ATTEMPT+1)):  $SERVER_FQDN resolves to $RESOLVED_IP. Actual IP is $SERVER_IP\n"

  if [[ "$RESOLVED_IP" == "$SERVER_IP" ]]; then
    STABLE_COUNT=$((STABLE_COUNT + 1))
  else
    STABLE_COUNT=0
  fi

  if [ $STABLE_COUNT -eq $STABLE_REQUIRED ]; then
    echo -e "DNS has stablised with $STABLE_REQUIRED correct sequential resolutions, continuing\n"
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  sleep 10

done

if [[ "$RESOLVED_IP" != "$SERVER_IP" ]]; then
  echo -e "\n$SERVER_FQDN IP was not resolved to private IP after $MAX_ATTEMPTS, quitting\n"
  exit 1
fi


#
# SQL functions
#
function sql_test_connection() {

  local SERVER_FQDN=$1
  local DATABASE=$2

  sqlcmd --server "$SERVER_FQDN" \
         --database-name "$DATABASE" \
         --authentication-method "ActiveDirectoryServicePrincipal" \
         --user-name "${AZ_SP_CLIENT_ID}@${AZ_SP_TENANT_ID}" \
         --password "$AZ_SP_CLIENT_SECRET" \
         --query "select 1;" \
         --query-timeout 30 \
         --exit-on-error 2>&1

}

function sql_execute_query() {

  local SERVER_FQDN=$1
  local DATABASE=$2
  local INPUT_FILE=$3
  local VARIABLE=$4

  sqlcmd --server "$SERVER_FQDN" \
         --database-name "$DATABASE" \
         --authentication-method "ActiveDirectoryServicePrincipal" \
         --user-name "${AZ_SP_CLIENT_ID}@${AZ_SP_TENANT_ID}" \
         --password "$AZ_SP_CLIENT_SECRET" \
         --input-file "$INPUT_FILE" \
         --variables "$VARIABLE" \
         --query-timeout 30 \
         --exit-on-error

}

function sql_get_singleton_value() {

  local SERVER_FQDN=$1
  local DATABASE=$2
  local INPUT_FILE=$3
  local VARIABLE=$4

  sqlcmd --server "$SERVER_FQDN" \
         --database-name "master" \
         --authentication-method "ActiveDirectoryServicePrincipal" \
         --user-name "${AZ_SP_CLIENT_ID}@${AZ_SP_TENANT_ID}" \
         --password "$AZ_SP_CLIENT_SECRET" \
         --input-file "$INPUT_FILE" \
         --variables "$VARIABLE" \
         --query-timeout 30 \
         --exit-on-error \
         --headers -1 \
    | tr -d '[:space:]' \
    | tr '[:upper:]' '[:lower:]'

}


#
# test SQL connection
#

MAX_ATTEMPTS=30
ATTEMPT=0
STABLE_COUNT=0
STABLE_REQUIRED=5
CONNECTION_SUCCESS=false

echo -e "\n> Testing SQL connection to $SERVER_FQDN...\n"

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do

  if SQLCMD_OUTPUT=$(sql_test_connection "$SERVER_FQDN" "$DATABASE_NAME"); then
    STABLE_COUNT=$((STABLE_COUNT + 1))
    echo -e "Attempt $((ATTEMPT+1)):  SQL connection succeeded to server $SERVER_FQDN\n"
  else
    STABLE_COUNT=0
    echo -e "Attempt $((ATTEMPT+1)):  SQL connection failed to server $SERVER_FQDN with error:  $SQLCMD_OUTPUT\n"
  fi

  if [ $STABLE_COUNT -eq $STABLE_REQUIRED ]; then
    echo -e "Azure SQL has stablised with $STABLE_REQUIRED successful sequential connections, continuing\n"
    CONNECTION_SUCCESS=true
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  sleep 10

done

if ! $CONNECTION_SUCCESS; then
  echo -e "\nSQL connection failed to server $SERVER_FQDN after $MAX_ATTEMPTS, quitting\n"
  exit 1
fi


#
# add users
#

echo -e "\n > Adding group [$ENTRA_SQL_USERS_GROUP] to master database...\n"
sql_execute_query "$SERVER_FQDN" "master" "$ADD_DATABASE_USER_SCRIPT" "username=$ENTRA_SQL_USERS_GROUP"

echo -e "\n > Adding group [$ENTRA_SQL_USERS_GROUP] to $DATABASE_NAME database...\n"
sql_execute_query "$SERVER_FQDN" "$DATABASE_NAME" "$ADD_DATABASE_USER_SCRIPT" "username=$ENTRA_SQL_USERS_GROUP"

echo -e "\n > Adding group [$ENTRA_SQL_ADMINS_GROUP] to $DATABASE_NAME database...\n"
sql_execute_query "$SERVER_FQDN" "$DATABASE_NAME" "$ADD_DATABASE_USER_SCRIPT" "username=$ENTRA_SQL_ADMINS_GROUP"

echo -e "\n > Adding custom roles to $DATABASE_NAME database...\n"
sql_execute_query "$SERVER_FQDN" "$DATABASE_NAME" "$ADD_DATABASE_ROLES_SCRIPT" "admin_username=$ENTRA_SQL_ADMINS_GROUP"

echo -e "\n > Granting permissions to [$ENTRA_SQL_USERS_GROUP] on $DATABASE_NAME database...\n"
sql_execute_query "$SERVER_FQDN" "$DATABASE_NAME" "$ADD_DATABASE_PERMISSIONS_SCRIPT" "username=$ENTRA_SQL_USERS_GROUP"

echo -e "\n > Retrieving user sid for [$ENTRA_SQL_USERS_GROUP]...\n"
SQL_USERS_SID=$(sql_get_singleton_value "$SERVER_FQDN" "master" "$GET_USER_SID_SCRIPT" "username=$ENTRA_SQL_USERS_GROUP")

echo -e "\n > Retrieving user sid for [$ENTRA_SQL_ADMINS_GROUP]...\n"
SQL_ADMINS_SID=$(sql_get_singleton_value "$SERVER_FQDN" "master" "$GET_USER_SID_SCRIPT" "username=$ENTRA_SQL_ADMINS_GROUP")

echo -e "\n > Retrieving user sid for [$CLOUD_ADMIN_USER]...\n"
CLOUD_ADMIN_SID=$(sql_get_singleton_value "$SERVER_FQDN" "master" "$GET_USER_SID_SCRIPT" "username=$CLOUD_ADMIN_USER")


#
# log in to azure (managed identity)
#
echo -e "\n> Setting azure cloud environment...\n"

az cloud set --name "$AZ_ENVIRONMENT"

echo -e "\n> Logging in to azure with managed identity...\n"

az login --identity \
  --username "$AZ_MI_CLIENT_ID"


#
# defender for sql functions
#

function initiate_scan() {

  local SCAN_RESPONSE

  echo -e "\n > Initiate SQL vulnerability scan on master...\n"

  if ! SCAN_RESPONSE=$(az rest --method post \
                               --uri "$BASE_URL/sqlVulnerabilityAssessments/default/initiateScan?api-version=2022-02-01-preview" \
                               --uri-parameters "systemDatabaseName=master" 2>&1); then

    echo "$SCAN_RESPONSE"

    if ! echo "$SCAN_RESPONSE" | grep -q "DatabaseVulnerabilityAssessmentScanIsAlreadyInProgress"; then
        echo "Failed to start scan, quitting"
        exit 1
    fi
  fi

  echo -e "\n > Initiate SQL vulnerability scan on $DATABASE_NAME...\n"

  if ! SCAN_RESPONSE=$(az rest --method post \
                               --uri "$BASE_URL/databases/$DATABASE_NAME/sqlVulnerabilityAssessments/default/initiateScan?api-version=2022-02-01-preview" 2>&1); then

    echo "$SCAN_RESPONSE"

    if ! echo "$SCAN_RESPONSE" | grep -q "DatabaseVulnerabilityAssessmentScanIsAlreadyInProgress"; then
        echo "Failed to start scan, quitting"
        exit 1
    fi
  fi

}

function have_scans_completed() {

  if ! az rest --method get \
               --uri "$BASE_URL/databases/$DATABASE_NAME/sqlVulnerabilityAssessments/default/scans?api-version=2024-05-01-preview" 2>&1; then

    return 1
  fi

  if ! az rest --method get \
               --uri "$BASE_URL/sqlVulnerabilityAssessments/default/scans?api-version=2024-05-01-preview" \
               --uri-parameters "systemDatabaseName=master" 2>&1; then
    return 1
  fi

  return 0
}


#
# enable defender for sql
#

echo -e "\n > Setting Defender for SQL baselines...\n"

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
BASE_URL="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Sql/servers/$SERVER_NAME"

echo -e "\n > Enable SQL vulnerability assessments...\n"

az rest --method put \
        --uri "$BASE_URL/sqlVulnerabilityAssessments/default?api-version=2022-02-01-preview" \
        --body "
{
    \"properties\": {
       \"state\": \"Enabled\"
    }
}"


#
# initiate defender scan
#

initiate_scan


#
# wait for defender scan to complete
#

MAX_ATTEMPTS=30
ATTEMPT=0
COMPLETION_SUCCESS=false

echo -e "\n> Waiting for SQL vulnerability scan to complete...\n"

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do

  if have_scans_completed; then
    echo -e "Attempt $((ATTEMPT+1)):  SQL vulnerability scan completed, continuing\n"
    COMPLETION_SUCCESS=true
    break
  fi

  echo -e "Attempt $((ATTEMPT+1)):  SQL vulnerability scan not yet complete\n"

  ATTEMPT=$((ATTEMPT + 1))
  sleep 10

done

if ! $COMPLETION_SUCCESS; then
  echo -e "\nSQL vulnerability scan not completed after $MAX_ATTEMPTS, quitting\n"
  exit 1
fi


#
# set defender for sql baselines
#

# VA2130  Track all users with access to the database
echo -e "\n > Setting VA2130 baseline on master...\n"

az rest --method put \
        --uri "$BASE_URL/sqlVulnerabilityAssessments/default/baselines/default?api-version=2022-02-01-preview" \
        --uri-parameters "systemDatabaseName=master" \
        --body "
{
    \"properties\": {
        \"latestScan\": false,
        \"results\": {
            \"VA2130\": [
                [
                    \"$ENTRA_SQL_ADMINS_GROUP\",
                    \"$SQL_ADMINS_SID\"
                ],
                [
                    \"$ENTRA_SQL_USERS_GROUP\",
                    \"$SQL_USERS_SID\"
                ],
                [
                    \"$CLOUD_ADMIN_USER\",
                    \"$CLOUD_ADMIN_SID\"
                ]
            ]
        }
    }
}"


# VA2130  Track all users with access to the database
# VA1281  All memberships for user-defined roles should be intended
echo -e "\n > Setting VA1281 and VA2130 baseline on $DATABASE_NAME...\n"

az rest --method put \
        --uri "$BASE_URL/databases/$DATABASE_NAME/sqlVulnerabilityAssessments/default/baselines/default?api-version=2022-02-01-preview" \
        --body "
{
    \"properties\": {
        \"latestScan\": false,
        \"results\": {
            \"VA1281\": [
                [
                    \"nwsde_datareader\",
                    \"$ENTRA_SQL_USERS_GROUP\"
                ],
                [
                    \"nwsde_datawriter\",
                    \"$ENTRA_SQL_USERS_GROUP\"
                ],
                [
                    \"nwsde_dataexecutor\",
                    \"$ENTRA_SQL_USERS_GROUP\"
                ],
                [
                    \"nwsde_ddladmin\",
                    \"$ENTRA_SQL_USERS_GROUP\"
                ]
            ],
            \"VA2130\": [
                [
                    \"$ENTRA_SQL_ADMINS_GROUP\",
                    \"$SQL_ADMINS_SID\"
                ],
                [
                    \"$ENTRA_SQL_USERS_GROUP\",
                    \"$SQL_USERS_SID\"
                ]
            ]
        }
    }
}"


#
# re initiate scan after setting baseline
#

initiate_scan


#
# end
#

echo -e "\n------------------------------------------------------------"
echo -e "-- Azure SQL add user completed"
echo -e "------------------------------------------------------------\n"
