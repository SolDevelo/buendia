#!/usr/bin/env bash
# Create (or update) an OpenMRS user for Buendia API / web login, in the RUNNING compose DB.
# Mirrors tools/openmrs_account_setup (password = sha2(concat(pass,salt),512)). The clean
# baseline seed ships no usable login, so provision one after `docker compose up`.
#
#   ./create-openmrs-user.sh <username> <password>
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE="$HERE/../compose/docker-compose.yml"
ENV_FILE="$HERE/../.env"
U="${1:?usage: $0 <username> <password>}"
P="${2:?usage: $0 <username> <password>}"
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a
salt="$(xxd -l 64 -p /dev/urandom | tr -d '\n')"

sql() { docker compose --env-file "$ENV_FILE" -f "$COMPOSE" exec -T db \
          mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N "${MYSQL_DATABASE:-openmrs}" 2>/dev/null; }

exists="$(echo "select count(*) from users where username='$U';" | sql)"

if [ "${exists:-0}" -ge 1 ]; then
  echo "user '$U' exists → updating password"
  sql <<SQL
update users set salt='$salt', password=sha2(concat('$P','$salt'),512) where username='$U';
SQL
else
  echo "creating user '$U'"
  sql <<SQL
set @admin_id := (select user_id from users where system_id='admin' or username='admin' limit 1);
insert into person (date_created, creator, uuid) values (now(), @admin_id, uuid());
set @pid := last_insert_id();
insert into person_name (preferred, given_name, family_name, date_created, creator, person_id, uuid)
  values (1, '$U', 'User', now(), @admin_id, @pid, uuid());
insert into users (system_id, username, password, salt, date_created, creator, person_id, uuid)
  values ('$U', '$U', sha2(concat('$P','$salt'),512), '$salt', now(), @admin_id, @pid, uuid());
set @uid := last_insert_id();
insert into user_role (user_id, role)
  select @uid, r.role from role r
  where r.role in ('System Developer','Clinician','Data Manager','Data Assistant','Provider','Authenticated');
SQL
fi
echo "done: '$U' ready for login / API."
