# syntax=docker/dockerfile:1
#
# buendia-openmrs image: OpenMRS Platform 1.10.6 on Tomcat 7 / Java 7, with the
# Buendia omod + xforms + webservices.rest modules and python2 profile-apply.
#
# Build context = REPO ROOT (so it can see openmrs/, tools/, packages/, deploy/).
# Driven by deploy/image/build-image.sh. Heavy deps (war + 2 omods) are vendored
# into deploy/image/artifacts/ by `build-image.sh --fetch` (run once).
#
# Java 7 base: openjdk:7 is gone from Docker Hub, so we use Azul Zulu OpenJDK 7
# (Debian 11 / bullseye). Tomcat 7 + Maven 3.5.4 are pinned tarballs.

ARG BASE_IMAGE=azul/zulu-openjdk-debian:7

# ---------------------------------------------------------------------------
# Stage 1 — builder: compile the Buendia omod (JDK 7 + Maven 3.5.4)
# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE} AS builder
ARG MAVEN_VERSION=3.5.4
ARG MAVEN_FLAGS=""
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
# Maven 3.5.4 (last release that runs on Java 7)
RUN curl -fSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
      -o /tmp/maven.tgz \
 && mkdir -p /opt/maven && tar xzf /tmp/maven.tgz -C /opt/maven --strip-components=1 && rm /tmp/maven.tgz
ENV PATH="/opt/maven/bin:${PATH}"

WORKDIR /src
# Optional Maven mirror settings (if OpenMRS/central repos are flaky — WS-3). Harmless if absent.
COPY deploy/image/settings.xm[l] /root/.m2/settings.xml
# The omod's git-commit-id-plugin searches upward for .git (to stamp git.properties, read
# by VersionInfo/RestController). Provide it at the copied repo root so the search resolves.
# Lives only in this discarded builder stage; cached across uncommitted edit→rebuild loops.
COPY .git /src/.git
# The omod symlinks its buendia xforms sources from here:
#   openmrs/omod/src/main/java/org/openmrs/module/xforms/buendia -> ../../third_party/openmrs-module-xforms/...
# so third_party must sit next to openmrs/ for that relative symlink to resolve during compile.
COPY third_party/openmrs-module-xforms /src/third_party/openmrs-module-xforms
COPY openmrs/ /src/openmrs/
WORKDIR /src/openmrs
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B clean install ${MAVEN_FLAGS}
# Result: /src/openmrs/omod/target/*.omod

# ---------------------------------------------------------------------------
# Stage 2 — runtime: Tomcat 7 + JRE 7 + OpenMRS war + modules + profile-apply
# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE} AS runtime
ARG TOMCAT_VERSION=7.0.109
ENV OPENMRS_APPLICATION_DATA_DIRECTORY=/opt/openmrs/ \
    JAVA_OPTS="-Duser.timezone=UTC"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gettext-base python2.7 \
 && ln -sf /usr/bin/python2.7 /usr/bin/python2 \
 # PyMySQL for python2 (profile-apply); python-pymysql apt package is gone on bullseye
 && curl -fSL https://bootstrap.pypa.io/pip/2.7/get-pip.py -o /tmp/get-pip.py \
 && python2 /tmp/get-pip.py \
 && python2 -m pip install --no-cache-dir "PyMySQL<1.0" \
 && rm -f /tmp/get-pip.py \
 && rm -rf /var/lib/apt/lists/*

# Tomcat 7 (pinned tarball from the stable Apache archive)
RUN curl -fSL "https://archive.apache.org/dist/tomcat/tomcat-7/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" -o /tmp/tomcat.tgz \
 && mkdir -p /opt/tomcat \
 && tar xzf /tmp/tomcat.tgz -C /opt/tomcat --strip-components=1 \
 && rm -f /tmp/tomcat.tgz \
 && rm -rf /opt/tomcat/webapps/*

RUN mkdir -p /opt/openmrs/modules /opt/openmrs/profiles /usr/share/buendia

# Vendored heavy artefacts (canonical names, produced by `build-image.sh --fetch`).
COPY deploy/image/artifacts/openmrs.war             /opt/tomcat/webapps/openmrs.war
COPY deploy/image/artifacts/xforms.omod             /opt/openmrs/modules/xforms.omod
COPY deploy/image/artifacts/webservices.rest.omod   /opt/openmrs/modules/webservices.rest.omod
# Freshly-built Buendia omod from the builder stage.
COPY --from=builder /src/openmrs/omod/target/*.omod /opt/openmrs/modules/

# profile-apply tooling (python2), matching tools/openmrs_setup.
COPY tools/profile_apply     /usr/bin/buendia-profile-apply
COPY tools/profile_validate  /usr/bin/buendia-profile-validate
COPY tools/server_clear_cache /usr/bin/buendia-server-clear-cache
COPY packages/buendia-utils/data/usr/share/buendia/utils.sh /usr/share/buendia/utils.sh
RUN chmod +x /usr/bin/buendia-profile-apply /usr/bin/buendia-profile-validate /usr/bin/buendia-server-clear-cache

COPY deploy/image/entrypoint.sh          /entrypoint.sh
COPY deploy/image/runtime.properties.tpl /opt/openmrs/runtime.properties.tpl
RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
