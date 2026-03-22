import sys
import json
import pickle as pkl
from itertools import combinations
from collections import defaultdict
import spacy

__DEBUG = True
__MODEL_FILE_NLP = "spacy_harry_potter.nlp.dat"
__MODEL_FILE_DOC = "spacy_harry_potter.doc.dat"

def trace(*args):
    if (__DEBUG): print(*args, file=sys.stderr)

def main():
    trace("Loading models...")
    with open(__MODEL_FILE_NLP, "rb") as modelfile: nlp = pkl.load(modelfile)
    with open(__MODEL_FILE_DOC, "rb") as modelfile: doc = pkl.load(modelfile)
    trace("Models loaded.")

    trace("Calculating levels...")
    friendshipLevels = defaultdict(int)
    allEntities = set()
    dsl = len(list(doc.sents))

    for i, sent in enumerate(doc.sents):
        trace(f"Analysing sentence {i}/{dsl}...")
        entities = list(map(lambda e: e.text.strip().lower(), filter(lambda e: e.label_ == "PER", sent.ents)))
        allEntities.update(entities)
        
        # Make results idempotent (A->B and B->A hold the same score)
        for pair in combinations(set(entities), 2):
            sorted_pair = tuple(sorted(pair))
            friendshipLevels[sorted_pair] += 1
    trace("Levels calculated.")

    sortedScores = sorted(dict(friendshipLevels).items(), key=lambda x: x[1], reverse=True)
    print(f"\n{'Entity Pair':<45} {'Co-occurrences':>15}")
    print("-" * 62)
    for (entity1, entity2), count in sortedScores:
        pair_str = f"{entity1} /// {entity2}"
        print(f"{pair_str:<45} {count:>15}")

if __name__ == "__main__":
    raise SystemExit(main())
