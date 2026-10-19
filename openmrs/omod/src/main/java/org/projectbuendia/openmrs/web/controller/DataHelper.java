package org.projectbuendia.openmrs.web.controller;

import org.joda.time.DateTime;
import org.joda.time.DateTimeZone;
import org.joda.time.Duration;
import org.joda.time.Instant;
import org.joda.time.format.DateTimeFormat;
import org.joda.time.format.DateTimeFormatter;
import org.openmrs.BaseOpenmrsData;
import org.openmrs.BaseOpenmrsMetadata;
import org.openmrs.BaseOpenmrsObject;
import org.openmrs.Concept;
import org.openmrs.Encounter;
import org.openmrs.EncounterProvider;
import org.openmrs.Form;
import org.openmrs.FormField;
import org.openmrs.Location;
import org.openmrs.Obs;
import org.openmrs.Order;
import org.openmrs.Patient;
import org.openmrs.PatientIdentifier;
import org.openmrs.Person;
import org.openmrs.Provider;
import org.openmrs.api.ConceptService;
import org.openmrs.api.EncounterService;
import org.openmrs.api.FormService;
import org.openmrs.api.LocationService;
import org.openmrs.api.ObsService;
import org.openmrs.api.OrderService;
import org.openmrs.api.PatientService;
import org.openmrs.api.ProviderService;
import org.openmrs.api.context.Context;
import org.projectbuendia.models.Intl;
import org.openmrs.projectbuendia.Utils;
import org.openmrs.projectbuendia.webservices.rest.DbUtils;
import org.projectbuendia.openmrs.api.ProjectBuendiaService;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import static org.openmrs.projectbuendia.Utils.eq;
import static org.openmrs.projectbuendia.Utils.toUuid;
import static org.openmrs.projectbuendia.webservices.rest.DbUtils.getConceptUuid;
import static org.openmrs.projectbuendia.webservices.rest.DbUtils.isYes;

public class DataHelper {
    protected final ProjectBuendiaService buendiaService;
    protected final ConceptService conceptService;
    protected final EncounterService encounterService;
    protected final FormService formService;
    protected final LocationService locationService;
    protected final ObsService obsService;
    protected final OrderService orderService;
    protected final PatientService patientService;
    protected final ProviderService providerService;

    private static final List<String> DISCHARGED_LOCATION_UUIDS = Arrays.asList(
        "73010980-d3e7-404a-95bf-180966f04fb8",  // historical Buendia sites
        "b990663d-b80b-41ba-9b55-de172a5db780"   // "[5] Discharged" in deploy/seed/initdb/20-buendia-site.sql
    );
    private static final String ADMISSION_DATETIME_UUID = Utils.toUuid(8001640);
    private static final String DISCHARGE_DATETIME_UUID = toUuid(8001641);
    private static final String PREGNANCY_UUID = Utils.toUuid(2005272);

    /** Printed in place of a value that was recorded but is missing from the database. */
    public static final String MISSING = "\u2014";

    private static final Intl TIME_PATTERN = new Intl("MMM d, HH:mm [fr:d MMM, HH'h'mm]");
    private static final Intl DATE_PATTERN = new Intl("MMM d [fr:d MMM]");

    private DateTimeZone zone;
    private Locale locale;
    private DateTimeFormatter timeFormatter;
    private DateTimeFormatter dateFormatter;

    private static final Comparator<Encounter> ENCOUNTER_TIME = new Comparator<Encounter>() {
        @Override public int compare(Encounter e1, Encounter e2) {
            DateTime dt1 = toDateTime(e1.getEncounterDatetime());
            DateTime dt2 = toDateTime(e2.getEncounterDatetime());
            return dt1.compareTo(dt2);
        }
    };

    private final Comparator<Obs> OBS_TIME = new Comparator<Obs>() {
        @Override public int compare(Obs o1, Obs o2) {
            DateTime dt1 = toDateTime(o1.getObsDatetime());
            DateTime dt2 = toDateTime(o2.getObsDatetime());
            return dt1.compareTo(dt2);
        }
    };

