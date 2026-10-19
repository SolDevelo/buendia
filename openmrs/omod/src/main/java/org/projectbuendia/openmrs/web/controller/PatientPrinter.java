package org.projectbuendia.openmrs.web.controller;

import org.joda.time.DateTime;
import org.joda.time.Days;
import org.joda.time.Duration;
import org.joda.time.Period;
import org.openmrs.BaseOpenmrsMetadata;
import org.openmrs.BaseOpenmrsObject;
import org.openmrs.Concept;
import org.openmrs.ConceptDatatype;
import org.openmrs.Encounter;
import org.openmrs.Form;
import org.openmrs.FormField;
import org.openmrs.Obs;
import org.openmrs.Order;
import org.openmrs.Patient;
import org.openmrs.PatientIdentifier;
import org.openmrs.Provider;
import org.openmrs.api.ProviderService;
import org.openmrs.projectbuendia.Utils;
import org.openmrs.projectbuendia.webservices.rest.DbUtils;
import org.projectbuendia.models.Catalog.Drug;
import org.projectbuendia.models.Catalog.Format;
import org.projectbuendia.models.Catalog.Route;
import org.projectbuendia.models.CatalogIndex;
import org.projectbuendia.models.Instructions;
import org.projectbuendia.models.Intl;
import org.projectbuendia.models.MsfCatalog;
import org.projectbuendia.models.Quantity;
import org.projectbuendia.models.Unit;
import org.projectbuendia.openmrs.web.controller.DataHelper.FormSection;
import org.projectbuendia.openmrs.web.controller.DataHelper.History;
import org.projectbuendia.openmrs.web.controller.HtmlOutput.Doc;
import org.projectbuendia.openmrs.web.controller.HtmlOutput.Sequence;

import java.io.IOException;
import java.io.Writer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import static org.openmrs.projectbuendia.Utils.eq;
import static org.openmrs.projectbuendia.Utils.eqAny;
import static org.openmrs.projectbuendia.Utils.toUuid;
import static org.openmrs.projectbuendia.webservices.rest.DbUtils.CONCEPT_PLACEMENT_UUID;
import static org.openmrs.projectbuendia.webservices.rest.DbUtils.isNo;
import static org.openmrs.projectbuendia.webservices.rest.DbUtils.isYes;
import static org.projectbuendia.openmrs.web.controller.DataHelper.MISSING;
import static org.projectbuendia.openmrs.web.controller.HtmlOutput.el;
import static org.projectbuendia.openmrs.web.controller.HtmlOutput.format;
import static org.projectbuendia.openmrs.web.controller.HtmlOutput.intl;
import static org.projectbuendia.openmrs.web.controller.HtmlOutput.seq;
import static org.projectbuendia.openmrs.web.controller.HtmlOutput.text;

class PatientPrinter {
    private final Writer writer;
    private final Locale locale;
    private final DataHelper helper;
    private final CatalogIndex index = MsfCatalog.INDEX;

    private static final List<String> CONCEPTS_OMIT_DUPLICATE_VALUES = Arrays.asList(
        ConceptUuids.PLACEMENT_UUID
    );

    public PatientPrinter(Writer writer, Locale locale, DataHelper helper) {
        this.writer = writer;
        this.locale = locale;
        this.helper = helper;
    }

    public void printPrologue() throws IOException {
        writer.write("<meta charset='UTF-8'>");
        writer.write("<style>");
        writer.write(PrintCss.CSS);
        writer.write("</style>");
    }

    public void printEpilogue() throws IOException {
        writer.write("<script>");
        writer.write("window.onload = print;");
        writer.write("</script>");
    }

