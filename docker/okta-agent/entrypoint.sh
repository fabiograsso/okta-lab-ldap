#!/bin/bash
set -e

# Start the agent, log to stdout 
exec /opt/Okta/OktaLDAPAgent/scripts/OktaLDAPAgent 2>&1