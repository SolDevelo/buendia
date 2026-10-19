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

package org.projectbuendia.openmrs.web.controller;

import org.joda.time.DateTimeZone;
import org.junit.Before;
import org.junit.Test;
import org.openmrs.Concept;
import org.openmrs.Encounter;
import org.openmrs.Obs;
import org.openmrs.projectbuendia.webservices.rest.DbUtils;
import org.openmrs.test.SkipBaseSetup;
import org.openmrs.web.test.BaseModuleWebContextSensitiveTest;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Locale;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertSame;

/**
 * Placements whose location was deleted or is missing (a placement is free text), missing times,
 * and which admission time counts.
 */
@SkipBaseSetup public class DataHelperTest extends BaseModuleWebContextSensitiveTest {
    // These should match the BASE_TEST_DATA file.
    static final String XANADU_UUID = "9356400c-a5a2-4532-8f2b-2361b3446eb8";
    static final String NEVER_NEVER_UUID = "167ce20c-4785-4285-9119-d197268f7f4a";
    static final String RETIRED_UUID = "8d6c993e-c2cc-11de-8d13-0010c6dffd0f";
    // Not a location in the BASE_TEST_DATA file.
    static final String DELETED_UUID = "13572468-1357-2468-1357-12345678abcd";

    private DataHelper helper;

    @Before public void setUp() throws Exception {
        initializeInMemoryDatabase();
        authenticate();
        executeDataSet("org/openmrs/projectbuendia/webservices/rest/base-test-data.xml");
        helper = new DataHelper(DateTimeZone.UTC, Locale.FRENCH);
    }

    @Test public void placementInDeletedLocationGetsTheDeletedLabel() {
        DataHelper.Placement p = helper.new Placement(DELETED_UUID + "/3");
        assertNull(p.getLocation());
        assertEquals("3", p.getBed());
        assertEquals("Lieu supprimé", p.getLocationName().loc(Locale.FRENCH));
        assertEquals("Deleted location", p.getLocationName().loc(Locale.ENGLISH));
    }

    @Test public void placementInRetiredLocationKeepsItsName() {
        DataHelper.Placement p = helper.new Placement(RETIRED_UUID + "/");
        assertNotNull(p.getLocation());
        assertEquals("", p.getBed());
        assertEquals("Unknown Location", p.getLocationName().loc(Locale.FRENCH));
    }

    @Test public void placementInExistingLocation() {
        DataHelper.Placement p = helper.new Placement(XANADU_UUID + "/7");
        assertEquals(XANADU_UUID, p.getLocation().getUuid());
        assertEquals("7", p.getBed());
        assertEquals("Xanadu", p.getLocationName().loc(Locale.FRENCH));
    }

    @Test public void deletedLocationsSortLast() {
        DataHelper.PatientPlacement deleted1 = helper.new PatientPlacement(null, DELETED_UUID + "/1");
        DataHelper.PatientPlacement xanadu2 = helper.new PatientPlacement(null, XANADU_UUID + "/2");
        DataHelper.PatientPlacement neverNever9 = helper.new PatientPlacement(null, NEVER_NEVER_UUID + "/9");
        DataHelper.PatientPlacement deleted0 = helper.new PatientPlacement(null, DELETED_UUID + "/0");
        List<DataHelper.PatientPlacement> list = new ArrayList<>(
            Arrays.asList(deleted1, xanadu2, neverNever9, deleted0));
        Collections.sort(list, helper.PATIENT_PLACEMENT);
        // By location name first ("Never Never Land" < "Xanadu"), then bed; deleted ones last.
        assertEquals(Arrays.asList(neverNever9, xanadu2, deleted0, deleted1), list);
    }

    @Test public void formatTimeOfNullIsDash() {
        assertEquals(DataHelper.MISSING, helper.formatTime(null));
        assertEquals(DataHelper.MISSING, helper.formatDate(null));
    }

    @Test public void nullValueTimeSortsNewest() {
        Obs missing1 = new Obs();
        Obs dated = new Obs();
        dated.setValueDatetime(new Date(0));
        Obs missing2 = new Obs();
        List<Obs> list = new ArrayList<>(Arrays.asList(missing1, dated, missing2));
        Collections.sort(list, DataHelper.OBS_VALUE_TIME);
        assertEquals(dated, list.get(0));
    }

    @Test public void emptyPlacementPrintsDash() {
        for (String text : Arrays.asList("/7", " /7")) {
            DataHelper.Placement p = helper.new Placement(text);
            assertNull(p.getLocation());
            assertEquals("7", p.getBed());
            assertEquals(DataHelper.MISSING, p.getLocationName().loc(Locale.FRENCH));
        }
    }

