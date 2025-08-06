#!/bin/bash
#
# Author: Fabio Grasso <fabio.grasso@okta.com>
# Version: 1.0.0
# License: Apache-2.0
# Description: Entrypoint docker script to for the Okta LDAP Agent
#
# Usage: ./entrypoint.sh
#
# -----------------------------------------------------------------------------
set -e
echo "                                                                
                  ████          ████                              
                  ████          ████                              
       █████      ████    ████  █████        ████   ███           
    ██████████    ████   █████  ████████  █████████████           
  ██████████████  ████  █████   █████   ███████████████           
 █████      █████ █████████     ████    ████       ████           
 ████        ████ ████████      ████   ████        ████           
 ████        ████ ██████████    ████    ████       ████           
  █████    ██████ ████  █████   ████    █████    ██████           
   █████████████  ████   ██████ ████████ ███████████████         
    ██████████    ████     █████ ███████   ████████ █████         

"

# Import the TLS Certificate
# Ref: https://help.okta.com/oie/en-us/content/topics/directory/ldap-agent-enable-ldap-ssl.htm
echo "🔐 Importing the TLS Certificate in the keytool..."
if [ -f /certs/cert.crt ]; then
	KEYTOOL=/opt/Okta/OktaLDAPAgent/jre/bin/keytool
	KEYPARAMS=("-alias" "openldap" "-cacerts" "-noprompt" "-storepass" "changeit")
	if $KEYTOOL -list "${KEYPARAMS[@]}" >/dev/null 2>&1; then
		$KEYTOOL -delete "${KEYPARAMS[@]}"
	fi
	$KEYTOOL -importcert -file /certs/cert.crt "${KEYPARAMS[@]}"
	echo "✅ Certificate imported."
else
	echo "⛔️ Certificate not found: /certs/cert.crt"
	exit 1
fi

# Loop until both config files exist and contain the required keys
MAIN_CONF_FILE="/opt/Okta/OktaLDAPAgent/conf/OktaLDAPAgent.conf"
ADDITIONAL_CONF_FILE="/var/lib/oktaldapagent/AdditionalOktaLDAPAgent.conf"
while true; do
	if [[ -f "$MAIN_CONF_FILE" && -f "$ADDITIONAL_CONF_FILE" ]] &&
		grep -qE "^agentId = " "$MAIN_CONF_FILE" &&
		grep -qE "^orgUrl = " "$MAIN_CONF_FILE" &&
		grep -qE "^clientId = " "$MAIN_CONF_FILE" &&
		grep -qE "^agentKey = " "$MAIN_CONF_FILE" &&
		grep -qE "^propertyKey = " "$ADDITIONAL_CONF_FILE"; then
		echo "✅  Configuration files are ready. Starting the LDAP Agent..."
		sleep 2
		break
	fi
	echo "⏳ Waiting for configuration files. Please configure the Agent..."
	sleep 10
done

# Start the agent, log to stdout
exec /opt/Okta/OktaLDAPAgent/scripts/OktaLDAPAgent 2>&1
