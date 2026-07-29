/*
 * Buendia field pilot — site seed (locations + default login account).
 *
 * WHY THIS FILE EXISTS
 *   10-buendia-base.sql (generated from db-snapshot by build-seed.sh) is the clinical baseline:
 *   concept dictionary, forms, sync triggers, and the baked profile. It deliberately ships
 *   NO locations and NO usable login account. Without those two things a freshly booted server
 *   cannot be used: the tablet has nowhere to admit a patient to, and nobody can log in.
 *
 *   This file closes that gap so the package is usable straight after `docker compose up`,
 *   with no manual configuration. MySQL's entrypoint runs /docker-entrypoint-initdb.d/*.sql in
 *   filename order on FIRST init only, so this lands right after the base seed.
 *
 * EDITING THIS FILE
 *   This is the file to tailor per site (facility name, ward/zone layout, accounts). It is small,
 *   committed, and human-readable on purpose. After editing, a fresh DB is required for it to be
 *   re-applied by the entrypoint:
 *       docker compose --env-file ../.env down -v && docker compose --env-file ../.env up -d
 *   (You do NOT need to re-run build-seed.sh — that only rebuilds the 80 MB base seed.)
 *   Every statement is idempotent (keyed on uuid), so it can also be applied by hand to a
 *   running DB:  docker compose exec -T db mysql -uroot -p<pw> openmrs < 20-buendia-site.sql
 *
 * NB on DISPLAY ORDER: the Android client sorts locations ALPHANUMERICALLY BY NAME
 * (LocationForest / Utils.ALPHANUMERIC_COMPARATOR) — insertion order and location_id are
 * ignored. The zones below therefore appear as: Confirmed Zone, Discharged, Probable Zone,
 * Suspect Zone, Triage. To force clinical-flow order, prefix the names ("1 Triage",
 * "2 Suspect Zone", ...) — the comparator sorts numeric prefixes numerically.
 */

/* All rows are attributed to the built-in admin account (user_id 1 in the base seed). */
SELECT @admin_id := user_id FROM users WHERE system_id = 'admin' LIMIT 1;

/* ---------------------------------------------------------------------------
 * 1. Locations
 *
 * Buendia's location model is a tree. The single parentless location is the root ("the
 * facility"); the client derives the root from it (no UUID is hardcoded anywhere, in either
 * the client or the server, so these UUIDs are free to change — keep them stable once a
 * tablet has synced, though, or already-admitted patients point at dead locations).
 *
 * Zones may themselves have children (tents/wards/beds) — add them with parent_location set
 * to the zone's id, following the pattern in section 1b.
 * ------------------------------------------------------------------------ */

/* Root. Rename 'Facility' to the actual site name before deployment. */
INSERT INTO location (name, description, creator, date_created, uuid, retired) VALUES
    ('Facility', 'Pilot site root location', @admin_id, NOW(), 'c99dac94-8d22-4328-b758-756f50f242c4', 0)
    ON DUPLICATE KEY UPDATE name = VALUES(name), retired = 0;

SELECT @facility_id := location_id FROM location
    WHERE uuid = 'c99dac94-8d22-4328-b758-756f50f242c4';

/* Zones (children of the root). */
INSERT INTO location (name, creator, date_created, uuid, parent_location, retired) VALUES
    ('Triage',         @admin_id, NOW(), '255800b2-2c20-4687-89d5-eb7ac7b19b46', @facility_id, 0),
    ('Confirmed Zone', @admin_id, NOW(), '66c6dc36-6d80-4bf3-a391-a20e50d19d78', @facility_id, 0),
    ('Suspect Zone',   @admin_id, NOW(), '930f5328-9d23-4a65-b364-d7dea1020217', @facility_id, 0),
    ('Probable Zone',  @admin_id, NOW(), 'c9e04bed-7abb-4b9f-8178-c74627c4970a', @facility_id, 0),
    ('Discharged',     @admin_id, NOW(), 'b990663d-b80b-41ba-9b55-de172a5db780', @facility_id, 0)
    ON DUPLICATE KEY UPDATE
        name = VALUES(name), parent_location = VALUES(parent_location), retired = 0;

