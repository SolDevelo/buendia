package org.projectbuendia.openmrs.web.controller;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.joda.time.DateTimeZone;
import org.openmrs.Patient;
import org.openmrs.api.APIAuthenticationException;
import org.openmrs.api.context.Context;
import org.openmrs.projectbuendia.Utils;
import org.springframework.stereotype.Controller;
import org.springframework.ui.ModelMap;
import org.springframework.web.bind.annotation.RequestMapping;

import java.io.IOException;
import java.io.StringWriter;
import java.io.Writer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import static org.springframework.web.bind.annotation.RequestMethod.GET;
import static org.springframework.web.bind.annotation.RequestMethod.POST;

@Controller public class Print {
    private static final Log log = LogFactory.getLog(Print.class);
    public static final String GLOBAL_PROPERTY_TIMEZONE = "projectbuendia.timezone";
    private static final DateTimeZone DEFAULT_ZONE = DateTimeZone.forID("Africa/Kinshasa"); // UTC+1, western DRC
    private static final Locale DEFAULT_LOCALE = new Locale("fr");

    /** The zone from the request's "tz" parameter, else the global property, else the default. */
    private DateTimeZone getZone(HttpServletRequest request) {
        String tz = request.getParameter("tz");
        if (tz != null) {
            try {
                return DateTimeZone.forID(tz);
            } catch (IllegalArgumentException e) { }
        }
        String property = Context.getAdministrationService().getGlobalProperty(GLOBAL_PROPERTY_TIMEZONE);
        if (Utils.hasChars(property)) {
            try {
                return DateTimeZone.forID(property.trim());
            } catch (IllegalArgumentException e) {
                log.warn("Global property " + GLOBAL_PROPERTY_TIMEZONE + " is not a time zone: \""
                    + property + "\"; printing in " + DEFAULT_ZONE.getID());
            }
        }
        return DEFAULT_ZONE;
    }

    private DataHelper getDataHelper(HttpServletRequest request) {
        DateTimeZone zone = getZone(request);

        Locale locale = DEFAULT_LOCALE;
        String tag = request.getParameter("lang");
        if (tag != null) {
            try {
                locale = Locale.forLanguageTag(tag);
            } catch (NullPointerException | IllegalArgumentException e) { }
        }
        Locale.setDefault(locale);
        return new DataHelper(zone, locale);
    }

    @RequestMapping(method = GET, value = "/module/projectbuendia/openmrs/print")
    public void get(HttpServletRequest request, ModelMap model) {
        DataHelper helper = getDataHelper(request);
        List<DataHelper.PatientPlacement> placements = helper.getPresentPatients();
        List<DataHelper.ObsDisplay> admissions = helper.getAdmissionTimes();

        List<DataHelper.ObsDisplay> recentAdmissions = new ArrayList<>(admissions);
        Collections.reverse(recentAdmissions);
        recentAdmissions = Utils.slice(recentAdmissions, 0, 6);

        List<DataHelper.ObsDisplay> discharges = helper.getDischargeTimes();
        List<DataHelper.ObsDisplay> recentDischarges = new ArrayList<>(discharges);
        Collections.reverse(recentDischarges);
        recentDischarges = Utils.slice(recentDischarges, 0, 6);

        model.addAttribute("showAll", request.getParameter("all") != null);
        model.addAttribute("allAdmissions", admissions);
        model.addAttribute("inpatients", placements);
        model.addAttribute("admissions", recentAdmissions);
        model.addAttribute("discharges", recentDischarges);
    }

    @RequestMapping(method = POST, value = "/module/projectbuendia/openmrs/print")
    public void post(HttpServletRequest request, HttpServletResponse response, ModelMap model)
        throws IOException {
        DataHelper helper = getDataHelper(request);
        response.setContentType("text/html; charset=utf-8");
        Writer out = response.getWriter();
        PatientPrinter printer = new PatientPrinter(out, helper.getLocale(), helper);
        printer.printPrologue();
        String[] uuids = request.getParameterValues("patient");
        if (uuids != null) {
            for (String uuid : new LinkedHashSet<>(Arrays.asList(uuids))) {
                printPatient(uuid, helper, printer, out);
            }
        }
        printer.printEpilogue();
    }

    /** Prints one patient's history; one that cannot be printed gets a notice, and the page goes on. */
    void printPatient(String uuid, DataHelper helper, PatientPrinter printer, Writer out)
        throws IOException {
        String ident = "";
        String name = "";
        try {
            Patient patient = helper.getPatient(uuid);
            if (patient == null || Boolean.TRUE.equals(patient.isVoided())
                || Boolean.TRUE.equals(patient.isPersonVoided())) {
                printer.printDeleted();
                return;
            }
            // Read first: after a failure inside a service call the patient may no longer load.
            ident = printer.getIdentifier(patient);
            name = printer.getName(patient);
            // Rendered apart, so a failure part-way leaves nothing of this patient on the page.
            StringWriter buffer = new StringWriter();
            new PatientPrinter(buffer, helper.getLocale(), helper).printHistory(patient);
            out.write(buffer.toString());
        } catch (APIAuthenticationException e) {
            throw e;  // an expired session still goes to the login page
        } catch (RuntimeException e) {
            log.error("Print Patient Files: could not print patient " + uuid, e);
            printer.printError(ident, name);
        }
    }
}
