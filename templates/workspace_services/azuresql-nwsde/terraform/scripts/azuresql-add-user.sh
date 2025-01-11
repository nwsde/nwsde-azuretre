#!/bin/bash
# shellcheck disable=SC2154

set -e  # exit on error

#
# variables populated by terraform template
#

SERVER_FQDN="${server_fqdn}"
SERVER_IP="${server_ip}"
DATABASE_NAME="${database_name}"
ADD_DATABASE_USER_SCRIPT="${add_database_user_script}"
ADD_DATABASE_PERMISSIONS_SCRIPT="${add_database_permissions_script}"
USER_TO_ADD="${user_to_add}"

echo -e "\nAzure SQL add user starting...\n"

#
# test private DNS resolution
#

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
    echo -e "DNS has stablised with $STABLE_REQUIRED correct sequential resolutions\n"
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
# add users
#

echo -e "\n > Adding master database user...\n"

sqlcmd --server "$SERVER_FQDN" \
       --database-name master \
       --use-aad \
       --input-file "$ADD_DATABASE_USER_SCRIPT" \
       --variables entra_username="$USER_TO_ADD" \
       --exit-on-error

echo -e "\n > Adding $DATABASE_NAME database user...\n"

sqlcmd --server "$SERVER_FQDN" \
       --database-name "$DATABASE_NAME" \
       --use-aad \
       --input-file "$ADD_DATABASE_USER_SCRIPT" \
       --variables entra_username="$USER_TO_ADD" \
       --exit-on-error

echo -e "\n > Adding $DATABASE_NAME database permissions...\n"

sqlcmd --server "$SERVER_FQDN" \
       --database-name "$DATABASE_NAME" \
       --use-aad \
       --input-file "$ADD_DATABASE_PERMISSIONS_SCRIPT" \
       --variables entra_username="$USER_TO_ADD" \
       --exit-on-error

#
# end
#

echo -e "\nAzure SQL add user completed\n"
