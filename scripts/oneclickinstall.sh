#!/bin/bash
#
# Author: Fabio Grasso <fabio.grasso@okta.com>
# License: Apache-2.0
# Version: 1.0.0
# Description: Script to install and configure:
#               - OpenLDAP
#               - Okta LDAP Agent
#               - ldap-ui
#
# Usage: ./oneclickinstall.sh
# Sample .env file:
#   OKTA_ORG=myorg.okta.com
#   LDAP_BASE_DN=dc=galaxy,dc=universe
#   LDAP_ADMIN_PASSWORD=adminpassword
#   LDAP_CONFIG_PASSWORD=configpassword
#
# -----------------------------------------------------------------------------
set -e
export DEBIAN_FRONTEND=noninteractive
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

# --- SCRIPT START ---

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BASE_DIR=$(dirname "$SCRIPT_DIR")
exec &> >(tee "$SCRIPT_DIR/oneclickinstall.log") #logfile

mkdir -p /tmp/ldap-setup/

# --- VERIFY OPERATING SYSTEM ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "24.04" ]; then
        echo "❌ ERROR: This script is designed to run only on Ubuntu 24.04 LTS."
        echo "Detected OS: $PRETTY_NAME"
        exit 1
    fi
else
    echo "❌ ERROR: Cannot determine OS version. /etc/os-release not found."
    exit 1
fi
if ! ls "$BASE_DIR/*.deb" 1>/dev/null 2>&1; then
    echo "❌ ERROR: No Okta LDAP Agent installer (.deb file) found in the '$BASE_DIR' directory."
    echo "Please download the agent from your Okta Admin Console and place it in that folder before running this script."
    exit 1
fi

# --- LOAD CONFIGURATION ---
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a && source "$SCRIPT_DIR/.env" && set +a
elif [ -f "$BASE_DIR/.env" ]; then
  set -a && source "$BASE_DIR/.env" && set +a
else
    echo "❌ ERROR: Configuration file '.env' not found."
    echo "Please create it based on the documentation before running."
    exit 1
fi

for var in "OKTA_ORG" "LDAP_BASE_DN" "LDAP_ADMIN_PASSWORD" "LDAP_CONFIG_PASSWORD"; do
    if [ -z "${!var}" ]; then
        echo "❌ ERROR: Required variable '${var}' was not loaded or is empty."
        echo "Please check your .env file."
        exit 1
    fi
done

LDAP_DOMAIN=$(echo "$LDAP_BASE_DN" | sed -E 's/dc=([^,]+),?/\1./g' | sed 's/\.$//')
LDAP_ADMIN_DN="cn=admin,$LDAP_BASE_DN"
LDAP_ORGANIZATION=${LDAP_ORGANIZATION:-$LDAP_DOMAIN}

echo "→→→ Starting OpenLDAP and Utilities Installation on Ubuntu 24.04 ←←←"
echo ""
echo "ℹ️ Using the following settings: "
echo "  ▪︎ LDAP_BASE_DN: $LDAP_BASE_DN"
echo "  ▪︎ LDAP_DOMAIN: $LDAP_DOMAIN"
echo "  ▪︎ LDAP_ADMIN_DN: $LDAP_ADMIN_DN"
echo "  ▪︎ LDAP_ADMIN_PASSWORD: $LDAP_ADMIN_PASSWORD"
echo "  ▪︎ LDAP_CONFIG_PASSWORD: $LDAP_CONFIG_PASSWORD"
echo ""

# --- Ask for confirmation if not silent ---
SILENT=false
[[ " $* " =~ " -s " || " $* " =~ " --silent " ]] && SILENT=true
if ! $SILENT; then
  read -r -t 30 -p "Continue? [Y/n] (auto-accepts in 30s) " CONFIRM
  CONFIRM=${CONFIRM:-y}  # Default to 'y' if empty
  case "$CONFIRM" in
    [yY][eE][sS]|[yY]) 
      echo "Continuing..."
      ;;
    *)
      echo "Aborted."
      exit 1
      ;;
  esac
else
  echo "🤐 Silent mode: skipping confirmation"
fi

# 1. System Preparation

echo "🧑‍💻 Preparing system..."
! $SILENT && sleep 1
sudo apt-get update -qq && sudo apt-get install -qq -y debconf-utils

if sudo ufw status | grep -q -i "Status: active"; then # Check if UFW is enabled
    echo "UFW is enabled. Adding the needed rules."
    sudo ufw allow 389/tcp   # LDAP
    sudo ufw allow 636/tcp   # LDAPS
    sudo ufw allow 5000/tcp  # Web Management tool
    sudo ufw reload
fi
echo "✅ System preparation complete."


# 2. Pre-configure slapd and slapd installation

echo "🗄️ Pre-configuring and installing slapd..."
cat <<EOF | sudo debconf-set-selections
slapd slapd/domain string $LDAP_DOMAIN
slapd slapd/organization string $LDAP_ORGANIZATION
slapd slapd/password1 password $LDAP_ADMIN_PASSWORD
slapd slapd/password2 password $LDAP_ADMIN_PASSWORD
slapd slapd/internal/adminpw password $LDAP_ADMIN_PASSWORD
slapd slapd/internal/generated_adminpw password $LDAP_ADMIN_PASSWORD
slapd slapd/backend select MDB
slapd slapd/no_configuration boolean false
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/dump_database select when needed
slapd slapd/dump_database_destdir string /var/lib/ldap/backups/slapd-VERSION
EOF
sudo apt-get install -qq -y slapd ldap-utils
echo "✅ slapd setup complete."