    static final Comparator<Obs> OBS_VALUE_TIME = new Comparator<Obs>() {
        @Override public int compare(Obs o1, Obs o2) {
            DateTime dt1 = toDateTime(o1.getValueDatetime());
            DateTime dt2 = toDateTime(o2.getValueDatetime());
            // A missing time sorts as the newest, so the patient stays in the recent lists.
            if (dt1 == null || dt2 == null) return dt1 == dt2 ? 0 : dt1 == null ? 1 : -1;
            return dt1.compareTo(dt2);
        }
    };

    final Comparator<PatientPlacement> PATIENT_PLACEMENT = new Comparator<PatientPlacement>() {
        @Override public int compare(PatientPlacement p1, PatientPlacement p2) {
            Location l1 = p1.placement.location;
            Location l2 = p2.placement.location;
            // Patients whose location was deleted go last.
            if ((l1 == null) != (l2 == null)) return l1 == null ? 1 : -1;
            if (l1 != null) {
                int c = Utils.ALPHANUMERIC_COMPARATOR.compare(l1.getName(), l2.getName());
                if (c != 0) return c;
            }
            return Utils.ALPHANUMERIC_COMPARATOR.compare(p1.placement.bed, p2.placement.bed);
        }
    };

    private final Comparator<Form> FORM_TITLE = new Comparator<Form>() {
        @Override public int compare(Form f1, Form f2) {
            return Utils.ALPHANUMERIC_COMPARATOR.compare(f1.getName(), f2.getName());
        }
    };

    private final Comparator<FormField> SORT_WEIGHT_FIELD_NUMBER = new Comparator<FormField>() {
        @Override public int compare(FormField f1, FormField f2) {
            float w1 = f1.getSortWeight();
            float w2 = f2.getSortWeight();
            if (w1 != w2) return Float.compare(w1, w2);
            return Integer.compare(f1.getFieldNumber(), f2.getFieldNumber());
        }
    };
    
    private static final Comparator<Event> EVENT_TIME = new Comparator<Event>() {
        @Override public int compare(Event e1, Event e2) {
            return e1.time.compareTo(e2.time);
        }
    };

    public DataHelper(DateTimeZone zone, Locale locale) {
        this.zone = zone;
        this.locale = locale;
        timeFormatter = DateTimeFormat.forPattern(TIME_PATTERN.loc(locale));
        dateFormatter = DateTimeFormat.forPattern(DATE_PATTERN.loc(locale));

        buendiaService = Context.getService(ProjectBuendiaService.class);
        conceptService = Context.getConceptService();
        encounterService = Context.getEncounterService();
        formService = Context.getFormService();
        locationService = Context.getLocationService();
        orderService = Context.getOrderService();
        obsService = Context.getObsService();
        patientService = Context.getPatientService();
        providerService = Context.getProviderService();
    }

    public Locale getLocale() {
        return locale;
    }

    // Joda prints a null time as the current time, so a missing time is printed as MISSING.
    public String formatTime(DateTime dt) {
        return dt != null ? timeFormatter.print(dt) : MISSING;
    }

    public String formatDate(DateTime dt) {
        return dt != null ? dateFormatter.print(dt) : MISSING;
    }

    private List<ObsDisplay> wrapObs(List<Obs> list) {
        List<ObsDisplay> wrapped = new ArrayList<>();
        for (Obs obs : list) {
            wrapped.add(new ObsDisplay(obs));
        }
        return wrapped;
    }

    public List<ObsDisplay> getAdmissionTimes() {
        List<Obs> admissionTimes = new ArrayList<>();
        Concept concept = conceptService.getConceptByUuid(ADMISSION_DATETIME_UUID);
        if (concept != null) {
            for (Patient patient : patientService.getAllPatients()) {
                Obs obs = chooseAdmissionObs(obsService.getObservations(
                    Arrays.asList((Person) patient), null,
                    Arrays.asList(concept), null, null, null, null,
                    null, null, null, null, false
                ));
                if (obs != null) admissionTimes.add(obs);
            }
        }
        Collections.sort(admissionTimes, OBS_VALUE_TIME);
        return wrapObs(admissionTimes);
    }

