// Copyright 2026 The Project Buendia Authors
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License.  You may obtain a copy
// of the License at: http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distrib-
// uted under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
// OR CONDITIONS OF ANY KIND, either express or implied.  See the License for
// specific language governing permissions and limitations under the License.

package org.openmrs.projectbuendia.webservices.rest;

import org.junit.Before;
import org.junit.Test;
import org.openmrs.Encounter;
import org.openmrs.EncounterProvider;
import org.openmrs.Obs;
import org.openmrs.api.context.Context;
import org.openmrs.module.webservices.rest.SimpleObject;
import org.openmrs.test.SkipBaseSetup;
import org.openmrs.web.test.BaseModuleWebContextSensitiveTest;

import java.util.Collections;
import java.util.Date;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;

/** Serialising observations for the observation sync. */
@SkipBaseSetup public class ObsUtilsTest extends BaseModuleWebContextSensitiveTest {
    // These should match the BASE_TEST_DATA file.
    static final String TEXT_CONCEPT_UUID = "96408258-000b-424e-af1a-403919332938";
    static final String PERSON_UUID = "ca6008b4-29fb-4eea-bd5e-116a04cc6c8d";
    static final String PROVIDER_UUID = "0a828bd6-d63c-4acc-b987-2400f2ab8c4c";

    @Before public void setUp() throws Exception {
        initializeInMemoryDatabase();
        authenticate();
        executeDataSet("org/openmrs/projectbuendia/webservices/rest/base-test-data.xml");
    }

    private Obs newTextObs() {
        Obs obs = new Obs();
        obs.setUuid("obs-without-encounter");
        obs.setPerson(Context.getPersonService().getPersonByUuid(PERSON_UUID));
        obs.setConcept(Context.getConceptService().getConceptByUuid(TEXT_CONCEPT_UUID));
        obs.setObsDatetime(new Date(0));
        obs.setValueText("Other non-coded");
        return obs;
    }

    /** LIME2-1366: an obs with no encounter failed the whole sync page with HTTP 500. */
    @Test public void obsWithoutEncounterSerialisesWithoutEncounterOrProvider() {
        SimpleObject json = ObsUtils.putObsAsJson(new SimpleObject(), newTextObs());

        assertEquals("obs-without-encounter", json.get("uuid"));
        assertEquals(PERSON_UUID, json.get("patient_uuid"));
        assertEquals(TEXT_CONCEPT_UUID, json.get("concept_uuid"));
        assertEquals("Other non-coded", json.get("value_text"));
        assertFalse(json.containsKey("encounter_uuid"));
        assertFalse(json.containsKey("provider_uuid"));
    }

    @Test public void obsInEncounterCarriesEncounterAndProvider() {
        EncounterProvider ep = new EncounterProvider();
        ep.setProvider(Context.getProviderService().getProviderByUuid(PROVIDER_UUID));
        Encounter encounter = new Encounter();
        encounter.setUuid("encounter-with-provider");
        encounter.setEncounterProviders(Collections.singleton(ep));
        Obs obs = newTextObs();
        obs.setEncounter(encounter);

        SimpleObject json = ObsUtils.putObsAsJson(new SimpleObject(), obs);

        assertEquals("encounter-with-provider", json.get("encounter_uuid"));
        assertEquals(PROVIDER_UUID, json.get("provider_uuid"));
    }
}