    public void printHistory(Patient pat) throws IOException {
        History history = helper.getHistory(pat);
        String ident = getIdentifier(pat);

        // Events after the discharge (e.g. a survivor's clinic visit) print after it.
        List<DataHelper.Event> events = getEvents(pat, history.evolution);
        List<DataHelper.Event> beforeDischarge = new ArrayList<>();
        List<DataHelper.Event> afterDischarge = new ArrayList<>();
        DateTime dischargeTime = history.discharge.isEmpty() ? null :
            helper.toLocalDateTime(history.discharge.get(0).getEncounterDatetime());
        for (DataHelper.Event event : events) {
            if (dischargeTime != null && !event.time.isBefore(dischargeTime)) {
                afterDischarge.add(event);
            } else {
                beforeDischarge.add(event);
            }
        }

        table("pages",
            el("thead",
                el("tr",
                    el("td",
                        div("ident", ident)))),
            el("tbody",
                el("tr",
                    el("td",
                        div("history",
                            renderIntro(pat),
                            !history.admission.isEmpty() ? renderAdmission(history.admission) : seq(),
                            !beforeDischarge.isEmpty() ? renderEvents(
                                intl("Evolution [fr:Evolution]"), beforeDischarge) : seq(),
                            !history.discharge.isEmpty() ? renderDischarge(history.discharge) : seq(),
                            !afterDischarge.isEmpty() ? renderEvents(
                                intl("After discharge [fr:Après la sortie]"), afterDischarge) : seq()
                        )
                    )
                )
            )
        ).writeTo(writer, locale);
    }

    // The French text holds a colon, which the packed "[fr:...]" form cannot carry.
    private static final Intl ERROR_MESSAGE = new Intl(
        "This patient's file could not be printed: some data is missing or damaged. "
            + "The other files are complete. Details are in the server log.",
        Collections.singletonMap("fr",
            "Impossible d'imprimer le dossier de ce patient : des données sont manquantes ou endommagées. "
                + "Les autres dossiers sont complets. Détail dans le journal du serveur."));

    /** In place of a patient whose history could not be printed: their ID and name, as far as read. */
    public void printError(String ident, String name) throws IOException {
        printNotice(ident, div("intro", div("ident", ident), div("name", name)), ERROR_MESSAGE);
    }

    /** In place of a patient deleted in OpenMRS: nothing of their record is printed. */
    public void printDeleted() throws IOException {
        printNotice("", seq(), intl(
            "This patient was deleted; their file is not printed. "
                + "[fr:Ce patient a été supprimé ; son dossier n'est pas imprimé.]"));
    }

    private void printNotice(String ident, Doc intro, Doc message) throws IOException {
        table("pages",
            ident.isEmpty() ? seq() : el("thead", el("tr", el("td", div("ident", ident)))),
            el("tbody", el("tr", el("td", div("notice", intro, div("message", message)))))
        ).writeTo(writer, locale);
    }

    public Doc renderIntro(Patient pat) {
        Doc age = renderAge(pat);
        Doc sex = renderSex(pat);
        return div("intro",
            div("ident", getIdentifier(pat)),
            div("name", getName(pat)),
            div("agesex", sex, sex.isEmpty() ? "" : ", ", age)
        );
    }

    /** The patient's name, or "" when every name was deleted. */
    String getName(Patient pat) {
        return pat.getPersonName() != null ? Utils.toNonnull(pat.getPersonName().getFullName()) : "";
    }

    /** The MSF identifier, or the local one generated for a patient registered without it. */
    String getIdentifier(Patient pat) {
        PatientIdentifier ident = pat.getPatientIdentifier("MSF");
        if (ident == null) ident = pat.getPatientIdentifier();
        return ident != null ? ident.getIdentifier() : "";
    }

    public Doc renderAge(Patient pat) {
        if (pat.getBirthdate() == null) return intl("age unknown [fr:âge inconnu]");
        Period age = new Period(
            helper.toLocalDateTime(pat.getBirthdate()),
            helper.toLocalDateTime(pat.getDateCreated()));
        int years = age.getYears();
        int months = age.getMonths();
        return span("age", format(
            years == 0 ? "%2$d mo [fr:%2$d mo]" :
                months == 0 ? "%1$d y [fr:%1$d a]" :
                    "%d y %d mo [fr:%d a %d mo]",
            years, months
        ));
    }

