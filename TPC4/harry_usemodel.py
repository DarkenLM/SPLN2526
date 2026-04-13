import re
import os
import sys
import time
import argparse
import warnings
from cryptography.utils import CryptographyDeprecationWarning
warnings.filterwarnings("ignore", category=CryptographyDeprecationWarning)

from typing import List
from functools import reduce
from gensim.models import KeyedVectors
import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from sklearn.decomposition import PCA

from util import tabulate

__DEBUG = False
__dirname = os.path.dirname(__file__)

def trace(*args):
    if (__DEBUG): print(*args, file=sys.stderr)

def err(*args):
    print(*args, file=sys.stderr)

def mostSimilar(wv: KeyedVectors, word: str):
    ms = wv.most_similar(word)
    print(f"Most similar words for '{word}':")
    print("\n".join(map(lambda l: f"- {l}", tabulate(ms, border=False).splitlines())))
    return ms

def howSimilar(wv: KeyedVectors, wordA: str, wordB: str):
    sim = wv.similarity(wordA, wordB)
    print(f"Similarity between '{wordA}' and '{wordB}': {sim}")

def analogy(wv: KeyedVectors, posA: str, posB: str, neg):
    aWords = wv.most_similar(positive=[posA, posB], negative=[neg])

    # I spent nearly half an hour debugging my own fucking function, only to realize that I was never printing the 
    # result. Just fucking shoot me at this point, fucking hell.
    print(tabulate(
        [[
            f"'{posA}' - '{neg}' + {posB}", 
            "\n".join(map(lambda w: w[0], aWords)), 
            "\n".join(map(lambda w: f"{w[1]}", aWords))
        ]],
        headers=["Analogy", "Word", "Similarity"]
    ))

def anomaly(wv: KeyedVectors, words: List[str]):
    anom = wv.doesnt_match(words)
    print(f"In [{', '.join(words)}], the anomaly is: '{anom}'")

def plotWordEmbeddingsHeatmap(wv, words, block):
    if (not block): return

    vectorData = list(map(lambda p: wv[p], words))
    frame = pd.DataFrame(vectorData, index=words)
    plt.figure(figsize=(len(words) * 3, len(words)))
    sns.heatmap(frame, cmap='RdBu_r', cbar=True, yticklabels=True, xticklabels=False)

    plt.title("Word Embeddings")
    plt.show(block=True)

def plotWordDistance(wv, words, block):
    if (not block): return

    validWords = list(filter(lambda w: w in wv, words))
    print(f"Valid words: {len(validWords)}/{len(words)}")
    if (len(validWords) != len(words)): err(f"Invalid words: {', '.join(filter(lambda w: w not in wv, words))}")

    vectors = np.array(list(map(lambda w: wv[w], validWords)))
    pca = PCA().fit_transform(vectors)[:,:2]

    plt.figure(figsize=(10, 10))
    plt.scatter(pca[:,0], pca[:,1], edgecolors='k', c='red', s=100)
    
    for i in range(0, len(validWords)):
        plt.text(pca[i][0] + 0.01, pca[i][1] + 0.01, validWords[i], fontsize=12)
        
    plt.title("Distance Map")
    plt.show(block=True)

def makeCLI() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Manipulate the knowledge extracted from the harry potter books (see harry_makemodel.py)."
    )
    p.add_argument(
        "-d", "--debug",
        type=bool, action=argparse.BooleanOptionalAction, default=False,
        help="Enables debug mode."
    )
    p.add_argument("-s", "--source", type=str, help="the source directory for the model file", default="models")
    p.add_argument(
        "-p", "--show-plots",
        type=bool, action=argparse.BooleanOptionalAction, default=False,
        help="Whether to show the graphs generated for the tests."
    )
    return p