    /**
     * Chooses which admission time (concept 1640) counts for a patient.  Registration
     * records one, stamped with the registration time; the Admission form records the date
     * the clinician entered.  The latest one recorded outside registration wins, even when
     * its time is earlier than the registration's; the registration's counts only when there
     * is no other.  Registration is the only writer that puts an admission time and a
     * placement in one encounter.  "Latest" orders by observation time, then by the admission
     * time entered (a missing one lowest), then by UUID.  The tablet applies the same rule
     * (AdmissionObs in the client); keep the two in step.
     */
    public static Obs chooseAdmissionObs(Collection<Obs> observations) {
        Obs registration = null;
        Obs form = null;
        for (Obs obs : observations) {
            if (!eq(getConceptUuid(obs), ADMISSION_DATETIME_UUID)) continue;
            if (hasPlacement(obs.getEncounter())) {
                registration = laterAdmission(registration, obs);
            } else {
                form = laterAdmission(form, obs);
            }
        }
        return form != null ? form : registration;
    }

    private static boolean hasPlacement(Encounter encounter) {
        if (encounter == null) return false;
        for (Obs obs : encounter.getAllObs()) {
            if (eq(getConceptUuid(obs), DbUtils.CONCEPT_PLACEMENT_UUID)) return true;
        }
        return false;
    }

    private static Obs laterAdmission(Obs a, Obs b) {
        if (a == null) return b;
        int result = a.getObsDatetime().compareTo(b.getObsDatetime());
        if (result == 0) result = Long.compare(valueMillis(a), valueMillis(b));
        if (result == 0) result = a.getUuid().compareTo(b.getUuid());
        return result < 0 ? b : a;
    }

    private static long valueMillis(Obs obs) {
        return obs.getValueDatetime() != null ? obs.getValueDatetime().getTime() : Long.MIN_VALUE;
    }

    public List<ObsDisplay> getDischargeTimes() {
        List<Obs> dischargeTimes = new ArrayList<>(getLatestObsByPatient(DISCHARGE_DATETIME_UUID).values());
        Collections.sort(dischargeTimes, OBS_VALUE_TIME);
        return wrapObs(dischargeTimes);
    }

    public static String getLocationUuidFromPlacement(String placement) {
        return Utils.splitFields(Utils.toNonnull(placement), "/", 2)[0].trim();
    }

    public List<PatientPlacement> getPresentPatients() {
        List<PatientPlacement> results = new ArrayList<>();
        Map<String, Obs> placements = getLatestObsByPatient(
            DbUtils.CONCEPT_PLACEMENT_UUID);
        for (String patientUuid : placements.keySet()) {
            Obs obs = placements.get(patientUuid);
            String placement = obs.getValueText();
            String locationUuid = getLocationUuidFromPlacement(placement);
            if (!DISCHARGED_LOCATION_UUIDS.contains(locationUuid)) {
                Patient patient = patientService.getPatientByUuid(patientUuid);
                results.add(new PatientPlacement(patient, placement));
            }
        }
        Collections.sort(results, PATIENT_PLACEMENT);
        return results;
    }

    public boolean isPregnant(Patient patient) {
        Obs latest = getLatestObsByPatient(PREGNANCY_UUID).get(patient.getUuid());
        return (latest != null && isYes(latest));
    }

    public Map<String, Obs> getLatestObsByPatient(String conceptUuid) {
        Map<String, Obs> results = new HashMap<>();
        Concept concept = conceptService.getConceptByUuid(conceptUuid);
        if (concept != null) {
            for (Patient patient : patientService.getAllPatients()) {
                Obs obs = getLatestObs(patient, concept);
                if (obs != null) results.put(patient.getUuid(), obs);
            }
        }
        return results;
    }

