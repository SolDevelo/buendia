--
-- Working data
--
SELECT @android := user_id FROM users WHERE username='android' LIMIT 1;
SELECT @assigned_location_id := person_attribute_type_id FROM person_attribute_type WHERE name='assigned_location' LIMIT 1;
SELECT @msf_type := patient_identifier_type_id FROM patient_identifier_type WHERE name='MSF' LIMIT 1;
SELECT @root_location := location_id FROM location WHERE uuid='3449f5fe-8e6b-4250-bcaa-fca5df28ddbf' LIMIT 1;
CREATE TEMPORARY TABLE locale_order (id INT PRIMARY KEY,locale VARCHAR(30));INSERT INTO locale_order (id, locale) VALUES (1, 'en_GB_client'), (2, 'en');--
-- Users
--
-- Guest User
INSERT INTO person (gender,creator,date_created) VALUES ('M',@android,NOW());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Guest","User",@android,NOW(),UUID());
INSERT INTO users (system_id,username,password,salt,creator,date_created,person_id,uuid)
  VALUES ("20-8","guest","1f356e800eb0aef5a2b9ddc9c9060856590679cf950de792540738efd659d3c98f751e4bc5bfbdbea90992f808cbe3a4f4fbb815e380ef07d0ff5a5a15fede82","ccaa9bb132115c6707cb0c54e6da7a85cb0f45115a5a7fbcb4ea745d4c4d97c387e3dc4baebf8002aab3d1518ba14bfc3675d7553d17a067ddb341f75af17fa7",@android,NOW(),@person_id,UUID());
INSERT INTO provider (person_id,name,creator,date_created,uuid) VALUES (@person_id,"Guest User",@android,NOW(),UUID());
--
-- Patients
--
--
-- Tara L Brima
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 42 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Tara L","Brima",@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.936",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Suspect 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Songowa Brima
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 402 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Songowa","Brima",@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.959",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Suspect 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Rose Lahai
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 726 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Rose","Lahai",@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.972",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Suspect 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Rosky Lahai
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 438 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Rosky","Lahai",@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.930",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Suspect 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Lansana Sangbah
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 498 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Lansana","Sangbah",@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.1025",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Suspect 1";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Triage";
INSERT INTO encounter (encounter_type,patient_id,location_id,encounter_datetime,creator,date_created,uuid) 
  VALUES (2,@person_id,@location_id,ADDTIME(CAST(DATE_SUB(CURDATE(), INTERVAL 1 DAY) AS DATETIME), "15:00"),@android,NOW(),UUID());
