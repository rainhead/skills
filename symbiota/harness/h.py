#!/usr/bin/env python3
"""Harness: drives Symbiota's real upload pages with a logged-in session, builds DwC-A zips, dumps rows."""
import io, re, sys, zipfile, subprocess, html, os, json
from html.parser import HTMLParser
import requests

W = os.environ.get('SYMTEST_DIR', os.path.dirname(os.path.abspath(__file__)))
B = os.environ.get('SYMTEST_URL', 'http://127.0.0.1:18181/sym')
S = requests.Session()
LOGDIR = W + '/logs'
os.makedirs(LOGDIR, exist_ok=True)
TERM = 'http://rs.tdwg.org/dwc/terms/'

def post(url, **kw):
    """POST with the session and raise on an HTTP error, so that a failed request cannot pass for an empty page."""
    r = S.post(url, **kw)
    if r.status_code >= 400:
        raise RuntimeError('POST %s answered HTTP %d' % (url, r.status_code))
    return r

def login():
    """Sign in as the baseline's administrator. Raises unless the portal answered 200 or 302 and set a session cookie."""
    r = S.post(B + '/profile/index.php', data={'login': 'admin', 'password': 'admin', 'action': 'login'}, allow_redirects=False)
    if r.status_code not in (200, 302):
        raise RuntimeError('login: the portal answered HTTP %d' % r.status_code)
    if not any(c.name == 'PHPSESSID' for c in S.cookies):
        raise RuntimeError('login: the portal set no session cookie')
    # A cookie is not a sign-in. The profile page redirects a signed-out visitor to the sign-in page, so a plain 200 shows the session is signed in.
    p = S.get(B + '/profile/viewprofile.php', allow_redirects=False)
    if p.status_code != 200:
        raise RuntimeError('login: a session cookie is not a sign-in (the profile page answered HTTP %d)' % p.status_code)

def text(h):
    h = re.sub(r'<script.*?</script>', '', h, flags=re.S)
    h = re.sub(r'<style.*?</style>', '', h, flags=re.S)
    h = re.sub(r'</(li|div|tr|p|h\d)>', '\n', h)
    h = re.sub(r'<[^>]+>', ' ', h)
    h = html.unescape(h)
    return '\n'.join(l.strip() for l in h.split('\n') if l.strip() and not l.strip().startswith('Notice :  ob_flush'))

class FormParser(HTMLParser):
    def __init__(self, name):
        super().__init__(); self.name = name; self.inform = False; self.fields = []; self.sel = None; self.opts = []; self.found = False
    def handle_starttag(self, tag, a):
        a = dict(a)
        if tag == 'form':
            if a.get('name') == self.name:
                self.inform = True; self.found = True
            return
        if not self.inform: return
        if tag == 'input':
            t = (a.get('type') or 'text').lower(); n = a.get('name')
            if not n or t in ('submit', 'button', 'file', 'image'): return
            if t in ('checkbox', 'radio') and 'checked' not in a: return
            if 'disabled' in a: return
            self.fields.append((n, a.get('value', 'on' if t == 'checkbox' else '')))
        elif tag == 'select':
            self.sel = a.get('name'); self.opts = []
        elif tag == 'option' and self.sel is not None:
            self.opts.append((a.get('value'), 'selected' in a))
    def handle_endtag(self, tag):
        if tag == 'form': self.inform = False
        if tag == 'select' and self.sel is not None:
            v = ''
            if self.opts:
                v = self.opts[0][0] or ''
                for o, s in self.opts:
                    if s: v = o or ''
            self.fields.append((self.sel, v)); self.sel = None

def form_fields(htmltxt, name):
    p = FormParser(name); p.feed(htmltxt)
    return p.fields if p.found else None