    public Obs getFirstObs(Patient pat, String conceptUuid) {
        return getFirstObs(pat, conceptService.getConceptByUuid(conceptUuid));
    }

    public Obs getFirstObs(Patient pat, Concept concept) {
        List<Obs> allObs = obsService.getObservations(
            Arrays.asList((Person) pat), null,
            Arrays.asList(concept), null, null, null, null,
            null, null, null, null, false
        );
        Collections.sort(allObs, OBS_TIME);
        for (Obs obs : allObs) {
            return obs;
        }
        return null;
    }

    public Obs getLatestObs(Patient pat, String conceptUuid) {
        return getLatestObs(pat, conceptService.getConceptByUuid(conceptUuid));
    }

    public Obs getLatestObs(Patient pat, Concept concept) {
        if (concept == null) return null;
        for (Obs obs : obsService.getObservations(
            Arrays.asList((Person) pat), null,
            Arrays.asList(concept), null, null, null, null,
            1, null, null, null, false
        )) {
            return obs;
        }
        return null;
    }

    public Map<String, Obs> getLatestObsByQuestion(List<Obs> group) {
        Map<String, Obs> obsByQuestion = new HashMap<>();
        for (Obs obs : group) {
            String key = obs.getConcept().getUuid();
            Obs previous = obsByQuestion.get(key);
            if (previous == null || inOrder(previous.getObsDatetime(), obs.getObsDatetime())) {
                obsByQuestion.put(key, obs);
            }
        }
        return obsByQuestion;
    }

    /**
     * The earlier values of each question in a group, oldest first, leaving out any value
     * that is repeated by the one after it; the latest value is not included.
     */
    public Map<String, List<Obs>> getEarlierObsByQuestion(List<Obs> group) {
        List<Obs> sorted = new ArrayList<>(group);
        Collections.sort(sorted, OBS_TIME);
        Map<String, List<Obs>> byQuestion = new HashMap<>();
        for (Obs obs : sorted) {
            String key = obs.getConcept().getUuid();
            if (!byQuestion.containsKey(key)) byQuestion.put(key, new ArrayList<Obs>());
            byQuestion.get(key).add(obs);
        }
        Map<String, List<Obs>> results = new HashMap<>();
        for (String key : byQuestion.keySet()) {
            List<Obs> values = byQuestion.get(key);
            List<Obs> earlier = new ArrayList<>();
            for (int i = 0; i < values.size() - 1; i++) {
                if (!eq(getValue(values.get(i)), getValue(values.get(i + 1)))) earlier.add(values.get(i));
            }
            if (!earlier.isEmpty()) results.put(key, earlier);
        }
        return results;
    }

    public Patient getPatient(String uuid) {
        return patientService.getPatientByUuid(uuid);
    }

    public List<Encounter> getEncountersWithConcept(Patient patient, String conceptUuid) {
        List<Encounter> results = new ArrayList<>();
        nextEncounter:
        for (Encounter enc : getEncounters(patient)) {
            for (Obs obs : enc.getAllObs()) {
                String uuid = getConceptUuid(obs);
                if (eq(uuid, conceptUuid)) {
                    results.add(enc);
                    continue nextEncounter;
                }
            }
        }
        return results;
    }

    public static class History {
        public final List<Encounter> admission = new ArrayList<>();
        public final List<Encounter> evolution = new ArrayList<>();
        public final List<Encounter> discharge = new ArrayList<>();

        public History(List<Encounter> encounters) {
            nextEncounter:
            for (Encounter enc : encounters) {
                for (Obs obs : enc.getAllObs()) {
                    String uuid = getConceptUuid(obs);
                    if (eq(uuid, ADMISSION_DATETIME_UUID)) {
                        admission.add(enc);
                        continue nextEncounter;
                    }
                    if (eq(uuid, DISCHARGE_DATETIME_UUID)) {
                        discharge.add(enc);
                        continue nextEncounter;
                    }
                }
                evolution.add(enc);
            }
        }
    }