def main():
    global __DEBUG

    parser = makeCLI()
    args = parser.parse_args(sys.argv[1:])
    __DEBUG = args.debug

    trace("ARGS:", args)
    source = os.path.join(__dirname, args.source)

    wv: KeyedVectors = KeyedVectors.load(f"{source}/harry.model")


    #region ---------- Most Similar Test -------
    print("-" * 20 + " Most Similar Test " + "-" * 20)
    mostSimilarWordList = ["harry", "quadribol", "grifinória", "dumbledore", "você-sabe-quem", "ojesed", "espelho"]
    for i in range(0, len(mostSimilarWordList)):
        wordSimilars = mostSimilar(wv, mostSimilarWordList[i])
        mostSimilar(wv, wordSimilars[0][0])
        if (i < len(mostSimilarWordList) - 1):  print("-" * 40)

    plotWordEmbeddingsHeatmap(wv, mostSimilarWordList, args.show_plots)
    #endregion ------- Most Similar TEst -------
    
    #region ---------- Similarity Tests -------
    print("-" * 20 + " Similarity Tests " + "-" * 20)
    similarWordPairList = [
        ("harry", "voldemort"), 
        ("harry", "dumbledore"), 
        ("voldemort", "dumbledore"),
        ("voldemort", "você-sabe-quem"),
        ("ojesed", "espelho")
    ]
    for i in range(0, len(similarWordPairList)):
        howSimilar(wv, similarWordPairList[i][0], similarWordPairList[i][1])
        # if (i < len(similarWordPairList) - 1):  print("-" * 80)
    #endregion ------- Similarity Tests -------

    #region ---------- Analogy Tests -------
    print("-" * 20 + " Analogy Tests " + "-" * 20)
    analogyWordTripleList = [
        ("harry", "voldemort", "sobreviveu"), 
        ("harry", "dumbledore", "calmamente"), # Dumbledore said, calmly 
        ("voldemort", "dumbledore", "morrer"),
        ("voldemort", "você-sabe-quem", "especial")
    ]
    for i in range(0, len(analogyWordTripleList)):
        (posA, posB, neg) = analogyWordTripleList[i]
        analogy(wv, posA, posB, neg)
        if (i < len(analogyWordTripleList) - 1):  print("-" * 80)
    #endregion ------- Analogy Tests -------

    #region ---------- Anomaly Tests -------
    print("-" * 20 + " Anomaly Tests " + "-" * 20)
    anomalyWordsList = [
        ('harry', 'rony', 'hermione', 'voldemort'), 
        ("dumbledore", "severo", "voldemort", "mcgonagall"),
        ("dumbledore", "severo", "harry", "mcgonagall"),
        ("dumbledore", "severo", "voldemort", "harry", "mcgonagall"),
        ("olivaras", "mione", "hagrid", "Harry"),
        ("voldemort", "tom", "riddle", "servoleo", "harry")
    ]
    for i in range(0, len(anomalyWordsList)):
        words = anomalyWordsList[i]
        anomaly(wv, words)
        if (i < len(anomalyWordsList) - 1):  print("-" * 80)
    #endregion ------- Anomaly Tests -------

    #region ---------- Distance Tests -------
    print("-" * 20 + " Distance Tests " + "-" * 20)
    distances = []
    distanceWordList = [
        "harry", "hermione", "mione", "rony", "weasley", "draco", "malfoy",
        "voldemort", "tom", "servoleo", "riddle", "vol",
        "severo", "snape", "dumbledore", "mcgonagall", "minerva",
        "ojesed"
    ]
    for word in distanceWordList:
        words = list(filter(lambda w: w != word, distanceWordList))
        _wordDists = "\n".join(map(lambda d: f"{d}", list(wv.distances(distanceWordList[i], words))))

        wordNames = "\n".join(words)
        distances.append((word, wordNames, _wordDists))

    print(tabulate(distances, headers=["Word", "Related", "Distance"], separateBetweenRows=True))
    plotWordDistance(wv, distanceWordList, args.show_plots)
    #endregion ------- Distance Tests -------

if __name__ == "__main__":
    raise SystemExit(main())
