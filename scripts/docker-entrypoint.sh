#!/bin/bash

# Exit immediatley if a command exits with a non-zero status.
set -e

# Variables
source /usr/bin/environment.sh

# functions
generate_ssl() {
  mkdir -p $DEFAULT_SSL_BASE
  confout="${DEFAULT_SSL_BASE}/conf"
  keyout="${DEFAULT_SSL_KEY}"
  certout="${DEFAULT_SSL_CRT}"
  cakey="${DEFAULT_SSL_BASE}/ca.key"
  cacert="${DEFAULT_SSL_BASE}/ca.crt"
  serialfile="${DEFAULT_SSL_BASE}/serial"

  logit "INFO" "Generating CA key"
  openssl genrsa -out $cakey 2048
  if [ $? -ne 0 ]; then exit 1 ; fi

  logit "INFO" "Generating CA certificate"
  openssl req \
          -x509 \
          -new \
          -nodes \
          -subj "/CN=${SERVER_HOSTNAME}" \
          -key $cakey \
          -sha256 \
          -days 7300 \
          -out $cacert
  if [ $? -ne 0 ]; then exit 1 ; fi

  logit "INFO" "Generating openssl configuration"

  cat <<EoCertConf>$confout
subjectAltName = DNS:${SERVER_HOSTNAME},IP:127.0.0.1
extendedKeyUsage = serverAuth
EoCertConf

  logit "INFO" "Generating server key..."
  openssl genrsa -out $keyout 2048
  if [ $? -ne 0 ]; then exit 1 ; fi

  logit "INFO" "Generating server signing request..."
  openssl req \
               -subj "/CN=${SERVER_HOSTNAME}" \
               -sha256 \
               -new \
               -key $keyout \
               -out /tmp/server.csr
  if [ $? -ne 0 ]; then exit 1 ; fi

  logit "INFO" "Generating server cert..."
  openssl x509 \
                -req \
                -days 7300 \
                -sha256 \
                -in /tmp/server.csr \
                -CA $cacert \
                -CAkey $cakey \
                -CAcreateserial \
                -CAserial $serialfile \
                -out $certout \
                -extfile $confout
  if [ $? -ne 0 ]; then exit 1 ; fi
}


update_config() {
    logit "INFO" "Updating krb5.conf"
    cp -a ${ADDC_PRIVATE_DIR}/krb5.conf /etc/krb5.conf

    logit "INFO" "Updating resolv.conf"
    cat ${ADDC_PRIVATE_DIR}/resolv.conf > /etc/resolv.conf

    logit "INFO" "Updating smb.conf"
    cp -a ${ADDC_PRIVATE_DIR}/smb.conf /etc/samba/smb.conf
}


provision_domain_controller() {
    IP_ADDRESS=$(hostname -i)

    logit "INFO" "Starting samba-tool"
    logit "DEBUG" "ADDC_REALM: ${ADDC_REALM}"
    logit "DEBUG" "ADDC_DOMAIN: ${ADDC_DOMAIN}"
    logit "DEBUG" "ADDC_ADMINPASS_FILE: ${ADDC_ADMINPASS_FILE}: $(cat ${ADDC_ADMINPASS_FILE})"
    samba-tool domain provision \
	--realm="${ADDC_REALM}" \
	--domain="${ADDC_DOMAIN}" \
	--server-role=dc \
	--adminpass="$(cat ${ADDC_ADMINPASS_FILE})" \
	--use-rfc2307

    logit "INFO" "Creating resolv.conf"
    (echo "search ${ADDC_REALM}"
     echo "nameserver ${IP_ADDRESS}"
     echo "options timeout:1")> ${ADDC_PRIVATE_DIR}/resolv.conf

     logit "INFO" "Moving smb.conf to private dir"
     cp -a /etc/samba/smb.conf ${ADDC_PRIVATE_DIR}/
}


