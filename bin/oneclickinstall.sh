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
exec &> >(tee $SCRIPT_DIR/oneclickinstall.log) #logfile

mkdir -p /tmp/ldap-setup/

# --- VERIFY OPERATING SYSTEM ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "24.04" ]; then
        echo "ERROR: This script is designed to run only on Ubuntu 24.04 LTS."
        echo "Detected OS: $PRETTY_NAME"
        exit 1
    fi
else
    echo "ERROR: Cannot determine OS version. /etc/os-release not found."
    exit 1
fi
if ! ls $BASE_DIR/packages/*.deb 1>/dev/null 2>&1; then
    echo "ERROR: No Okta LDAP Agent installer (.deb file) found in the '$BASE_DIR/packages/' directory."
    echo "Please download the agent from your Okta Admin Console and place it in that folder before running this script."
    exit 1
fi

# --- LOAD CONFIGURATION ---
if [ -f $SCRIPT_DIR/.env ]; then
  set -a && source $SCRIPT_DIR/.env && set +a
elif [ -f $BASE_DIR/.env ]; then
  set -a && source $BASE_DIR/.env && set +a
else
    echo "ERROR: Configuration file '.env' not found."
    echo "Please create it based on the documentation before running."
    exit 1
fi

for var in "OKTA_ORG" "LDAP_BASE_DN" "LDAP_ADMIN_PASSWORD" "LDAP_CONFIG_PASSWORD"; do
    if [ -z "${!var}" ]; then
        echo "ERROR: Required variable '${var}' was not loaded or is empty."
        echo "Please check your .env file."
        exit 1
    fi
done

LDAP_DOMAIN=$(echo "$LDAP_BASE_DN" | sed -E 's/dc=([^,]+),?/\1./g' | sed 's/\.$//')
LDAP_ADMIN_DN="cn=admin,$LDAP_BASE_DN"

echo "--- Starting OpenLDAP and Utilities Installation on Ubuntu 24.04 ---"
echo ""
echo "Using the following settings: "
echo "  - LDAP_BASE_DN: $LDAP_BASE_DN"
echo "  - LDAP_DOMAIN: $LDAP_DOMAIN"
echo "  - LDAP_ADMIN_DN: $LDAP_ADMIN_DN"
echo "  - LDAP_ADMIN_PASSWORD: $LDAP_ADMIN_PASSWORD"
echo "  - LDAP_CONFIG_PASSWORD: $LDAP_CONFIG_PASSWORD"
echo ""

# --- Ask for confirmation if not silent ---
SILENT=false
[[ " $* " =~ " -s " || " $* " =~ " --silent " ]] && SILENT=true
if ! $SILENT; then
  read -t 30 -p "Continue? [Y/n] (auto-accepts in 30s) " CONFIRM
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
  echo "Silent mode: skipping confirmation"
fi

# 1. System Preparation
echo "--> Preparing system..."
! $SILENT && sleep 1
sudo apt-get update -qq && sudo apt-get install -qq -y debconf-utils

if sudo ufw status | grep -q -i "Status: active"; then # Check if UFW is enabled
    echo "UFW is enabled. Adding the needed rules."
    sudo ufw allow 389/tcp   # LDAP
    sudo ufw allow 636/tcp   # LDAPS
    sudo ufw allow 5000/tcp  # Web Management tool
    sudo ufw reload
fi

# 2. Pre-configure slapd installation
echo "--> Pre-configuring slapd..."
cat <<EOF | debconf-set-selections
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

# 3. Install OpenLDAP
echo "--> Installing slapd and ldap-utils..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -qq -y slapd ldap-utils

# 4. Configure cn=config user and root access
echo "--> Set cn=admin,dc=galaxy,dc=universe..."
sudo ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=admin,dc=galaxy,dc=universe
changetype: modify
replace: userPassword
userPassword: $(slappasswd -s "$LDAP_ADMIN_PASSWORD")
EOF

echo "--> Set cn=config password..."
sudo ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={0}config,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: $(slappasswd -s "$LDAP_CONFIG_PASSWORD")
EOF

echo "--> Enabling root access into LDAP..."
sudo ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={0}config,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * 
  by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage
  by dn.base="cn=config" manage
  by * none
EOF
sudo ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * 
  by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage
  by dn.base="cn=admin,dc=galaxy,dc=universe" manage
  by * none
EOF

# 5. Load LDIF data
echo "--> Loading data into LDAP..."
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f $BASE_DIR/src/ldifs/1.ou.ldif
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f $BASE_DIR/src/ldifs/2.users.ldif
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f $BASE_DIR/src/ldifs/3.groups.ldif
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f $BASE_DIR/src/ldifs/4.photos.ldif

# 6. Install and Configure ldap-ui
echo "--> Installing and configuring ldap-ui..."
sudo apt-get install -qq -y python3-dev libldap2-dev libsasl2-dev ldap-utils \
                        tox lcov valgrind python3-pip python3-venv python3-ldap
sudo useradd -r -s /bin/false ldap-ui
sudo mkdir /opt/ldap-ui
sudo chown ldap-ui:ldap-ui /opt/ldap-ui
sudo -u ldap-ui python3 -m venv /opt/ldap-ui/.venv3
sudo -u ldap-ui /opt/ldap-ui/.venv3/bin/pip install ldap-ui

echo "--> Creating systemd service for ldap-ui..."
cat > /tmp/ldap-setup/ldap-ui.service << EOF
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
Environment=BASE_DN=$LDAP_BASE_DN
Environment=LDAP_URL=ldap://127.0.0.1
Environment=LOGIN_ATTR=cn"
Environment=BIND_PATTERN=cn=%s,$LDAP_BASE_DN
ProtectHome=true
ProtectSystem=strict
SystemCallFilter=@system-service
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/ldap-setup/ldap-ui.service /etc/systemd/system/ldap-ui.service
sudo systemctl daemon-reload
sudo systemctl enable --now ldap-ui.service
#sudo systemctl start ldap-ui.service

# 7. Okta LDAP Agent
echo "--> Preparing for Okta LDAP Agent..."
sudo dpkg -i $BASE_DIR/packages/OktaLDAPAgent-*.deb
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

# 8. Cleanup
rm -rf /tmp/ldap-setup

echo "--- Installation Finished ---"
echo ""
echo "✅ OpenLDAP, ldap-ui, and the Okta LDAP Agent have been successfully installed and configured."
echo ""
echo "You can manage your LDAP server via the web at http://<your-server-ip>:5000"
echo ""
echo "--- IMPORTANT ---"
echo "The automated setup is complete. You must now configure the Okta LDAP Agent."
echo ""
echo "Run 'sudo /opt/Okta/OktaLDAPAgent/scripts/configure_agent.sh'."
echo ""
echo "---"