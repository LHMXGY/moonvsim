# -*- coding: utf-8 -*-
"""Convert docs/PROJECT_PLAN.zh.md into a formatted .docx project plan."""
import pathlib
import re
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = str(ROOT / "docs" / "PROJECT_PLAN.zh.md")
DST = str(ROOT / "docs" / "PROJECT_PLAN.zh.docx")

BODY_FONT = "Microsoft YaHei"
MONO_FONT = "Consolas"
ACCENT = RGBColor(0x1F, 0x4E, 0x79)
GREY = RGBColor(0x59, 0x59, 0x59)


def set_font(run, name=BODY_FONT, size=None, bold=None, color=None, mono=False):
    run.font.name = MONO_FONT if mono else name
    rpr = run._element.get_or_add_rPr()
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = OxmlElement("w:rFonts")
        rpr.append(rfonts)
    rfonts.set(qn("w:eastAsia"), name)
    rfonts.set(qn("w:ascii"), MONO_FONT if mono else name)
    rfonts.set(qn("w:hAnsi"), MONO_FONT if mono else name)
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.font.bold = bold
    if color is not None:
        run.font.color.rgb = color


def shade(element, hexcolor):
    tcpr = element.get_or_add_tcPr() if hasattr(element, "get_or_add_tcPr") else element
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hexcolor)
    tcpr.append(shd)


def para_shade(p, hexcolor):
    ppr = p._element.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hexcolor)
    ppr.append(shd)


def add_page_number_footer(section):
    p = section.footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run()
    set_font(run, size=9, color=GREY)
    fld_begin = OxmlElement("w:fldChar")
    fld_begin.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = " PAGE "
    fld_end = OxmlElement("w:fldChar")
    fld_end.set(qn("w:fldCharType"), "end")
    run._r.append(fld_begin)
    run._r.append(instr)
    run._r.append(fld_end)


TOKEN = re.compile(r"(\*\*.+?\*\*|`[^`]+`|<https?://[^>]+>)")


def display_len(s):
    return sum(2 if ord(c) > 0x2E80 else 1 for c in s)


def add_inline(p, text, size=10.5, color=None, bold_all=False):
    for part in TOKEN.split(text):
        if not part:
            continue
        if part.startswith("**") and part.endswith("**"):
            r = p.add_run(part[2:-2])
            set_font(r, size=size, bold=True, color=color)
        elif part.startswith("`") and part.endswith("`"):
            r = p.add_run(part[1:-1])
            set_font(r, size=size - 0.5, mono=True, color=ACCENT)
        elif part.startswith("<http"):
            url = part[1:-1]
            r = p.add_run(url)
            set_font(r, size=size, color=RGBColor(0x1F, 0x4E, 0x79))
            r.font.underline = True
        else:
            r = p.add_run(part)
            set_font(r, size=size, bold=bold_all or None, color=color)


def style_body(p):
    pf = p.paragraph_format
    pf.space_before = Pt(3)
    pf.space_after = Pt(3)
    pf.line_spacing = 1.35


def fixed_layout(table, width_cm):
    tblPr = table._tbl.tblPr
    layout = OxmlElement("w:tblLayout")
    layout.set(qn("w:type"), "fixed")
    tblPr.append(layout)
    tblW = OxmlElement("w:tblW")
    tblW.set(qn("w:w"), str(int(width_cm * 567)))
    tblW.set(qn("w:type"), "dxa")
    tblPr.append(tblW)


def mark_header_row(row):
    trPr = row._tr.get_or_add_trPr()
    hdr = OxmlElement("w:tblHeader")
    hdr.set(qn("w:val"), "true")
    trPr.append(hdr)


def no_split(row):
    trPr = row._tr.get_or_add_trPr()
    cs = OxmlElement("w:cantSplit")
    cs.set(qn("w:val"), "true")
    trPr.append(cs)


