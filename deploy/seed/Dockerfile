# Buendia DB image: mysql:5.6 with the baseline seed baked in.
#
# WHY THIS EXISTS: the baseline seed is ~83 MB of generated SQL that is git-ignored.
# When it was bind-mounted from the host, `docker pull` was NOT enough to stand up a
# server — someone had to copy that file onto the machine as well. Baking it into an
# image means the whole heavy, stable part of the deployment travels over the registry,
# so a site server needs internet only at SETUP time (`docker pull`), never at runtime.
#
# The SPLIT is deliberate:
#   10-buendia-base.sql  heavy + stable + regenerable  -> baked in HERE
#   20-buendia-site.sql  ~12 KB, hand-edited per site  -> bind-mounted by compose
# so tailoring a site (locations, accounts) still needs no image rebuild or push.
#
# mysql's entrypoint runs /docker-entrypoint-initdb.d/*.sql in alphabetical order, and
# only on FIRST boot (empty data volume), so 10- then 20- keeps working unchanged.
#
# Build with ./build-db-image.sh (which checks the seed exists first). Do not `docker build`
# this by hand without that check — a missing seed silently produces an unusable image.
ARG MYSQL_IMAGE=mysql:5.6
FROM ${MYSQL_IMAGE}

# Baked baseline: schema + ~50k concepts + the active clinical profile.
# NB COPY of an 83 MB file; the pushed layer is gzip-compressed (~15-20 MB on the wire).
COPY initdb/10-buendia-base.sql /docker-entrypoint-initdb.d/10-buendia-base.sql

# Provenance, readable without unpacking the image: docker image inspect --format '{{json .Config.Labels}}'
ARG SEED_SHA256=unknown
ARG SEED_BYTES=unknown
ARG GIT_SHA=unknown
LABEL org.opencontainers.image.title="Buendia field-pilot database (MySQL 5.6 + baked seed)" \
      org.opencontainers.image.source="https://github.com/SolDevelo/buendia" \
      org.projectbuendia.seed.sha256="${SEED_SHA256}" \
      org.projectbuendia.seed.bytes="${SEED_BYTES}" \
      org.projectbuendia.git.sha="${GIT_SHA}"
