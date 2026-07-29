#!/bin/bash
# buendia-openmrs container entrypoint: render runtime props from env, start Tomcat.
set -e

: "${DB_HOST:=db}"
: "${DB_DATABASE:=openmrs}"
: "${DB_USERNAME:=openmrs}"
: "${DB_PASSWORD:?DB_PASSWORD must be set}"
export DB_HOST DB_DATABASE DB_USERNAME DB_PASSWORD
# NB: trailing slash is required — OpenMRS joins this dir + "openmrs-runtime.properties"
# (and + "modules") WITHOUT a separator, so /opt/openmrs → /opt/openmrsopenmrs-runtime.properties.
export OPENMRS_APPLICATION_DATA_DIRECTORY=/opt/openmrs/

# Render openmrs-runtime.properties (webapp context is "openmrs" → this filename).
envsubst < /opt/openmrs/runtime.properties.tpl > /opt/openmrs/openmrs-runtime.properties
echo "Wrote /opt/openmrs/openmrs-runtime.properties (DB_HOST=$DB_HOST DB_DATABASE=$DB_DATABASE)"

# buendia-profile-apply resolves its DB connection through utils.sh, which sources
# /usr/share/buendia/site/*. In the split-container setup MySQL is the `db` host (not
# localhost), so provide the connection there.
mkdir -p /usr/share/buendia/site
cat > /usr/share/buendia/site/10-openmrs-db <<EOF
OPENMRS_MYSQL_HOST=${DB_HOST}
OPENMRS_MYSQL_USER=${DB_USERNAME}
OPENMRS_MYSQL_PASSWORD=${DB_PASSWORD}
EOF

# buendia-server-clear-cache (called by profile-apply) hits the REST API on the container's
# internal port with the Buendia API account. Defaults to the conventional buendia/buendia;
# override SERVER_OPENMRS_USER/PASSWORD if you provision a different API user.
cat > /usr/share/buendia/site/20-clear-cache <<EOF
SERVER_OPENMRS_URL=http://localhost:8080/openmrs
SERVER_OPENMRS_USER=${SERVER_OPENMRS_USER:-buendia}
SERVER_OPENMRS_PASSWORD=${SERVER_OPENMRS_PASSWORD:-buendia}
EOF

# OpenMRS finds its data dir + runtime props via this system property.
export CATALINA_OPTS="${JAVA_OPTS:-} -DOPENMRS_APPLICATION_DATA_DIRECTORY=/opt/openmrs/"

echo "Starting Tomcat (CATALINA_OPTS=$CATALINA_OPTS)"
exec /opt/tomcat/bin/catalina.sh run
