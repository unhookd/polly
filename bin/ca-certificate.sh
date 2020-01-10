#!/bin/bash

set -e
set -x

OPENSSL_ROOT=/var/tmp/polly-certificate

mkdir -p ${OPENSSL_ROOT}/tmp \
         ${OPENSSL_ROOT}/ca-certificates \
         ${OPENSSL_ROOT}/ssl/CA \
         ${OPENSSL_ROOT}/ssl/private \
         ${OPENSSL_ROOT}/ssl/private/newcerts \

#openssl dhparam -out ${OPENSSL_ROOT}/tmp/dh2048.pem 2048

echo "01" | tee ${OPENSSL_ROOT}/ssl/CA/serial | tee ${OPENSSL_ROOT}/ssl/CA/crlnumber
touch ${OPENSSL_ROOT}/ssl/CA/index{.txt,.txt.attr}

openssl req -config config/openssl.conf -new -x509 \
  -keyout ${OPENSSL_ROOT}/ssl/private/cakey.pem \
  -out ${OPENSSL_ROOT}/ca-certificates/ca.polly.crt \
  -days 365 -subj "/C=US/ST=Oregon/L=Portland/O=POLLYCA" -passout pass:01234567890123456789 \
  -extensions for_ca_req

openssl ca -gencrl -extensions v3_req \
  -keyfile ${OPENSSL_ROOT}/ssl/private/cakey.pem \
  -cert ${OPENSSL_ROOT}/ca-certificates/ca.polly.crt \
  -out ${OPENSSL_ROOT}/ssl/CA/ca.polly.crl \
  -config config/openssl.conf \
  -passin pass:01234567890123456789 \
  -policy policy_anything -batch

openssl genrsa -out ${OPENSSL_ROOT}/ssl/private/registry.polly.key 2048

openssl req -new -out ${OPENSSL_ROOT}/ssl/private/registry.polly.csr \
  -key ${OPENSSL_ROOT}/ssl/private/registry.polly.key \
  -config config/openssl.conf \
  -extensions for_server_req \
  -subj "/C=US/ST=Oregon/L=Portland/O=POLLY-SERVER/CN=POLLY"

openssl ca -in ${OPENSSL_ROOT}/ssl/private/registry.polly.csr \
  -out ${OPENSSL_ROOT}/ssl/private/registry.polly.pem \
  -config config/openssl.conf \
  -policy policy_anything \
  -batch -passin pass:01234567890123456789 \
  -extensions for_server_req

openssl x509 -in ${OPENSSL_ROOT}/ssl/private/registry.polly.pem -outform DER -out ${OPENSSL_ROOT}/ssl/private/registry.polly.crt 