SELECT @encounter_id := LAST_INSERT_ID();
SELECT @encounter_datetime := encounter_datetime FROM encounter WHERE encounter_id=@encounter_id;
SELECT @provider_id := provider_id FROM provider WHERE name="Guest User";
INSERT INTO encounter_provider (encounter_id,provider_id,encounter_role_id,creator,date_created,uuid) 
  VALUES (@encounter_id,@provider_id,3,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Temperature °C" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_numeric,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,37.5,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Severe Weakness" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Nausea" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Vomiting" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Severe" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Diarrhoea" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Severe" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Cough" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Dyspnoea" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Hiccups" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Pain Assessment" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Severe" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Headache" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Chest" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Abdominal" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Back" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Arthralgia/Myalgia" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Bleeding" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Oral Bleeding" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Haemoptysis" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Haematemesis" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="PR Bleeding" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Haematuria" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Condition" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Very Poor" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Best Conscious State" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Unresponsive" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Mobility" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Bed-bound" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Tolerating Diet" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Nothing" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Hydration" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="IV" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Pregnant" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="IV fitted" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
--
-- Aiah Munda
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 354 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Aiah","Munda",@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.963",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Suspect 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Layla Sangbah
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 30 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Layla","Sangbah",@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.946",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Suspect 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Alice Dabundeh
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 642 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Alice","Dabundeh",@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.964",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Suspect 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Triage";
INSERT INTO encounter (encounter_type,patient_id,location_id,encounter_datetime,creator,date_created,uuid) 
  VALUES (2,@person_id,@location_id,ADDTIME(CAST(DATE_SUB(CURDATE(), INTERVAL 0 DAY) AS DATETIME), "15:00"),@android,NOW(),UUID());
SELECT @encounter_id := LAST_INSERT_ID();
SELECT @encounter_datetime := encounter_datetime FROM encounter WHERE encounter_id=@encounter_id;
SELECT @provider_id := provider_id FROM provider WHERE name="Guest User";
INSERT INTO encounter_provider (encounter_id,provider_id,encounter_role_id,creator,date_created,uuid) 
  VALUES (@encounter_id,@provider_id,3,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Pregnant" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
--
-- Alimany Kargbo
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 330 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Alimany","Kargbo",@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.960",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Probable 1";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Triage";
INSERT INTO encounter (encounter_type,patient_id,location_id,encounter_datetime,creator,date_created,uuid) 
  VALUES (2,@person_id,@location_id,ADDTIME(CAST(DATE_SUB(CURDATE(), INTERVAL 1 DAY) AS DATETIME), "15:00"),@android,NOW(),UUID());
SELECT @encounter_id := LAST_INSERT_ID();
SELECT @encounter_datetime := encounter_datetime FROM encounter WHERE encounter_id=@encounter_id;
SELECT @provider_id := provider_id FROM provider WHERE name="Guest User";
INSERT INTO encounter_provider (encounter_id,provider_id,encounter_role_id,creator,date_created,uuid) 
  VALUES (@encounter_id,@provider_id,3,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Pregnant" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
--
-- Komba Konuwa
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 306 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Komba","Konuwa",@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.925",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Probable 1";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Tamara Yema Fatorma
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 546 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 2 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Tamara Yema","Fatorma",@android,DATE_SUB(CURDATE(), INTERVAL 2 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 2 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.938",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Probable 1";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Tom Osho-Lewally
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 246 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Tom","Osho-Lewally",@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.937",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Probable 1";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Julia Lahai
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 546 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Julia","Lahai",@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.970",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Probable 1";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Bliss Badara Maju Sho
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 426 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 2 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Bliss Badara","Maju Sho",@android,DATE_SUB(CURDATE(), INTERVAL 2 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 2 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.962",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Probable 1";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Komba Kemokai
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 666 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Komba","Kemokai",@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.949",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Probable 1";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Mabinty Lahai
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 246 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Mabinty","Lahai",@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.973",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Probable 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Alusine Gbappy-Lahai
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 138 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Alusine","Gbappy-Lahai",@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 0 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.943",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Probable 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- UNKNOWN 
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 606 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"UNKNOWN","",@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 1 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.974",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Probable 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- UNKNOWN 
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 390 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 5 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"UNKNOWN","",@android,DATE_SUB(CURDATE(), INTERVAL 5 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 5 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.1002",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 1";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Sheku Badara Munu-Koroma
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 318 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Sheku Badara","Munu-Koroma",@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.993",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 1";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Triage";
INSERT INTO encounter (encounter_type,patient_id,location_id,encounter_datetime,creator,date_created,uuid) 
  VALUES (2,@person_id,@location_id,ADDTIME(CAST(DATE_SUB(CURDATE(), INTERVAL 8 DAY) AS DATETIME), "15:00"),@android,NOW(),UUID());
SELECT @encounter_id := LAST_INSERT_ID();
SELECT @encounter_datetime := encounter_datetime FROM encounter WHERE encounter_id=@encounter_id;
SELECT @provider_id := provider_id FROM provider WHERE name="Guest User";
INSERT INTO encounter_provider (encounter_id,provider_id,encounter_role_id,creator,date_created,uuid) 
  VALUES (@encounter_id,@provider_id,3,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Pregnant" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
--
-- Saar Munu-Koroma
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 465 DAY),@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Saar","Munu-Koroma",@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.994",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 1";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Augustine Salamy
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 198 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 9 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Augustine","Salamy",@android,DATE_SUB(CURDATE(), INTERVAL 9 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 9 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.926",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Tamba Bakarr Jajua
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 42 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Tamba Bakarr","Jajua",@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.924",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Frederick sangbeh
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 342 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 2 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Frederick","sangbeh",@android,DATE_SUB(CURDATE(), INTERVAL 2 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 2 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.975",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Saar Tunis
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 366 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 12 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Saar","Tunis",@android,DATE_SUB(CURDATE(), INTERVAL 12 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 12 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.948",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Habiba Tengbeh
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 666 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 7 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Habiba","Tengbeh",@android,DATE_SUB(CURDATE(), INTERVAL 7 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 7 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.957",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Bai Momoh
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 162 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 15 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Bai","Momoh",@android,DATE_SUB(CURDATE(), INTERVAL 15 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 15 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.971",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Lansana Koroma
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 150 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 11 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Lansana","Koroma",@android,DATE_SUB(CURDATE(), INTERVAL 11 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 11 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.932",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 2";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Kadie Sangbah
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 270 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 6 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Kadie","Sangbah",@android,DATE_SUB(CURDATE(), INTERVAL 6 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 6 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.929",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 3";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Triage";
INSERT INTO encounter (encounter_type,patient_id,location_id,encounter_datetime,creator,date_created,uuid) 
  VALUES (2,@person_id,@location_id,ADDTIME(CAST(DATE_SUB(CURDATE(), INTERVAL 5 DAY) AS DATETIME), "15:00"),@android,NOW(),UUID());
SELECT @encounter_id := LAST_INSERT_ID();
SELECT @encounter_datetime := encounter_datetime FROM encounter WHERE encounter_id=@encounter_id;
SELECT @provider_id := provider_id FROM provider WHERE name="Guest User";
INSERT INTO encounter_provider (encounter_id,provider_id,encounter_role_id,creator,date_created,uuid) 
  VALUES (@encounter_id,@provider_id,3,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Pregnant" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
--
-- Nika Mbahoh
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 534 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 6 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Nika","Mbahoh",@android,DATE_SUB(CURDATE(), INTERVAL 6 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 6 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.965",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 3";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Triage";
INSERT INTO encounter (encounter_type,patient_id,location_id,encounter_datetime,creator,date_created,uuid) 
  VALUES (2,@person_id,@location_id,ADDTIME(CAST(DATE_SUB(CURDATE(), INTERVAL 6 DAY) AS DATETIME), "15:00"),@android,NOW(),UUID());
SELECT @encounter_id := LAST_INSERT_ID();
SELECT @encounter_datetime := encounter_datetime FROM encounter WHERE encounter_id=@encounter_id;
SELECT @provider_id := provider_id FROM provider WHERE name="Guest User";
INSERT INTO encounter_provider (encounter_id,provider_id,encounter_role_id,creator,date_created,uuid) 
  VALUES (@encounter_id,@provider_id,3,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Pregnant" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
--
-- Frederick Lewally
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 234 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 7 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Frederick","Lewally",@android,DATE_SUB(CURDATE(), INTERVAL 7 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 7 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.961",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 3";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Bernadette Sesay
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 246 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 3 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Bernadette","Sesay",@android,DATE_SUB(CURDATE(), INTERVAL 3 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 3 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.976",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 3";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Tamba Lungay
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 570 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 5 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Tamba","Lungay",@android,DATE_SUB(CURDATE(), INTERVAL 5 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 5 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.941",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 3";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Mohamed Konuwa
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 366 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 18 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Mohamed","Konuwa",@android,DATE_SUB(CURDATE(), INTERVAL 18 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 18 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.955",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 4";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Sahr Entocher
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 522 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 4 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Sahr","Entocher",@android,DATE_SUB(CURDATE(), INTERVAL 4 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 4 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.944",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 4";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Rosa F M Yokie
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 30 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 3 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Rosa F","M Yokie",@android,DATE_SUB(CURDATE(), INTERVAL 3 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 3 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.969",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 4";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- UNKNOWN UNKNOWN
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 726 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 16 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"UNKNOWN","UNKNOWN",@android,DATE_SUB(CURDATE(), INTERVAL 16 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 16 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.933",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 4";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Alie Konuwa
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 114 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 11 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Alie","Konuwa",@android,DATE_SUB(CURDATE(), INTERVAL 11 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 11 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.956",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 4";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Henneh Jabbi
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 714 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 12 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Henneh","Jabbi",@android,DATE_SUB(CURDATE(), INTERVAL 12 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 12 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.981",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Veronica Sandy
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 42 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 11 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Veronica","Sandy",@android,DATE_SUB(CURDATE(), INTERVAL 11 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 11 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.939",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Rosky Gbamoh Konuwa
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 90 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 22 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Rosky Gbamoh","Konuwa",@android,DATE_SUB(CURDATE(), INTERVAL 22 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 22 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.945",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- UNKNOWN UNKNOWN
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 375 DAY),@android,DATE_SUB(CURDATE(), INTERVAL 13 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"UNKNOWN","UNKNOWN",@android,DATE_SUB(CURDATE(), INTERVAL 13 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 13 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.950",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Gladys Yema BanurA
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 162 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 13 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Gladys Yema","BanurA",@android,DATE_SUB(CURDATE(), INTERVAL 13 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 13 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.951",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Alusine Mansaray
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 246 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 9 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Alusine","Mansaray",@android,DATE_SUB(CURDATE(), INTERVAL 9 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 9 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.966",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Abdulai Sandy
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 366 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Abdulai","Sandy",@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.968",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Thomus Kaloko
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 366 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 6 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Thomus","Kaloko",@android,DATE_SUB(CURDATE(), INTERVAL 6 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 6 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.978",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- UNKNOWN UNKNOWN
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 606 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 23 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"UNKNOWN","UNKNOWN",@android,DATE_SUB(CURDATE(), INTERVAL 23 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 23 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.934",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Senesie Kanneh
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 138 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 21 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Senesie","Kanneh",@android,DATE_SUB(CURDATE(), INTERVAL 21 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 21 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.931",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Helen Tarawally
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 342 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 18 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Helen","Tarawally",@android,DATE_SUB(CURDATE(), INTERVAL 18 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 18 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.952",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Rosky zangbe
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 366 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 19 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Rosky","zangbe",@android,DATE_SUB(CURDATE(), INTERVAL 19 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 19 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.942",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Triage";
INSERT INTO encounter (encounter_type,patient_id,location_id,encounter_datetime,creator,date_created,uuid) 
  VALUES (2,@person_id,@location_id,ADDTIME(CAST(DATE_SUB(CURDATE(), INTERVAL 18 DAY) AS DATETIME), "09:00"),@android,NOW(),UUID());
SELECT @encounter_id := LAST_INSERT_ID();
SELECT @encounter_datetime := encounter_datetime FROM encounter WHERE encounter_id=@encounter_id;
SELECT @provider_id := provider_id FROM provider WHERE name="Guest User";
INSERT INTO encounter_provider (encounter_id,provider_id,encounter_role_id,creator,date_created,uuid) 
  VALUES (@encounter_id,@provider_id,3,@android,NOW(),UUID());
SELECT @concept_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Pregnant" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
SELECT @value_id := (SELECT concept.concept_id FROM concept_name  JOIN concept ON concept.concept_id=concept_name.concept_id INNER JOIN locale_order ON concept_name.locale=locale_order.locale WHERE name="Yes" AND voided=0 AND concept.retired=0 ORDER BY locale_order.id ASC, locale_preferred DESC LIMIT 1);
INSERT INTO obs (person_id,concept_id,encounter_id,obs_datetime,value_coded,creator,date_created,uuid) 
  VALUES (@person_id,@concept_id,@encounter_id,@encounter_datetime,@value_id,@android,NOW(),UUID());
--
-- Marta C Rogers
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 402 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 6 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Marta C","Rogers",@android,DATE_SUB(CURDATE(), INTERVAL 6 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 6 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.967",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Chernor Torto
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 426 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 22 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Chernor","Torto",@android,DATE_SUB(CURDATE(), INTERVAL 22 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 22 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.947",@msf_type,@root_location,@android,NOW(),UUID());
SELECT @location_id := location_id FROM location WHERE name="Confirmed 5";
INSERT INTO person_attribute (person_id,value,person_attribute_type_id,creator,date_created,uuid) VALUES (@person_id,@location_id,@assigned_location_id,@android,NOW(),UUID());
--
-- Michel Sawyer
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 486 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 19 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Michel","Sawyer",@android,DATE_SUB(CURDATE(), INTERVAL 19 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 19 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.977",@msf_type,@root_location,@android,NOW(),UUID());
--
-- Nicholas X Munda
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("M",DATE_SUB(CURDATE(), INTERVAL 606 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Nicholas X","Munda",@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 8 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.940",@msf_type,@root_location,@android,NOW(),UUID());
--
-- Sandy Komba
INSERT INTO person (gender,birthdate,creator,date_created,uuid) VALUES ("F",DATE_SUB(CURDATE(), INTERVAL 690 MONTH),@android,DATE_SUB(CURDATE(), INTERVAL 19 DAY),UUID());
SELECT @person_id := LAST_INSERT_ID();
INSERT INTO person_name (person_id,given_name,family_name,creator,date_created,uuid) VALUES (@person_id,"Sandy","Komba",@android,DATE_SUB(CURDATE(), INTERVAL 19 DAY),UUID());
INSERT INTO patient (patient_id,creator,date_created) VALUES (@person_id,@android,DATE_SUB(CURDATE(), INTERVAL 19 DAY));
INSERT INTO patient_identifier (patient_id,identifier,identifier_type,location_id,creator,date_created,uuid) VALUES (@person_id,"KH.927",@msf_type,@root_location,@android,NOW(),UUID());