# 4. Set root access and cn=config password 


echo "🤖 Enabling root access into LDAP..."
sudo ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={0}config,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * 
  by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage
  by dn.base="cn=config" manage
  by * none

dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * 
  by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage
  by dn.base="$LDAP_ADMIN_DN" manage
  by * none

dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: mail,surname,givenname eq,pres,sub
EOF

echo "🤖 Set cn=config password..."
sudo ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={0}config,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: $(slappasswd -s "$LDAP_CONFIG_PASSWORD")
EOF
echo "✅ Root access, cn=admin, and cn=config account configured."

# Rebuild all indexes
sudo systemctl stop slapd && sudo slapindex -F /etc/ldap/slapd.d && sudo systemctl start slapd

# 5. Load LDIF data

echo "📇 Loading data into LDAP..."
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f "$BASE_DIR/src/ldifs/1.ou.ldif"
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f "$BASE_DIR/src/ldifs/2.users.ldif"
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f "$BASE_DIR/src/ldifs/3.groups.ldif"
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f "$BASE_DIR/src/ldifs/4.photos.ldif"
echo "✅ LDIF import complete."


# 6. LDAPS [todo]
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
sudo openssl req -x509 -nodes -days "$CERT_DAYS" -newkey "rsa:$CERT_KEY_SIZE" \
             -keyout /etc/ldap/sasl2/cert.key -out /etc/ldap/sasl2/cert.crt \
             -subj "$subject"
sudo chown -R openldap:openldap /etc/ldap/sasl2
sudo ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=config
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ldap/sasl2/cert.crt
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/sasl2/cert.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/sasl2/cert.key
-
replace: olcTLSVerifyClient
olcTLSVerifyClient: never
EOF
sudo sed -i 's#^SLAPD_SERVICES=.*#SLAPD_SERVICES="ldap:/// ldapi:/// ldaps:///"#' /etc/default/slapd && \
sudo systemctl restart slapd

# 6. Install and Configure ldap-ui

echo "🧑‍💻 Installing and configuring ldap-ui..."
sudo apt-get install -qq -y python3-dev libldap2-dev libsasl2-dev ldap-utils \
                        tox lcov valgrind python3-pip python3-venv python3-ldap
sudo useradd -r -s /bin/false ldap-ui
sudo mkdir /opt/ldap-ui
sudo chown ldap-ui:ldap-ui /opt/ldap-ui
sudo -u ldap-ui python3 -m venv /opt/ldap-ui/.venv3
sudo -u ldap-ui /opt/ldap-ui/.venv3/bin/pip install ldap-ui

echo "--> Creating systemd service for ldap-ui..."

sudo tee /opt/ldap-ui/.env > /dev/null <<EOF
BASE_DN=$LDAP_BASE_DN
LDAP_URL=ldap://127.0.0.1
LOGIN_ATTR=uid
BIND_PATTERN=cn=%s,$LDAP_BASE_DN
EOF
sudo chown ldap-ui:ldap-ui /opt/ldap-ui.env
sudo tee /etc/systemd/system/ldap-ui.service > /dev/null <<EOF
[Unit]
Description=ldap-ui - Lightweight LDAP Web UI
After=network.target auditd.service slapd.service
BindsTo=slapd.service

[Service]
WorkingDirectory=/opt/ldap-ui
ExecStart=/opt/ldap-ui/.venv3/bin/ldap-ui --host 0.0.0.0 --port 5000
Type=simple
User=ldap-ui
Group=ldap-ui
Restart=always
ProtectHome=true
ProtectSystem=strict
SystemCallFilter=@system-service
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now ldap-ui.service
echo "✅ ldap-ui setup complete. ldap-ui is accessible on port 5000."


# 7. Okta LDAP Agent

echo "🔐 Install Okta LDAP Agent..."
sudo dpkg -i "$BASE_DIR/OktaLDAPAgent-*.deb"
sudo tee /opt/Okta/OktaLDAPAgent/conf/InstallOktaLDAPAgent.conf > /dev/null <<EOF
orgUrl=https://$OKTA_ORG/
ldapHost=localhost
ldapAdminDN=$LDAP_ADMIN_DN
ldapPort=636
ldapSSLPort=636
baseDN=$LDAP_BASE_DN
ldapUseSSL=true
proxyEnabled=false
sslPinningEnabled=true
fipsMode=true
EOF
sudo chown OktaLDAPService:OktaLDAPService /opt/Okta/OktaLDAPAgent/conf/InstallOktaLDAPAgent.conf
echo "✅ Okta LDAP Agent setup complete."

# 8. Cleanup

echo "🧹 Final cleanup"
rm -rf /tmp/ldap-setup

echo "→→→ Installation Finished ←←←"
echo ""
echo "✅ OpenLDAP, ldap-ui, and the Okta LDAP Agent have been successfully installed and configured."
echo ""
echo "You can manage your LDAP server via the web at http://<your-server-ip>:5000"
echo ""
echo "⚠️ IMPORTANT ⚠️"
echo "The automated setup is complete. You must now configure the Okta LDAP Agent."
echo ""
echo "Run 'sudo /opt/Okta/OktaLDAPAgent/scripts/configure_agent.sh'."
echo ""
echo ""