    public Doc renderSex(Patient pat) {
        if (!Utils.hasChars(pat.getGender())) return seq();
        Sequence pregnancy = seq();
        if (helper.isPregnant(pat)) pregnancy.add(text(", "), intl("pregnant [fr:enceinte]"));
        return span("sex", pat.getGender(), pregnancy);
    }

    public static String DISCHARGE_DATETIME_UUID = toUuid(8001641);
    public static String ADMISSION_DATETIME_UUID = toUuid(8001640);

    public DateTime getDateTimeValue(Obs obs) {
        return obs != null ? helper.toLocalDateTime(obs.getValueDatetime()) : null;
    }

    public Doc renderAdmission(List<Encounter> encounters) {
        Map<String, Obs> map = helper.getLastObsByConcept(encounters);
        DateTime admissionTime = getDateTimeValue(map.get(ADMISSION_DATETIME_UUID));
        return div("admission",
            div("heading", intl("Admission [fr:Admission]")),
            div("time", helper.formatTime(admissionTime)),
            div("observations", renderObsList(map))
        );
    }

    public Doc renderDischarge(List<Encounter> encounters) {
        Map<String, Obs> map = helper.getLastObsByConcept(encounters);
        DateTime dischargeTime = getDateTimeValue(map.get(DISCHARGE_DATETIME_UUID));
        return div("discharge",
            div("heading", intl("Discharge [fr:Sorti]")),
            div("time", helper.formatTime(dischargeTime)),
            div("observations", renderObsList(map))
        );
    }

    private List<DataHelper.Event> getEvents(Patient pat, List<Encounter> evolution) {
        List<DataHelper.Event> events = helper.getEvolution(pat, evolution);
        events = helper.mergeEvents(events, Duration.standardMinutes(10), Duration.standardMinutes(20));
        return helper.deduplicateObs(events, CONCEPTS_OMIT_DUPLICATE_VALUES);
    }

    public Doc renderEvents(Doc heading, List<DataHelper.Event> events) {
        Sequence results = seq();
        for (DataHelper.Event event : events) {
            Map<String, Obs> obsByQuestion = helper.getLatestObsByQuestion(event.obs);
            Sequence obsList = renderObsList(obsByQuestion, helper.getEarlierObsByQuestion(event.obs));
            Sequence orderList = renderOrderList(event.orders);
            Sequence execList = renderExecList(event.execs);
            if (!obsList.isEmpty() || !orderList.isEmpty() || !execList.isEmpty()) {
                results.add(div(
                    "event",
                    div("time", helper.formatTime(event.time)),
                    columns(
                        column("50%",
                            obsList.isEmpty() ? seq() : div("observations", obsList)
                        ),
                        column("50%", div("treatments",
                            orderList.isEmpty() ? seq() : div("orders", orderList),
                            execList.isEmpty() ? seq() : div("executions", execList)
                        ))
                    )
                ));
            }
        }
        return div("evolution",
            div("heading", heading),
            div("events", results)
        );
    }

    Doc renderProvider(Provider provider) {
        return span("provider", provider != null && provider.getName() != null ?
            provider.getName() : intl("unknown [fr:inconnu]"));
    }

    private Provider getPluralityProvider(Map<String, Obs> obsByQuestion) {
        Map<String, Integer> countsByUuid = new HashMap<>();
        for (String conceptUuid : obsByQuestion.keySet()) {
            if (eqAny(conceptUuid,
                ConceptUuids.ORDER_EXECUTED_UUID,
                ConceptUuids.PLACEMENT_UUID,
                ConceptUuids.PREGNANCY_UUID
            )) continue;
            Obs obs = obsByQuestion.get(conceptUuid);
            Provider provider = helper.getProvider(obs);
            if (provider != null) {
                String providerUuid = provider.getUuid();
                int count = 0;
                if (countsByUuid.containsKey(providerUuid)) count = countsByUuid.get(providerUuid);
                countsByUuid.put(providerUuid, count + 1);
            }
        }
        Provider result = null;
        int maxCount = 0;
        for (String uuid : countsByUuid.keySet()) {
            int count = countsByUuid.get(uuid);
            if (count > maxCount) {
                result = helper.getProvider(uuid);
                maxCount = count;
            }
        }
        return result;
    }

