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


# Generate setup config files
echo "orgUrl=https://$OKTA_ORG/ 
ldapHost=openldap
ldapAdminDN=cn=admin,$LDAP_BASE_DN
ldapPort=1636
ldapSSLPort=1636
baseDN=$LDAP_BASE_DN
ldapUseSSL=true
proxyEnabled=false
sslPinningEnabled=true
fipsMode=true" > /opt/Okta/OktaLDAPAgent/conf/InstallOktaLDAPAgent.conf

#cd /opt/Okta/OktaLDAPAgent/jre/bin
#./keytool -importcert -alias openldap -file /certs/cert.crt -keystore ../lib/security/cacerts -storepass changeit -noprompt
# openssl s_client -connect openldap:1636 -showcerts </dev/null

# Import the TLS Certificate
# Ref: https://help.okta.com/oie/en-us/content/topics/directory/ldap-agent-enable-ldap-ssl.htm
echo "🔐 Importing the TLS Certificate in the keytool..."
if [ -f /certs/cert.crt ]; then
	KEYTOOL_DIR=/opt/Okta/OktaLDAPAgent/jre/bin
	KEYTOOL=$KEYTOOL_DIR/keytool
	KEYPARAMS=("-alias" "openldap" "-noprompt" "-cacerts" "-storepass" "changeit")
	# 
	cd $KEYTOOL_DIR
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
KEYSTORE="/var/lib/oktaldapagent/security/OktaLdapKeystore.p12"

mkdir -p /var/lib/oktaldapagent/security
chown -R OktaLDAPService:OktaLDAPService /var/lib/oktaldapagent

while true; do
	if [[ -f "$MAIN_CONF_FILE" && -f "$ADDITIONAL_CONF_FILE" && -f "$KEYSTORE" ]] &&
		grep -qE "^orgUrl =" "$MAIN_CONF_FILE" &&
		grep -qE "^agentRegistrationToken = " "$MAIN_CONF_FILE" &&
		grep -qE "^keystoreKey = " "$ADDITIONAL_CONF_FILE" &&
		grep -qE "^keyPassword = " "$ADDITIONAL_CONF_FILE"; then
		echo "✅  Configuration files are ready. Starting the LDAP Agent..."
		sleep 2
		break
	fi
	echo "⏳ Waiting for configuration files. Please configure the Agent..."
	sleep 10
done

# Start the agent, log to stdout
exec /opt/Okta/OktaLDAPAgent/scripts/OktaLDAPAgent 2>&1
