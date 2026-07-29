#!/usr/bin/env bash
# Publish the Buendia images to a registry (default: Docker Hub, namespace `soldevelo`), so a
# site server can be built with `docker pull` and needs internet only at SETUP time.
#
#   ./publish-images.sh                  # PLAN only: print exactly what would be pushed
#   ./publish-images.sh --push           # actually tag + push
#   ./publish-images.sh --push --version 1.0.0    # also push a human-readable version tag
#
# Pushing is deliberately NOT the default: it publishes artefacts to a public namespace.
# Requires `docker login` first (a Docker Hub personal access token with write scope).
#
# After pushing, the digests printed at the end are what belongs in deploy/.env — pin by
# digest, not by tag, or a re-run months later is a different deployment.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/../.env"
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }

NAMESPACE="${REGISTRY_NAMESPACE:-soldevelo}"
PUSH=0; VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --push)      PUSH=1; shift ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --version)   VERSION="$2"; shift 2 ;;
    -h|--help)   sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

# Local image -> repository name. The pkgserver image is site-specific (the APK inside bakes in
# the server address and password), which is why it is listed but flagged.
declare -a LOCAL=() REMOTE=() NOTE=()
add() { LOCAL+=("$1"); REMOTE+=("$2"); NOTE+=("${3:-}"); }

pick() {  # newest local image matching a repo name, preferring an explicit .env value
  local envval="$1" repo="$2"
  if [[ -n "$envval" ]] && docker image inspect "$envval" >/dev/null 2>&1; then echo "$envval"; return; fi
  # `|| true` is required: under `set -o pipefail` a grep that matches nothing fails the whole
  # pipeline, which inside $(...) aborts the script with no output at all. "No such image" is a
  # normal answer here (e.g. no site-specific pkgserver image has been built yet).
  docker images --filter "reference=${repo}:*" --format '{{.Repository}}:{{.Tag}}' \
    | grep -v ':latest$' | head -1 || true
}

# Never publish `:latest` as the pilot's image: .env is supposed to pin a reproducible reference,
# and a floating tag makes a re-run months later a different deployment. If the local image is
# tagged :latest, find the concrete tag (git sha / version) pointing at the same image id.
resolve_tag() {
  local img="$1" id concrete
  [[ -n "$img" && "$img" == *:latest ]] || { echo "$img"; return; }
  id="$(docker image inspect --format '{{.Id}}' "$img" 2>/dev/null || true)"
  [[ -n "$id" ]] || { echo "$img"; return; }
  concrete="$(docker images --no-trunc --format '{{.Repository}}:{{.Tag}} {{.ID}}' \
    | awk -v id="$id" '$2==id {print $1}' | grep -v ':latest$' | head -1 || true)"
  if [[ -n "$concrete" ]]; then
    echo "  (resolved $img -> $concrete)" >&2
    echo "$concrete"
  else
    echo "WARNING: $img has no concrete tag — publishing a floating :latest is not reproducible." >&2
    echo "$img"
  fi
}

db="$(resolve_tag "$(pick "${DB_IMAGE:-}" buendia-db)")"
om="$(resolve_tag "$(pick "${OPENMRS_IMAGE:-}" buendia-openmrs)")"
pk="$(resolve_tag "$(pick "${PKGSERVER_IMAGE:-}" buendia-pkgserver)")"

[[ -n "$db" ]] && add "$db" "$NAMESPACE/buendia-db"
[[ -n "$om" ]] && add "$om" "$NAMESPACE/buendia-openmrs"
[[ -n "$pk" ]] && add "$pk" "$NAMESPACE/buendia-pkgserver" \
  "SITE-SPECIFIC: contains the APK, which bakes in the server address and password"

[[ ${#LOCAL[@]} -gt 0 ]] || {
  echo "ERROR: found no local buendia-* images to publish." >&2
  echo "       Build them first: seed/build-db-image.sh, image/build-image.sh" >&2
  exit 1
}

echo "Registry namespace: $NAMESPACE"
[[ $PUSH -eq 1 ]] || echo "Mode: PLAN ONLY (re-run with --push to publish)"
echo

for i in "${!LOCAL[@]}"; do
  src="${LOCAL[$i]}"; repo="${REMOTE[$i]}"
  tag="${src##*:}"                       # reuse the local tag (carries the git sha / version)
  dst="$repo:$tag"
  echo "  $src"
  echo "    -> $dst"
  [[ -n "${NOTE[$i]}" ]] && echo "       ⚠️  ${NOTE[$i]}"
  if [[ $PUSH -eq 1 ]]; then
    docker tag "$src" "$dst"
    docker push "$dst"
    if [[ -n "$VERSION" ]]; then
      docker tag "$src" "$repo:$VERSION"; docker push "$repo:$VERSION"
    fi
  fi
done

if [[ $PUSH -eq 0 ]]; then
  echo
  echo "Nothing was pushed. Run:  docker login   then   $0 --push"
  exit 0
fi

echo
echo "==> published. Pin these in deploy/.env (digest, not tag):"
for i in "${!LOCAL[@]}"; do
  repo="${REMOTE[$i]}"; tag="${LOCAL[$i]##*:}"
  digest="$(docker inspect --format '{{index .RepoDigests 0}}' "$repo:$tag" 2>/dev/null || true)"
  case "$repo" in
    *buendia-db)        var=DB_IMAGE ;;
    *buendia-openmrs)   var=OPENMRS_IMAGE ;;
    *buendia-pkgserver) var=PKGSERVER_IMAGE ;;
  esac
  echo "    ${var}=${digest:-$repo:$tag}"
done