    private Sequence renderObsList(Map<String, Obs> obsMap) {
        return renderObsList(obsMap, new HashMap<String, List<Obs>>());
    }

    /** Renders the latest value of each question, preceded by its earlier values in "earlier". */
    private Sequence renderObsList(Map<String, Obs> obsMap, Map<String, List<Obs>> earlier) {
        Sequence results = new Sequence();
        Set<String> remaining = new HashSet<>(obsMap.keySet());
        boolean admissionFormSubmitted = obsMap.containsKey(
            ConceptUuids.ADMISSION_DATETIME_UUID);

        while (remaining.size() > 0) {
            if (remaining.contains(CONCEPT_PLACEMENT_UUID)) {
                Obs obs = obsMap.get(CONCEPT_PLACEMENT_UUID);
                results.add(div("form", renderObsContent(obs, earlier)));
                remaining.remove(CONCEPT_PLACEMENT_UUID);
                continue;
            }
            String providerUuid = null;
            for (Form form : helper.getForms()) {
                Doc groupHeading = seq();
                Sequence items = seq();
                if (!admissionFormSubmitted && isAdmissionForm(form)) continue;
                for (FormSection section : helper.getFormSections(form)) {
                    List<Obs> children = new ArrayList<>();
                    int noCount = 0;
                    for (FormField option : section.fields) {
                        String uuid = DbUtils.getConceptUuid(option);
                        if (uuid != null && remaining.contains(uuid)) {
                            Obs obs = obsMap.get(uuid);
                            if (providerUuid == null) {
                                Provider provider = helper.getProvider(obs);
                                providerUuid = helper.getUuid(provider);
                                groupHeading = div("group", format(
                                    "Observations by %s [fr:Observations par %s]",
                                    renderProvider(provider)
                                ));
                            }
                            if (eq(helper.getProviderUuid(obs), providerUuid)) {
                                if (isNo(obs)) noCount++;
                                children.add(obs);
                                remaining.remove(uuid);
                            }
                        }
                    }
                    if (!children.isEmpty()) {
                        Doc title = intl(section.title);
                        if (section.title.contains("[binary]")) {
                            if (noCount == section.fields.size()) {
                                items.add(renderNoneSelected(title, children));
                            } else {
                                items.add(renderMultipleSelect(title, children));
                            }
                        } else {
                            items.add(renderFormSection(title, children, earlier));
                        }
                    }
                }
                if (!items.isEmpty()) {
                    results.add(groupHeading, div("form", items));
                }
            }
            Doc groupHeading = seq();
            Sequence extras = new Sequence();
            for (String uuid : obsMap.keySet()) {
                if (remaining.contains(uuid)) {
                    Obs obs = obsMap.get(uuid);
                    if (providerUuid == null) {
                        Provider provider = helper.getProvider(obs);
                        providerUuid = helper.getUuid(provider);
                        groupHeading = div("group", format(
                            "Observations by %s [fr:Observations par %s]",
                            renderProvider(provider)
                        ));
                    }
                    if (eq(helper.getProviderUuid(obs), providerUuid)) {
                        extras.add(renderObsContent(obs, earlier));
                        remaining.remove(uuid);
                    }
                }
            }
            if (!extras.isEmpty()) {
                results.add(groupHeading, div("form extras", extras));
            }
        }
        return results;
    }

