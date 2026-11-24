"""Builds data/templates/IWRS_events_and_theses_template.xlsx (needs: pip install openpyxl).

The template is what IWRS fills in for the statistics that have no database: talks, symposia,
workshops, panels and other academic events on invertebrate sentience or welfare, and
PhD and Master's theses. Dropdown lists keep the values clean so that
scripts/08_build_events_data.R can count them and the dashboard can show them.
Run:  python tools/build_events_template.py
"""
from openpyxl import Workbook
from openpyxl.comments import Comment
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

LISTS = {
    "item_type": ["Talk", "Symposium", "Workshop", "Panel", "Other event"],
    "venue_type": ["Major conference", "Other conference", "Standalone event"],
    "event_series": ["ESA annual meeting", "International Congress of Entomology", "Insects as Food and Feed (IAFF)",
                     "Other major conference", "Not applicable"],
    "taxon_scope": ["Insects", "Crustaceans", "Cephalopods", "Other invertebrates", "Invertebrates (general)", "Multiple groups"],
    "topic": ["Welfare", "Sentience", "Welfare and sentience", "Related (pain, cognition, ethics, ...)"],
    "format": ["In person", "Online", "Hybrid"],
    "degree": ["PhD", "Master's"],
}
EVENT_COLS = [  # (header, width, list key or None, help text)
    ("item_type", 14, "item_type", "What the row is. Talk = one presentation. Symposium, Workshop, Panel = a dedicated session. Other event = a standalone seminar, webinar, meeting or conference."),
    ("year", 8, None, "Year it took place (4 digits, 1990 to 2035)."),
    ("start_date", 13, None, "Optional. Format YYYY-MM-DD."),
    ("event_name", 34, None, "Name of the conference or event, for example 'Entomology 2025'."),
    ("venue_type", 18, "venue_type", "Major conference = ESA, International Congress of Entomology, Insects as Food and Feed, or another large meeting IWRS counts as major. Standalone event = organised on its own."),
    ("event_series", 30, "event_series", "The conference series, if it is one of those listed. Otherwise 'Other major conference' or 'Not applicable'."),
    ("country", 16, None, "Country where it took place, or 'Online'."),
    ("title", 50, None, "Title of the talk, session or event, as in the public programme."),
    ("taxon_scope", 22, "taxon_scope", "Main animal group."),
    ("topic", 28, "topic", "Welfare, sentience, both, or a related topic."),
    ("format", 12, "format", "In person, online or hybrid."),
    ("source_url", 40, None, "Link to the public programme or announcement. Do not use private links."),
    ("notes", 30, None, "Anything useful. Do not write names of people."),
]
THESIS_COLS = [
    ("degree", 11, "degree", "PhD or Master's."),
    ("year", 8, None, "Year of the defence or deposit (4 digits)."),
    ("country", 16, None, "Country of the university."),
    ("institution", 34, None, "University. Public information only."),
    ("title", 55, None, "Title of the thesis."),
    ("language", 12, None, "Language of the thesis, for example English or Portuguese."),
    ("taxon_scope", 22, "taxon_scope", "Main animal group."),
    ("topic", 28, "topic", "Welfare, sentience, both, or a related topic."),
    ("repository_url", 40, None, "Link to the public repository entry. Do not use private links."),
    ("notes", 30, None, "Anything useful. Do not write names of people."),
]
README = [
    ("Insect and invertebrate welfare research: events and theses", "title"),
    ("", None),
    ("What this file is for", "h"),
    ("Some statistics for the annual report cannot be downloaded from a database: talks and sessions at conferences, other academic events, and theses. IWRS fills them in here, once a year or whenever something is found. The dashboard reads this file, so the more regular the entries, the better it works.", None),
    ("", None),
    ("How to fill it", "h"),
    ("1. Use the sheet 'Events' for talks, symposia, workshops, panels and other events, and the sheet 'Theses' for PhD and Master's theses.", None),
    ("2. One row per item. Pick values from the dropdown lists; do not type your own.", None),
    ("3. Keep the header row as it is. Do not rename, move or delete columns.", None),
    ("4. Use only public information, and add the link in source_url or repository_url when there is one.", None),
    ("5. Do NOT write names of speakers, authors or supervisors, nor emails or other personal data.", None),
    ("6. The sheet 'Examples' shows how a filled row looks. Delete nothing from it; it is not read.", None),
    ("", None),
    ("What is counted", "h"),
    ("Talks at major conferences per year: rows with item_type = Talk and venue_type = Major conference.", None),
    ("Symposia, workshops and panels at major conferences per year: item_type = Symposium, Workshop or Panel and venue_type = Major conference.", None),
    ("Academic events of any kind per year: rows with item_type = Symposium, Workshop, Panel or Other event, at any venue (talks are not counted here).", None),
    ("Theses per year: rows of the sheet 'Theses', by degree.", None),
    ("The topic must be invertebrate sentience or welfare. If a talk is only loosely related, choose the topic 'Related' so it can be told apart.", None),
    ("", None),
    ("Where to save it", "h"),
    ("Save the filled file as data/curated/IWRS_events_and_theses.xlsx in the project folder, then run scripts/08_build_events_data.R. It checks every row and lists the problems it finds.", None),
]
EXAMPLES = [
    ["Talk", 2025, "2025-11-09", "Entomology 2025", "Major conference", "ESA annual meeting", "United States", "Welfare of farmed insects: a research agenda", "Insects", "Welfare", "In person", "https://example.org/programme", "EXAMPLE, not a real entry"],
    ["Symposium", 2025, "2025-11-10", "Entomology 2025", "Major conference", "ESA annual meeting", "United States", "Insect sentience: evidence and implications", "Insects", "Sentience", "In person", "", "EXAMPLE, not a real entry"],
    ["Other event", 2024, "2024-06-03", "Invertebrate Sentience Workshop", "Standalone event", "Not applicable", "Online", "Workshop on pain in decapod crustaceans", "Crustaceans", "Welfare and sentience", "Online", "", "EXAMPLE, not a real entry"],
]
THESIS_EXAMPLE = ["PhD", 2023, "Brazil", "Example University", "Behavioural indicators of welfare in farmed crickets", "English", "Insects", "Welfare", "", "EXAMPLE, not a real entry"]