def make_zip(path, core_cols, core_rows, ident_cols=None, ident_rows=None, id_col='id'):
    """core_cols: list of column names (first is the id column). Rows are lists. Terms use dwc namespace."""
    def meta():
        x = ['<?xml version="1.0" encoding="UTF-8"?>', '<archive xmlns="http://rs.tdwg.org/dwc/text/" metadata="eml.xml">']
        x.append('<core encoding="UTF-8" fieldsTerminatedBy="\\t" linesTerminatedBy="\\n" fieldsEnclosedBy="" ignoreHeaderLines="1" rowType="http://rs.tdwg.org/dwc/terms/Occurrence"><files><location>occurrences.tsv</location></files><id index="0"/>')
        for i, c in enumerate(core_cols):
            if i == 0: continue
            x.append('<field index="%d" term="%s"/>' % (i, term(c)))
        x.append('</core>')
        if ident_cols:
            x.append('<extension encoding="UTF-8" fieldsTerminatedBy="\\t" linesTerminatedBy="\\n" fieldsEnclosedBy="" ignoreHeaderLines="1" rowType="http://rs.tdwg.org/dwc/terms/Identification"><files><location>identifications.tsv</location></files><coreid index="0"/>')
            for i, c in enumerate(ident_cols):
                if i == 0: continue
                x.append('<field index="%d" term="%s"/>' % (i, term(c)))
            x.append('</extension>')
        x.append('</archive>')
        return '\n'.join(x)
    def term(c):
        if c == 'eventDate2': return 'https://symbiota.org/terms/eventDate2'
        if c == 'identificationIsCurrent': return 'https://symbiota.org/terms/identificationIsCurrent'
        if ':' in c: return 'https://symbiota.org/terms/' + c
        return TERM + c
    def tsv(cols, rows):
        for v in [c for c in cols] + [v for r in rows for v in r]:
            if v is not None and any(ch in str(v) for ch in '\t\n\r'):
                raise ValueError('value %r holds a tab or line break, which would break the tab-separated row' % (v,))
        return '\n'.join(['\t'.join(cols)] + ['\t'.join('' if v is None else str(v) for v in r) for r in rows]) + '\n'
    with zipfile.ZipFile(path, 'w') as z:
        z.writestr('meta.xml', meta())
        z.writestr('eml.xml', '<?xml version="1.0"?><eml:eml xmlns:eml="eml://ecoinformatics.org/eml-2.1.1" packageId="x" system="x"><dataset><title>t</title></dataset></eml:eml>')
        z.writestr('occurrences.tsv', tsv(core_cols, core_rows))
        if ident_cols: z.writestr('identifications.tsv', tsv(ident_cols, ident_rows))

def upload(label, collid, zippath, importident=True, matchcat=True, matchothercat=False, versiondata=False, uploadtype=6, mapfix=None, dry=False):
    """Drive specuploadmap.php (analyze) -> specuploadprocessor.php (Start Upload) -> final transfer.
    dry=True stops at the Pending Data Transfer Report: nothing is written to the collection, the upload stays staged."""
    with open(zippath, 'rb') as f:
        r = post(B + '/collections/admin/specuploadmap.php',
                   data={'collid': collid, 'uploadtype': uploadtype, 'uspid': 0, 'automap': 1, 'action': 'Analyze File', 'MAX_FILE_SIZE': 100000000},
                   files={'uploadfile': ('dwca.zip', f, 'application/zip')})
    open('%s/%s.1-analyze.html' % (LOGDIR, label), 'w').write(r.text)
    fields = form_fields(r.text, 'dwcauploadform')
    if fields is None:
        raise RuntimeError('ANALYZE FAILED: ' + text(r.text)[-600:])
    fields = [(k, v) for k, v in fields if k not in ('matchcatnum', 'matchothercatnum', 'importident')]
    if mapfix: fields = mapfix(fields)
    if importident: fields.append(('importident', '1'))
    if matchcat: fields.append(('matchcatnum', '1'))
    if matchothercat: fields.append(('matchothercatnum', '1'))
    if versiondata: fields.append(('versiondata', '1'))
    fields.append(('action', 'Start Upload'))
    r2 = post(B + '/collections/admin/specuploadprocessor.php', data=fields)
    open('%s/%s.2-start.html' % (LOGDIR, label), 'w').write(r2.text)
    t2 = text(r2.text)
    ff = form_fields(r2.text, 'finaltransferform')
    out = '== START UPLOAD\n' + t2[t2.find('Upload Status'):]
    if ff is None:
        raise RuntimeError('no transfer form after Start Upload, so nothing was transferred. The page said: ' + out[-1500:])
    if dry:
        print(out[-1500:]); return out
    ff = [(k, v) for k, v in ff] + [('action', 'activateOccurrences')]
    r3 = post(B + '/collections/admin/specuploadprocessor.php', data=ff)
    open('%s/%s.3-final.html' % (LOGDIR, label), 'w').write(r3.text)
    t3 = text(r3.text)
    out += '\n== FINAL TRANSFER\n' + t3[t3.find('Starting Stage'):] if 'Starting Stage' in t3 else '\n== FINAL TRANSFER (raw)\n' + t3[-2000:]
    open('%s/%s.txt' % (LOGDIR, label), 'w').write(out)
    if 'Upload Procedure Complete' not in t3:
        raise RuntimeError('the transfer page did not end with "Upload Procedure Complete", so the transfer may not have finished. It said: ' + t3[-1500:])
    keep=[l for l in out.split('\n') if re.search(r'to be updated|New records|Identification|identification|FAILED|ERROR|WARNING|loaded|updated|inserted|Pending|matching|Matching|Remove', l)]
    print('[upload %s]' % label, ' | '.join(keep))
    return out