set_up_tls() {
    if [[ ! -z ${CONFD__ADDC__TLS_KEYFILE_URL} && \
	    -e ${CONFD__ADDC__TLS_KEYFILE_URL} && \
	  ! -z ${CONFD__ADDC__TLS_CERTFILE_URL} && \
	    -e ${CONFD__ADDC__TLS_CERTFILE_URL} && \
	  ! -z ${CONFD__ADDC__TLS_CAFILE_URL} && \
	    -e ${CONFD__ADDC__TLS_CAFILE_URL} ]]; then
	logit "INFO" "Found valid TLS, copying files"
	mkdir -p ${ADDC_PRIVATE_DIR}/ssl
	cp ${CONFD__ADDC__TLS_KEYFILE_URL} \
	    ${CONFD__ADDC__TLS_CERTFILE_URL} \
	    ${CONFD__ADDC__TLS_CAFILE_URL} \
	    ${ADDC_PRIVATE_DIR}/ssl/

	_KEY=$(basename "${CONFD__ADDC__TLS_KEYFILE_URL}")
	_CRT=$(basename "${CONFD__ADDC__TLS_CERTFILE_URL}")
	_CA=$(basename "${CONFD__ADDC__TLS_CAFILE_URL}")
	chmod 600 ${ADDC_PRIVATE_DIR}/ssl/$_KEY
	chmod 600 ${ADDC_PRIVATE_DIR}/ssl/$_CRT
	chmod 600 ${ADDC_PRIVATE_DIR}/ssl/$_CA

	logit "INFO" "Modifying /etc/samba/smb.conf"
	logit "DEBUG" "smb.conf: Add tls keyfile"
	_FILE=${ADDC_PRIVATE_DIR}/ssl/${_KEY}
	sed -i 's|^\w*\[global\]\w*$|[global]\n\ttls keyfile = '${_FILE}'|' ${ADDC_PRIVATE_DIR}/smb.conf
	logit "DEBUG" "smb.conf: Add tls certfile"
	_FILE=${ADDC_PRIVATE_DIR}/ssl/${_CRT}
	sed -i 's|^\w*\[global\]\w*$|[global]\n\ttls certfile = '${_FILE}'|' ${ADDC_PRIVATE_DIR}/smb.conf
	logit "DEBUG" "smb.conf: Add tls cafile"
	_FILE=${ADDC_PRIVATE_DIR}/ssl/${_CA}
	sed -i 's|^\w*\[global\]\w*$|[global]\n\ttls cafile = '${_FILE}'|' ${ADDC_PRIVATE_DIR}/smb.conf
    else
	logit "INFO" "No TLS information proveded: Skipping"
    fi
}


initialize() {
    #generate_ssl

    # first set up confd itself from env
    logit "INFO" "Setting up confd..."
    /usr/bin/confd -onetime -backend env -confdir /tmp/etc/confd -sync-only

    # now set up all config files initially
    #logit "INFO" "Setting up config files"
    #/usr/bin/confd -onetime -confdir /etc/confd \
#	-config-file /etc/confd/confd.toml -sync-only

    # Check if data volume contains data
    DB_FILES=$(find ${ADDC_STATE_DIR} -name '*.tdb' -or -name '*.ldb' | wc -l)
    logit "DEBUG" "DB_FILES: ${DB_FILES}"
    logit "DEBUG" "ADDC_STATE_DIR: ${ADDC_STATE_DIR}"
    logit "DEBUG" "find ${ADDC_STATE_DIR}: $(find ${ADDC_STATE_DIR} -print)"

    if [[ "${DB_FILES}" -gt 0 ]]; then
	logit "INFO" "Data volume contains data: Skipping Provisioning"
    else
	logit "INFO" "Data volume empty: Provisioning new domain controller"
	provision_domain_controller

	logit "INFO" "Setting up TLS"
	set_up_tls
    fi

    logit "INFO" "Updating config files"
    update_config


    touch "$FIRST_START_FILE_URL"
    logit "INFO" "Initialization done"
}



###############################################################################
# main
if [[ ! -e "$FIRST_START_FILE_URL" ]]; then
	# Do stuff
	initialize
fi


# Start ad dc
if [[ "$@" == "samba-addc" ]]; then
    logit "INFO" "Starting supervisord..."
    exec /usr/bin/supervisord -c /etc/supervisord.conf
else
    logit "INFO" "Start cmd: $@"
    exec "$@"
fi

