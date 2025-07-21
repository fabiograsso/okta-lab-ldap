FROM ubuntu:24.04

LABEL maintainer="Fabio Gasso <fabio.grasso@okta.com>"
LABEL org.opencontainers.image.authors="Fabio Gasso <fabio.grasso@okta.com>"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/fabiograsso/okta-lab-radius"
LABEL org.opencontainers.image.description="Okta LDAP Agent"

# Install dependencies
RUN apt-get update && apt-get install -y openjdk-11-jre-headless curl sudo bash-completion && rm -rf /var/lib/apt/lists/*

# Copy the agent installer into the image
COPY OktaLDAPAgent*.deb /tmp/okta_agent.deb

# Install the agent
RUN dpkg -i /tmp/okta_agent.deb

# The agent will be started by the docker-compose command

CMD bash -c "/opt/Okta/OktaLDAPAgent/scripts/service_script.sh precheck && /opt/Okta/OktaLDAPAgent/scripts/OktaLDAPAgent && tail -f /opt/Okta/OktaLDAPAgent/logs/agent.log"