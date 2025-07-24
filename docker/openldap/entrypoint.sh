#!/bin/sh
#
# Author: Fabio Grasso <fabio.grasso@okta.com>
# Version: 1.0.0
# License: Apache-2.0
# Description: Entrypoint docker script to for OpenLDAP with certificate
#              management.
#
# Usage: ./entrypoint.sh
#
# -----------------------------------------------------------------------------
set -e
echo "
                           ####               ####                              
                           ####               ####                              
                           ####               ####                              
                           ####               ####                              
       ############        ####      #####    ##########     ###########  ####  
     ################      ####     ####      ##########   ###################  
   ######        #####     ####   #####       ####        #####        #######  
   ####           #####    ####  #####        ####       #####           #####  
  #####            #####   #########          ####       ####            #####  
  ####             #####   ##########         ####      #####             ####  
  #####            ####    ####  #####        ####       ####            #####  
   #####          #####    ####   ######      ####       #####          ######  
    ######      ######     ####     #####     ####        #######     ########  
     ###############       ####      ######   ##########    ############# ######
         ########          ####        #####    ########       ########     ####                                                                       
"

CERT_FILE_NAME=${CERT_FILE_NAME:-cert.crt}
CERT_DIR=${CERT_DIR:-/certs}
mkdir -p "$CERT_DIR"

if [ ! -f "$CERT_DIR/$CERT_FILE_NAME" ]; then
  echo "🔐  Generating self-signed certificate..."
  KEY_FILE_NAME=${KEY_FILE_NAME:-cert.key}
  CERT_DAYS=${CERT_DAYS:-3650}
  CERT_CN=${CERT_CN:-localhost}
  CERT_KEY_SIZE=${CERT_KEY_SIZE:-2048}
  # Subject + optional fields
  subject=""
  [ -n "$CERT_C" ]  && subject="$subject/C=$CERT_C"
  [ -n "$CERT_ST" ] && subject="$subject/ST=$CERT_ST"
  [ -n "$CERT_L" ]  && subject="$subject/L=$CERT_L"
  [ -n "$CERT_O" ]  && subject="$subject/O=$CERT_O"
  subject="$subject/CN=$CERT_CN"
  echo "Using subject: $subject"

  openssl req -x509 -nodes -days "$CERT_DAYS" -newkey rsa:$CERT_KEY_SIZE \
    -keyout "$CERT_DIR/$KEY_FILE_NAME" \
    -out "$CERT_DIR/$CERT_FILE_NAME" \
    -subj "$subject"
  echo "✅   Certificate generated at $CERT_DIR"
else
  echo "📎   Certificate already exists at $CERT_DIR/$CERT_FILE_NAME, skipping generation."
fi

# Display cert info
echo ""
openssl x509 -in "$CERT_DIR/$CERT_FILE_NAME" -noout -subject -issuer -dates -serial
echo ""

exec /opt/bitnami/scripts/openldap/entrypoint.sh "$@"