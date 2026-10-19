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
import org.openmrs.test.SkipBaseSetup;
import org.openmrs.web.test.BaseModuleWebContextSensitiveTest;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;

/** Placements whose location was deleted in OpenMRS (a placement is free text). */
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
}
