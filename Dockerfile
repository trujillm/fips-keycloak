FROM quay.io/keycloak/keycloak:nightly as builder

ADD files /tmp/files/

ENV KC_HEALTH_ENABLED=true
ENV KC_DB=postgres

WORKDIR /opt/keycloak
RUN cp /tmp/files/*.jar /opt/keycloak/providers/
RUN cp /tmp/files/keycloak-fips.keystore.* /opt/keycloak/bin/
# RUN cp /tmp/files/trust.bcfks.jks /opt/keycloak/bin/
RUN cp /tmp/files/ca.* /opt/keycloak/bin

RUN /opt/keycloak/bin/kc.sh show-config


RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:nightly
COPY --from=builder /opt/keycloak/ /opt/keycloak/

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]