    private Sequence renderExecList(List<Obs> execs) {
        Sequence items = seq();
        while (execs.size() > 0) {
            Provider provider = helper.getProvider(execs.get(0));
            Sequence group = seq(
                div("group", format(
                    "Treatments given by %s [fr:Traitements donnés par %s]",
                    renderProvider(provider)
                ))
            );
            Set<String> displayed = new HashSet<>();
            for (Obs exec : execs) {
                if (eq(helper.getProviderUuid(exec), helper.getUuid(provider))) {
                    group.add(renderObsContent(exec));
                    displayed.add(exec.getUuid());
                }
            }
            execs = filterOut(execs, displayed);
            items.add(group);
        }
        return items;
    }

    private <T extends BaseOpenmrsObject> List<T> filterOut(List<T> items, Collection<String> uuidsToOmit) {
        List<T> result = new ArrayList<>();
        for (T item : items) {
            if (!uuidsToOmit.contains(item.getUuid())) result.add(item);
        }
        return result;
    }

    private Sequence renderOrderList(List<Order> orders) {
        Set<String> revised = new HashSet<>();
        for (Order order : orders) {
            Order previous = order.getPreviousOrder();
            if (previous != null) {
                revised.add(previous.getUuid());
            }
        }

        List<Order> remaining = filterOut(orders, revised);

        Sequence results = seq();
        while (remaining.size() > 0) {
            Provider provider = helper.getProvider(remaining.get(0));
            Sequence group = seq(
                div("group", format(
                    "Treatments ordered by %s [fr:Traitements commandés par %s]",
                    renderProvider(provider)
                ))
            );
            Set<String> displayed = new HashSet<>();
            for (Order order : remaining) {
                if (eq(helper.getProviderUuid(order), helper.getUuid(provider))) {
                    displayed.add(order.getUuid());
                    group.add(div("order",
                        renderOrderChange(order),
                        renderOrderTreatment(order),
                        renderOrderSchedule(order)
                    ));
                }
            }
            results.add(group);
            remaining = filterOut(remaining, displayed);
        }

        return results;
    }

    private boolean isAdmissionForm(Form form) {
        return DbUtils.getName(form).toLowerCase().contains("admiss");
    }

    private Doc renderNoneSelected(Doc title, List<Obs> children) {
        return div("obs", span("label", title, ": "), " ", span("value", intl("None [fr:Aucun]")));
    }

    private Doc renderMultipleSelect(Doc title, List<Obs> children) {
        Sequence results = seq();
        boolean first = true;
        Provider provider = null;
        for (Obs obs : children) {
            if (isYes(obs)) {
                if (!first) results.add(text(", "));
                results.add(coded(obs.getConcept()));
                first = false;
            }
        }
        return results.isEmpty() ? seq() : div("obs",
            span("label", title, ": "), " ", span("value", results)
        );
    }

    private Doc renderFormSection(Doc title, List<Obs> children, Map<String, List<Obs>> earlier) {
        Sequence results = seq();
        for (Obs obs : children) {
            results.add(renderObsContent(obs, earlier));
        }
        return results;
    }

    Doc renderObsContent(Obs obs) {
        return renderObsContent(obs, new HashMap<String, List<Obs>>());
    }

    private Doc renderObsContent(Obs obs, Map<String, List<Obs>> earlier) {
        Sequence value = seq();
        List<Obs> before = earlier.get(DbUtils.getConceptUuid(obs));

        switch (DbUtils.getConceptUuid(obs)) {
            case DbUtils.CONCEPT_PLACEMENT_UUID:
                if (before != null) {
                    for (Obs b : before) value.add(renderPlacement(helper.getPlacement(b)), text(" → "));
                }
                DataHelper.Placement p = helper.getPlacement(obs);
                value.add(renderPlacement(p));
                return div("obs placement",
                    span("label", intl("Placement [fr:Emplacement]"), ": "),
                    span("value", value)
                );

            case DbUtils.CONCEPT_ORDER_EXECUTED_UUID:
                // A dose whose order link is missing prints MISSING as its treatment.
                if (obs.getOrder() == null) return div("execution", MISSING);
                Order order = getRevisionAt(obs.getOrder(), obs.getObsDatetime());
                return div("execution", renderOrderTreatment(order));

            default:
                if (before != null) {
                    for (Obs b : before) value.add(renderValue(b), text(" → "));
                }
                value.add(renderValue(obs));
                return div("obs " + getConceptCssClass(obs.getConcept()),
                    span("label", coded(obs.getConcept()), ":"),
                    " ",
                    span("value", value)
                );
        }
    }