def main():
    text = open(SRC, encoding="utf-8").read()
    lines = text.split("\n")

    doc = Document()
    sec = doc.sections[0]
    sec.page_width = Cm(21.0)
    sec.page_height = Cm(29.7)
    sec.top_margin = Cm(2.2)
    sec.bottom_margin = Cm(2.2)
    sec.left_margin = Cm(2.4)
    sec.right_margin = Cm(2.4)
    add_page_number_footer(sec)

    normal = doc.styles["Normal"]
    normal.font.size = Pt(10.5)
    normal.font.name = BODY_FONT
    normal.element.rPr.rFonts.set(qn("w:eastAsia"), BODY_FONT)

    # ---- cover -------------------------------------------------------
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(70)
    r = p.add_run("moonvsim 项目计划书")
    set_font(r, size=30, bold=True, color=ACCENT)

    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("2026 MoonBit 黑客松 · 十一月赛（第二赛季度 11 月—次年 1 月）")
    set_font(r, size=12, color=GREY)

    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("MoonBit 原生四态事件驱动 Verilog RTL 仿真内核")
    set_font(r, size=12, bold=True, color=GREY)
    p.paragraph_format.space_after = Pt(40)

    # ---- body --------------------------------------------------------
    i = 0
    n = len(lines)
    pending_table = []

    def flush_table():
        nonlocal pending_table
        if not pending_table:
            return
        rows = []
        for ln in pending_table:
            cells = [c.strip() for c in ln.strip().strip("|").split("|")]
            if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
                continue
            rows.append(cells)
        pending_table = []
        if not rows:
            return
        ncol = max(len(r) for r in rows)
        weights = []
        for ci in range(ncol):
            w = max((display_len(r[ci]) if ci < len(r) else 0) for r in rows)
            weights.append(max(w, 6))
        total = sum(weights)
        widths = [max(2.3, 16.2 * w / total) for w in weights]
        scale = 16.2 / sum(widths)
        widths = [w * scale for w in widths]
        table = doc.add_table(rows=0, cols=ncol)
        table.style = "Table Grid"
        table.alignment = WD_TABLE_ALIGNMENT.CENTER
        table.autofit = False
        fixed_layout(table, 16.2)
        for ci in range(ncol):
            table.columns[ci].width = Cm(widths[ci])
        for ri, row in enumerate(rows):
            cells = table.add_row().cells
            for ci in range(ncol):
                val = row[ci] if ci < len(row) else ""
                cell = cells[ci]
                cell.width = Cm(widths[ci])
                cell.text = ""
                cp = cell.paragraphs[0]
                cp.paragraph_format.space_before = Pt(1)
                cp.paragraph_format.space_after = Pt(1)
                cp.paragraph_format.line_spacing = 1.1
                add_inline(cp, val, size=9, bold_all=(ri == 0))
                if ri == 0:
                    shade(cell._tc, "E8EEF5")
            if ri == 0:
                mark_header_row(table.rows[0])
            no_split(table.rows[-1])
        doc.add_paragraph().paragraph_format.space_after = Pt(2)

    while i < n:
        ln = lines[i]
        stripped = ln.rstrip()

        if stripped.startswith("|"):
            pending_table.append(stripped)
            i += 1
            continue
        flush_table()

        if stripped == "# moonvsim 项目计划书" or stripped.startswith("**2026 MoonBit 黑客松 · 十一月赛"):
            i += 1
            continue

        if stripped == "---":
            i += 1
            continue

        if stripped.startswith("```"):
            i += 1
            block = []
            while i < n and not lines[i].startswith("```"):
                block.append(lines[i])
                i += 1
            i += 1
            for bl in block:
                p = doc.add_paragraph()
                pf = p.paragraph_format
                pf.space_before = Pt(0)
                pf.space_after = Pt(0)
                pf.line_spacing = 1.0
                pf.left_indent = Cm(0.4)
                r = p.add_run(bl if bl.strip() else " ")
                set_font(r, size=8.5, mono=True, color=RGBColor(0x33, 0x33, 0x33))
                para_shade(p, "F4F5F7")
            doc.add_paragraph().paragraph_format.space_after = Pt(2)
            continue

        if stripped.startswith("> "):
            p = doc.add_paragraph()
            style_body(p)
            pf = p.paragraph_format
            pf.left_indent = Cm(0.6)
            pf.space_before = Pt(6)
            pf.space_after = Pt(6)
            add_inline(p, stripped[2:], size=10.5, color=RGBColor(0x33, 0x4E, 0x68))
            para_shade(p, "F7F9FB")
            i += 1
            continue

        m = re.match(r"^(#{2,4})\s+(.*)$", stripped)
        if m:
            level = len(m.group(1)) - 1  # ## -> 1, ### -> 2
            heading = m.group(2)
            if heading.startswith("0. "):
                doc.add_page_break()
            p = doc.add_heading(level=level)
            p.paragraph_format.space_before = Pt(14 if level == 1 else 10)
            p.paragraph_format.space_after = Pt(6)
            r = p.add_run(heading)
            size = {1: 16, 2: 13, 3: 11.5}.get(level, 11)
            set_font(r, size=size, bold=True, color=ACCENT)
            i += 1
            continue

        m = re.match(r"^[-*]\s+(.*)$", stripped)
        if m:
            p = doc.add_paragraph(style="List Bullet")
            style_body(p)
            p.paragraph_format.left_indent = Cm(0.75)
            add_inline(p, m.group(1))
            i += 1
            continue

        m = re.match(r"^(\d+)\.\s+(.*)$", stripped)
        if m:
            p = doc.add_paragraph(style="List Number")
            style_body(p)
            p.paragraph_format.left_indent = Cm(0.75)
            add_inline(p, m.group(2))
            i += 1
            continue

        if stripped.strip() == "":
            i += 1
            continue

        p = doc.add_paragraph()
        style_body(p)
        add_inline(p, stripped.strip())
        i += 1

    flush_table()
    doc.save(DST)
    print("saved", DST)


if __name__ == "__main__":
    main()
