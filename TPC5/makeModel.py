import os
import sys
import time
import argparse
import traceback

import spacy
from spacy.tokens import DocBin, Span
from datasets import load_dataset

__DEBUG = False
__dirname = os.path.dirname(__file__)

def trace(*args):
    if (__DEBUG): print(*args, file=sys.stderr)

def err(*args):
    print(*args, file=sys.stderr)

def makeCLI() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Random bullshit."
    )
    p.add_argument(
        "-d", "--debug",
        type=bool, action=argparse.BooleanOptionalAction, default=False,
        help="Enables debug mode."
    )
    p.add_argument(
        "-o", "--output", 
        default=f"{__dirname}/datasets", 
        help="The output directory for the generated datasets."
    )
    return p

def convert(nlp, dataset, outfile):
    db = DocBin()
    labels = dataset.features["ner_tags"].feature.names
    
    trace(f"Converting {dataset}...")
    startTime = time.monotonic()
    for item in dataset:
        doc = nlp.make_doc(" ".join(item["tokens"]))
        
        entities = []
        openInd = None
        openLabel = None
        
        tags = item["ner_tags"]
        for i, tag in enumerate(tags):
            label = labels[tag]
            
            if label.startswith("B-"):
                if openInd is not None: entities.append(Span(doc, openInd, i, label=openLabel))

                openInd = i
                openLabel = label[2:]
            elif label.startswith("I-"):
                if openInd is None:
                    openInd = i
                    openLabel = label[2:]
            else:
                if openInd is not None:
                    entities.append(Span(doc, openInd, i, label=openLabel))
                    openInd = None
                    openLabel = None
        
        if openInd is not None:
            entities.append(Span(doc, openInd, len(tags), label=openLabel))

        try:
            doc.ents = entities
            db.add(doc)
        except Exception as e:
            traceback.print_exception()
            continue 
            
    db.to_disk(outfile)
    trace(f"Converted '{dataset}' in {time.monotonic() - startTime}ms")

def makeDatasets(outDir):
    rawDatasets = load_dataset("lfcc/portuguese_ner")
    nlp = spacy.blank("pt") 

    convert(nlp, rawDatasets["train"], f"{outDir}/train.spacy")
    convert(nlp, rawDatasets["test"], f"{outDir}/dev.spacy")

def main():
    global __DEBUG

    parser = makeCLI()
    args = parser.parse_args(sys.argv[1:])
    __DEBUG = args.debug

    trace("ARGS:", args)
    makeDatasets(args.output)
    
if __name__ == "__main__":
    raise SystemExit(main())