import pickle as pkl
import json
import spacy

__MODEL_FILE_NLP = "spacy_harry_potter.nlp.dat"
__MODEL_FILE_DOC = "spacy_harry_potter.doc.dat"

with open("Harry Potter e A Pedra Filosofal.out") as inputFile:
    print("Reading text...")
    texto = inputFile.read()
    print("Read text.")

print("Loading model...")
nlp = spacy.load("pt_core_news_sm")
doc = nlp(texto)
print("Loaded model.")

with open(__MODEL_FILE_NLP, "wb") as modelfile: 
    pkl.dump(nlp, modelfile)
    print(f"Saved nlp to {__MODEL_FILE_NLP}")
with open(__MODEL_FILE_DOC, "wb") as modelfile: 
    pkl.dump(doc, modelfile)
    print(f"Saved doc to {__MODEL_FILE_DOC}")
