# OpenMRS runtime properties (rendered by entrypoint.sh via envsubst).
# Connection string mirrors tools/openmrs_setup — note storage_engine=InnoDB, which
# is why MySQL 5.6 is required (removed in 5.7+, plan §3.1).
connection.url=jdbc:mysql://${DB_HOST}:3306/${DB_DATABASE}?autoReconnect=true&sessionVariables=storage_engine=InnoDB&useUnicode=true&characterEncoding=UTF-8
connection.username=${DB_USERNAME}
connection.password=${DB_PASSWORD}
auto_update_database=true
module.allow_web_admin=true
profile_manager.profile_dir=/opt/openmrs/profiles
