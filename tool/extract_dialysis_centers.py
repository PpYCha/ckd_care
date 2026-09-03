"""One-time generator: parse the PhilHealth accredited-dialysis-clinics PDF
into assets/data/dialysis_centers.json. Dev tool only — not shipped in the app.
Run:  python tool/extract_dialysis_centers.py
Requires: pip install pdfplumber
"""
import pdfplumber, json, re, os

SRC = os.environ.get("DIALYSIS_PDF",
    os.path.expanduser("~/Documents/Accreditted Dialysis Center FDC_073126.pdf"))
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "data",
                   "dialysis_centers.json")

REGIONS = ["CORDILLERA ADMINISTRATIVE REGION", "REGION I", "REGION II",
    "REGION III", "NATIONAL CAPITAL REGION & RIZAL", "REGION IV-A", "REGION IV-B",
    "REGION V", "REGION VI", "REGION VII", "REGION VIII", "REGION IX", "REGION X",
    "REGION XI", "REGION XII", "CARAGA REGION", "BANGSAMORO AUTONOMOUS REGION OF"]
REGION_LABEL = {r: r for r in REGIONS}
REGION_LABEL["BANGSAMORO AUTONOMOUS REGION OF"] = "BANGSAMORO AUTONOMOUS REGION (BARMM)"
SKIP_FRAG = {"MUSLIM MINDANAO"}  # BARMM header 2nd line — not a facility name

DATE = re.compile(r'^\d{1,2}/\d{1,2}/\d{4}$')
PHONE = re.compile(r'^[\d\(\)\/\s\.\-;+]+$')

def classify(t, x0):
    if '@' in t: return 'email'
    if DATE.match(t): return 'expire'
    if x0 >= 780 and t.strip(';') in ('P', 'G'): return 'sec'
    digits = sum(c.isdigit() for c in t)
    if x0 < 355 and PHONE.match(t) and digits >= 6: return 'tel'
    if x0 < 285: return 'name'
    if 285 <= x0 < 420: return 'tel' if (PHONE.match(t) and digits >= 3) else 'name'
    if 420 <= x0 < 672: return 'street'
    if 672 <= x0 < 749: return 'muni'
    if 749 <= x0 < 782: return 'expire'
    return 'street'

def main():
    pdf = pdfplumber.open(SRC)
    records = []
    region = province = None
    for page in pdf.pages:
        words = page.extract_words(use_text_flow=False)
        lines = {}
        for w in words:
            lines.setdefault(round(w['top'] / 3.0), []).append(w)
        parsed = []
        for k in sorted(lines):
            ws = sorted(lines[k], key=lambda w: w['x0'])
            top = min(w['top'] for w in ws); x0f = ws[0]['x0']
            joined = ' '.join(w['text'] for w in ws)
            if (joined.startswith('NAME OF HEALTH') or
                    joined.startswith('List of Accredited') or
                    joined.startswith('Page ')):
                continue
            cells = {}; toks = ws[:]
            num = None
            if toks and re.fullmatch(r'\d+', toks[0]['text']) and toks[0]['x0'] < 45:
                num = int(toks[0]['text']); toks = toks[1:]
            for w in toks:
                c = classify(w['text'], w['x0'])
                cells[c] = (cells.get(c, '') + ' ' + w['text']).strip()
            parsed.append((top, x0f, num, cells, joined.strip()))
        events = []
        for top, x0f, num, cells, joined in parsed:
            other = any(cells.get(c) for c in
                        ('tel', 'email', 'street', 'muni', 'expire', 'sec'))
            if x0f < 31 and num is None and joined.isupper() and not other:
                events.append(('hdr', top, joined)); continue
            if num is not None:
                events.append(('anc', top, num, cells))
            else:
                events.append(('frag', top, cells, joined))
        anchors = []
        for e in events:
            if e[0] == 'hdr':
                h = e[2]
                reg = next((r for r in sorted(REGIONS, key=len, reverse=True)
                            if h == r or re.match(re.escape(r) + r'(?![A-Z0-9])', h)), None)
                if reg: region = REGION_LABEL[reg]; province = None
                else: province = h
            elif e[0] == 'anc':
                _, top, num, cells = e
                anchors.append({'num': num, 'region': region, 'province': province,
                    '_name': [(top, cells.get('name', ''))] if cells.get('name') else [],
                    '_street': [(top, cells.get('street', ''))] if cells.get('street') else [],
                    'tels': [cells['tel']] if cells.get('tel') else [],
                    'emails': [cells['email']] if cells.get('email') else [],
                    'municipality': cells.get('muni', ''),
                    'expiry': [cells['expire']] if cells.get('expire') else [],
                    'sec': cells.get('sec', ''), '_top': top})
        if not anchors: continue
        tops = [a['_top'] for a in anchors]
        near = lambda top: anchors[min(range(len(tops)),
                                       key=lambda i: abs(tops[i] - top))]
        for e in events:
            if e[0] != 'frag': continue
            _, top, cells, joined = e
            if joined in SKIP_FRAG: continue
            a = near(top)
            if cells.get('name'): a['_name'].append((top, cells['name']))
            if cells.get('street'): a['_street'].append((top, cells['street']))
            if cells.get('tel'): a['tels'].append(cells['tel'])
            if cells.get('email'): a['emails'].append(cells['email'])
            if cells.get('expire'): a['expiry'].append(cells['expire'])
            if cells.get('muni') and not a['municipality']:
                a['municipality'] = cells['muni']
            if cells.get('sec') and not a['sec']: a['sec'] = cells['sec']
        for a in anchors:
            name = ' '.join(t for _, t in sorted(a['_name']) if t).strip()
            name = re.sub(r'\s*/\s*$', '', name).strip(' /')  # strip stray trailing slash
            a['name'] = name
            a['street'] = ' '.join(t for _, t in sorted(a['_street']) if t).strip(' /')
            for k in ('_name', '_street', '_top'): a.pop(k)
            records.append(a)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(records, open(OUT, 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    regions = {}
    for r in records: regions.setdefault(r['region'], set()).add(r['province'])
    print(f"records: {len(records)}  regions: {len(regions)}")
    assert len(records) == 959, f"expected 959 records, got {len(records)}"
    assert len(regions) == 17, f"expected 17 regions, got {len(regions)}"
    assert all(r['name'] for r in records), "some records have an empty name"

if __name__ == '__main__':
    main()
