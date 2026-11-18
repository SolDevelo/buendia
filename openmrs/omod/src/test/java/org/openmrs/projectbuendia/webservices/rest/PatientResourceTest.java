/*
 * Copyright 2016 The Project Buendia Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not
 * use this file except in compliance with the License.  You may obtain a copy
 * of the License at: http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distrib-
 * uted under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
 * OR CONDITIONS OF ANY KIND, either express or implied.  See the License for
 * specific language governing permissions and limitations under the License.
 */

package org.openmrs.projectbuendia.webservices.rest;

import org.junit.Assert;
import org.junit.Test;
import org.openmrs.Location;
import org.openmrs.Patient;
import org.openmrs.PatientIdentifierType;
import org.openmrs.api.context.Context;
import org.openmrs.module.webservices.rest.SimpleObject;
import org.openmrs.test.SkipBaseSetup;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.bind.annotation.RequestMethod;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

/** REST API tests for PatientResource. */
@SkipBaseSetup
public class PatientResourceTest extends BaseApiRequestTest {
    // These constants should match the values in the data files.
    String PETER_PAN_UUID = "f6f74ed9-5681-482a-9aa5-c3192579fa59";
    String XANADU_UUID = "9356400c-a5a2-4532-8f2b-2361b3446eb8";
    String NUMERIC_CONCEPT_UUID = "c607c80f-1ea9-4da3-bb88-6276ce8868dd";
    String CODED_CONCEPT_UUID = "95312123-e0c2-466d-b6b1-cb6e990d0d65";
    String UNKNOWN_UUID = "lime2-1379-unknown";

    public String[] getInitialDataFiles() {
        return new String[] {
            "org/openmrs/projectbuendia/webservices/rest/base-test-data.xml",
            "org/openmrs/projectbuendia/webservices/rest/patient-test-data.xml"
        };
    };

    public String getURI() {
        return "/patients";
    }

    public long getAllCount() {
        return 2;  // number of patients in the test data file
    }

    public String getUuid() {
        return PETER_PAN_UUID;
    }

    @Test public void testGetPatient() throws Exception {
        MockHttpServletRequest request = this.request(RequestMethod.GET, this.getURI() + "/" + PETER_PAN_UUID);
        SimpleObject response = this.deserialize(this.handle(request));
        Assert.assertNotNull(response);

        assertEquals(PETER_PAN_UUID, response.get("uuid"));
        assertEquals("Peter", response.get("given_name"));
        assertEquals("Pan", response.get("family_name"));
        assertEquals("M", response.get("sex"));
        assertEquals("ABC123", response.get("id"));
    }

    @Test public void testCreatePatient() throws Exception {
        SimpleObject input = new SimpleObject();
        input.add("id", "XYZ");
        input.add("given_name", "Mary");
        input.add("family_name", "Poppins");
        input.add("sex", "F");
        input.add("birthdate", "1970-01-01");

        MockHttpServletRequest request = newPostRequest(getURI(), input);
        SimpleObject response = deserialize(handle(request));

        String uuid = (String) response.get("uuid");
        assertEquals("XYZ", response.get("id"));
        assertEquals("Mary", response.get("given_name"));
        assertEquals("Poppins", response.get("family_name"));
        assertEquals("F", response.get("sex"));
        assertEquals("1970-01-01", response.get("birthdate"));

        Patient patient = patientService.getPatientByUuid(uuid);
        assertEquals("XYZ", patient.getPatientIdentifier(DbUtils.getMsfIdType()).getIdentifier());
    }

    @Test public void testCreatePatientWithObservation() throws Exception {
        SimpleObject input = new SimpleObject();
        input.add("id", "XYZ");
        input.add("given_name", "Mary");
        input.add("family_name", "Poppins");
        input.add("sex", "F");
        input.add("birthdate", "1970-01-01");

        List<Map> observations = new ArrayList<>();
        SimpleObject obs = new SimpleObject();
        obs.add("provider_uuid", "0a828bd6-d63c-4acc-b987-2400f2ab8c4c");
        obs.add("concept_uuid", "96408258-000b-424e-af1a-403919332938");
        obs.add("value_text", "abc");
        observations.add(obs);
        input.add("observations", observations);

        MockHttpServletRequest request = newPostRequest(getURI(), input);
        SimpleObject response = deserialize(handle(request));

        String uuid = (String) response.get("uuid");
        assertEquals("XYZ", response.get("id"));
        assertEquals("Mary", response.get("given_name"));
        assertEquals("Poppins", response.get("family_name"));
        assertEquals("F", response.get("sex"));
        assertEquals("1970-01-01", response.get("birthdate"));

        List<Map> respList = (List<Map>) response.get("observations");
        assertEquals(1, respList.size());
        Map respObs = respList.get(0);
        assertEquals("0a828bd6-d63c-4acc-b987-2400f2ab8c4c", respObs.get("provider_uuid"));
        assertEquals("96408258-000b-424e-af1a-403919332938", respObs.get("concept_uuid"));
        assertEquals("abc", respObs.get("value_text"));
    }

    // LIME2-1379: a rejected observation answers 400 and writes nothing.

    private SimpleObject obs(String conceptUuid, String key, Object value) {
        SimpleObject obs = new SimpleObject();
        obs.add("concept_uuid", conceptUuid);
        if (key != null) obs.add(key, value);
        return obs;
    }

