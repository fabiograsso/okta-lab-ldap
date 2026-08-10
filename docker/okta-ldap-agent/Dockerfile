FROM debian:13-slim

LABEL maintainer="Fabio Gasso <fabio.grasso@okta.com>"
LABEL org.opencontainers.image.authors="Fabio Gasso <fabio.grasso@okta.com>"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/fabiograsso/okta-lab-radius"
LABEL org.opencontainers.image.description="Okta LDAP Agent"

ARG DEB_URL

RUN apt-get update -qq && apt-get install -qq -y --no-install-recommends sudo curl net-tools ldap-utils && rm -rf /var/lib/apt/lists/* && rm -rf /var/log/apt && rm -rf /var/log/dpkg.log

COPY package/ /tmp/package/

RUN \
    if [ -z "$(find /tmp/package/ -name '*.deb' -print -quit)" ]; then \
        echo "--> Local .deb not found. Downloading from ${DEB_URL}..." && \
        FILENAME=$(basename "${DEB_URL}") && \
        curl -k -fSL -o "/tmp/package/${FILENAME}" "${DEB_URL}"; \
    fi && \
    dpkg -i /tmp/package/*.deb && \
    rm -rf /tmp/package/ && rm -rf /var/lib/apt/lists/* && rm -rf /var/log/apt && rm -rf /var/log/dpkg.log

COPY healthcheck.sh /usr/local/bin/healthcheck.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN  chmod +x /usr/local/bin/healthcheck.sh && chmod +x /usr/local/bin/entrypoint.sh

HEALTHCHECK --start-period=10s CMD pgrep -f "OktaLDAPAgent" >/dev/null || { echo "Okta LDAP Agent is not running"; exit 1; }

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]