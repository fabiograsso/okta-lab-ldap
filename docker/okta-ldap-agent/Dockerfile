FROM debian:12-slim

LABEL maintainer="Fabio Gasso <fabio.grasso@okta.com>"
LABEL org.opencontainers.image.authors="Fabio Gasso <fabio.grasso@okta.com>"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/fabiograsso/okta-lab-radius"
LABEL org.opencontainers.image.description="Okta LDAP Agent"

ARG DEB_URL

RUN apt-get update -qq && apt-get install -qq -y sudo net-tools && rm -rf /var/lib/apt/lists/* && rm -rf /var/log/apt && rm -rf /var/log/dpkg.log

COPY package/ /tmp/package/
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN \
    if [ -z "$(find /tmp/package/ -name '*.deb' -print -quit)" ]; then \
        echo "--> Local .deb not found. Downloading from ${DEB_URL}..." && \
        FILENAME=$(basename "$DEB_URL") && \
        curl -fSL -o "/tmp/package/${FILENAME}" "${DEB_URL}"; \
    fi && \
    dpkg -i /tmp/package/*.deb && \
    rm -rf /tmp/package/ && \
    chmod +x /usr/local/bin/healthcheck.sh && chmod +x /usr/local/bin/entrypoint.sh

HEALTHCHECK --start-period=10s CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]