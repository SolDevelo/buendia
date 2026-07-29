# Buendia profile CSV format

A **profile** is a single CSV file that defines everything site-specific about what
clinicians see on the tablet app:

- the **data-entry forms** (the XForms opened from the "Add observations" screens), and
- the **patient chart / dashboard** (the tiles at the top of a patient's page and the
  grid of observations over time).

You upload and apply a profile from the OpenMRS admin UI (**Manage → Buendia profiles**).
Applying it runs `buendia-profile-apply`, which reads the CSV and writes the corresponding
OpenMRS concepts, forms and chart definitions into the database; the tablet then picks them
up on its next sync.

The canonical full example is
[`ebola/bunia.csv`](https://github.com/projectbuendia/profiles/blob/master/ebola/bunia.csv).
The examples below are taken from it.

---

## 1. Big picture

One CSV file describes **many** forms and **one** chart. Every row is one line of the file;
its meaning comes from **which columns are filled in**, not from a row "type" column.

The file is conceptually split into two parts by the first column, `tab`:

| `tab` value | What the following rows define |
|-------------|--------------------------------|
| `form`      | A data-entry form (repeat to define several forms) |
| `chart`     | The patient chart/dashboard (tiles + grid) |

The `tab` value **sticks downward**: you write `form` (or `chart`) once on the row that
begins a section, and every row below it belongs to that tab until the next `tab` value
appears. In practice each form starts on a row that has both `tab = form` **and** a `title`.

Forms are always processed before the chart, because the chart can only display concepts
that a form has already defined.

---

## 2. The columns

The header row must contain at least `section`, `concept`, and `label` (the validator
rejects the file otherwise). The full set of columns, in order, is:

```
tab, title, section, type, required, concept, label,
option concept, option label,
normal, subcritical, absolute,
format, caption format, css class, css style, script
```

| Column | Used in | Meaning |
|--------|---------|---------|
| `tab` | both | `form` or `chart`; selects which part of the file the row belongs to (sticky). |
| `title` | both | Starts a **new form** (form tab) or a **new chart panel** (chart tab). |
| `section` | both | Starts a **new section** (a heading grouping the questions/rows below it). |
| `type` | both | The **field type**. In a form it's the data type of the question; in the chart it's the rendering type. |
| `required` | form | `yes`/`no` — whether the question must be answered. |
| `concept` | both | The **OpenMRS concept ID** the field records (an integer). |
| `label` | both | The text shown to the user for the question / chart row. Supports translations (see §6). |
| `option concept` | form | For `select_one` / `select_multiple`: the concept ID of one answer choice. |
| `option label` | form | The text shown for that answer choice. |
| `normal` | form | Numeric field: the normal range (e.g. `36-37.5`). |
| `subcritical` | form | Numeric field: the wider "concerning but not critical" range. |
| `absolute` | form | Numeric field: the absolute plausible range; values outside are rejected as typos. |
| `format` | chart | How to render the value (format mini-language, see §5). |
| `caption format` | chart | Secondary text under a tile / in a grid popup. |
| `css class` | chart | CSS class name(s) to attach (can be computed from the value). |
| `css style` | chart | Inline CSS applied to the tile / grid row. |
| `script` | chart | Optional JavaScript for advanced rendering. |

> **Note:** the ranges columns are read by position/name as **normal / subcritical /
> absolute**. (Internally the apply script calls the middle one `noncritical`; the header in
> the sample files spells it `subcritical`. Use `subcritical` in your header to be safe.)

The three "empty" leading columns matter: because meaning comes from *which* cells are
filled, a question row leaves `tab`, `title`, and `section` blank and starts filling from
the `type` column; an answer-option row leaves everything blank up to `option concept`.

---

## 3. Row kinds

Within either tab, a row plays one of four roles depending on which columns are filled:

1. **Title row** — has a `title`. Starts a new form (form tab) or a new chart panel (chart
   tab). Everything else on the row is usually blank.
   ```csv
   form,[1] Admission
   ```

2. **Section row** — has a `section` but no `type`. Starts a new heading / group.
   ```csv
   ,,Vitals [fr:Signes vitaux]
   ```

3. **Question / field row** — has a `type` (and usually a `concept` and `label`). Defines
   one field.
   ```csv
   ,,,number,,5088,Temperature (°C) [fr:Température (C)],,,36-37.5,36-39,35-45
   ```

4. **Option row** — has an `option concept` / `option label` but no `type`. Adds one answer
   choice to the `select_one` / `select_multiple` question immediately above it.
   ```csv
   ,,,,,,,142177,S. Suspect [fr:S. Suspect]
   ```

---

## 4. The `form` tab

Each form begins with a title row (`tab = form`, `title = ...`). The bracketed numbers in
the sample titles (`[1] Admission`, `[2] Accompanying person`, …) are just naming/ordering
conventions that show up in the form list on the tablet.

Inside a form you write section rows to group questions, then question rows, then (for
choice questions) option rows.

### Field types (`type` column)

| `type` | What it produces |
|--------|------------------|
| `text` | Free text box. |
| `number` | Numeric entry; honours the `normal` / `subcritical` / `absolute` ranges. |
| `date` | Date picker. |
| `datetime` | Date + time picker. |
| `yes_no` | Yes / No toggle. |
| `yes_no_unknown` | Yes / No / Unknown toggle. |
| `select_one` | Single-choice list; the choices are the `option` rows that follow. |
| `select_multiple` | Multi-choice list (a group of on/off toggles); choices follow as `option` rows. |

Example — a single-choice question with three answers:

```csv
,,,select_one,,900005,Status [fr:État]
,,,,,,,142177,S. Suspect [fr:S. Suspect]
,,,,,,,159392,C. Confirmed [fr:C. Confirmé]
,,,,,,,119844,Con. Convalescent [fr:Con. Convalescence]
```

Example — a multi-select. The question row leaves `concept` blank and just names the group
via `label`; each following option row is one checkbox concept:

```csv
,,,select_multiple,,,Bleeding [fr:Saignement]
,,,,,,,517,Conjunctival injection [fr:Injection conjonctive]
,,,,,,,133499,Epistaxis [fr:Epistaxie]
,,,,,,,138905,Hemoptysis [fr:Hemoptysie]
```

### Numeric ranges

For `number` questions, the three range columns drive validation and colour-coding:

```csv
,,,number,,5088,Temperature (°C),,,36-37.5,36-39,35-45
```

- `normal` = `36-37.5` — values in this range are treated as normal.
- `subcritical` = `36-39` — the wider acceptable band.
- `absolute` = `35-45` — hard bounds; a value outside this is assumed to be a typo and rejected.

A range is written `low-high` (a `..` separator also works, e.g. `36..37.5`). Leave a range
blank to omit it.

### `required`

Put `yes` (or `1`, `true`) in the `required` column to make a question mandatory; blank or
`no` makes it optional.

```csv
,,,number,1,900022,Blood sugar (mg/dL),,,70-300,50-315,0-500
```

---

## 5. The `chart` tab

The chart tab defines the patient dashboard: the **tiles** across the top and the
**grid** of observations underneath. There is only one chart; you can split it into several
labelled panels with `title` rows.

The key idea: **the `section` cell's brackets choose what kind of section it is.**

| `section` value | Section kind | Renders as |
|-----------------|--------------|------------|
| `[[ ... ]]` (double brackets) | **Fixed row** | A fixed key/value row at the very top (e.g. admission date, location). |
| `[ ... ]` (single brackets)   | **Tile row** | A row of dashboard **tiles** (big at-a-glance values). |
| plain text (no brackets)      | **Grid section** | A titled block of **grid rows** — one row per observation, columns = time. |

The bracketed text itself is just a label; `[tiles]`, `[[fixed]]`, `[tiles 1]` etc. are all
fine. Grid sections use their plain text as the visible heading (`Vitals`, `Symptoms`, …).

### Chart rows

Under a chart section, each row with a `type` and a `concept` is one chart item — a tile (in
a tile row) or a grid line (in a grid section). For the chart, `type` is a **rendering hint**
(commonly `number`, `text`, `select_one`, `yes_no`); it does not redefine the concept's data
type. The concept must already have been defined by a form (or exist in the dictionary).

A grid row references **exactly one** concept. A tile / fixed row may combine **several**
concepts, separated by `;`, so a single tile can summarise multiple observations:

```csv
,,,text,,900023;900024,Ebola tests,,,,,,"{1,select,664:NEG;703:POS;·} / {2,select,664:NEG;703:POS;·}"
```

Here `{1,...}` is the first concept (`900023`) and `{2,...}` is the second (`900024`).

### Styling columns

`css class` and `css style` let you colour a tile or grid row based on the value; and both,
like `format`, use the format mini-language, so the class can be computed from the
observation. Example — a "Category" tile shown green/yellow/red:

```csv
,,,text,,900019,Category,,,,,,"{1,select,900041:Vert;900042:Jaune;900043:Rouge;–}",,"{1,select,900041:green;900042:yellow;900043:red}",".green { background: #7c7; } .yellow { background: #fc4; } .red { background: #f76; }"
```

- `format` → the displayed text (`Vert` / `Jaune` / `Rouge`, or `–` if unobserved).
- `css class` → `green` / `yellow` / `red` depending on the coded value.
- `css style` → the CSS defining those classes.

---

## 6. Labels and translations

Any label (`label`, `option label`, section text) can carry translations inline, using
`[<lang>:<text>]` suffixes:

```
Temperature (°C) [fr:Température (C)]
```

The base text is the default (English here); `[fr:...]` supplies the French rendering.

Because the CSV is comma-separated, wrap any label that contains a comma in double quotes:

```csv
,,,number,,5085,"BP, systolic (mmHg) [fr:TA, systolique (mmHg)]",,,100-160,80-200,0-300
```

---

## 7. The format mini-language (chart `format`, `caption format`, `css class`, `css style`)

These four chart columns aren't plain text — they're rendered with a small template
language (based on Java's `MessageFormat`, but **1-based**). This is the part worth
understanding well, because it's what makes the dashboard concise.

### Referencing values

`{1}` is the first concept of the row, `{2}` the second, and so on (matching the `;`-separated
IDs in the `concept` column). A bare number like `#.0` is shorthand for "format the first
value as a number".

### Sub-formats: `{<n>,<format>,<args>}`

| Format | Purpose | Example |
|--------|---------|---------|
| `number` | Format a numeric value (Java `DecimalFormat` pattern). | `{1,number,#.0}` → `37.5`; also `#'%'` → `95%` |
| `text` | Show text, optionally truncated. | `{1,text}`, `{1,text,20}` |
| `date` | Format a date value (Joda pattern). | `{1,date,d MMM}` → `4 Aug` |
| `time` | Format a date-time value. | `{1,time,d MMM HH:mm}` |
| `day_number` | Days since the observed date, counting that date as day 1. | `Jour {1,day_number,#}` → `Jour 3` |
| `yes_no` | Render a boolean as two (or three) labels: `yes;no;null`. | `{1,yes_no,Present;Absent}` |
| `abbr` / `name` | Abbreviation / full name of a coded answer. | `{1,name}` |
| `location` | Resolve a location value to its name. | `{1,location}` |
| `select` | Map a coded/numeric value to text, or choose a format by condition. | see below |

### `select` — the workhorse

`select` maps a value to different output. Two modes:

**By coded value** — `id:text` pairs separated by `;`, with an optional final fallback:

```
{1,select,664:NEG;703:POS;·}
```
→ `NEG` if the value is concept 664, `POS` if 703, otherwise `·`.

**By condition** — with comparison operators (`<`, `<=`, `>`, `>=`, `=`):

```
{1,select,=:;=0:jour;jours}
```
→ empty if unobserved, `jour` if the value is 0, else `jours` (used to pluralise "day/days").

An empty condition (`=:`) tests for "no value observed"; the branch text can itself contain
more `{...}` placeholders, so selects can nest.

### Worked examples from `bunia.csv`

```csv
,,,text,,1640,Admission,,,,,,"Jour {1,day_number,#}","{1,time,d MMM HH:mm}"
```
Tile: main line `Jour 3`, caption `4 Aug 09:15`.

```csv
,,,text,,buendia_concept_placement,Location,,,,,,"{1,location}","{2,select,=:;Lit {2,text}}"
```
Tile: patient's location name, with caption `Lit 12` when a bed is recorded (blank if not).

```csv
,,,text,,900020;900021,Sample taken,,,,,,"{2,select,1065:Prélevé (2);:{1,select,1065:Prélevé (1);:Aucun}}"
```
Combines two yes/no concepts: shows `Prélevé (2)` if the 2nd sample was taken, else
`Prélevé (1)` if the 1st was, else `Aucun`.

If a format string is invalid it is shown verbatim (prefixed with `??`) rather than crashing
the app, which makes profiles easy to debug on-device.

---

## 8. Concept IDs

The `concept` and `option concept` columns are **numeric OpenMRS concept IDs**. Standard
clinical concepts use their canonical CIEL/OpenMRS IDs (e.g. `5088` = temperature, `1065` =
Yes, `1066` = No). Site-specific concepts that don't exist in the standard dictionary are
given IDs in a private range (the sample uses `9000xx`, e.g. `900005` = Status). Applying the
profile creates any concepts that don't yet exist, using the row's `label` (and its
translations) as the concept name.

---

## 9. Minimal template

```csv
tab,title,section,type,required,concept,label,option concept,option label,normal,subcritical,absolute,format,caption format,css class,css style,script
form,My form
,,Vitals
,,,number,,5088,Temperature (°C),,,36-37.5,36-39,35-45
,,,select_one,,900005,Status
,,,,,,,142177,Suspect
,,,,,,,159392,Confirmed
chart,Chart
,,[tiles]
,,,number,,5088,Temp,,,,,,#.0°
,,Vitals
,,,number,,5088,Temperature,,,,,,#.0
```