    private SimpleObject encounterJson(SimpleObject... observations) {
        SimpleObject input = new SimpleObject();
        input.add("patient_uuid", PETER_PAN_UUID);
        List<Map> list = new ArrayList<>();
        for (SimpleObject o : observations) list.add(o);
        input.add("observations", list);
        return input;
    }

    /** Posts the input, expects a 400 (InvalidObjectDataException) and returns its message. */
    private String rejection(String uri, SimpleObject input) throws Exception {
        try {
            handle(newPostRequest(uri, input));
        } catch (InvalidObjectDataException e) {
            assertTrue(e.getMessage(), e.getMessage().contains("failed to validate with reason: "));
            return e.getMessage();
        }
        fail("expected InvalidObjectDataException");
        return null;
    }

    private int encounterCount() {
        Patient patient = patientService.getPatientByUuid(PETER_PAN_UUID);
        return encounterService.getEncountersByPatient(patient).size();
    }

    private int obsCount() {
        Patient patient = patientService.getPatientByUuid(PETER_PAN_UUID);
        return Context.getObsService().getObservationsByPerson(patient).size();
    }

    private void assertRejectedAndNothingSaved(SimpleObject input, String expectedText) throws Exception {
        int encounters = encounterCount();
        int observations = obsCount();
        String message = rejection("/encounters", input);
        assertTrue(message, message.contains(expectedText));
        assertEquals(encounters, encounterCount());
        assertEquals(observations, obsCount());
    }

    @Test public void unknownConceptRejectedAndNothingSaved() throws Exception {
        assertRejectedAndNothingSaved(
            encounterJson(obs(UNKNOWN_UUID, "value_numeric", 37)),
            "concept_uuid: unknown concept " + UNKNOWN_UUID);
    }

    @Test public void oneBadObsRejectsWholeEncounter() throws Exception {
        assertRejectedAndNothingSaved(
            encounterJson(obs(NUMERIC_CONCEPT_UUID, "value_numeric", 37),
                obs(UNKNOWN_UUID, "value_numeric", 1)),
            "unknown concept " + UNKNOWN_UUID);
    }

    @Test public void unknownCodedValueRejected() throws Exception {
        assertRejectedAndNothingSaved(
            encounterJson(obs(CODED_CONCEPT_UUID, "value_coded", UNKNOWN_UUID)),
            "value_coded: unknown concept " + UNKNOWN_UUID);
    }

    @Test public void wrongValueTypeRejected() throws Exception {
        assertRejectedAndNothingSaved(
            encounterJson(obs(CODED_CONCEPT_UUID, "value_numeric", 1)), "valueCoded: ");
    }

    @Test public void missingValueRejected() throws Exception {
        int encounters = encounterCount();
        String message = rejection("/encounters", encounterJson(obs(NUMERIC_CONCEPT_UUID, null, null)));
        // A global error is written without a field, as core's ValidateUtil does.
        // (Tests load no message properties, so the codes are not resolved here.)
        assertTrue(message, message.contains("reason: error.noValue"));
        assertFalse(message, message.contains("null:"));
        assertEquals(encounters, encounterCount());
    }

    @Test public void testCreatePatientWithUnknownConceptCreatesNothing() throws Exception {
        int patients = patientService.getAllPatients(true).size();
        SimpleObject input = new SimpleObject();
        input.add("given_name", "Mary");
        input.add("family_name", "Poppins");
        input.add("sex", "F");
        List<Map> observations = new ArrayList<>();
        observations.add(obs(UNKNOWN_UUID, "value_text", "abc"));
        input.add("observations", observations);
        String message = rejection(getURI(), input);
        assertTrue(message, message.contains("unknown concept " + UNKNOWN_UUID));
        assertEquals(patients, patientService.getAllPatients(true).size());
    }

    @Test public void testCreatePatientWithBadObsValueCreatesNothing() throws Exception {
        int patients = patientService.getAllPatients(true).size();
        SimpleObject input = new SimpleObject();
        input.add("given_name", "Mary");
        input.add("family_name", "Poppins");
        input.add("sex", "F");
        List<Map> observations = new ArrayList<>();
        observations.add(obs(CODED_CONCEPT_UUID, "value_numeric", 1));
        input.add("observations", observations);
        String message = rejection(getURI(), input);
        assertFalse(message, message.contains("person"));
        assertEquals(patients, patientService.getAllPatients(true).size());
    }

    @Test public void testGetUnknownFormIsNotFound() throws Exception {
        try {
            handle(newGetRequest("/xforms/" + UNKNOWN_UUID));
            fail("expected ItemNotFoundException");
        } catch (ItemNotFoundException expected) {
        }
    }

    @Test public void testCreatePatientWhenRootRetired() throws Exception {
        // retireLocation also retires Never Never Land here (core cascades the retire to
        // the loaded child collection), so every location is retired: Xanadu, the root
        // with children, must win over the fixture's lone retired "Unknown Location".
        locationService.retireLocation(locationService.getLocationByUuid(XANADU_UUID), "LIME2-1379 test");
        assertTrue(locationService.getAllLocations(false).isEmpty());
        SimpleObject input = new SimpleObject();
        input.add("given_name", "Mary");
        input.add("family_name", "Poppins");
        input.add("sex", "F");
        SimpleObject response = deserialize(handle(newPostRequest(getURI(), input)));
        Patient patient = patientService.getPatientByUuid((String) response.get("uuid"));
        assertEquals(XANADU_UUID, patient.getPatientIdentifier().getLocation().getUuid());
    }
}
