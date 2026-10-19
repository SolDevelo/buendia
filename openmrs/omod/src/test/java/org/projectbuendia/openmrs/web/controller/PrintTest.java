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
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.openmrs.Patient;
import org.openmrs.api.APIAuthenticationException;
import org.openmrs.api.context.Context;
import org.openmrs.test.SkipBaseSetup;
import org.openmrs.web.test.BaseModuleWebContextSensitiveTest;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.ui.ModelMap;

import java.io.StringWriter;
import java.util.Locale;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

/** One patient that cannot be printed does not stop the others from printing. */
@SkipBaseSetup public class PrintTest extends BaseModuleWebContextSensitiveTest {
    // These should match the patient-test-data file.
    static final String PETER_PAN_UUID = "f6f74ed9-5681-482a-9aa5-c3192579fa59";
    static final String OTHER_UUID = "5946f880-b197-400b-9caa-a3c661d23041";
    static final String ERROR_FR = "Impossible d'imprimer le dossier de ce patient";
    static final String DELETED_FR = "Ce patient a été supprimé ; son dossier n'est pas imprimé.";

    private Locale defaultLocale;

    @Before public void setUp() throws Exception {
        defaultLocale = Locale.getDefault();  // Print sets the default locale for the request
        initializeInMemoryDatabase();
        authenticate();
        executeDataSet("org/openmrs/projectbuendia/webservices/rest/base-test-data.xml");
        executeDataSet("org/openmrs/projectbuendia/webservices/rest/patient-test-data.xml");
    }

    @After public void tearDown() {
        Locale.setDefault(defaultLocale);
    }

    private String post(String... uuids) throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/module/projectbuendia/openmrs/print");
        if (uuids.length > 0) request.addParameter("patient", uuids);
        MockHttpServletResponse response = new MockHttpServletResponse();
        new Print().post(request, response, new ModelMap());
        assertEquals(200, response.getStatus());
        return response.getContentAsString();
    }

    @Test public void failingPatientPrintsErrorAndOthersPrint() throws Exception {
        DataHelper helper = new DataHelper(DateTimeZone.UTC, Locale.FRENCH) {
            @Override public History getHistory(Patient patient) {
                if (PETER_PAN_UUID.equals(patient.getUuid())) throw new NullPointerException("test");
                return super.getHistory(patient);
            }
        };
        StringWriter out = new StringWriter();
        PatientPrinter printer = new PatientPrinter(out, Locale.FRENCH, helper);
        Print print = new Print();
        print.printPatient(OTHER_UUID, helper, printer, out);
        print.printPatient(PETER_PAN_UUID, helper, printer, out);
        print.printPatient(OTHER_UUID, helper, printer, out);
        String page = out.toString();
        assertTrue(page, page.contains(ERROR_FR));
        assertTrue(page, page.contains("ABC123"));  // Peter Pan's ID in the error block
        assertEquals(page, 2, page.split("class='history'", -1).length - 1);
    }

    @Test(expected = APIAuthenticationException.class)
    public void expiredSessionIsNotContained() throws Exception {
        DataHelper helper = new DataHelper(DateTimeZone.UTC, Locale.FRENCH) {
            @Override public History getHistory(Patient patient) {
                throw new APIAuthenticationException("test");
            }
        };
        StringWriter out = new StringWriter();
        new Print().printPatient(PETER_PAN_UUID, helper, new PatientPrinter(out, Locale.FRENCH, helper), out);
    }

    @Test public void duplicateUuidPrintsOnce() throws Exception {
        String page = post(OTHER_UUID, OTHER_UUID);
        assertEquals(page, 1, page.split("class='history'", -1).length - 1);
    }

    @Test public void deletedPatientPrintsDeletedLine() throws Exception {
        Patient patient = Context.getPatientService().getPatientByUuid(OTHER_UUID);
        Context.getPatientService().voidPatient(patient, "test");
        String page = post(OTHER_UUID, PETER_PAN_UUID);
        assertTrue(page, page.contains(DELETED_FR));
        assertEquals(page, 1, page.split("class='history'", -1).length - 1);
    }

    @Test public void unknownUuidPrintsDeletedLine() throws Exception {
        String page = post("13572468-1357-2468-1357-12345678abcd");
        assertTrue(page, page.contains(DELETED_FR));
        assertFalse(page, page.contains("class='history'"));
    }

    @Test public void noPatientSelectedPrintsEmptyPage() throws Exception {
        String page = post();
        assertTrue(page, page.contains("window.onload = print;"));
        assertFalse(page, page.contains("class='history'"));
    }
}
