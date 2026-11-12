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
import org.openmrs.Field;
import org.openmrs.Form;
import org.openmrs.FormField;
import org.openmrs.api.context.Context;
import org.openmrs.module.webservices.rest.SimpleObject;
import org.openmrs.module.webservices.rest.web.RequestContext;
import org.openmrs.module.webservices.rest.web.representation.Representation;
import org.openmrs.test.SkipBaseSetup;
import org.openmrs.web.test.BaseModuleWebContextSensitiveTest;

import java.util.HashSet;
import java.util.List;
import java.util.Map;

import static org.junit.Assert.assertEquals;

/** A chart form edited outside Buendia must not fail the chart sync. */
@SkipBaseSetup public class ChartResourceTest extends BaseModuleWebContextSensitiveTest {
    // This should match the BASE_TEST_DATA file.
    static final String TEXT_CONCEPT_UUID = "96408258-000b-424e-af1a-403919332938";

    private ChartResource resource;
    private RequestContext full;

    @Before public void setUp() throws Exception {
        initializeInMemoryDatabase();
        authenticate();
        executeDataSet("org/openmrs/projectbuendia/webservices/rest/base-test-data.xml");
        resource = new ChartResource();
        full = new RequestContext();
        full.setRepresentation(Representation.FULL);
    }

    private static FormField formField(int id, FormField parent, String name, float weight) {
        Field field = new Field();
        field.setName(name);  // no description, as the legacy form designer allows
        FormField formField = new FormField();
        formField.setFormFieldId(id);
        formField.setParent(parent);
        formField.setField(field);
        formField.setSortWeight(weight);
        return formField;
    }

    @Test public void emptyFormHasNoSections() {
        Form form = new Form();
        form.setVersion("1");
        form.setFormFields(new HashSet<FormField>());  // as Hibernate loads a form with no fields

        SimpleObject json = new SimpleObject();
        resource.populateJson(json, form, full);

        assertEquals(0, ((List) json.get("sections")).size());
    }

    @Test public void sectionsWithoutRowsAndRowsWithoutConceptsAreTolerated() {
        Form form = new Form();
        form.setVersion("1");
        FormField vitals = formField(1, null, "Vitals", 1);
        FormField temperature = formField(2, vitals, "Temperature", 1);
        temperature.getField().setConcept(
            Context.getConceptService().getConceptByUuid(TEXT_CONCEPT_UUID));
        FormField noConcept = formField(3, vitals, "Heading only", 2);
        FormField emptySection = formField(4, null, "Empty", 2);
        form.addFormField(vitals);
        form.addFormField(temperature);
        form.addFormField(noConcept);
        form.addFormField(emptySection);

        SimpleObject json = new SimpleObject();
        resource.populateJson(json, form, full);

        List<Map> sections = (List<Map>) json.get("sections");
        assertEquals(2, sections.size());
        assertEquals("Vitals", sections.get(0).get("label"));
        List<Map> vitalsItems = (List<Map>) sections.get(0).get("items");
        assertEquals(1, vitalsItems.size());
        assertEquals("Temperature", vitalsItems.get(0).get("label"));
        assertEquals("Empty", sections.get(1).get("label"));
        assertEquals(0, ((List) sections.get(1).get("items")).size());
    }
}