    public History getHistory(Patient patient) {
        // getEncounters promises to sort its results chronologically.
        return new History(getEncounters(patient));
    }

    public List<Encounter> getEncounters(Patient patient) {
        return encounterService.getEncounters(
            patient, null, null, null,
            null, null, null, null, null, false
        );
    }

    public Provider getProvider(String uuid) {
        return providerService.getProviderByUuid(uuid);
    }

    public static Provider getProvider(Obs obs) {
        return getProvider(obs.getEncounter());
    }

    public static String getProviderUuid(Obs obs) {
        return getUuid(getProvider(obs));
    }

    public static String getProviderUuid(Order order) {
        return getUuid(getProvider(order));
    }

    public static Provider getProvider(Order order) {
        return getProvider(order.getEncounter());
    }

    public static Provider getProvider(Encounter enc) {
        if (enc == null) return null;
        for (EncounterProvider ep : enc.getEncounterProviders()) {
            return ep.getProvider();
        }
        return null;
    }

    public static String getUuid(BaseOpenmrsObject obj) {
        return obj != null ? obj.getUuid() : null;
    }

    public static Map<String, Obs> getLastObsByConcept(Encounter encounter) {
        return getLastObsByConcept(Arrays.asList(encounter));
    }

    public static Map<String, Obs> getLastObsByConcept(List<Encounter> encounters) {
        Map<String, Obs> results = new HashMap<>();
        for (Encounter enc : encounters) {
            for (Obs obs : enc.getAllObs()) {
                results.put(getConceptUuid(obs), obs);
            }
        }
        return results;
    }

    /** Orders of the patient, leaving out the ones deleted on the tablet (voided). */
    public List<Order> getOrders(Patient patient) {
        List<Order> orders = new ArrayList<>();
        for (Order order : orderService.getAllOrdersByPatient(patient)) {
            if (!order.isVoided()) orders.add(order);
        }
        return orders;
    }

    public List<Form> getForms() {
        List<Form> forms = new ArrayList<>();
        for (Form form : formService.getAllForms()) {
            if (form.getPublished()) {
                forms.add(form);
            }
        }
        Collections.sort(forms, FORM_TITLE);
        return forms;
    }

    public List<FormSection> getFormSections(Form form) {
        List<FormSection> sections = new ArrayList<>();
        List<FormField> heads = new ArrayList<>();
        for (FormField ff : form.getFormFields()) {
            if (ff != null && ff.getParent() == null) heads.add(ff);
        }
        Collections.sort(heads, SORT_WEIGHT_FIELD_NUMBER);
        for (FormField head : heads) {
            List<FormField> children = new ArrayList<>();
            for (FormField ff : form.getFormFields()) {
                if (ff.getParent() != null && ff.getParent().getId() == head.getId()) {
                    children.add(ff);
                }
            }
            Collections.sort(children, SORT_WEIGHT_FIELD_NUMBER);
            sections.add(new FormSection(head.getField().getName(), children));
        }
        return sections;
    }

    public List<Event> getEvolution(Patient pat, List<Encounter> evolution) {
        List<Event> events = new ArrayList<>();
        for (Encounter enc : evolution) {
            events.add(new Event(
                toLocalDateTime(enc.getEncounterDatetime()),
                new ArrayList<>(enc.getObs()),
                Arrays.<Order>asList()
            ));
        }
        for (Order order : getOrders(pat)) {
            events.add(new Event(
                toLocalDateTime(order.getDateCreated()),
                Arrays.<Obs>asList(),
                Arrays.asList(order)
            ));
        }
        Collections.sort(events, EVENT_TIME);
        return events;
    }

