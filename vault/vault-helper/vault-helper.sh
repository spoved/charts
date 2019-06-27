#!/bin/sh

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
API_TOKEN_PATH=/var/run/secrets/kubernetes.io/serviceaccount/token
API_TOKEN=$(cat ${API_TOKEN_PATH})

VAULT_KEYS_SECRET_URL="https://kubernetes.default.svc/api/v1/namespaces/${NAMESPACE}/secrets/vault-keys"
DEFAULT_PODS_URL="https://kubernetes.default.svc/api/v1/namespaces/${NAMESPACE}/pods"

API_HEADER="Authorization: Bearer ${API_TOKEN}"

VAULT_PODS_RAW=$(curl -sqk --header "${API_HEADER}" "${DEFAULT_PODS_URL}?labelSelector=app=vault,component=server")
VAULT_HOST=$(echo ${VAULT_PODS_RAW} | jq -r '.items[1].status.podIP')

refresh_pod_list() {
  VAULT_PODS_RAW=$(curl -sqk --header "${API_HEADER}" "${DEFAULT_PODS_URL}?labelSelector=app=vault,component=server")
}

get_vault_status() {
  export VAULT_ADDR="http://${VAULT_HOST}:8200"
  VAULT_STATUS=$(vault status -format json -address ${VAULT_ADDR})

  if [ "$(echo ${VAULT_STATUS} | jq .type -r)" = "null" ]; then
    echo "Unable to gather status"
    exit 1
  fi
}

initialize_vault() {
  echo "Checking vault status"
  get_vault_status

  initialized=$(echo $VAULT_STATUS | jq .initialized -r)
  echo "Initialized: ${initialized}"

  if [  "${initialized}" = "false" ]; then
    echo "!! Vault is not initialized"
    echo "- Initializing now"
    keys=$(vault operator init -format json -address ${VAULT_ADDR})

    if [ "$?" -ne "0" ]; then
      echo "Unable to initialize vault"
      exit 1
    fi

    # Enable approle
    # vault auth enable approle

    if [  "$(echo ${keys} | jq .root_token)" != "null" ]; then
      echo "- Successfully initialized vault"
      echo "- Saving keys to secret"
      encoded_keys=$(echo ${keys} | base64 | tr -d '[:space:]')
      curl -sqk \
        --header "Content-Type: application/json" \
        --header "${API_HEADER}" \
        --request PUT \
        --data "{ \"apiVersion\": \"v1\", \"data\": { \"keys\": \"${encoded_keys}\" }, \"kind\": \"Secret\", \"metadata\": { \"name\": \"vault-keys\", \"namespace\": \"default\" }, \"type\": \"Opaque\" }" \
        ${VAULT_KEYS_SECRET_URL}

      if [ "$?" -ne "0" ]; then
        echo "Unable to update secret. Hope you find these keys!"
        echo ${encoded_keys}
        exit 1
      fi
      echo "- Updated secret"
      echo "- Sleeping for a bit to let vault initialize"
      sleep 120
    fi
  fi
}

unseal_vault() {

  get_vault_status

  raw_resp=$(curl -sqk --header "${API_HEADER}" ${VAULT_KEYS_SECRET_URL} | jq .data.keys)
  if [  "${raw_resp}" = "null" ]; then
    echo "!! No keys found"
    exit 1
  fi

  keys=$(echo ${raw_resp} | base64 -d)

  for key in $(echo ${keys} | jq -r '.unseal_keys_hex[]'); do
    output=$(vault operator unseal -format json -address ${VAULT_ADDR} ${key})
    if [ "$?" -ne "0" ]; then
      echo "Unable to unseal vault"
      echo ${output}
      exit 1
    fi
  done

  get_vault_status

  sealed=$(echo ${VAULT_STATUS} | jq .sealed -r)
  echo "Sealed: ${sealed}"
  if [  "${sealed}" = "true" ]; then
    echo "!! Failed to unseal"
    exit 1
  fi
}

check_pods() {
  echo "Checking host: ${VAULT_HOST}"

  get_vault_status

  initialized=$(echo ${VAULT_STATUS} | jq .initialized -r)
  echo "Initialized: ${initialized}"

  if [  "${initialized}" = "false" ]; then
    echo "!! Vault is not initialized"
    initialize_vault
  fi

  sealed=$(echo ${VAULT_STATUS} | jq .sealed -r)
  echo "Sealed: ${sealed}"

  if [  "${sealed}" = "true" ]; then
    echo "!! Vault is sealed"
    echo "- Attempting to unseal"
    unseal_vault
    echo "- Unsealed vault"
  fi
}

initialize_vault

while true; do
  for host in $(echo ${VAULT_PODS_RAW} | jq '.items[] | select(.status.phase == "Running") | .status.podIP' -r); do
    if [ "${host}" != "null" ]; then
      VAULT_HOST=${host}
      check_pods
    fi
  done
  sleep 500
  refresh_pod_list
done

exit 1
