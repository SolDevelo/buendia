#!/usr/bin/env bash
#
# Build the buendia-openmrs image. Run from anywhere; context is the repo root.
#
#   ./build-image.sh --fetch        # ONE-TIME: download war + xforms + webservices.rest into artifacts/
#   ./build-image.sh                # rebuild the image (fast: recompiles the omod, reuses vendored deps)
#   ./build-image.sh --skip-tests   # skip the omod's mvn tests (faster iteration)
#   ./build-image.sh --tag myname   # override image name
#   ./build-image.sh --no-cache     # force a clean rebuild
#
# The frequent loop while fixing bugs is just:  ./build-image.sh --skip-tests
# then, in deploy/:  docker compose up -d --force-recreate openmrs
#
set -euo pipefail

IMAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$IMAGE_DIR/../.." && pwd)"
# shellcheck disable=SC1091
source "$IMAGE_DIR/versions.env"

DO_FETCH=false
DO_PUSH=false
MAVEN_FLAGS=""
NOCACHE=""
PLATFORM="${PLATFORM:-linux/amd64}"   # server is x86-64; force amd64 even on an ARM build host
IMAGE_NAME="${IMAGE_NAME:-buendia-openmrs}"   # set to e.g. docker.io/yourorg/buendia-openmrs to push
for arg in "$@"; do
  case "$arg" in
    --fetch)      DO_FETCH=true ;;
    --push)       DO_PUSH=true ;;
    --skip-tests) MAVEN_FLAGS="$MAVEN_FLAGS -DskipTests" ;;
    --no-cache)   NOCACHE="--no-cache" ;;
    --tag=*)      IMAGE_NAME="${arg#*=}" ;;
    -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done
# allow "--tag NAME"
prev=""
for arg in "$@"; do [[ "$prev" == "--tag" ]] && IMAGE_NAME="$arg"; prev="$arg"; done

GIT_SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo nogit)"
TAG="${IMAGE_NAME}:${OPENMRS_PLATFORM_VERSION}-${GIT_SHA}"
LATEST="${IMAGE_NAME}:latest"

# ---------------------------------------------------------------------------
# --fetch: vendor the heavy artefacts once via direct download from the OpenMRS Maven repo
# (URLs in versions.env, verified against the repo). The omods are published as .jar; we save
# them under the canonical .omod names the Dockerfile expects.
# ---------------------------------------------------------------------------
if $DO_FETCH; then
  echo "==> Fetching vendored artefacts into $IMAGE_DIR/artifacts/ (direct download)"
  fetch() { # <url> <dest-filename>
    echo "    $2  <-  $1"
    curl -fSL "$1" -o "$IMAGE_DIR/artifacts/$2"
  }
  fetch "$WAR_URL"    "openmrs.war"
  fetch "$XFORMS_URL" "xforms.omod"
  fetch "$WSREST_URL" "webservices.rest.omod"
  echo "    Fetched:"
  ls -la "$IMAGE_DIR/artifacts/" | grep -E 'openmrs\.war|xforms\.omod|webservices\.rest\.omod'
fi

# ---------------------------------------------------------------------------
# Preflight: artefacts must be vendored before an image build.
# ---------------------------------------------------------------------------
for f in openmrs.war xforms.omod webservices.rest.omod; do
  [[ -s "$IMAGE_DIR/artifacts/$f" ]] || {
    echo "ERROR: deploy/image/artifacts/$f missing. Run: $0 --fetch" >&2; exit 1; }
done

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
echo "==> Building $TAG  (platform: $PLATFORM, maven flags: '${MAVEN_FLAGS:-none}')"
DOCKER_BUILDKIT=1 docker build $NOCACHE \
  --platform "$PLATFORM" \
  -f "$IMAGE_DIR/Dockerfile" \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --build-arg "MAVEN_VERSION=${MAVEN_VERSION}" \
  --build-arg "MAVEN_FLAGS=${MAVEN_FLAGS}" \
  --build-arg "TOMCAT_VERSION=${TOMCAT_VERSION}" \
  -t "$TAG" -t "$LATEST" \
  "$REPO_ROOT"

echo
echo "==> Built:  $TAG  (+ $LATEST)"
docker image inspect "$TAG" --format '    id: {{.Id}}' 2>/dev/null || true

if $DO_PUSH; then
  case "$IMAGE_NAME" in */*) ;; *)
    echo "ERROR: --push needs a registry path, e.g. --tag=docker.io/yourorg/buendia-openmrs" >&2; exit 1 ;;
  esac
  echo "==> Pushing to registry"
  docker push "$TAG"
  docker push "$LATEST"
  DIGEST="$(docker inspect --format '{{index .RepoDigests 0}}' "$TAG" 2>/dev/null || true)"
  echo "    pushed. Pin by digest in deploy/.env:  OPENMRS_IMAGE=${DIGEST:-$TAG}"
else
  echo
  echo "Point deploy/.env at it:  OPENMRS_IMAGE=$TAG"
  echo "Then in deploy/:          docker compose up -d --force-recreate openmrs"
  echo "To publish:               $0 --tag=docker.io/yourorg/buendia-openmrs --push"
fi