    private String getConceptCssClass(Concept concept) {
        if (concept == null) return "";
        String uuid = concept.getUuid();
        Object comp = Utils.compressUuid(uuid);
        if (comp instanceof Integer) {
            return "c-" + (((int) comp) % 1000000);
        } else {
            return "c-" + comp;
        }
    }

    private Doc renderPlacement(DataHelper.Placement p) {
        Sequence result = seq(p.getLocationName());
        if (!p.getBed().isEmpty()) {
            result.add(seq(", ", intl("Bed [fr:Lit]"), " ", p.getBed()));
        }
        return result;
    }

    /** The revision of an order that was in force at the given time. */
    private Order getRevisionAt(Order order, Date time) {
        Order revision = DbUtils.getLastRevision(order);
        while (revision.getPreviousOrder() != null && revision.getDateCreated().after(time)) {
            revision = revision.getPreviousOrder();
        }
        return revision;
    }

    private Doc renderOrderChange(Order order) {
        Order previous = order.getPreviousOrder();
        if (previous == null) return seq();
        Date stop = order.getAutoExpireDate();
        // A stop is a revision that only moves the end to (about) the moment it was made.
        boolean stopped = stop != null && eq(order.getInstructions(), previous.getInstructions())
            && stop.getTime() <= order.getDateCreated().getTime() + 60 * 1000;
        return div("change", stopped ? intl("Stopped [fr:Arrêté]") : intl("Modified [fr:Modifié]"));
    }

    Doc renderOrderTreatment(Order order) {
        Instructions instr = new Instructions(order.getInstructions());
        Drug drug = index.getDrug(instr.code);
        Format format = index.getFormat(instr.code);
        Doc dosage = instr.isContinuous() ?
            span("dosage", format("%s in %s [fr:%s dans %s]",
                instr.amount != null ? renderQuantity(instr.amount) : text(MISSING),
                renderQuantity(instr.duration)
            )) :
            instr.amount != null ?
                span("dosage", renderQuantity(instr.amount)) : seq();

        Route route = index.getRoute(instr.route);
        boolean inCatalog = drug != Drug.UNSPECIFIED;
        return div("treatment",
            div("drug", inCatalog ? drug.name : text(instr.code.isEmpty() ? MISSING : instr.code)),
            format != Format.UNSPECIFIED ?
                div("format", span("label", intl("Format"), ": "), format.description) : seq(),
            div("dosageroute",
                span("label", intl("Dosage"), ": "), dosage, " ",
                !route.abbr.isEmpty() ?
                   span("route", format("%s (%s)", route.abbr, route.name)) : seq()
            ),
            Utils.hasChars(instr.notes) ?
                div("notes", span("label", intl("Notes [fr:Remarques]"), ": "), instr.notes) : seq()
        );
    }

    private Doc renderQuantity(Quantity quantity) {
        // A backspace in a unit abbreviation means "no space before it", e.g. "3x/jour".
        String abbr = quantity.unit.abbr.loc(locale);
        return span("quantity",
            span("mag", Utils.format(quantity.mag, 6)),
            abbr.contains("\b") ? "" : " ",
            span("unit", abbr.replace("\b", ""))
        );
    }

