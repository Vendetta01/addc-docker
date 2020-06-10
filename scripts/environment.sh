#!/bin/bash

# Import environment base
source /usr/bin/environment_base.sh

# Variables
export DEFAULT_SSL_BASE=/etc/ssl
export DEFAULT_SSL_CRT=${DEFAULT_SSL_BASE}/default.crt
export DEFAULT_SSL_KEY=${DEFAULT_SSL_BASE}/default.key

export ADDC_REALM=${CONFD__ADDC__REALM:-"SAMDOM.EXAMPLE.COM"}
export ADDC_DOMAIN=${CONFD__ADDC__DOMAIN:-"SAMDOM"}
SECRETS_BASE="/run/secrets"
export ADDC_ADMINPASS_FILE=${SECRETS_BASE}/addc_adminpass

# If no password file is set, create it from env
if [[ -z "${CONFD__ADDC__ADMINPASS_FILE}" && \
      ! -e "${ADDC_ADMINPASS_FILE}" ]]; then
    logit "INFO" "Creating adminpass file from env"
    mkdir -p ${SECRETS_BASE}
    echo "${CONFD__ADDC__ADMINPASS:-'Passw0rd!'}" > ${ADDC_ADMINPASS_FILE}
elif [[ ! -z "${CONFD__ADDC__ADMINPASS_FILE}" ]]; then
    logit "INFO" "Adminpass file is set"
    ADDC_ADMINPASS_FILE=${CONFD__ADDC__ADMINPASS_FILE}
else
    logit "WARN" "Adminpass file not set but file does exist. Using existing file"
fi


export ADDC_STATE_DIR=/var/lib/samba
export ADDC_PRIVATE_DIR=${ADDC_STATE_DIR}/private
