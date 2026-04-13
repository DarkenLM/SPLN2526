import re
import os
import sys
import time
import argparse
import warnings
from cryptography.utils import CryptographyDeprecationWarning
warnings.filterwarnings("ignore", category=CryptographyDeprecationWarning)

from functools import reduce
from gensim.models import Word2Vec, KeyedVectors
from gensim.scripts.word2vec2tensor import word2vec2tensor
import spacy

__DEBUG = False
__dirname = os.path.dirname(__file__)

def trace(*args):
    if (__DEBUG): print(*args, file=sys.stderr)

def err(*args):
    print(*args, file=sys.stderr)

def makeCLI() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Extract knowledge from the harry potter books."
    )
    p.add_argument(
        "-d", "--debug",
        type=bool, action=argparse.BooleanOptionalAction, default=False,
        help="Enables debug mode."
    )
    p.add_argument("-s", "--source", type=str, help="the source directory for the harry potter file", default="dest")
    p.add_argument("-o", "--output", type=str, help="the output directory for the model file", default="models")
    p.add_argument(
        "-v", "--vector", 
        type=str, help="save as a vector format", 
        choices=["binary", "text"], 
        default=None, required=False
    )
    p.add_argument(
        "-t", "--tensor",
        type=bool, action=argparse.BooleanOptionalAction, default=False,
        help="Export a tensor from the model."
    )
    p.add_argument(
        "--reuse",
        type=bool, action=argparse.BooleanOptionalAction, default=False,
        help="Do not recalculate the model."
    )
    return p

def processFile(nlp, file):
    with open(file) as f: 
        doc = nlp(f.read())
        # sents = list(filter(
        #     lambda t: len("".join(t)) > 0,
        #     map(lambda sent: re.split(r"\s+", sent.text.lower()), doc.sents)
        # ))

        # I spent three fucking hours debugging just to find that propositions may contain spaces. Fuck my life sideways
        sents = []
        for sent in doc.sents:
            tokens = reduce(
                lambda a,c: a + (c if isinstance(c, list) else [c]),
                list(map(
                    lambda t: re.split(r"\s+", t.text.lower()),
                    filter(lambda t: not t.is_punct and not t.is_space and t.text.strip(), sent)
                )),
                []
            )
            if tokens: sents.append(tokens)
        return sents

def main():
    global __DEBUG

    parser = makeCLI()
    args = parser.parse_args(sys.argv[1:])
    __DEBUG = args.debug

    saveAsTensor = args.tensor
    saveAsVector = args.vector != None
    vectorFormat = args.vector

    trace("ARGS:", args)
    source = os.path.join(__dirname, args.source)
    output = os.path.join(__dirname, args.output)

    wv = None
    if (not args.reuse):
        nlp = spacy.load("pt_core_news_sm")
        sentences = []

        print("Processing 'camara'...")
        startTime = time.monotonic()
        sentences.extend(processFile(nlp, f"{source}/Harry_Potter_Camara_Secreta-br.preproc.txt"))
        print(f"Processed 'camara' in {time.monotonic() - startTime}ms")

        print("Processing 'filosofal'...")
        startTime = time.monotonic()
        sentences.extend(processFile(nlp, f"{source}/Harry Potter e A Pedra Filosofal.preproc.txt"))
        print(f"Processed 'filosofal' in {time.monotonic() - startTime}ms")

        print("Generating model...")
        startTime = time.monotonic()
        # model = Word2Vec(sentences, vector_size=100, window=5, min_count=1, workers=4, sg=1, epochs=5)
        # model = Word2Vec(sentences, vector_size=100, window=5, min_count=1, workers=4, sg=1, epochs=15)
        # model = Word2Vec(sentences, vector_size=100, window=5, min_count=2, workers=4, sg=1, epochs=15)
        # model = Word2Vec(sentences, vector_size=200, window=5, min_count=1, workers=4, sg=1, epochs=15)

        model = Word2Vec(sentences, vector_size=400, window=5, min_count=1, workers=4, sg=1, epochs=15)

        # model = Word2Vec(sentences, vector_size=200, window=5, min_count=1, workers=4, sg=1, epochs=100)
        wv = model.wv
        print(f"Generated model in {time.monotonic() - startTime}ms")
    else:
        print("Loading previous model...")
        startTime = time.monotonic()
        wv = KeyedVectors.load(f"{output}/harry.model")
        print(f"Loaded previous model in {time.monotonic() - startTime}ms")

    print(f"Saving model...")
    startTime = time.monotonic()
    wv.save(f"{output}/harry.model")

    if (not os.path.exists(output)): os.mkdir(output)
    if (saveAsVector):
        modelPath = ""
        match vectorFormat:
            case "binary": wv.save_word2vec_format(modelPath := (f"{output}/harry.bin"), binary=True)
            case "text": wv.save_word2vec_format(modelPath := (f"{output}/harry.txt"), binary=False)
            case _: raise KeyError(f"Unknown vector format: {vectorFormat}")

        if (saveAsTensor): word2vec2tensor(modelPath, f"{output}/harry", binary=(vectorFormat == "binary"))
    
    print(f"Saved models in {time.monotonic() - startTime}ms")

if __name__ == "__main__":
    raise SystemExit(main())
