#!/bin/bash
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


# Import the TLS Certificate
# Ref: https://help.okta.com/oie/en-us/content/topics/directory/ldap-agent-enable-ldap-ssl.htm
if [ -f /certs/cert.crt ]; then
  echo "🔐  Importing the TLS Certificate in the keytool..."
  /opt/Okta/OktaLDAPAgent/jre/bin/keytool -importcert \
    -alias openldap \
    -file /certs/cert.crt \
    -cacerts \
    -storepass changeit \
    -noprompt
  echo "✅   Certificate imported."
else
  echo "⛔️  Certificate not found: /certs/cert.crt"
  exit 1
fi

# Start the agent, log to stdout 
exec /opt/Okta/OktaLDAPAgent/scripts/OktaLDAPAgent 2>&1