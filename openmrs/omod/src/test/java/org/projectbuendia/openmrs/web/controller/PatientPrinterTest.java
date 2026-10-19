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
import org.openmrs.Obs;
import org.openmrs.Order;
import org.openmrs.Patient;
import org.openmrs.PersonName;
import org.openmrs.Provider;
import org.openmrs.api.context.Context;
import org.openmrs.projectbuendia.webservices.rest.DbUtils;
import org.openmrs.test.SkipBaseSetup;
import org.openmrs.web.test.BaseModuleWebContextSensitiveTest;
import org.projectbuendia.openmrs.web.controller.HtmlOutput.Doc;

import java.io.IOException;
import java.io.StringWriter;
import java.util.Date;
import java.util.Locale;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.projectbuendia.openmrs.web.controller.DataHelper.MISSING;

/** Values missing from the database print as a dash instead of failing or printing "now". */
@SkipBaseSetup public class PatientPrinterTest extends BaseModuleWebContextSensitiveTest {
    static final String RS = "\u001e";
    static final String US = "\u001f";

    private PatientPrinter printer;

    @Before public void setUp() throws Exception {
        initializeInMemoryDatabase();
        authenticate();
        executeDataSet("org/openmrs/projectbuendia/webservices/rest/base-test-data.xml");
        DataHelper helper = new DataHelper(DateTimeZone.UTC, Locale.FRENCH);
        printer = new PatientPrinter(new StringWriter(), Locale.FRENCH, helper);
    }

    /** The text of a rendered Doc, tags removed and spaces collapsed. */
    private static String render(Doc doc) throws IOException {
        StringWriter writer = new StringWriter();
        doc.writeTo(writer, Locale.FRENCH);
        return writer.toString().replaceAll("<[^>]*>", " ").replaceAll("\\s+", " ").trim();
    }

    /** An obs with no value, of a concept with the given datatype. */
    private static Obs emptyObs(int datatypeId) {
        Concept concept = new Concept();
        concept.setDatatype(Context.getConceptService().getConceptDatatype(datatypeId));
        Obs obs = new Obs();
        obs.setConcept(concept);
        return obs;
    }

    @Test public void textObsWithNoValuePrintsDash() throws Exception {
        assertEquals(MISSING, render(printer.renderValue(emptyObs(3))));
    }

    @Test public void numericObsWithNoValuePrintsDash() throws Exception {
        assertEquals(MISSING, render(printer.renderValue(emptyObs(1))));
    }

    @Test public void dateObsWithNoValuePrintsDash() throws Exception {
        assertEquals(MISSING, render(printer.renderValue(emptyObs(6))));
        assertEquals(MISSING, render(printer.renderValue(emptyObs(8))));
    }

    @Test public void booleanObsWithNoValuePrintsDash() throws Exception {
        assertEquals(MISSING, render(printer.renderValue(emptyObs(10))));
    }

    @Test public void codedObsWithNoValuePrintsDash() throws Exception {
        assertEquals(MISSING, render(printer.renderValue(emptyObs(2))));
    }

    @Test public void doseWithNoOrderPrintsDash() throws Exception {
        Concept executed = new Concept();
        executed.setUuid(DbUtils.CONCEPT_ORDER_EXECUTED_UUID);
        Obs dose = new Obs();
        dose.setConcept(executed);
        assertEquals(MISSING, render(printer.renderObsContent(dose)));
    }

    private static Order order(String instructions, Date start, Date stop) {
        Order order = new Order();
        order.setInstructions(instructions);
        order.setScheduledDate(start);
        order.setAutoExpireDate(stop);
        order.setDateCreated(new Date(0));
        return order;
    }

    @Test public void orderWithNoInstructionsPrintsDash() throws Exception {
        Order order = order(null, new Date(0), new Date(86400000L));
        assertTrue(render(printer.renderOrderTreatment(order)).startsWith(MISSING));
        String schedule = render(printer.renderOrderSchedule(order));
        assertTrue(schedule, schedule.contains("commencer") && schedule.contains("arrêter"));
        assertFalse(schedule, schedule.contains("dose unique"));
    }

    @Test public void continuousOrderWithNoAmount() throws Exception {
        Order order = order("DINFSODC9FBF1" + US + "IV" + RS + "0" + US + "ML" + US + "8" + US + "HOUR"
            + RS + US + RS, new Date(0), null);
        String treatment = render(printer.renderOrderTreatment(order));
        assertTrue(treatment, treatment.contains(MISSING + " dans 8"));
    }

    @Test public void seriesOrderWithNoStart() throws Exception {
        Order order = order("DORAPARA5T" + US + "PO" + RS + "2" + US + "TABLET" + US + RS + "3" + US + "PER_DAY"
            + RS, null, new Date(86400000L));
        String schedule = render(printer.renderOrderSchedule(order));
        assertTrue(schedule, schedule.contains("commencer " + MISSING));
        assertFalse(schedule, schedule.contains("doses"));
    }

    @Test public void providerWithNoNamePrintsUnknown() throws Exception {
        assertEquals("inconnu", render(printer.renderProvider(new Provider())));
    }

    @Test public void patientWithNoLiveNamePrintsIntro() throws Exception {
        Patient pat = new Patient();
        PersonName name = new PersonName("Peter", null, "Pan");
        name.setVoided(true);
        pat.addName(name);
        String intro = render(printer.renderIntro(pat));
        assertFalse(intro, intro.contains("Pan"));
        assertFalse(intro, intro.contains("null"));
    }
}
