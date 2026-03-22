import re
import os
import sys

__DEBUG = True
__dirname = os.path.dirname(__file__)

__ACC_NEXT = ""

def trace(*args):
    if (__DEBUG): print(*args)

def matchGroupOrNone(p, c, withPos=False, strip=False, g = 1):
    m = re.search(p, c)
    mg = m.group(g) if (m != None) else None
    if (mg != None and strip): mg = mg.strip()
    if (withPos): return (mg, m.end() if (m != None) else None)
    return mg

def processFragment(f: str):
    global __ACC_NEXT
    print("====================================")
    trace(f)
    trace("---<1>------------------------------")
    acc = ""
    fs = f
    while (nm := matchGroupOrNone(r"<text.+?>(?:<[^>]?>)*(.+?)(?:</[^>]?>)*</text>", fs, True)): 
        trace("MATCH:", nm)
        if (nm[0] == None): break

        if (nm[0].startswith("\x0B")):
            __ACC_NEXT += nm[0].strip()
        elif (nm[0].startswith("\x07")):
            acc = acc[:-1] + re.sub(r"\s*$", "", nm[0][1:]) + " "
        else:
            v = nm[0].strip()
            if (len(v) > 0 and v[0] in "!?.,;" and acc[-1].isspace()):
                acc = acc[:-1] 
                acc += nm[0] + " "
            else:
                acc += nm[0] + " "

        fs = fs[nm[1]:]

    trace("---<2>------------------------------")
    trace(acc)
    return re.sub(r" {2,}", " ", acc.strip())
        

def main():
    global __ACC_NEXT
    with open(f"{__dirname}/Harry Potter e A Pedra Filosofal.xml") as file: text: str = file.read()

    ntext = re.sub(r"(<text.+?left=\"60\".+?>)", r"@\1", text)
    ntext = re.sub(r"(<text.+?left=\"38\".+?font=\"0\"[^>]*?>)", r"\1" + "\x0B", ntext) # Chapter start
    ntext = re.sub(r"(<text.+?left=\"(?!38)\d+\".+?font=\"4\"[^>]*?>)", r"\1" + "\x07", ntext) # Broken styled text
    fragments = ntext.split("@")
    finalText = ""

    for f in fragments:
        pre = __ACC_NEXT
        res = processFragment(f)
        if (not res): continue

        # Add chapter start to rest of it's paragraph
        if (pre == __ACC_NEXT and pre != ""):
            finalText += pre + " "
            __ACC_NEXT = ""

        finalText += res + "\n"
    
    fout = open(f"{__dirname}/Harry Potter e A Pedra Filosofal.out", "w", encoding="utf8")
    fout.write(finalText)
    fout.close()

if __name__ == "__main__":
    raise SystemExit(main())