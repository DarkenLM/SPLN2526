# TPC1
**Titulo:** Semana 4  
**Id:** PG60298  
**Nome:** Rafael Santos Fernandes  
**Data:** 2026-03-06  
<img src="../assets/img/foto.jpg" alt="foto" width="200" />

## Resumo
Este trabalho incidiu sobre a extração de informação de um ficheiro XML contendo a informação de um PDF.

## Resultados
## 1. Análise
### 1.1. Informação Alvo 
É pretendido extraír do PDF todas as entradas do seu Vocabulário e guardá-las num ficheiro JSON, cujas propriedades representam a informação de cada conceito:  
- **id**: Número único do conceito.  
- **ga**: Nome do conceito, em Galêgo.  
- **pos**: Morfologia do nome do conceito, em Galêgo. (Opcional)  
- **dom**: O(s) domínio(s) em que o conceito se enquadra. (Opcional)  
- **sin**: Possíveis sinónimos para o conceito, em Galêgo. (Opcional)  
- **var**: Possíveis variantes do conceito. (Opcional)  
- **nota**: Notas que sejam consideradas relevantes para o conceito. (Opcional)  
- **langs**: Objeto contendo as traduções em Espanhol, Português, Inglẽs e Latim (último opcional).  
  - **Estrutura ([Notação Typescript](https://www.typescriptlang.org/docs/handbook/2/mapped-types.html))**: `{ [key: string]: string[] }`.  

### 1.2. Análise da Estrutura 
Comecei por analisar o ficheiro XML para identificar a estrutura dos dados representados. O ficheiro é constituído maioritariamente por tags `text`, cuja maior parte dos atributos pode ser ignorada. Porém, nessas tags existe um atributo útil para identificação dos elementos que elas representam, com o identificador `font`. Todas as outras tags no ficheiro podem ser ignoradas, excepto a tag `page`, que serve para separar o último conceito do Vocabulário de informação irrelevante do capítulo seguinte, que entraria em conflito com os campos do conceito durante o seu processamento.  
O atributo `font` possúi diferentes valores dependendo da informação que representa:  
- `id`, `ga`, `pos`: Possúi 4 variantes:  
  - **Variante 1:** Texto contido numa única tag, com `font="3"`. Nesta variante, os 3 elementos encontram-se envolvidos numa única tag `b`.  
  - **Variante 2:** `id` numa tag isolada, com `font="2"`. `ga` e `pos` juntos numa outra tag, com `font="3"`. Nesta variante, `id` não possúi modificadores de estilo, enquanto `ga` e `pos` encontram-se envolvidos numa única tag `b`.  
    - **Variante 2.1:** `id` numa tag isolada, com `font="12"`. `ga` e `pos` juntos numa outra tag, com `font="11"`. Estruturalmente idêntico á **Variante 2**, exceto pelo atributo `font`.  
  - **Variante 3:** `id`, `ga` e `pos` em tags separadas, `font="3"`, `font="10"` e `font="3"`, respetivamente. Nesta variante, `id` encontra-se envolvido numa tag `b`, `ga` encontra-se envolvido por tags `i` e `b`, por essa ordem, e `pos` encontra-se envolvido numa tag `b`.  
- `dom`: Tag com `font="6"`, com o conteúdo envolvido numa tag `i`. Múltiplos domínios estão separados por múltiplos caráteres de espaço.  
- `sin` e `var`: Se todo o conteúdo existir numa única tag, a mesma possúi `font="5"`. Se o conteúdo for dividido entre tags, a primeira possúi o mesmo atributo, enquanto tags subsequentes possúem `font` com valor `5` ou `6`. Em cada um dos casos, o conteúdo dentro de cada tag está envolvido numa tag `i`.  
  - **Nota:** Entre as tags que representam `id`, `ga` e `pos`, e `dom` podem existir outras tags com `font="5"`.  
- `nota`: Todo o conteúdo encontra-se em uma ou mais tags com `font="9"` consecutivas.  
- `langs`: Cada tradução começa com uma tag com `font="0"` com espaço em branco, seguida de outra tag com o mesmo atributo com o código da linguagem (`es`, `en`, `pt` ou `la`), seguida de uma ou mais tags com `font="7"` com a tradução, repartida entre as tags. Caso haja mais do que uma tradução para a mesma linguagem, segue-se uma tag com `font="0"` com o conteúdo `; `, seguida de outra tag com `font="7"`. O conteúdo das tags com `font="7"` encontra-se envolvido numa tag `i`  


## 2. Implementação
### 2.1. Detalhes de implementação 
A implementação começa por ler um ficheiro `medicina.xml` e marcar as tags que contêm a informação do campo `id` com o marcador `@`. Caso a tag represente a **Variante 2/2.1**, é também adicionado o marcador `£`. Após isso, a implementação divide o ficheiro pelo marcador `@` e processa cada substring indivídualmente.  
Caso a entrada comece com o marcador `£`, a implementação tenta extraír os campos `id`, `ga` e `pos` de acordo com a estrutura das **Variantes 2 ou 2.1**. Caso nenhuma consiga extraír a informação, a entrada é marcada como nula. Caso a entrada ***não*** comece com o marcador `£`, a implementação tenta extraír os campos de acordo com a estrutura da **Variante 1**. Caso essa falhe, a implementação tenta a mesma operação segundo a estrutura da **Variante 3**. Caso essa também falhe, a entrada é marcada como nula.  
De seguida, a implementação extraí a informação dos domínios do conceito. Após este passo, a implementação move o apontador do início da substring para o fim da tag contendo o domínio, de forma a evitar o problema descrito na estrutura dos campos `sin` e `var`.  
De seguida, a implementação tenta extraír esses mesmos campos, começando por capturar todas as tags consecutivas com o atributo `font` com o valor `5` ou `6` e marcando as tags cujo conteúdo comece com `SIN.-` ou `VAR.-` com o marcador `@`. Após tal, a implementação extraí para cada um dos campos toda a substring entre os marcadores, removendo espaços duplicados e concatenando o conteúdo de tags consecutivas.  
De seguida, a implementação tenta extraír a informação da `nota` associada ao conceito, se existir, conforme descrito no capítulo anterior. O conteúdo é sujeito ao mesmo processo de pós-processamento dos campos `sin` e `var`.  
De igual modo, a implementação extraí todas as traduções do conteúdo, conforme descrito no capítulo anterior, fazendo recurso do método `re.search`, movendo o apontador do início da substring para o fim de cada *match*.  
No fim, a implementação reúne todos os campos num dicionário, preenchendo os campos opcionais não reconhecidos com `None`, e retorna-o.  
Havendo coletado todas as entradas, a implementação reúne-as todas num array JSON e escreve-as num ficheiro `medicina.out.json`.  


## 3. Scripts
### 3.1. checkMissing.py 
Criado para verificar se existem entradas que não tenham sido extraídas do ficheiro XML.  
Esta ferramenta extrái todos os ids dos conceitos e indica os 'buracos' na sequência. Esta ferramenta observa tanto o output do script de extração, como do ficheiro de output que o mesmo produz.  
*Ex.:* Se os conceitos `1`, `2` e `5` foram reconhecidos, o script irá indicar os conceitos `3` e `4` como em falta.  
> **Ficheiro relacionado:** [./checkMissing.sh](./checkMissing.sh)
### 3.2. extractConcepts.py 
Criado para extraír a informação alvo de um ficheiro XML `medicina.xml`.  
Esta ferramenta aplica a metodologia descrita anteriormente.  
> **Ficheiro relacionado:** [./extractConcepts.py](./extractConcepts.py)


