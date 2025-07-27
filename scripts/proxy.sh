#!/bin/bash

echo "🌍 Installing and configuring nginx Reverse Proxy..."
sudo apt-get update -qq && apt-get install -y -qq nginx
sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF
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
sudo systemctl reload nginx
echo "✅ nginx Reverse Proxy setup complete. ldap-ui is accessible on port 80."
