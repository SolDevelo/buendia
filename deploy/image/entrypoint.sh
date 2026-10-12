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

# OpenMRS skips any module whose <id>.started global property is 'false' at boot. The seed (and so
# every installed site) carries 'false' for Reporting and its dependencies, left over from 2015, so
# switch them on here; a database that predates this image would otherwise never get them.
# Also make Reporting load the report descriptors baked into /opt/openmrs/configuration/reports.
# Never fatal: the tablet API does not depend on Reporting.
python2 - <<'EOF' || echo "WARNING: could not enable the Reporting modules"
import os, pymysql
db = pymysql.connect(host=os.environ['DB_HOST'], user=os.environ['DB_USERNAME'],
                     passwd=os.environ['DB_PASSWORD'], db=os.environ['DB_DATABASE'],
                     connect_timeout=20)
with db.cursor() as c:
    n = c.execute("UPDATE global_property SET property_value = 'true'"
                  " WHERE property IN ('reporting.started', 'serialization.xstream.started',"
                  " 'htmlwidgets.started', 'calculation.started') AND property_value <> 'true'")
    c.execute("INSERT INTO global_property (property, property_value, uuid)"
              " VALUES ('reporting.loadReportsFromConfigurationAtStartup', 'true', UUID())"
              " ON DUPLICATE KEY UPDATE property_value = 'true'")
db.commit()
print("Marked %d Reporting module(s) as started; report descriptors load at startup" % n)
EOF

# Java 7's default PermGen (~82 MB) is too small once Reporting and its dependencies load: its pages
# fail with 'OutOfMemoryError: PermGen space'. Set first, so JAVA_OPTS can still override it.
# OpenMRS finds its data dir + runtime props via the system property.
export CATALINA_OPTS="-XX:MaxPermSize=256m ${JAVA_OPTS:-} -DOPENMRS_APPLICATION_DATA_DIRECTORY=/opt/openmrs/"

echo "Starting Tomcat (CATALINA_OPTS=$CATALINA_OPTS)"
exec /opt/tomcat/bin/catalina.sh run
