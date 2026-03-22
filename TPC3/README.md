# TPC4
**Titulo:** Semana 5  
**Id:** PG60298  
**Nome:** Rafael Santos Fernandes  
**Data:** 2026-03-22  
<img src="../assets/img/foto.jpg" alt="foto" width="200" />

## Resumo
Este trabalho incidiu sobre a extração de entidades nomeadas a partir do texto de um livro no PDF.

## Resultados
## 1. Extração de Texto
### 1.1. Informação Alvo 
É pretendido extraír do livro "Harry Potter e A Pedra Filosofal" todas as entidades nomeadas e classificar as relações entre as mesmas pelo seu nível de amizade, que é calculado pelo número de vezes onde essas entidades se encontram juntas na mesma frase.  

### 1.2. Análise da Estrutura 
Comecei por transformar o ficheiro PDF em XML, dado que a versão em texto utilizada na aula possuía as páginas quebradas, que as tornavam mais difíceis de tratar com a ferramenta spaCy. O ficheiro é constituído maioritariamente por tags `text`, cuja maior parte dos atributos pode ser ignorada. Porém, nessas tags existem dois atributos úteis para a identificação dos elementos que elas representam, com os identificadores `font` e `left`. Todas as outras tags no ficheiro podem ser ignoradas.  
O atributo `font` possúi os diferentes valores dependendo da informação que representa:  
- Tags com `font="0"` contêm uma única letra do primeiro parágrafo de cada capítulo.  
- Tags com `font="4"` contêm texto que foi separado por diferenças de estilo (itálico, etc.).  
- Todos os outros valores para este atributo podem ser ignorados.  
  
O atributo `left` possúi os diferentes valores dependendo da informação que representa:  
- Tags com `left="60"` contêm o início de um parágrafo.  
- Todos os outros valores para este atributo podem ser ignorados.  

### 1.3. Detalhes de implementação 
A implementação começa por ler um ficheiro `Harry Potter e A Pedra Filosofal.xml` e marcar as tags que contêm o início de cada parágrafo com o marcador `@`: as tags que contêm a letra inicial de cada capítulo com o marcador `\x0B` (ASCII Vertical Spacing); e as tags que contêm texto quebrado com o marcador `\x007` (ASCII Bell). Após isso, a implementação divide o ficheiro pelo marcador `@` e processa cada substring indivídualmente.  
Caso a entrada comece com o marcador `\x0B`, a implementação extrái a letra inicial e adiciona-a a um buffer que será concatenado á esquerda do próximo parágrafo processado.  
Caso a entrada comece com o marcador `\x007`, a implementação extrái o fragmento de texto e concatena-o á direita do buffer do parágrafo atual, após remover o último caractere (que no funcionamento normal deverá ser um caractere de espaço).  
Caso a entrada comece com um caractere de pontuação (`!`, `?`, `.`, `,`, `;`) e o último caractere no buffer do parágrafo atual fôr um espaço em branco, a implementação extrái o fragmento de texto e concatena-o á direita do buffer do parágrafo atual, após remover o último caractere.  
No fim, a implementação concatena todos os parágrafos com um *newline* entre eles, e escreve-as num ficheiro `Harry Potter e A Pedra Filosofal.out`.  


## 2. Análise de Texto
### 2.1. Detalhes de implementação 
A implementação começa por carregar o modelo gerado pelo script utilitário `spacy_load.py`.  
De seguida, a implementação itera por todas as frases identificadas pelo modelo e extraí todas as pessoas a partir do conjunto de entidades nomeadas presentes na frase (todas as entidades com a label `PER`).  
Após isso, a implementação gera todas as combinações idempotentes de dois elementos entre todas as pessoas identificadas e incrementa o seu nível de amizade.  
No fim, a implementação formata todos os resultados numa série de linhas com o formato `PESSOA1 /// PESSOA2 <S> NÍVEL`, onde `<S>` é espaço variável.  

### 2.2. Limitações e Problemas Encontrados 
Após a execução da implementação e a análise dos resultados, apercebi-me dos seguintes problemas:  
- Existem entradas com modificadores que remete para a mesma entidade (ex.: `Petúnia` e `Tia Petúnia` encontram-se separadas)  
- Existem entradas com sinais de pontuação (ex.: `tiago...`, `“`)  
- Existem entradas que não possúem pessoas, possúindo em vez outros componentes gramaticais (ex.: `dê`, `c-c-conhecê-lo`, `aquilo`)  
- Existem entradas que possúem fragmentos de frase incorretamente interpretados como um nome próprio com títulos afixados (ex.: `prezado sr. potter,[\n]temos`)  
  
Estes problemas necessitariam de uma análise mais profunda e possívelmente uma fonte de verdade externa que validasse e filtrasse as entidades utilizadas na agregação.  


## 3. Scripts
### 3.1. extractXML.py 
Criado para extraír a informação alvo de um ficheiro XML `Harry Potter e A Pedra Filosofal.xml`.  
Esta ferramenta aplica a metodologia descrita anteriormente.  
> **Ficheiro relacionado:** [./extractXML.py](./extractXML.py)
### 3.2. spacy_load.py 
Criado para carregar um modelo de processamento de texto da ferramenta spaCy e marshalizá-lo para ser carregado mais rapidamente.  
> **Ficheiro relacionado:** [./spacy_load.py](./spacy_load.py)
### 3.3. extractRelationships.py 
Criado para carregar o modelo de processamento de texto da ferramenta spaCy e extraír as relações de amizade entre as Entidades Nomeadas extraídas do modelo.  
> **Ficheiro relacionado:** [./extractRelationships.py](./extractRelationships.py)


