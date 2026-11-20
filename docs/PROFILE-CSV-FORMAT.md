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

One CSV file describes many forms and one chart. Each row is one line of the file. What a row
means depends on which of its columns are filled in; no column states the row's kind.

The first column, `tab`, splits the file into two parts:

| `tab` value | What the following rows define |
|-------------|--------------------------------|
| `form`      | A data-entry form (repeat to define several forms) |
| `chart`     | The patient chart/dashboard (tiles + grid) |

A `tab` value carries down: write `form` or `chart` once on the row that begins a part, and
every row below it belongs to that tab until the next `tab` value. In practice each form
starts on a row that has both `tab = form` and a `title`.

Forms are always processed before the chart, because the chart can only display concepts
that a form has already defined.

---

## 2. The columns

The upload check looks only for the `section`, `concept` and `label` columns; applying the
file also needs `tab`. Columns are found by their header name, so their order does not matter. The usual
order is:

```
tab, title, section, type, required, concept, label,
option concept, option label,
normal, noncritical, absolute,
format, caption format, css class, css style, script
```

| Column | Used in | Meaning |
|--------|---------|---------|
| `tab` | both | `form` or `chart`; selects which part of the file the row belongs to (sticky). |
| `title` | both | Starts a new form (form tab) or a new chart panel (chart tab). |
| `section` | both | Starts a new section: a heading over the questions or rows below it. |
| `type` | both | The field type: in a form, the question's data type; in the chart, the rendering type. |
| `required` | form | `yes`/`no`: whether the question must be answered. |
| `concept` | both | The OpenMRS concept ID (an integer) that the field records. |
| `label` | both | The text shown for the question or chart row. Can carry translations (see §6). |
| `option concept` | form | For `select_one` / `select_multiple`: the concept ID of one answer choice. |
| `option label` | form | The text shown for that answer choice. |
| `normal` | form | Numeric field: the normal range (e.g. `36-37.5`). See §4. |
| `noncritical` | form | Numeric field: the wider "concerning but not critical" range. See §4. |
| `absolute` | form | Numeric field: the plausible range; the tablet refuses a value outside it as a typo. |
| `format` | chart | How to render the value (format mini-language, see §7). |
| `caption format` | chart | Secondary text under a tile or in a grid pop-up. |
| `css class` | chart | Class name(s) given to the tile or grid cell, usually computed from the value (§5). |
| `css style` | chart | CSS rules added to the chart page as written (§5). |
| `script` | chart | Optional JavaScript for advanced rendering. |

> **Note:** the middle range column must be headed `noncritical`. Some old sample files call
> it `subcritical`; with that heading the range is silently ignored.

Because a row's meaning depends on which cells are filled, leave the leading cells empty where
they do not apply. A question row leaves `tab`, `title` and `section` blank and starts at the
`type` column. An answer-option row leaves every column before `option concept` blank.

---

## 3. Row kinds

In both tabs, a row is one of four kinds, depending on which columns are filled:

1. **Title row**: has a `title`. Starts a new form (form tab) or a new chart panel (chart
   tab). Everything else on the row is usually blank.
   ```csv
   form,[1] Admission
   ```

2. **Section row**: has a `section` but no `type`. Starts a new heading (a group).
   ```csv
   ,,Vitals [fr:Signes vitaux]
   ```

3. **Question (field) row**: has a `type` (and usually a `concept` and `label`). Defines
   one field.
   ```csv
   ,,,number,,5088,Temperature (°C) [fr:Température (C)],,,36-37.5,36-39,35-45
   ```

4. **Option row**: has an `option concept` / `option label` but no `type`. Adds one answer
   choice to the `select_one` / `select_multiple` question immediately above it.
   ```csv
   ,,,,,,,142177,S. Suspect [fr:S. Suspect]
   ```

---

## 4. The `form` tab

Each form begins with a title row (`tab = form`, `title = ...`). The bracketed numbers in
the sample titles (`[1] Admission`, `[2] Accompanying person`, …) are a naming convention
for ordering; they appear in the form list on the tablet.

Inside a form, write section rows to group the questions, then question rows, and after each
choice question its option rows.

### Field types (`type` column)

| `type` | What it produces |
|--------|------------------|
| `text` | Free text box. |
| `number` | Numeric entry; refuses values outside the `absolute` range. |
| `date` | Date picker. |
| `datetime` | Date and time picker. |
| `yes_no` | Yes / No toggle. |
| `yes_no_unknown` | Yes / No / Unknown toggle. |
| `select_one` | Single-choice list; the choices are the `option` rows that follow. |
| `select_multiple` | Multi-choice list (a group of on/off toggles); choices follow as `option` rows. |

