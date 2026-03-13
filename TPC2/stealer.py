import json
import requests
from bs4 import BeautifulSoup

URL = "https://www.atlasdasaude.pt/doencasaaz/"
URL_BASE = "https://www.atlasdasaude.pt"

def fetchAndProcess(ch, doencas):
    htmlContent = requests.get(URL + ch).text
    soup = BeautifulSoup(htmlContent, "html.parser")

    context = soup.select("#block-system-main > div > div > div.view-content > div.views-row")
    for child in context:
        title = child.find(class_="views-field-title").h3.a.text
        link = child.find(class_="views-field-title").h3.a.attrs["href"]
        body = child.find(class_="views-field-body").text

        print(f"GOT {title}")

        childContent = requests.get(URL_BASE + link).text
        childSoup = BeautifulSoup(childContent, "html.parser")
        childContext = childSoup.select(
            "#block-system-main > div > div > " 
                + "div.field.field-name-body.field-type-text-with-summary.field-label-hidden > div > div"
        )
        
        childLong = ""
        for childchild in childContext[0]:
            if (isinstance(childchild, str) and childchild.isspace()): continue
            if ("artigos relacionados" in childchild.text.lower()): break
            if (childchild.name == "h2"): childLong += "## "
            childLong += childchild.text.strip() + "  \n"
            if (childchild.name != "h2"): childLong += "\n"

        doencas[title.strip()] = {
            "short": body.strip(),
            "long": childLong.strip() 
        }

def main():
    doencas = {}
    for ch in range(ord('a'), ord('z')):
        entries = fetchAndProcess(chr(ch), doencas)

    fout = open(f"doencas.json", "w", encoding="utf8")
    json.dump(doencas, fout, indent=4, ensure_ascii=False)

if __name__ == "__main__":
    raise SystemExit(main())
