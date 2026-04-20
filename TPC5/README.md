# TPC5
**Titulo:** Semana 9  
**Id:** PG60298  
**Nome:** Rafael Santos Fernandes  
**Data:** 2026-04-20  
<img src="../assets/img/foto.jpg" alt="foto" width="200" />

## Resumo
Este trabalho incidiu sobre o treino de um modelo NER utilizando a ferramenta spaCy.

## Resultados
## 1. Datasets
### 1.1. Informação Alvo 
É pretendido treinar um modelo NER a partir dos datasets presentes em `lfcc/portuguese_ner`.  

### 1.2. Tratamento dos Datasets 
Para cada dataset (train e dev), tokens que contenham entidades nomeadas fragmentadas são concatenados num único, referente á entidade em questão.  


## 2. Modelo Final
### 2.1. Métricas 
As seguintes métricas foram obtidas ao fim de 30 *epochs* de treino. As métricas **F-Score**, **Precision** e **Recall** foram extraídas das colunas `ENTS_F`, `ENTS_P` e `ENTS_R`, respetivamente, do output do comando `train` do spaCy.  
- **F-Score:** 94.44  
- **Precision:** 94.46  
- **Score:** 0.94  

### 2.2. Testes 
Foi criada uma bateria de testes (ver [useModel.py](./useModel.py)) para avaliar a performance do modelo.  
Durante a mesma, várias entidades não foram reconhecidas, o que coloca em questão a qualidade do modelo.  


## 3. Scripts
### 3.1. model.sh 
Ponto de entrada para todo o processo de treino e teste do modelo. Uma utilização normal deste script utiliza os comandos `prepare`+ -> `init` -> `train` -> `test`.  
Use `model.sh -h` para mais informações acerca do script.  
  
Para referẽncia, os seguintes comandos foram utilizados:  
```  
./model.sh -m arquivo_ner_train.iob prepare  
./model.sh -m arquivo_ner_test.iob prepare  
./model.sh init  
./model.sh -d -o outputs train --paths.train datasets/arquivo_ner_train.spacy --paths.dev datasets/arquivo_ner_test.spacy  
./model.sh -d test  
```  
> **Ficheiro relacionado:** [./model.sh](./model.sh)
### 3.2. makeModel.py 
Criado para extraír o dataset lfcc/portuguese_ner da HuggingFace.  
> NOTA: Não devidamente testado, devido a falhas de conexão com a HF durante os testes.  
> **Ficheiro relacionado:** [./makeModel.py](./makeModel.py)
### 3.3. useModel.py 
Criado para testar o modelo treinado.  
> **Ficheiro relacionado:** [./useModel.py](./useModel.py)
### 3.4. dlmcmd.sh 
Utilitário para a geração automática de CLIs em bash, no qual eu talvez ou talvez não tenha afundado a maior parte do tempo alocado para este TPC.  
> NOTA: Não inteiramente funcional.  
> **Ficheiro relacionado:** [./dlmcmd.sh](./dlmcmd.sh)


