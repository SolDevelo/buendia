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

package org.projectbuendia.openmrs.webservices.rest;

import org.junit.Test;
import org.openmrs.api.APIException;
import org.openmrs.module.webservices.rest.SimpleObject;
import org.openmrs.web.test.BaseModuleWebContextSensitiveTest;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.util.List;
import java.util.Map;

import static org.junit.Assert.assertEquals;

/** The error handler must report the error, not fail on it. */
public class RestControllerTest extends BaseModuleWebContextSensitiveTest {
    private SimpleObject handle(Exception e, MockHttpServletResponse response) throws Exception {
        return new RestController().handleException(e, new MockHttpServletRequest(), response);
    }

    /** The JVM drops the stack trace of an exception thrown repeatedly from the same place. */
    @Test public void exceptionWithoutStackTraceIsReported() throws Exception {
        NullPointerException npe = new NullPointerException();
        npe.setStackTrace(new StackTraceElement[0]);
        MockHttpServletResponse response = new MockHttpServletResponse();

        SimpleObject json = handle(npe, response);

        assertEquals(500, response.getStatus());
        List<Map> errors = (List<Map>) json.get("errors");
        assertEquals(NullPointerException.class.getName(), errors.get(0).get("type"));
        assertEquals(0, ((List) errors.get(0).get("frames")).size());
    }

    @Test public void apiExceptionWithoutMessageIsReported() throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();

        SimpleObject json = handle(new APIException((String) null), response);

        assertEquals(500, response.getStatus());
        assertEquals(1, ((List) json.get("errors")).size());
    }
}