HEAD_FILL = PatternFill("solid", start_color="4D6E66")      # same green as the site's brand band
HEAD_FONT = Font(bold=True, color="FFFFFF")


def sheet(wb, name, cols, rows=None, first=False):
    ws = wb.active if first else wb.create_sheet(name)
    ws.title = name
    for i, (h, w, _, tip) in enumerate(cols, 1):
        c = ws.cell(row=1, column=i, value=h)
        c.fill, c.font = HEAD_FILL, HEAD_FONT
        c.alignment = Alignment(vertical="center")
        c.comment = Comment(tip, "IWRS template")
        ws.column_dimensions[get_column_letter(i)].width = w
    ws.freeze_panes = "A2"
    for r in rows or []:
        ws.append(r)
    return ws


def validations(ws, cols, lists_ws, keys, last_row=2000):
    for i, (h, _, key, _) in enumerate(cols, 1):
        col = get_column_letter(i)
        if key:
            n = len(LISTS[key]); letter = get_column_letter(keys.index(key) + 1)
            dv = DataValidation(type="list", formula1=f"=Lists!${letter}$2:${letter}${n + 1}", allow_blank=True,
                                showErrorMessage=True, errorTitle="Choose from the list", error="Please pick one of the values in the dropdown.")
        elif h == "year":
            dv = DataValidation(type="whole", operator="between", formula1="1990", formula2="2035", allow_blank=True,
                                showErrorMessage=True, errorTitle="Year", error="Use a 4-digit year between 1990 and 2035.")
        else:
            continue
        ws.add_data_validation(dv); dv.add(f"{col}2:{col}{last_row}")


wb = Workbook()
rd = wb.active; rd.title = "README"; rd.column_dimensions["A"].width = 120
for text, kind in README:
    rd.append([text]); c = rd.cell(row=rd.max_row, column=1)
    c.alignment = Alignment(wrap_text=True, vertical="top")
    if kind == "title": c.font = Font(bold=True, size=15)
    if kind == "h": c.font = Font(bold=True, size=12, color="4D6E66")
keys = list(LISTS)
lists_ws = wb.create_sheet("Lists")
for j, k in enumerate(keys, 1):
    lists_ws.cell(row=1, column=j, value=k).font = Font(bold=True)
    for i, v in enumerate(LISTS[k], 2): lists_ws.cell(row=i, column=j, value=v)
    lists_ws.column_dimensions[get_column_letter(j)].width = 36
ev = sheet(wb, "Events", EVENT_COLS); validations(ev, EVENT_COLS, lists_ws, keys)
th = sheet(wb, "Theses", THESIS_COLS); validations(th, THESIS_COLS, lists_ws, keys)
ex = sheet(wb, "Examples", EVENT_COLS, EXAMPLES)
ex.append([]); ex.append(["Thesis example (sheet 'Theses'):"]); ex.append([c[0] for c in THESIS_COLS]); ex.append(THESIS_EXAMPLE)
wb.move_sheet("Lists", offset=len(wb.sheetnames))      # lists last
wb.save("data/templates/IWRS_events_and_theses_template.xlsx")
print("sheets:", wb.sheetnames)
