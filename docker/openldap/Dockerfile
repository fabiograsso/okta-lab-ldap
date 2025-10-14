FROM bitnamilegacy/openldap:latest

LABEL maintainer="Fabio Gasso <fabio.grasso@okta.com>"
LABEL org.opencontainers.image.authors="Fabio Gasso <fabio.grasso@okta.com>"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/fabiograsso/okta-lab-radius"
LABEL org.opencontainers.image.description="OpenLDAP with certificate autocreation"

USER root

RUN apt-get update -qq && \
    apt-get upgrade -qq -y && \
    apt-get install -qq -y --no-install-recommends sudo curl net-tools && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/log/apt && rm -rf /var/log/dpkg.log

COPY entrypoint.sh /opt/bitnami/scripts/openldap/custom-entrypoint.sh
RUN chmod +x "/opt/bitnami/scripts/openldap/custom-entrypoint.sh"

USER 1001

# Override entrypoint
ENTRYPOINT ["/opt/bitnami/scripts/openldap/custom-entrypoint.sh"]

CMD [ "/opt/bitnami/scripts/openldap/run.sh" ]