A single-choice question with three answers:

```csv
,,,select_one,,900005,Status [fr:État]
,,,,,,,142177,S. Suspect [fr:S. Suspect]
,,,,,,,159392,C. Confirmed [fr:C. Confirmé]
,,,,,,,119844,Con. Convalescent [fr:Con. Convalescence]
```

A multi-select question. The question row leaves `concept` blank and names the group in
`label`; each option row below it is one checkbox concept:

```csv
,,,select_multiple,,,Bleeding [fr:Saignement]
,,,,,,,517,Conjunctival injection [fr:Injection conjonctive]
,,,,,,,133499,Epistaxis [fr:Epistaxie]
,,,,,,,138905,Hemoptysis [fr:Hemoptysie]
```

### Numeric ranges

A `number` question can carry three ranges:

```csv
,,,number,,5088,Temperature (°C),,,36-37.5,36-39,35-45
```

- `absolute` = `35-45`: the tablet refuses a value outside this range as a typo.
- `normal` = `36-37.5` and `noncritical` = `36-39`: stored in OpenMRS as the concept's normal
  and critical limits. They do not change what the tablet shows.

If the same concept is a `number` question in several forms, the last one in the file sets all
three ranges, even where its cells are blank. A blank `absolute` there removes the typo check, so
give the concept the same ranges in every form.

The ranges do not colour anything on the patient chart. To show out-of-range values in colour,
write a rule in the chart row's `css class` column (§5, "Colouring out-of-range values").
The `noncritical` range should contain the `normal` one (here 36–39 around 36–37.5).

A range is written `low-high` (a `..` separator also works, e.g. `36..37.5`). Leave the cell
blank to omit a range.

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

The brackets in the `section` cell set the kind of section:

| `section` value | Section kind | Renders as |
|-----------------|--------------|------------|
| `[[ ... ]]` (double brackets) | Fixed row | A fixed key/value row at the very top (e.g. admission date, location). |
| `[ ... ]` (single brackets)   | Tile row | A row of dashboard tiles (large values read at a glance). |
| plain text (no brackets)      | Grid section | A titled block of grid rows: one row per observation, time across the columns. |

The text inside the brackets is only a label: `[tiles]`, `[[fixed]]` and `[tiles 1]` all work.
A grid section's plain text is its visible heading (`Vitals`, `Symptoms`, …).

### Chart rows

Under a chart section, each row with a `type` and a `concept` is one chart item: a tile in a
tile row, or a grid row in a grid section. In the chart, `type` is a rendering hint (commonly
`number`, `text`, `select_one`, `yes_no`); it does not redefine the concept's data type. The concept must already have been defined by a form (or exist in the dictionary).

A grid row refers to exactly one concept. A tile or fixed row can combine several concepts,
separated by `;`, to summarise several observations in one tile:

```csv
,,,text,,900023;900024,Ebola tests,,,,,,"{1,select,664:NEG;703:POS;·} / {2,select,664:NEG;703:POS;·}"
```

Here `{1,...}` is the first concept (`900023`) and `{2,...}` is the second (`900024`).

### Styling columns

`css class` gives the tile or grid cell a class name. Like `format`, it uses the format
mini-language (§7), so the class can depend on the observed value. `css style` is plain CSS:
the tablet adds the text of every row's `css style` to one stylesheet for the whole chart page.
A rule written on one row therefore applies to every row. A "Category" tile shown green,
yellow or red:

```csv
,,,text,,900019,Category,,,,,,"{1,select,900041:Vert;900042:Jaune;900043:Rouge;–}",,"{1,select,900041:green;900042:yellow;900043:red}",".green { background: #7c7; } .yellow { background: #fc4; } .red { background: #f76; }"
```

- `format` gives the displayed text: `Vert`, `Jaune` or `Rouge`, or `–` if unobserved.
- `css class` gives `green`, `yellow` or `red`, depending on the coded value.
- `css style` holds the CSS that defines those classes.

### Colouring out-of-range values

The chart already has two colours for values outside their range:

| Class | Colour | Use it for |
|-------|--------|------------|
| `abnormal` | orange | outside the normal range |
| `critical` | red | outside the non-critical range |

From the next update of the tablet app, both colours are darker and bold.

To use them, put a `select` rule in the row's `css class` column that compares the value with
the row's range. Temperature, normal 36–37.5, with fever above 37.5 and high fever above 39:

```csv
,,,number,,5088,Temp. (°C),,,36-37.5,37.6-39,32-45,#.0°,,"{1,select,<36:abnormal;>39:critical;>37.5:abnormal}"
```

- 35.5 → orange, 37.0 → no colour, 38.2 → orange, 40.1 → red.

