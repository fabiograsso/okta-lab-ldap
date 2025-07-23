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
  echo "✅  Certificate imported."
else
  echo "⛔️  Certificate not found: /certs/cert.crt"
  exit 1
fi

# Loop until both config files exist and contain the required keys
echo "⏳  Waiting for configuration files. Please configure the Agent."
MAIN_CONF_FILE="/opt/Okta/OktaLDAPAgent/conf/OktaLDAPAgent.conf"
ADDITIONAL_CONF_FILE="/var/lib/oktaldapagent/AdditionalOktaLDAPAgent.conf"
while true; do
  if [[ -f "$MAIN_CONF_FILE" && -f "$ADDITIONAL_CONF_FILE" ]] && \
    grep -qE "^agentId = " "$MAIN_CONF_FILE" && \
    grep -qE "^orgUrl = " "$MAIN_CONF_FILE" && \
    grep -qE "^clientId = " "$MAIN_CONF_FILE" && \
    grep -qE "^agentKey = " "$MAIN_CONF_FILE" && \
    grep -qE "^propertyKey = " "$ADDITIONAL_CONF_FILE"; then
    echo "✅  Configuration files are now ready."
    sleep 2
    break
  fi
  sleep 5
  echo "⏳  Still waiting for configuration files. Please configure the Agent."
done

# Start the agent, log to stdout 
exec /opt/Okta/OktaLDAPAgent/scripts/OktaLDAPAgent 2>&1