def sql(q, args=('-t',)):
    p = subprocess.run([W + '/sql.sh', *args, '-e', q], capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError('sql.sh failed (status %d): %s' % (p.returncode, p.stderr.strip()))
    return p.stdout.strip()

def lit(v):
    """The one encoder for a value in a SQL string literal (MariaDB with the default backslash escapes): backslash and quote doubled, a NUL byte refused."""
    v = str(v)
    if '\0' in v:
        raise ValueError('a NUL byte cannot go in a SQL literal: %r' % v)
    return "'" + v.replace('\\', '\\\\').replace("'", "''") + "'"

def lits(vs):
    return ','.join(lit(v) for v in vs)

def dump(cats=None, label=''):
    if cats is not None and not list(cats): raise ValueError('dump(): an empty list of catalog numbers; pass None for every record')
    where = ''
    if cats is not None: where = ' WHERE catalogNumber IN (%s)' % lits(cats)
    print('--- %s occurrences' % label)
    print(sql("SELECT occid, catalogNumber cat, dbpk, sciname, identifiedBy idby, dateIdentified di, scientificNameAuthorship auth, identificationQualifier q, sex, reproductiveCondition repro, disposition, locality, dateLastModified dlm FROM omoccurrences%s ORDER BY occid" % where))
    print('--- %s determinations' % label)
    w2 = ''
    if cats is not None: w2 = ' WHERE o.catalogNumber IN (%s)' % lits(cats)
    print(sql("SELECT d.detid, o.catalogNumber cat, d.sciname, d.identifiedBy idby, d.dateIdentified di, d.isCurrent cur, d.scientificNameAuthorship auth, d.identificationQualifier q, d.verbatimIdentification vi, d.taxonRank rk, d.identifiedByID byid, d.identificationRemarks rem, d.sortSequence srt, d.sourceIdentifier src FROM omoccurdeterminations d JOIN omoccurrences o USING(occid)%s ORDER BY o.occid, d.detid" % w2))

def editor_add(collid, **f):
    d = {'collid': collid, 'submitaction': 'addOccurRecord'}
    d.update(f)
    r = post(B + '/collections/editor/occurrenceeditor.php', data=d)
    open(LOGDIR + '/editor_add.html', 'w').write(r.text)
    return r

def editor_det(collid, occid, **f):
    d = {'collid': collid, 'occid': occid, 'submitaction': 'submitDetermination', 'makecurrent': 1, 'tidtoadd': '', 'scientificnameauthorship': '',
         'identificationqualifier': '', 'identificationreferences': '', 'identificationremarks': '', 'confidenceranking': ''}
    d.update(f)
    r = post(B + '/collections/editor/occurrenceeditor.php', data=d)
    open(LOGDIR + '/editor_det.html', 'w').write(r.text)
    return r

if __name__ == '__main__':
    login()

def set_map(fields, prefix, source, target):
    """Set the target select that follows source sf field (as a user would pick in the mapping form). Raises when the form has no such source column, so a mapping that was not applied cannot pass for one that was."""
    out = []; want = False; done = False
    for k, v in fields:
        if k == prefix + 'sf[]' and v == source.lower(): want = True
        elif k == prefix + 'tf[]' and want: v = target; want = False; done = True
        out.append((k, v))
    if not done: raise ValueError('set_map: no %ssf[] field for %r with a following %stf[] in the form' % (prefix, source, prefix))
    return out

def ident_options(label):
    s = open('%s/%s.1-analyze.html' % (LOGDIR, label)).read()
    i = s.find('dwcaIdentDiv'); seg = s[i:]
    m = re.search(r'<select name="ID-tf\[\]".*?</select>', seg, re.S)
    return re.findall(r'<option value="([^"]*)"', m.group(0)) if m else []

def upload_csv(label, collid, path, matchcat=True, matchothercat=False, versiondata=False, uploadtype=3, setfields=None, quiet=False):
    """Plain spreadsheet (csv) upload: specuploadmap.php (analyze, automap) -> specuploadprocessor.php, then final transfer."""
    with open(path, 'rb') as f:
        r = post(B + '/collections/admin/specuploadmap.php',
                   data={'collid': collid, 'uploadtype': uploadtype, 'uspid': 0, 'automap': 1, 'action': 'Analyze File', 'MAX_FILE_SIZE': 100000000},
                   files={'uploadfile': (os.path.basename(path), f, 'text/csv')})
    open('%s/%s.1-analyze.html' % (LOGDIR, label), 'w').write(r.text)
    fields = form_fields(r.text, 'filemappingform')
    if fields is None:
        raise RuntimeError('ANALYZE FAILED: ' + text(r.text)[-800:])
    fields = [(k, v) for k, v in fields if k not in ('matchcatnum', 'matchothercatnum', 'versiondata')]
    if matchcat: fields.append(('matchcatnum', '1'))
    if matchothercat: fields.append(('matchothercatnum', '1'))
    if versiondata: fields.append(('versiondata', '1'))
    if setfields:
        fields = [(k, v) for k, v in fields if k not in setfields] + list(setfields.items())
    fields.append(('action', 'Start Upload'))
    r2 = post(B + '/collections/admin/specuploadprocessor.php', data=fields)
    open('%s/%s.2-start.html' % (LOGDIR, label), 'w').write(r2.text)
    ff = form_fields(r2.text, 'finaltransferform')
    if ff is None:
        raise RuntimeError('NO FINAL FORM, so nothing was transferred. The page said: ' + text(r2.text)[-1500:])
    r3 = post(B + '/collections/admin/specuploadprocessor.php', data=ff + [('action', 'activateOccurrences')])
    out = text(r2.text) + '\n==FINAL\n' + text(r3.text)
    open('%s/%s.txt' % (LOGDIR, label), 'w').write(out)
    if 'Upload Procedure Complete' not in text(r3.text):
        raise RuntimeError('the transfer page did not end with "Upload Procedure Complete", so the transfer may not have finished. It said: ' + text(r3.text)[-1500:])
    keep=[l for l in out.split('\n') if re.search(r'to be updated|New records|FAILED|ERROR|WARNING|loaded|updated|inserted|Pending|matching|Matching', l)]
    print('[csv upload %s]' % label, ' | '.join(keep))
    return out

def import_ext(label, collid, importType, path, associationType='', relationship='', subtype='', replace=False, createnew=False, extra=None):
    """Symbiota's 'Import extended data' page (collections/admin/importextended.php)."""
    with open(path, 'rb') as f:
        r = post(B + '/collections/admin/importextended.php',
                   data={'collid': collid, 'importType': importType, 'associationType': associationType, 'submitAction': 'initiateImport', 'MAX_FILE_SIZE': 10000000},
                   files={'importFile': (os.path.basename(path), f, 'text/csv')})
    open('%s/%s.1.html' % (LOGDIR, label), 'w').write(r.text)
    fields = form_fields(r.text, 'mappingform')
    if fields is None:
        raise RuntimeError('IMPORT-EXT INIT FAILED: ' + text(r.text)[-800:])
    fields = [(k, v) for k, v in fields if k not in ('relationship', 'subType', 'replace', 'createNew')]
    if relationship: fields.append(('relationship', relationship))
    if subtype: fields.append(('subType', subtype))
    if replace: fields.append(('replace', '1'))
    if createnew: fields.append(('createNew', '1'))
    if extra: fields += extra
    fields.append(('submitAction', 'importData'))
    r2 = post(B + '/collections/admin/importextended.php', data=fields)
    out = text(r2.text); i = out.find('Action Panel'); 
    open('%s/%s.txt' % (LOGDIR, label), 'w').write(out)
    print('[import-ext %s]' % label, ' | '.join(l for l in out[i if i>=0 else 0:].split('\n')[:25] if 'footer' not in l.lower() and 'NSF' not in l and 'Symbiota' not in l))
    return out


ABSENT = '<absent>'

def snap(cat):
    """Every column of the one occurrence row with this catalog number, as a dict. An empty dict means no such record. Raises when two or more rows share the catalog number, because merging them would hide changes."""
    cols = sql("select column_name from information_schema.columns where table_schema='symbdb' and table_name='omoccurrences' order by ordinal_position", args=('-N', '-B')).split('\n')
    if not cols or cols == ['']: raise RuntimeError('snap(): could not read the omoccurrences columns')
    pairs = ','.join("%s,`%s`" % (lit(c), c) for c in cols)
    # json_object keeps NULL (null) apart from an empty string, and -r with one JSON document per row keeps a value with a line break on one line.
    out = sql("select json_object(%s) from omoccurrences where catalogNumber=%s order by occid" % (pairs, lit(cat)), args=('-N', '-B', '-r'))
    rows = [json.loads(l) for l in out.split('\n') if l.strip()]
    if len(rows) > 1:
        raise RuntimeError('snap(): %d records share catalog number %r (occid %s)' % (len(rows), cat, ', '.join(str(r['occid']) for r in rows)))
    return rows[0] if rows else {}

def diff(b, a, ignore=()):
    """The fields that differ between two snapshots, over the union of their keys. A key missing from one snapshot (a record that did not exist, or a column added) is shown as <absent>, which differs from an empty value or NULL."""
    ch = []
    for k in sorted(set(b) | set(a)):
        if k in ignore: continue
        bv = b.get(k, ABSENT); av = a.get(k, ABSENT)
        if bv != av or (k in b) != (k in a):
            ch.append('%s: %s -> %s' % (k, bv, av))
    return ch
