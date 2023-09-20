ARG MARIADB_VERSION, MARIADB_USER, MARIADB_PASSWORD
FROM docker.io/bitnami/mariadb:${MARIADB_VERSION}

# Establecer las variables de entorno dentro del contenedor
ENV MARIADB_USER=${MARIADB_USER} \
    MARIADB_PASSWORD=${MARIADB_PASSWORD} \