    @Test public void nullPlacementPrintsDash() {
        DataHelper.Placement p = helper.new Placement((String) null);
        assertNull(p.getLocation());
        assertEquals("", p.getBed());
        assertEquals(DataHelper.MISSING, p.getLocationName().loc(Locale.FRENCH));
        assertEquals("", DataHelper.getLocationUuidFromPlacement(null));
    }

    /** An obs of the given concept in the given encounter (null for none), observed at obsTime. */
    static Obs obs(String conceptUuid, Encounter encounter, long obsTime, Date value) {
        Concept concept = new Concept();
        concept.setUuid(conceptUuid);
        Obs obs = new Obs();
        obs.setConcept(concept);
        obs.setObsDatetime(new Date(obsTime));
        obs.setValueDatetime(value);
        if (encounter != null) encounter.addObs(obs);
        return obs;
    }

    static final long REGISTERED = 1760868000000L;  // 2025-10-19 10:00 UTC
    static final long ADMITTED = REGISTERED - 3 * 24 * 3600 * 1000L;
    static final long DAY = 24 * 3600 * 1000L;

    /** Registration records an admission time and a placement in one encounter. */
    static Obs registration(List<Obs> all) {
        Encounter encounter = new Encounter();
        Obs admission = obs(ConceptUuids.ADMISSION_DATETIME_UUID, encounter, REGISTERED, new Date(REGISTERED));
        all.add(admission);
        all.add(obs(DbUtils.CONCEPT_PLACEMENT_UUID, encounter, REGISTERED, null));
        return admission;
    }

    static Obs form(List<Obs> all, long obsTime, Date value) {
        Obs admission = obs(ConceptUuids.ADMISSION_DATETIME_UUID, new Encounter(), obsTime, value);
        all.add(admission);
        return admission;
    }

    @Test public void admissionFromRegistrationOnly() {
        List<Obs> all = new ArrayList<>();
        Obs registration = registration(all);
        assertSame(registration, DataHelper.chooseAdmissionObs(all));
    }

    @Test public void noAdmissionTimeChoosesNothing() {
        assertNull(DataHelper.chooseAdmissionObs(new ArrayList<Obs>()));
    }

    @Test public void admissionFormAfterRegistrationWins() {
        List<Obs> all = new ArrayList<>();
        registration(all);
        Obs form = form(all, REGISTERED + 60000, new Date(ADMITTED));
        assertSame(form, DataHelper.chooseAdmissionObs(all));
    }

    @Test public void admissionTimeWithNoEncounterCountsAsAForm() {
        List<Obs> all = new ArrayList<>();
        registration(all);
        Obs orphan = obs(ConceptUuids.ADMISSION_DATETIME_UUID, null, ADMITTED, new Date(ADMITTED));
        all.add(orphan);
        assertSame(orphan, DataHelper.chooseAdmissionObs(all));
    }

    @Test public void backdatedAdmissionFormBeatsRegistration() {
        List<Obs> all = new ArrayList<>();
        Obs form = form(all, ADMITTED, new Date(ADMITTED));
        registration(all);
        assertSame(form, DataHelper.chooseAdmissionObs(all));
    }

    @Test public void laterAdmissionFormWins() {
        List<Obs> all = new ArrayList<>();
        form(all, ADMITTED, new Date(ADMITTED));
        Obs correction = form(all, REGISTERED - 60000, new Date(ADMITTED + DAY));
        registration(all);
        assertSame(correction, DataHelper.chooseAdmissionObs(all));
    }

    @Test public void tieOnTimeGoesToTheLaterAdmissionTimeThenUuid() {
        List<Obs> all = new ArrayList<>();
        Obs late = form(all, ADMITTED, new Date(ADMITTED + DAY));
        Obs early = form(all, ADMITTED, new Date(ADMITTED));
        assertSame(late, DataHelper.chooseAdmissionObs(all));
        Collections.reverse(all);
        assertSame(late, DataHelper.chooseAdmissionObs(all));

        early.setValueDatetime(new Date(ADMITTED + DAY));
        early.setUuid("b");
        late.setUuid("a");
        assertSame(early, DataHelper.chooseAdmissionObs(all));
        Collections.reverse(all);
        assertSame(early, DataHelper.chooseAdmissionObs(all));
    }

    @Test public void admissionFormWithNoValueRanksLowest() {
        List<Obs> all = new ArrayList<>();
        form(all, ADMITTED, null).setUuid("b");
        Obs filled = form(all, ADMITTED, new Date(ADMITTED));
        filled.setUuid("a");
        assertSame(filled, DataHelper.chooseAdmissionObs(all));
    }
}
