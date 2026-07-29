# Buendia package server: nginx with the tablet APK and its index baked in.
#
# WHY: the APK cannot be built on the site server (that needs JDK 8 + the Android SDK), so it
# has to come from us. Baking the generated document root into an image means the APK reaches
# the site over the same channel as everything else — `docker pull` — with no file copying and
# no USB stick. First install by QR then works the moment the stack is up.
#
# The image is SITE-SPECIFIC, because the APK bakes in the server address and password
# (deploy/apk/build-apk.sh). Tag it per site+APK version, e.g. buendia-pkgserver:pilot-1.0.0,
# and rebuild it whenever the APK is rebuilt.
#
#   ./publish.sh                  # generate www/ from the newest built APK (do this first)
#   ./build-pkgserver-image.sh    # then bake www/ + nginx.conf into an image
#
# For local development the compose service can still bind-mount www/ instead (the default);
# this image is for what ships.
ARG NGINX_IMAGE=nginx:alpine-slim
FROM ${NGINX_IMAGE}

# .apk is NOT in nginx's default mime.types; nginx.conf fixes that in a location block (a
# `types` block in server context would REPLACE the inherited map, not extend it).
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY www/ /usr/share/nginx/html/

ARG APK_VERSION=unknown
ARG APK_SHA256=unknown
ARG SITE_ID=unknown
LABEL org.opencontainers.image.title="Buendia field-pilot package server (APK baked in)" \
      org.opencontainers.image.source="https://github.com/SolDevelo/buendia" \
      org.projectbuendia.apk.version="${APK_VERSION}" \
      org.projectbuendia.apk.sha256="${APK_SHA256}" \
      org.projectbuendia.site.id="${SITE_ID}"
