# TPC6
**Titulo:** Semana 10  
**Id:** PG60298  
**Nome:** Rafael Santos Fernandes  
**Data:** 2026-04-26  
<img src="../assets/img/foto.jpg" alt="foto" width="200" />

## Resumo
Este trabalho incidiu sobre o treino de um modelo TF-IDF.

## Resultados
## 1. Datasets
### 1.1. Tratamento dos Datasets 
Para o dataset utilizado no treino do modelo, são removidos os sinais de pontuação e todas as _stopwords_ (utilizando a lista de stopwords extraída do NLTK), sendo substituídos por espaços. Sequências de dois ou mais espaços são normalizadas para um único espaço.  


## 2. Criação do Modelo
### 2.1. Geração do Modelo 
Para a criação do modelo, decidi utilizar a linguagem de _scripting_ BASH, única e exclusivamente porque me apeteceu.  
  
1. O script começa por ler as _stopwords_ de um ficheiro `stopwords.en`, onde cada linha corresponde a uma _stopword_, e cria uma expressão regular para filtrar as mesmas do corpus.  
2. De seguida, o script lê o ficheiro contendo o corpus e preprocessa-o linha a linha, removendo sinais de pontuação e _stopwords_ utilizando a expressão regular criada anteriormente. Cada linha é adicionada a uma matriz de corpora identificada devidamente para o corpus.  
3. Para cada corpora, são calculados os `TF`s de cada palavra nele contida, sendo de seguida adicionados a uma matriz identificada devidamente para o corpus.  
4. Para o corpus na sua totalidade, são calculados os `IDF`s para cada palavra nele contida, sendo de seguida adicionados a uma matriz indentificada devidamente para o corpus.  
5. Para cada corpora, e para cada `TF` correspondente ao mesmo, são calculados os seus `TF-IDF`s, que são adicionados a uma matriz identificada devidamente para o corpus.  
  
De seguida, o utilizador pode opcionalmente exportar o modelo para um ficheiro, no formato  
```  
<número de corpora no corpus>  
<número de palavras únicas no corpus>  
<para cada palavra única no corpus>  
    <palavra> <identificador>  
<para cada corpora no corpus>  
    <magnitude do vetor TF-IDF do corpora>  
<para cada palavra única no corpus>  
    <identificador> <TF-IDF> <para cada corpora no corpus>(<tf-idf da palavra no corpora>)  
```  
> **Ficheiro relacionado:** [./makeModel.sh](./makeModel.sh)
### 2.2. Utilização do modelo 
Após gerar o modelo e exportá-lo para um ficheiro, o utilizador pode executar uma query sobre o mesmo:  
1. Para o texto da query, são executados os passos 2 a 5 do fluxo normal da Geração do Modelo, substituíndo a identificação do corpus pela identificação da query.  
2. De seguida são calculados os produtos vetoriais entre os vetores TF-IDF do modelo e da query.  
3. É calculada a magnitude do vetor TF-IDF da query.  
4. Com base nos valores calculados anteriormente, e nas magnitudes previamente calculadas na geração do modelo, são calculadas as similaridades do cosseno para cada corpora.  
5. As similaridades são ordernadas por ordem decrescente de similaridade e impressas no `stdout`.  
> **Ficheiro relacionado:** [./useModel.sh](./useModel.sh)
### 2.3. Notas acerca da implementação 
- Dado o BASH não possuír _arrays_ multidimensionais, é utilizado frequentemente um padrão de construção de _arrays_ multidimensionais á custa de um _array_ índice, contendo os índices de cada linha e múltiplos _arrays_, um para cada índice. Esta escolha é preferível a um único _array_ para todas as linhas, utilizando aritmética de ponteiros para mapear as mesmas, dado que as linhas podem não ter o mesmo tamanho.  


## 3. Modelo Final
### 3.1. Testes 
Foi criada uma bateria de testes (ver [test.sh](./test.sh) e [queries.txt](./queries.txt)) para avaliar a performance do modelo.  
Para cada uma das queries no ficheiro de testes, é avaliado se o modelo seleciona corretamente uma similaridade não nula para os corpora indicados.  
Caso o modelo selecione um corpora não indicado para a query, é emitido um aviso.  


## 4. Scripts
### 4.1. tfidfs.sh 
Contém as funções de cálculo de `TF`, `IDF` e `TF-IDF`, comuns tanto á geração como utilização do modelo, necessitando o último devido á necessidade de calcular tais valores para a query.  
> NOTA: Este script não é suposto ser invocado diretamente.  
> **Ficheiro relacionado:** [./model.sh](./model.sh)
### 4.2. makeModel.sh 
Criado para treinar o modelo TF-IDF. Aceita um corpus através do seu `stdin`, um corpora por linha.  
> **Invocação utilizada durante testes:** `cat test.txt | ./makeModel.sh`  
> **Ficheiro relacionado:** [./makeModel.sh](./makeModel.sh)
### 4.3. useModel.sh 
Criado para executar queries sobre o modelo treinado. Aceita queries através dos seus argumentos posicionais.  
> **Invocação utilizada durante testes:** `./useModel.sh <query>`  
> **Ficheiro relacionado:** [./useModel.sh](./useModel.sh)
### 4.4. test.sh 
Utilitário para o teste de diferentes queries fornecidas através de um ficheiro.  
  
**Formato do ficheiro de testes:**  
```  
<para cada caso de teste>  
    <query>|<cada documento que deverá possuír uma similaridade não nula, separado por ','>  
```  
> **Ficheiro relacionado:** [./test.sh](./test.sh)


