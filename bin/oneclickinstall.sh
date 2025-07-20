#!/bin/bash
set -e

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
if ! ls ./lab-ldap/*.deb 1>/dev/null 2>&1; then
    echo "ERROR: No Okta LDAP Agent installer (.deb file) found in the ./lab-ldap/ directory."
    echo "Please download the agent from your Okta Admin Console and place it in that folder before running this script."
    exit 1
fi

# --- LOAD CONFIGURATION ---
if [ ! -f .env ]; then
    echo "ERROR: Configuration file '.env' not found."
    echo "Please create it based on the documentation before running."
    exit 1
else
    set -a && source .env && set +a
fi
for var in "OKTA_ORG" "LDAP_ORGANISATION" "LDAP_DOMAIN" "LDAP_ADMIN_PASSWORD"; do
    if [ -z "${!var}" ]; then
        echo "ERROR: Required variable '${var}' was not loaded or is empty."
        echo "Please check your .env file."
        exit 1
    fi
done

# --- SCRIPT START ---

BASE_DN=$(echo "$LDAP_DOMAIN" | sed 's/\./,dc=/g' | sed 's/^/dc=/')
ADMIN_DN="cn=admin,$BASE_DN"

echo "--- Starting OpenLDAP and Utilities Installation on Ubuntu 24.04 ---"

# 1. System Preparation
echo "--> Preparing system..."
sudo apt update && sudo apt upgrade -y
sudo apt-get install -y debconf-utils

# Check if UFW is enabled
ufw_status=$(sudo ufw status | grep -i "Status: active")
if [ -n "$ufw_status" ]; then
    echo "UFW is enabled. Adding the needed rules."
    sudo ufw allow 389/tcp   # LDAP
    sudo ufw allow 636/tcp   # LDAPS
    sudo ufw allow 5000/tcp  # Custom API or web service
    sudo ufw reload
fi

# 2. Pre-configure slapd installation
echo "--> Pre-configuring slapd..."
echo "slapd slapd/domain string $LDAP_DOMAIN" | sudo debconf-set-selections
echo "slapd slapd/organization string $LDAP_ORGANIZATION" | sudo debconf-set-selections
echo "slapd slapd/password password $LDAP_ADMIN_PASSWORD" | sudo debconf-set-selections
echo "slapd slapd/password_again password $LDAP_ADMIN_PASSWORD" | sudo debconf-set-selections
echo "slapd slapd/backend select MDB" | sudo debconf-set-selections

# 3. Install OpenLDAP
echo "--> Installing slapd and ldap-utils..."
sudo apt-get install -y slapd ldap-utils

# 4. Create LDIF files
echo "--> Creating LDIF data files..."
mkdir -p /tmp/ldap-setup
cp src/*.ldif /tmp/ldap-setup/
find /tmp/ldap-setup -type f -name "*.ldif" -exec sed -i "s/{{ *LDAP_BASE_DN *}}/${BASE_DN//\//\\/}/g" {} +
find /tmp/ldap-setup -type f -name "*.ldif" -exec sed -i "s/{{ *LDAP_ORGANISATION *}}/${LDAP_ORGANISATION//\//\\/}/g" {} +


# 5. Load LDIF data
echo "--> Loading data into LDAP..."
ldapadd -x -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/ldap-setup/ou.ldif
ldapadd -x -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/ldap-setup/users.ldif
ldapadd -x -D "$ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f /tmp/ldap-setup/groups.ldif

# 6. Install and Configure ldap-ui
echo "--> Installing and configuring ldap-ui..."
sudo apt-get install -y python3-dev libldap2-dev libsasl2-dev ldap-utils \
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
ExecStart=/opt/ldap-ui/.venv3/bin/ldap-ui
Type=simple
User=ldap-ui
Group=ldap-ui
Restart=always
Environment="BASE_DN=$BASE_DN"
Environment="LDAP_URL=ldap://127.0.0.1"
Environment="LOGIN_ATTR=cn"
Environment="BIND_PATTERN=cn=%s,$BASE_DN"
ProtectHome=true
ProtectSystem=strict
SystemCallFilter=@system-service
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/ldap-setup/ldap-ui.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now ldap-ui.service

# 7. Okta LDAP Agent Setup
echo "--> Preparing for Okta LDAP Agent..."
sudo dpkg -i OktaLDAPAgent-*.deb
cat > /opt/Okta/OktaLDAPAgent/conf/InstallOktaLDAPAgent.conf << EOF
orgUrl=https://$OKTA_ORG
ldapHost=localhost
ldapAdminDN=$ADMIN_DN
ldapPort=389
baseDN=$BASE_DN
ldapUseSSL=false
proxyEnabled=false
sslPinningEnabled=true
fipsMode=true
EOF

# 8. Cleanup
rm -rf /tmp/ldap-setup

echo "--- Installation Finished ---"
echo ""
echo "Okta agent pre-configuration file created at /tmp/ldap-setup/InstallOktaLDAPAgent.conf"
echo ""
echo "--- IMPORTANT ---"
echo "The automated setup is complete. You must now configure the Okta LDAP Agent."
echo ""
echo "Run 'sudo /opt/Okta/OktaLDAPAgent/scripts/configure_agent.sh'."
echo ""
echo "---"