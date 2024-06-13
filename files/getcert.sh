#!/bin/bash
# Set the configuration directory
CFG_DIR="${CFG_DIR:-$(pwd)/cfg}"

# AppRole Credentials
ROLE_ID="${ROLE_ID:-${CFG_DIR}/role-id}"
SECRET_ID="${SECRET_ID:-${CFG_DIR}/secret-id}"

# Vault Configuration
# VAULT_CACERT="${VAULT_CACERT:-${CFG_DIR}/ca.pem}"
VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
VAULT_CA_MOUNT_PATH="${VAULT_CA_MOUNT_PATH:-config_auth_ca}"
VAULT_CA_ROLE="${VAULT_CA_ROLE:-int_ca_role}"
VAULT_CA_SIGN_PATH="${VAULT_CA_SIGN_PATH:-v1/${VAULT_CA_MOUNT_PATH}/sign/${VAULT_CA_ROLE}}"
VAULT_CA_SIGN_URL="${VAULT_CA_SIGN_URL:-${VAULT_ADDR}/${VAULT_CA_SIGN_PATH}}"
VAULT_APPROLE_MOUNT_PATH="${VAULT_APPROLE_MOUNT_PATH:-approle}"
VAULT_APPROLE_PATH="${VAULT_APPROLE_PATH:-v1/auth/${VAULT_APPROLE_MOUNT_PATH}/login}"
VAULT_APPROLE_URL="${VAULT_APPROLE_URL:-${VAULT_ADDR}/${VAULT_APPROLE_PATH}}"

# Certificate Configuration
CERT_FILE="${CERT_FILE:-${CFG_DIR}/pki/cert.pem}"
KEY_FILE="${KEY_FILE:-${CFG_DIR}/pki/key.pem}"
CSR_FILE="${CSR_FILE:-${CFG_DIR}/pki/csr.pem}"
CERT_SUBJECT="${CERT_SUBJECT:-/C=US/ST=SomeState/L=SomeCity/O=Corp/OU=Platform/CN=config@corp.local/emailAddress=config@corp.local}"
PKI_OWNER="${PKI_OWNER:-100:100}"

# Function to check if the certificate is expired
check_if_expired() {
    local cert_file="$1"
    if [ ! -f "${cert_file}" ]; then
        echo "Certificate file not found."
        return 1
    else
        # Check if the certificate is expired
        openssl x509 -checkend 0 -noout -in "${cert_file}"
        return $?
    fi
}

# Check if the certificate is expired
check_if_expired "${CERT_FILE}"
if [ $? -eq 1 ]; then
    echo "Signing the certificate..."

    # Generate a private key and a CSR
    openssl genrsa -out ${KEY_FILE} 2048
    openssl req -new -key ${KEY_FILE} -out ${CSR_FILE} -subj ${CERT_SUBJECT}

    # Authenticate with AppRole auth and get token
    VAULT_TOKEN=$(curl \
            ${VAULT_CACERT:+--cacert "${VAULT_CACERT}"} \
            --request POST \
            --data "{\"role_id\": \"$(cat ${ROLE_ID})\", \"secret_id\": \"$(cat ${SECRET_ID})\"}" \
            ${VAULT_APPROLE_URL} \
        | jq -r '.auth.client_token')

    # Encode the CSR
    csr_content=$(awk 'BEGIN {ORS="\\n"}; {print}' ${CSR_FILE})

    # Sign the CSR
    curl \
            ${VAULT_CACERT:+--cacert "${VAULT_CACERT}"} \
            --header 'Content-Type: application/json' \
            --header "X-Vault-Token: ${VAULT_TOKEN}" \
            --request POST \
            --data "{\"csr\": \"${csr_content}\", \"format\": \"pem_bundle\"}" \
            ${VAULT_CA_SIGN_URL} \
        | jq -r '.data.certificate' \
        | openssl x509 > ${CERT_FILE}

    # Check for the output
    if [ -f ${CERT_FILE} ] && [ -s ${CERT_FILE} ]; then
        chown -R 100:100 ${CFG_DIR}/pki
        echo "Certificate signed and saved to ${CERT_FILE}"
    else
        echo "Failed to sign the certificate"
    fi
fi