Potassium, normal 3.8–5, non-critical 2.4–6.6:

```
{1,select,<2.4:critical;<3.8:abnormal;>6.6:critical;>5:abnormal}
```

A lab with only a normal range, haemoglobin 10.5–18.5:

```
{1,select,<10.5:abnormal;>18.5:abnormal}
```

How to write the rule:

- The conditions are checked from left to right and the first one that matches wins, so put
  the critical bound before the abnormal one on each side.
- A value inside the normal range matches nothing and keeps the normal colour. The bounds
  themselves count as normal: with `<36` and `>37.5`, both 36 and 37.5 are normal.
- **Every branch needs a condition.** Do not end the rule with a branch that has none
  (`…;critical`): that branch is also used for a tile with no observation, which would then
  show as critical.
- The rule copies the numbers from the range columns. When you change a range, change the rule
  on the chart row too.
- Do not use `[` or `]` in a rule: the tablet removes anything in square brackets, as it does
  for translations.

Things to know:

- A grid cell shows the latest value recorded in that time slot, and its colour follows that
  value. An earlier out-of-range reading in the same slot does not colour the cell.
- A `number` row with no `format` shows whole numbers, so K+ 3.75 would show as "4" in orange.
  Give such rows the format `0.##`, which shows up to two decimals (3.75, 9, 140).
- The detail pop-up that opens when you tap a cell is not coloured.
- After applying a changed profile, re-sync each tablet before checking the colours.

---

## 6. Labels and translations

Any label (`label`, `option label`, section text) can carry translations as
`[<lang>:<text>]` suffixes:

```
Temperature (°C) [fr:Température (C)]
```

The text before the brackets is the default (here English); `[fr:...]` gives the French text.

Because the CSV is comma-separated, wrap any label that contains a comma in double quotes:

```csv
,,,number,,5085,"BP, systolic (mmHg) [fr:TA, systolique (mmHg)]",,,100-160,80-200,0-300
```

---

## 7. The format mini-language (chart `format`, `caption format`, `css class`)

The text in these three chart columns is a template in a small format language. It is based
on Java's `MessageFormat`, but it counts from 1.

### Referencing values

`{1}` is the first concept of the row, `{2}` the second, and so on, in the order of the
`;`-separated IDs in the `concept` column. A bare number pattern such as `#.0` is short for
formatting the first value as a number.

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

### `select`

`select` chooses the output according to the value. It works in two ways.

**By coded value**: `id:text` pairs separated by `;`, with an optional final fallback:

```
{1,select,664:NEG;703:POS;·}
```
This shows `NEG` if the value is concept 664, `POS` if 703, and `·` otherwise.

**By condition**: with comparison operators (`<`, `<=`, `>`, `>=`, `=`):

```
{1,select,>39:High fever;>37.5:Fever;Normal}
```
This shows `High fever` above 39, `Fever` above 37.5, and `Normal` otherwise.

A branch with no condition (like `Normal` above) is the fallback. It is also used when nothing
has been observed, so this example shows `Normal` for a patient with no temperature recorded.
`select` has no condition for "no value": `=:` does not test for it, and on a number it
matches the value 0. A branch's text can contain further `{...}` placeholders, so one select
can sit inside another.

### Worked examples from `bunia.csv`

```csv
,,,text,,1640,Admission,,,,,,"Jour {1,day_number,#}","{1,time,d MMM HH:mm}"
```
Tile: main line `Jour 3`, caption `4 Aug 09:15`. Concept 1640 is recorded by registration and again
by the Admission form; the tile and the chart's day numbers use the Admission form's date when there
is one, and the registration time only when there is not.

```csv
,,,text,,buendia_concept_placement,Location,,,,,,"{1,location}","{2,select,=:;Lit {2,text}}"
```
Tile: the patient's location name, with the caption `Lit 12` when a bed is recorded and
`Lit –` when none is.

```csv
,,,text,,900020;900021,Sample taken,,,,,,"{2,select,1065:Prélevé (2);:{1,select,1065:Prélevé (1);:Aucun}}"
```
Combines two yes/no concepts. It shows `Prélevé (2)` if the second sample was taken,
otherwise `Prélevé (1)` if the first was, otherwise `Aucun`.

An invalid format string does not crash the app: it is shown as written, prefixed with `??`,
so you can find the mistake on the tablet.

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
tab,title,section,type,required,concept,label,option concept,option label,normal,noncritical,absolute,format,caption format,css class,css style,script
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
,,,number,,5088,Temperature,,,,,,#.0,,"{1,select,<36:critical;>39:critical;>37.5:abnormal}"
```
