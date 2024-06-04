# Stage 1: Generate certificates
FROM alpine:latest AS cert-generator

RUN apk add --no-cache openssl

WORKDIR /certs

# Generate the CA key and certificate
RUN openssl ecparam -out myCA.key -name prime256v1 -genkey
RUN openssl req -new -sha256 -key myCA.key -out myCA.csr -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=myCA"
RUN openssl x509 -req -sha256 -days 365 -in myCA.csr -signkey myCA.key -out myCA.crt

# Generate the PostgreSQL key and certificate signed by the CA
RUN openssl ecparam -out postgresdb.key -name prime256v1 -genkey
RUN openssl req -new -sha256 -key postgresdb.key -out postgresdb.csr -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=postgresdb"
RUN openssl x509 -req -in postgresdb.csr -CA myCA.crt -CAkey myCA.key -CAcreateserial -out postgresdb.crt -days 365 -sha256

# Stage 2: PostgreSQL setup
FROM postgres:16-alpine

# Create the directory before copying files
RUN mkdir -p /var/lib/postgresql/certs

COPY --from=cert-generator /certs/postgresdb.key /var/lib/postgresql/certs
COPY --from=cert-generator /certs/postgresdb.crt /var/lib/postgresql/certs
COPY --from=cert-generator /certs/myCA.crt /var/lib/postgresql/certs

RUN chown 0:70 /var/lib/postgresql/certs/postgresdb.key && chmod 640 /var/lib/postgresql/certs/postgresdb.key
RUN chown 0:70 /var/lib/postgresql/certs/postgresdb.crt && chmod 640 /var/lib/postgresql/certs/postgresdb.crt
RUN chown 0:70 /var/lib/postgresql/certs/myCA.crt && chmod 640 /var/lib/postgresql/certs/myCA.crt

# COPY ssl-conf.sh /usr/local/bin/
# RUN chmod +x /usr/local/bin/ssl-conf.sh

CMD ["postgres", "-c", "ssl=on", "-c", "ssl_cert_file=/var/lib/postgresql/certs/postgresdb.crt", "-c", \
    "ssl_key_file=/var/lib/postgresql/certs/postgresdb.key", "-c", "ssl_ca_file=/var/lib/postgresql/certs/postgresdb.crt"]