    public List<Event> mergeEvents(List<Event> events, Duration maxGap, Duration maxDuration) {
        List<Event> sorted = new ArrayList<>(events);
        Collections.sort(sorted, EVENT_TIME);

        List<Event> merged = new ArrayList<>();
        DateTime lastGroupStart = null;
        DateTime lastGroupEnd = null;
        for (Event event : sorted) {
            if (lastGroupEnd == null || !event.time.isBefore(lastGroupEnd.plus(maxGap)) ||
                lastGroupStart == null || !event.time.isBefore(lastGroupStart.plus(maxDuration))) {
                merged.add(event);
                lastGroupStart = lastGroupEnd = event.time;
            } else {
                merged.set(merged.size() - 1, Utils.last(merged).mergeWith(event));
                lastGroupEnd = event.time;
            }
        }
        return merged;
    }

    public List<Event> deduplicateObs(List<Event> events, List<String> conceptUuids) {
        Map<String, Object> lastValues = new HashMap<>();
        List<Event> results = new ArrayList<>();
        for (Event event : events) {
            List<Obs> dedupedObs = new ArrayList<>();
            for (Obs obs : event.obs) {
                String uuid = DbUtils.getConceptUuid(obs);
                Object value = getValue(obs);
                if (conceptUuids.contains(uuid) && lastValues.containsKey(uuid)
                    && eq(value, lastValues.get(uuid))) continue;
                dedupedObs.add(obs);
                lastValues.put(uuid, value);
            }
            Event newEvent = new Event(event.time, dedupedObs, event.orders, event.execs);
            if (!newEvent.obs.isEmpty() || !newEvent.orders.isEmpty() || !newEvent.execs.isEmpty()) {
                results.add(newEvent);
            }
        }
        return results;
    }

    public Object getValue(Obs obs) {
        return obs.getValueAsString(Locale.US);
    }

    public Intl getConceptName(Concept concept) {
        if (concept == null) return new Intl("");
        return new Intl(DbUtils.getConceptName(concept));
    }

    public static DateTime toDateTime(Date date) {
        if (date == null) return null;

        // Dates in the MySQL database are stored as their components
        // (e.g. "2019-12-05 11:39:00").  When OpenMRS loads them, it
        // unfortunately interprets the date and time in the local
        // time zone, which means that OpenMRS databaxses will randomly
        // corrupt dates and times when the server's time zone changes
        // or the database is copied to another system.
        //
        // To avoid any ambiguity about stored dates and times, all
        // Buendia systems are required to use UTC as the system-wide
        // time zone.  To interpret a date and time properly, then,
        // we must interpret the components as though they expressed
        // a time in UTC.  It is never safe to use the horrible Java
        // Date class; all date and time calculations within Buendia
        // are performed using the Joda library.  All operations in
        // Buendia should be completely firewalled from Date objects
        // using this function.
        return new DateTime(
            1900 + date.getYear(),
            date.getMonth() + 1,  // Java insanely represents months as 0-11
            date.getDate(),  // a terrible name for "day of the month"
            date.getHours(),
            date.getMinutes(),
            date.getSeconds(),
            DateTimeZone.UTC
        );
    }

    public DateTime toLocalDateTime(Date date) {
        if (date == null) return null;
        return new DateTime(toDateTime(date).getMillis(), zone);
    }

    public Instant toInstant(Date date) {
        if (date == null) return null;
        return new Instant(toDateTime(date).getMillis());
    }

    public boolean inOrder(Date a, Date b) {
        return toInstant(a).isBefore(toInstant(b));
    }

    public DateTime getObsLocalTime(Obs obs) {
        if (obs == null) return null;
        return toLocalDateTime(obs.getObsDatetime());
    }

    public DateTime getValueLocalTime(Obs obs) {
        if (obs == null) return null;
        return toLocalDateTime(obs.getValueDatetime());
    }

    public class ObsDisplay {
        private Obs obs;
        private DateTime obsTime;
        private DateTime valueTime;

        public ObsDisplay(Obs obs) {
            this.obs = obs;
            this.obsTime = getObsLocalTime(obs);
            this.valueTime = getValueLocalTime(obs);
        }