/* 1b. Tents / wards / beds — none for the pilot start. Example (uncomment + add real UUIDs):
 *
 * SELECT @confirmed_id := location_id FROM location
 *     WHERE uuid = '66c6dc36-6d80-4bf3-a391-a20e50d19d78';
 * INSERT INTO location (name, creator, date_created, uuid, parent_location, retired) VALUES
 *     ('C1', @admin_id, NOW(), '<uuid>', @confirmed_id, 0),
 *     ('C2', @admin_id, NOW(), '<uuid>', @confirmed_id, 0)
 *     ON DUPLICATE KEY UPDATE name = VALUES(name), parent_location = VALUES(parent_location);
 */

/* ---------------------------------------------------------------------------
 * 2. Default login account  (username: buendia / password: buendia)
 *
 * Used for the web admin UI, the REST API, and as the tablet's server credentials.
 * OpenMRS 1.10 stores password = SHA2(CONCAT(<plaintext>, salt), 512) with a 64-byte hex salt
 * (see tools/openmrs_account_setup and deploy/tools/create-openmrs-user.sh).
 *
 * !! CHANGE THE PASSWORD BEFORE THE REAL DEPLOYMENT. The salt below is committed, so it is
 * !! public — it adds no secrecy for the well-known default password. Rotate with:
 * !!     deploy/tools/create-openmrs-user.sh buendia <new-password>
 * !! which generates a fresh random salt against the running DB.
 * ------------------------------------------------------------------------ */

SET @user_name     := 'buendia';
SET @user_password := 'buendia';
SET @user_salt     := 'f57fed149d9b9912873deba6dbda878317ddbe742bc0f02b999f14d7202d75c3f98211b434987a883b8162c36c76d126cc50965ac590a8f4539f0e173196a188';

INSERT INTO person (gender, date_created, creator, uuid, voided) VALUES
    ('', NOW(), @admin_id, '7201d848-c52b-455c-9c4c-ff887812802c', 0)
    ON DUPLICATE KEY UPDATE voided = 0;

SELECT @person_id := person_id FROM person WHERE uuid = '7201d848-c52b-455c-9c4c-ff887812802c';

INSERT INTO person_name (preferred, person_id, given_name, family_name, date_created, creator, uuid, voided) VALUES
    (1, @person_id, 'Buendia', 'User', NOW(), @admin_id, '0622e440-c34a-4792-9e2b-27db2bfba99b', 0)
    ON DUPLICATE KEY UPDATE given_name = VALUES(given_name), family_name = VALUES(family_name), voided = 0;

INSERT INTO users (system_id, username, password, salt, person_id, date_created, creator, uuid, retired) VALUES
    (@user_name, @user_name, SHA2(CONCAT(@user_password, @user_salt), 512), @user_salt,
     @person_id, NOW(), @admin_id, '85c96ba2-547c-4f0f-9369-ae5b4570563f', 0)
    ON DUPLICATE KEY UPDATE
        username = VALUES(username), password = VALUES(password), salt = VALUES(salt), retired = 0;

SELECT @user_id := user_id FROM users WHERE uuid = '85c96ba2-547c-4f0f-9369-ae5b4570563f';

/* Roles. Mirrors deploy/tools/create-openmrs-user.sh; all six exist in the base seed.
 * 'System Developer' is what grants the REST access the tablet needs. */
INSERT IGNORE INTO user_role (user_id, role)
    SELECT @user_id, r.role FROM role r WHERE r.role IN
        ('System Developer', 'Clinician', 'Data Manager', 'Data Assistant', 'Provider', 'Authenticated');

/* ---------------------------------------------------------------------------
 * 3. Providers  (the "user list" the tablet shows when picking who you are)
 *
 * The client's user picker reads GET /ws/rest/buendia/providers, which returns all non-retired
 * `provider` rows. The base seed ships exactly one: 'Guest'. Without more, every observation is
 * attributed to Guest. Add one row per clinician here once MSF confirms the account list
 * (open decision, plan §8); the row below makes the default account selectable too.
 * ------------------------------------------------------------------------ */

INSERT INTO provider (person_id, identifier, name, creator, date_created, uuid, retired) VALUES
    (@person_id, 'buendia', 'Buendia User', @admin_id, NOW(), 'f0582eb9-026a-43df-81b7-338934eb6d4d', 0)
    ON DUPLICATE KEY UPDATE person_id = VALUES(person_id), name = VALUES(name), retired = 0;
