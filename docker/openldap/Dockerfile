FROM bitnami/openldap:latest

LABEL maintainer="Fabio Gasso <fabio.grasso@okta.com>"
LABEL org.opencontainers.image.authors="Fabio Gasso <fabio.grasso@okta.com>"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/fabiograsso/okta-lab-radius"
LABEL org.opencontainers.image.description="OpenLDAP with certificate autocreation"

COPY entrypoint.sh /opt/bitnami/scripts/openldap/custom-entrypoint.sh
USER root
RUN chmod +x "/opt/bitnami/scripts/openldap/custom-entrypoint.sh"
USER 1001
# Override entrypoint
ENTRYPOINT ["/opt/bitnami/scripts/openldap/custom-entrypoint.sh"]
CMD [ "/opt/bitnami/scripts/openldap/run.sh" ]