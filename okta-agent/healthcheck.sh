#!/bin/bash
#
# Author: Fabio Grasso <fabio.grasso@okta.com>
# Version: 1.0.0
# License: Apache-2.0
# Description: Simple healthcheck for the Okta LDAP Agent
#
# Usage: ./healthcheck.sh
#
# -----------------------------------------------------------------------------

pgrep -f "OktaLDAPAgent" > /dev/null
if [ $? -ne 0 ]; then
  echo "Okta LDAP Agent is not running"
  exit 1
fi

# Everything OK
exit 0