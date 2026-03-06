import re
import os
import sys
import json

__DEBUG = True
__dirname = os.path.dirname(__file__)

def trace(*args):
    if (__DEBUG): print(*args)

def matchGroupOrNone(p, c, withPos=False, strip=False, g = 1):
    m = re.search(p, c)
    mg = m.group(g) if (m != None) else None
    if (mg != None and strip): mg = mg.strip()
    if (withPos): return (mg, m.end() if (m != None) else None)
    return mg

def processConcept(c):
    print("====================================")
    trace(c)
    trace("---<1>------------------------------")
    if (c.startswith("£")):
        cidMatch = re.search(r"<text .+? font=\"1?2\"> +(\d+) *</text>", c)
        hMatch = re.search(r"<text .+? font=\"3|11\"><b> *(.+?) *?(?:  +(.+?))?</b></text>", c)
        trace("CIDMATCH:", cidMatch)
        trace("HMATCH:", hMatch)
        
        if (cidMatch == None or hMatch == None): return None # Does not contain a concept. Skip it.
        cid = cidMatch.group(1)
        cga = hMatch.group(1)
        cpos = hMatch.group(2)
    else:
        hMatch = re.search(r"<text .+? font=\"3\"><b> *(\d+) +(.+?) *?(?:  +(.+?))?</b></text>", c)
        trace("HMATCH:", hMatch)
        if (hMatch != None): 
            cid = hMatch.group(1)
            cga = hMatch.group(2)
            cpos = hMatch.group(3)
        else:
            # Edge case: Split id, <i><b>ga</i></b> pos
            cidMatch = re.search(r"<text .+? font=\"3\"><b> *(\d+) *</b></text>", c)
            cgaMatch = re.search(r"<text .+? font=\"10\"><i><b> *(.+?) *</b></i></text>", c)
            cposMatch = re.search(r"<text .+? font=\"3\"><b> *(.+?)</b></text>", c)

            # Does not contain a concept. Skip it.
            if (cidMatch == None or cgaMatch == None or cposMatch == None): return None 

            cid = cidMatch.group(1)
            cga = cgaMatch.group(1)
            cpos = cposMatch.group(1)

    (cdom, npos) = matchGroupOrNone(r"<text .+? font=\"6\"><i> *(.+?)</i></text>", c, True)
    if (cdom): cdom = re.sub(r"\s+", " ", cdom).split(" ")

    c = c[npos:] # Truncate, as otherwise it might capture the font 5 segments present between the header and domains
    csin = None
    cvar = None
    _cspec = matchGroupOrNone(r"\s*((<text .+? font=\"[56]\">.+?</text>\n?)+)", c)
    if (_cspec != None):
        cspec = re.sub(r"<text .+? font=\"[56]\">(.+?)</text>", r"\1", _cspec)
        cspec = re.sub(r"(SIN|VAR)\.-", r"@\1.-", cspec)

        csin = matchGroupOrNone(r"@SIN\.-([^@#]+)", cspec, strip=True)
        if (csin != None): 
            csin = re.sub(r" {2,}", " ", csin.replace("\n", "").strip())
            csin = re.sub(r"</?[a-z]+>", "", csin)

        cvar = matchGroupOrNone(r"@VAR\.-([^@#]+)", cspec, strip=True)
        if (cvar != None): 
            cvar = re.sub(r" {2,}", " ", cvar.replace("\n", "").strip())
            cvar = re.sub(r"</?[a-z]+>", "", cvar)
    
    cnota = None
    _cnota = matchGroupOrNone(r"\s*((<text .+? font=\"9\">.+?</text>\n?)+)", c)
    if (_cnota != None):
        cnota = re.sub(r"<text .+? font=\"9\">(?: *Nota.- +)?(.+?)</text>", r"\1", _cnota).replace("\n", "").strip()
        cnota = re.sub(r" {2,}", " ", cnota)
        cnota = re.sub(r"</?[a-z]+>", "", cnota)

    clangs = {}
    lastLang = None
    while (len(c) > 0):
        candidateMatch = re.search(r"<text .+? font=\"0\">(.+?)</text>", c)
        if (candidateMatch == None): break

        c = c[candidateMatch.end():]
        candidate = candidateMatch.group(1).strip()
        if (len(candidate) > 1):
            # New language
            clangs[candidate] = []
            lastLang = candidate
        elif (len(candidate) == 0):
            continue # Skip empty tag
        # Otherwise, it is a sinonym separator (";"). Allow it to be added.

        _langContent = matchGroupOrNone(r"\s*((<text .+? font=\"7\">.+?</text>\n)+)", c)
        if (_langContent != None):
            langContent = re.sub(r"<text .+? font=\"7\"><i>(.+?)</i></text>", r"\1", _langContent).replace("\n", "")
            langContent = re.sub(r" {2,}", " ", langContent).strip()
            clangs[lastLang].append(langContent)

    print("cid:  |", cid, "|")
    print("cga:  |", cga, "|")
    print("cpos: |", cpos, "|")
    print("cdom: |", cdom, "|")
    print("csin: |", csin, "|")
    print("cvar: |", cvar, "|")
    print("cnota: |", cnota, "|")
    print("clangs: |", clangs, "|")

    res = {
        "id": cid,
        "ga": cga,
        "pos": cga,
        "dom": cga,
        "sin": csin,
        "var": cvar,
        "nota": cnota,
        "langs": clangs,
    }
    return res



def main():
    with open(f"{__dirname}/medicina.xml") as file:
        text: str = file.read()

    text = "".join(text.split("<page")[:-1]) # Skip end of page, as it contains unused content
    ntext = re.sub(r"(<text .+? font=\"3\"><b> *\d+.+?</b></text>)", r"@\1", text)
    # Edge case: Split id with Font 2 or 12. Force whitespace at start to not catch page numbers
    ntext = re.sub(r"(<text .+? font=\"1?2\"> +\d+ *</text>)", r"@£\1", ntext)
    concepts = ntext.split("@")
    entries = {}

    # print(ntext)
    # return 1

    for c in concepts:
        res = processConcept(c)
        if (not res): continue
        entries[res["id"]] = res
    
    fout = open(f"{__dirname}/medicina.out", "w", encoding="utf8")
    json.dump(entries, fout, indent=4, ensure_ascii=False)

if __name__ == "__main__":
    raise SystemExit(main())