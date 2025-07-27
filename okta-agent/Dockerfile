FROM ubuntu:24.04

LABEL maintainer="Fabio Gasso <fabio.grasso@okta.com>"
LABEL org.opencontainers.image.authors="Fabio Gasso <fabio.grasso@okta.com>"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/fabiograsso/okta-lab-radius"
LABEL org.opencontainers.image.description="Okta LDAP Agent"

# Install dependencies
RUN apt-get update -qq && apt-get install -qq -y sudo net-tools && rm -rf /var/lib/apt/lists/* && rm -rf /var/log/apt && rm -rf /var/log/dpkg.log

# Copy the agent installer into the image
COPY ../packages/OktaLDAPAgent*.deb /tmp/okta_agent.deb

# Install the agent
RUN dpkg -i /tmp/okta_agent.deb && rm /tmp/okta_agent.deb

# Healthcheck custom script + entrypoint
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/healthcheck.sh /usr/local/bin/entrypoint.sh

HEALTHCHECK --start-period=10s CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]