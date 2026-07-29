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
 *   Every statement is idempotent, so it can also be applied by hand to a running DB:
 *       docker compose exec -T db mysql -uroot -p<pw> openmrs < 20-buendia-site.sql
 *   ...then flush the server's caches, or renames won't reach the tablet:
 *       curl -u buendia:buendia 'http://localhost:9000/openmrs/ws/rest/buendia/locations?clear-cache'
 *   Idempotency is NOT uniform, though: most sections lean on a unique `uuid` index and
 *   ON DUPLICATE KEY UPDATE, but `users` HAS NO SUCH INDEX and needs an explicit guard —
 *   see the warning in section 2 before touching it. Section 4 self-checks the result;
 *   if it prints FATAL, fix it before letting a tablet near the server.
 *
 * NB on LOCATION NAMES — the client reads markup out of the name. Anything in SQUARE
 * BRACKETS is stripped before display (client Intl.java), so brackets carry metadata that
 * clinicians never see:
 *
 *   [<number>]  controls DISPLAY ORDER. The client sorts locations ALPHANUMERICALLY BY NAME
 *               (LocationForest / Utils.ALPHANUMERIC_COMPARATOR); insertion order and
 *               location_id are ignored, and there is no sort-order column. A bracketed
 *               numeric prefix sorts numerically ("[2]" before "[11]") and stays invisible.
 *               Without it the zones would appear alphabetically: Confirmed, Discharged,
 *               Probable, Suspect, Triage — i.e. not in clinical-flow order.
 *   [*]         marks the DEFAULT LOCATION for newly-added patients. The add-patient dialog
 *               offers no location picker: it always uses LocationForest.getDefaultLocation()
 *               (client PatientDialogFragment.java), which is the location whose name contains
 *               an asterisk, or — if none does — THE FIRST LEAF IN ALPHANUMERIC ORDER. Without
 *               the marker, every new patient silently landed in "Confirmed Zone", which is
 *               clinically wrong and was found during the 2026-07-29 tablet smoke test.
 *   [fr:...]    a localized name, e.g. 'Triage [fr:Triage]' (same convention as the profile CSV).
 *
 * So '[1] Triage [*]' displays as "Triage", sorts first, and receives new patients.
 * Renaming a location is safe and syncs to tablets; changing a UUID is not (see below).
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
/* Displayed names are Triage / Suspect Zone / Probable Zone / Confirmed Zone / Discharged,
   in that (clinical-flow) order; the bracketed prefixes are invisible. Triage carries [*] so
   new patients are admitted there, which is where they physically arrive. */
    ('[1] Triage [*]',    @admin_id, NOW(), '255800b2-2c20-4687-89d5-eb7ac7b19b46', @facility_id, 0),
    ('[2] Suspect Zone',  @admin_id, NOW(), '930f5328-9d23-4a65-b364-d7dea1020217', @facility_id, 0),
    ('[3] Probable Zone', @admin_id, NOW(), 'c9e04bed-7abb-4b9f-8178-c74627c4970a', @facility_id, 0),
    ('[4] Confirmed Zone',@admin_id, NOW(), '66c6dc36-6d80-4bf3-a391-a20e50d19d78', @facility_id, 0),
    ('[5] Discharged',    @admin_id, NOW(), 'b990663d-b80b-41ba-9b55-de172a5db780', @facility_id, 0)
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

/* ⚠️ `users` is the ONE table used by this file that has NO unique index on `uuid`
 * (verified on the pilot DB: location, person, person_name and provider all have one; users
 * does not). So `INSERT ... ON DUPLICATE KEY UPDATE` — which is what every other section here
 * relies on — silently does NOT de-duplicate for users: re-applying this file would insert a
 * SECOND users row with the same uuid, and OpenMRS then fails EVERY login with "username or
 * password incorrect" because the username no longer resolves to a single user. That happened
 * on 2026-07-29 and locked the tablet out. Hence the explicit existence guard below instead of
 * ON DUPLICATE KEY UPDATE. Recovery, if it ever happens again:
 *   DELETE FROM user_role WHERE user_id = <the higher id>;
 *   DELETE FROM users     WHERE user_id = <the higher id>;
 * then hit any endpoint with ?clear-cache. Keep the LOWER id — that is the row the tablets
 * have been authenticating against. */
INSERT INTO users (system_id, username, password, salt, person_id, date_created, creator, uuid, retired)
SELECT @user_name, @user_name, SHA2(CONCAT(@user_password, @user_salt), 512), @user_salt,
       @person_id, NOW(), @admin_id, '85c96ba2-547c-4f0f-9369-ae5b4570563f', 0
  FROM (SELECT 1) AS dummy
 WHERE NOT EXISTS (SELECT 1 FROM (SELECT uuid, username FROM users) u
                    WHERE u.uuid = '85c96ba2-547c-4f0f-9369-ae5b4570563f'
                       OR u.username = @user_name);

/* Re-assert the credential on the existing row, so that changing @user_password/@user_salt
 * above and re-applying this file actually rotates the password. */
UPDATE users
   SET system_id = @user_name, username = @user_name,
       password = SHA2(CONCAT(@user_password, @user_salt), 512),
       salt = @user_salt, retired = 0
 WHERE uuid = '85c96ba2-547c-4f0f-9369-ae5b4570563f';

SELECT @user_id := user_id FROM users
    WHERE uuid = '85c96ba2-547c-4f0f-9369-ae5b4570563f' ORDER BY user_id LIMIT 1;

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

/* ---------------------------------------------------------------------------
 * 4. Self-check
 *
 * Printed when this file is applied by hand. Exactly ONE row must carry the login username:
 * more than one and OpenMRS rejects every login (see the warning in section 2). This is here
 * because that failure mode is silent at apply time and only shows up as a locked-out tablet.
 * ------------------------------------------------------------------------ */
SELECT
    IF(COUNT(*) = 1,
       CONCAT('OK: one login account (user_id ', MIN(user_id), ')'),
       CONCAT('*** FATAL: ', COUNT(*), ' rows have username=''', @user_name,
              ''' -- every login will fail. Delete all but the lowest user_id. ***')
    ) AS login_account_check
FROM users WHERE username = @user_name;