    Doc renderOrderSchedule(Order order) {
        DateTime start = helper.toLocalDateTime(order.getScheduledDate());
        DateTime stop = helper.toLocalDateTime(order.getAutoExpireDate());
        Instructions instr = new Instructions(order.getInstructions());
        int doses = 0;
        if (start != null && stop != null && instr.isSeries() && eq(instr.frequency.unit, Unit.PER_DAY)) {
            int days = Days.daysBetween(start.toLocalDate(), stop.toLocalDate()).getDays();
            doses = days * (int) instr.frequency.mag;
        }
        if (!Utils.hasChars(order.getInstructions())) {
            // Nothing says how often it is given, so print only the dates: not "one dose only".
            return div("schedule", span("label", intl("Schedule [fr:Horaire]"), ": "), stop != null ?
                format("starting %s; stopping %s [fr:commencer %s; arrêter %s]",
                    helper.formatTime(start), helper.formatTime(stop)) :
                format("starting %s [fr:commencer %s]", helper.formatTime(start)));
        }
        return div("schedule", span("label", intl("Schedule [fr:Horaire]"), ": "), instr.isSeries() && instr.frequency.mag > 0 ?
            (stop != null ?
                (doses > 0 ?
                    seq(renderQuantity(instr.frequency), ", ",
                        format("starting %s; stopping %s after %d doses [fr:commencer %s; arrêter %s après %d doses]",
                            helper.formatTime(start), helper.formatTime(stop), doses)) :
                    seq(renderQuantity(instr.frequency), ", ",
                        format("starting %s; stopping %s [fr:commencer %s; arrêter %s]",
                            helper.formatTime(start), helper.formatTime(stop)))
                ) :
                seq(renderQuantity(instr.frequency), ", ",
                    format("starting %s, continuing indefinitely [fr:commencer %s; continuer indéfiniment]",
                        helper.formatTime(start)))
            ) :
            instr.isContinuous() ?
                (stop != null ?
                    format("infusion starting %s; stopping %s [fr:perfusion, commencer %s; arrêter %s]",
                        helper.formatTime(start), helper.formatTime(stop)) :
                    format("infusion starting %s [fr:perfusion, commencer %s]",
                        helper.formatTime(start))) :
            format("one dose only, ordered %s [fr:dose unique, commandé %s]",
                helper.formatTime(start))
        );
    }

    Doc renderValue(Obs obs) {
        ConceptDatatype type = obs.getConcept().getDatatype();
        // A value missing from the database prints MISSING; dates via formatDate/formatTime.
        switch (type.getHl7Abbreviation()) {
            case ConceptDatatype.BOOLEAN:
                Boolean bool = obs.getValueBoolean();
                return text(bool != null ? Boolean.toString(bool) : MISSING);
            case ConceptDatatype.CODED:
                return obs.getValueCoded() != null ? coded(obs.getValueCoded()) : text(MISSING);
            case ConceptDatatype.NUMERIC:
                Double num = obs.getValueNumeric();
                return text(num != null ? Utils.format(num, 6) : MISSING);
            case ConceptDatatype.TEXT:
                String str = obs.getValueText();
                return text(str != null ? str.replace("\n", "; ") : MISSING);
            case ConceptDatatype.DATE:
                return text(helper.formatDate(helper.toLocalDateTime(obs.getValueDate())));
            case ConceptDatatype.DATETIME:
                return text(helper.formatTime(helper.toLocalDateTime(obs.getValueDatetime())));
        }
        return text("?");
    }

    private Doc coded(Concept concept) {
        return intl(helper.getConceptName(concept));
    }

    private Doc span(String cls, Object... objects) {
        return el("span class='" + cls + "'", objects);
    }

    private Doc div(String cls, Object... objects) {
        return el("div class='" + cls + "'", objects);
    }

    private Doc table(String cls, Object... contents) {
        return el("table cellspacing=0 cellpadding=0 class='" + cls + "'", contents);
    }

    private Doc columns(Object... columns) {
        return el("table cellspacing=0 cellpadding=0 class='columns'", el("tr", columns));
    }

    private Doc column(String width, Object... objects) {
        return el("td width='" + width + "'", objects);
    }

}
