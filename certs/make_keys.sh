#!/usr/bin/env bash

set -x

#Current directory
DIR="$( cd "$( dirname "$0" )" && pwd )"

echo "Current directory $DIR"

# Certificates password.
PASS=123456

# Server.
SERVER_DN="CN=localhost,OU=RC,O=RC,L=Los Angelest,S=CA,C=US"

# Client.
CLIENT_DN="CN=www.localhost.com,OU=RC,O=RC,L=Los Angelest,S=CA,C=US"

# Cleanup.
rm -vf node.*
rm -vf client.*
rm -vf wc.*
rm -vf ca.*
rm -vf in*
rm -vf seri*
rm -vf trust*
rm -vf *pem
rm -vf *cnf
rm -vf *conf

# ca key config.
cat << EOF > ca_key.conf
[req]
prompt                 = no
distinguished_name     = dn
req_extensions         = req_ext
[ dn ]
countryName            = US
stateOrProvinceName    = CA
localityName           = Los Angelest
organizationName       = localhost
commonName             = localhost
organizationalUnitName = localhost
emailAddress           = localhost@localhost.com
[ req_ext ]
subjectAltName         = @alt_names
[ alt_names ]
DNS.1                  = localhost
EOF

# ca configuration file
cat << EOF > ca.cnf
[ ca ]
default_ca = CertificateAuthority

[ CertificateAuthority ]
certificate = ./ca.pem
database = ./index.txt
private_key = ./ca.key
new_certs_dir = ./
default_md = sha1
policy = policy_match
serial = ./serial
default_days = 365

[policy_match]
commonName = supplied
EOF

# webconsole configuration file
cat << EOF > wc.conf
[req]
prompt                 = no
distinguished_name     = dn
req_extensions         = req_ext
[ dn ]
countryName            = US
stateOrProvinceName    = CA
localityName           = Los Angelest
organizationName       = localhost
commonName             = localhost
organizationalUnitName = localhost
emailAddress           = localhost@localhost.com
[ req_ext ]
subjectAltName         = @alt_names
[ alt_names ]
DNS.1                  = localhost
IP.1                   = 127.0.0.1
EOF

touch index.txt
echo 01 > serial

# Generate CA
openssl req -new -newkey rsa:2048 -nodes -config ca_key.conf -out ca.csr -keyout ca.key
openssl x509 -trustout -signkey ca.key -req -in ca.csr -out ca.pem
keytool -deststorepass ${PASS} -noprompt  -import -file ca.pem -alias CertificateAuthority -keystore trust.jks

# Generate node certificates
keytool -genkey -keyalg RSA -keysize 2048 -alias node -deststorepass ${PASS} -keystore node.jks -noprompt \
 -dname "${SERVER_DN}" \
 -storepass ${PASS} \
 -keypass ${PASS}
keytool -deststorepass ${PASS} -certreq -alias node -file node.csr -keystore node.jks
openssl ca -batch -config ca.cnf -out node.pem -infiles node.csr
keytool -deststorepass ${PASS} -import -alias ca -keystore node.jks -file ca.pem -noprompt
keytool -deststorepass ${PASS} -import -alias node -keystore node.jks -file node.pem -noprompt
keytool -importkeystore -srcstoretype JKS -deststoretype PKCS12 -srckeystore node.jks -destkeystore node.p12 -srcstorepass ${PASS} -deststorepass ${PASS} -srcalias node -destalias node -noprompt
openssl pkcs12 -in node.p12 -out ca_odbc.pem -passin pass:${PASS} -nodes

# Generate Client cerificates
keytool -genkey -keyalg RSA -keysize 2048 -alias client -deststorepass ${PASS} -keystore client.jks -noprompt \
 -dname "${CLIENT_DN}" \
 -storepass ${PASS} \
 -keypass ${PASS}
keytool -deststorepass ${PASS} -certreq -alias client -file client.csr -keystore client.jks
openssl ca -batch -config ca.cnf -out client.pem -infiles client.csr
keytool -deststorepass ${PASS} -import -alias ca -keystore client.jks -file ca.pem -noprompt
keytool -deststorepass ${PASS} -import -alias client -keystore client.jks -file client.pem -noprompt
keytool -importkeystore -srcstoretype JKS -deststoretype PKCS12 -srckeystore client.jks -destkeystore client.p12 -srcstorepass ${PASS} -deststorepass ${PASS} -srcalias client -destalias client -noprompt
openssl pkcs12 -in client.p12 -out client.pem -passin pass:${PASS} -nodes

# Generate web console cerificates
openssl genrsa -des3 -passout pass:${PASS} -out wc.key 1024
openssl req -new -passin pass:${PASS} -key wc.key -config wc.conf -out wc.csr
openssl x509 -req -days 365 -in wc.csr -CA ca.pem -CAkey ca.key -set_serial 01 -extensions req_ext -extfile wc.conf -out wc.crt
openssl pkcs12 -export -in wc.crt -inkey wc.key -passin pass:${PASS} -certfile wc.crt -out wc.p12 -passout pass:${PASS}
keytool -importkeystore -srckeystore wc.p12 -srcstoretype PKCS12 -destkeystore wc.jks -deststoretype JKS -noprompt -srcstorepass ${PASS} -deststorepass ${PASS}

# Convert java keystore format from jks to bcfks
keytool -importkeystore -srckeystore node.jks -srcstoretype JKS -srcstorepass ${PASS} \
-destkeystore node.bcfks -deststorepass ${PASS} -deststoretype BCFKS -providername BCFIPS \
-provider org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider -providerpath ${DIR}/bc-fips-1.0.2.3.jar
keytool -importkeystore -srckeystore trust.jks -srcstoretype JKS -srcstorepass ${PASS} \
-destkeystore trust.bcfks -deststorepass ${PASS} -deststoretype BCFKS -providername BCFIPS \
-provider org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider -providerpath ${DIR}/bc-fips-1.0.2.3.jar

# Copies certs to files dir
cp ca.pem ca.key ../files
