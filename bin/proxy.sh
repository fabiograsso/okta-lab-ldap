#!/bin/bash
set -e

echo "--> Updating package lists and installing Nginx..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq nginx

echo "--> Configuring Nginx as a reverse proxy..."
# Create the Nginx configuration file using a here-document
sudo tee /etc/nginx/sites-available/ldap-ui > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

echo "--> Enabling the new site configuration..."
# Remove the default site if it exists
sudo rm -f /etc/nginx/sites-enabled/default
# Enable the ldap-ui site
sudo ln -s -f /etc/nginx/sites-available/ldap-ui /etc/nginx/sites-enabled/

echo "--> Restarting Nginx to apply changes..."
sudo systemctl restart nginx

echo "✅ Reverse proxy setup complete. ldap-ui is accessible on port 80."