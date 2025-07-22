#!/bin/bash

pgrep -f "OktaLDAPAgent" > /dev/null
if [ $? -ne 0 ]; then
  echo "Okta LDAP Agent is not running"
  exit 1
fi

# Everything OK
exit 0