        public Obs getObs() {
            return obs;
        }

        public Patient getPatient() {
            return obs.getPatient();
        }

        public String getPatientId() {
            Patient p = obs.getPatient();
            PatientIdentifier pi = p != null ? p.getPatientIdentifier("MSF") : null;
            return pi != null ? pi.getIdentifier() : "";
        }

        public DateTime getObsTime() {
            return obsTime;
        }

        public DateTime getValueTime() {
            return valueTime;
        }

        public String getFormattedObsTime() {
            return formatTime(obsTime);
        }

        public String getFormattedValueTime() {
            return formatTime(valueTime);
        }
    }

    public class PatientPlacement {
        private Patient patient;
        private Placement placement;

        public PatientPlacement(Patient patient, String placement) {
            this.patient = patient;
            this.placement = new Placement(placement);
        }

        public Patient getPatient() {
            return patient;
        }

        public String getPatientId() {
            Patient p = getPatient();
            PatientIdentifier pi = p != null ? p.getPatientIdentifier("MSF") : null;
            return pi != null ? pi.getIdentifier() : "";
        }

        public Placement getPlacement() {
            return placement;
        }
    }

    public Placement getPlacement(Obs obs) {
        return new Placement(obs);
    }

    public class Placement {
        private String placement;
        private String locationUuid;
        private Location location;
        private Intl locationName;
        private String bed;

        public Placement(String placement) {
            this.placement = placement;
            locationUuid = getLocationUuidFromPlacement(placement);
            location = locationService.getLocationByUuid(locationUuid);
            // A placement is free text, so its location can be deleted while patients are placed there.
            locationName = new Intl(location != null ? location.getName() :
                locationUuid.isEmpty() ? MISSING : "Deleted location [fr:Lieu supprimé]");
            bed = Utils.splitFields(Utils.toNonnull(placement), "/", 2)[1].trim();
        }

        public Placement(Obs obs) {
            this(obs.getValueText());
        }

        public String getDescription() {
            String desc = Utils.localize(locationName);
            if (!bed.isEmpty()) {
                desc += ", " + bed;
            }
            return desc;
        }

        public Location getLocation() {
            return location;
        }

        public Intl getLocationName() {
            return locationName;
        }

        public String getBed() {
            return bed;
        }
    }

    public static class FormSection {
        public final String title;
        public final List<FormField> fields;

        public FormSection(String title, List<FormField> fields) {
            this.title = title;
            this.fields = fields;
        }
    }

    public class Event {
        public final DateTime time;
        public final List<Obs> obs;
        public final List<Order> orders;
        public final List<Obs> execs;

        public Event(DateTime time, List<Obs> obs, List<Order> orders, List<Obs> execs) {
            this.time = time;
            this.obs = obs;
            this.orders = orders;
            this.execs = execs;
        }

        public Event(DateTime time, List<Obs> obs, List<Order> orders) {
            List<Obs> points = new ArrayList<>();
            List<Obs> execs = new ArrayList<>();
            for (Obs o : obs) {
                if (eq(DbUtils.getConceptUuid(o), ConceptUuids.ORDER_EXECUTED_UUID)) {
                    // Doses of an order deleted on the tablet are not shown there either.
                    if (o.getOrder() == null || !o.getOrder().isVoided()) execs.add(o);
                } else {
                    points.add(o);
                }
            }
            this.time = time;
            this.obs = points;
            this.orders = orders;
            this.execs = execs;
        }

        public Event mergeWith(Event other) {
            List<Obs> allObs = new ArrayList<>(obs);
            allObs.addAll(other.obs);
            List<Order> allOrders = new ArrayList<>(orders);
            allOrders.addAll(other.orders);
            List<Obs> allExecs = new ArrayList<>(execs);
            allExecs.addAll(other.execs);
            return new Event(Utils.min(time, other.time), allObs, allOrders, allExecs);
        }
    }
}
