# TPC2
**Titulo:** Semana 5  
**Id:** PG60298  
**Nome:** Rafael Santos Fernandes  
**Data:** 2026-03-13  
<img src="../assets/img/foto.jpg" alt="foto" width="200" />

## Resumo
Este trabalho incidiu sobre a criação de um Web Scrapper para a extração de informação de uma página web.

## Resultados
## 1. Análise
### 1.1. Informação Alvo 
É pretendido extraír da página web todas as entradas da sua Lista de Doenças e guardá-las num ficheiro JSON. O ficheiro é um array de objetos, onde cada objeto representa cada doença, com as seguintes propriedades:  
- **short**: Resumo da descrição da doença, presente na página de agregação (Doenças de A a Z).  
- **long**: Toda a descrição da doença, que é obtida ao navegar para a página apontada por uma âncora presente no título da entrada da doença na página de agregação.  

### 1.2. Análise da Estrutura da Página de Agregação 
Toda a informação necessária encontra-se num elemento `div` com a classe `view-content`. No entanto, existe um outro elemento com esta classe anteriormente na DOM, que contém os elementos de navegação da lista capitular das doenças. Para poder selecionar apenas o elemento alvo, obtíve o seletor CSS do elemento em questão com a ajuda das DevTools do browser.  
Dento do *container* selecionado, todas as entradas seguem uma estrutura semelhante, com o título e descrição de cada doença isolados nos seus próprios elementos com as classes `views-field-title` e `views-field-body`, respetivamente. O nome da doença encontra-se num elemento `a`, dentro de um elemento `h3`, dentro do elemento do título, enquanto a sua descrição encontra-se num elemento `p`, dentro de um elemento `div`, dentro do elemento do corpo. Nesta última existem exceções á regra, com certas entradas contendo a descrição num elemento `div` em vez do normal `p`.  
Para extraír corretamente o conteúdo, pode-se discriminar o seletor para suportar os dois ramos, ou extraír o conteúdo textual através da propriedade `text`. Eu escolhi a segunda opção tanto para o corpo como para o título.  
A âncora que contém o nome da doença contém também um link para uma página que contém a descrição completa da doença. O link não possúi um padrão útil á sua estrutura, além do facto de ser um *hyperlink* absoluto, pelo que pode ser resolvido a partir da *origin* da página.  

### 1.3. Análise da Estrutura da Página da Doença 
Toda a informaçáo necessária encontra-se num container comum a todas as páginas de descrição de doença. De igual modo como na página de agregação, obtive o seletor CSS através das DevTools para obter uma referência ao elemento.  
Após analisar as páginas de descrição de diversas doenças, concluí que existe pouca consistência na organização dos elementos que compõem o conteúdo do elemento:  
- Certas páginas possúem subtítulos, representados por elementos `h3`, enquanto outras não possúem qualquer subtítulo.  
- Certas páginas inclúem uma secção no fim do *container* com "Artigos Relacionados", enquanto outras não a possúem.  
- Os parágrafos podem ser representados tanto com elementos `p`, como elementos `div`.  


## 2. Implementação
### 2.1. Detalhes de implementação 
A implementação começa por obter o conteúdo da página de agregação através do seu URL, por meio da biblioteca `requests`.  
De seguida, transforma o conteúdo HTML em texto puro numa DOM da biblioteca `BeautifulSoup` e obtém uma referência ao *container* das entradas das doenças através do seletor CSS obtido na fase de análise.  
Através dessa referência, a implementação itera por todos os descendentes do elemento e extraí o conteúdo textual do título e do corpo da entrada, bem como o *link* da âncora do título, através da hierarquia de elementos descrita na fase de análise.  
Para cada entrada, a implementação navega para o endereço da descrição da doença relativo á origem da página e constrói a DOM da página do mesmo modo como para a página de agregação, e obtém o *container* da descrição como seletor CSS obtido na fase de análise.  
Através dessa referência, a implementação itera por todos os descendentes do elemento e discrimina o tipo do elemento, excluíndo a secção de "Artigos Relacionados" ao parar a iteração ao encontrar o título com tal nome; transformando todos os elementos `h2` em subtítulos de segundo nível em Markdown e extraíndo todo o conteúdo textual de todos os outros elementos, acumulando todo o texto numa única string.  
Por fim, a implementação constrói um objeto JSON com o conteúdo extraído e adiciona-o ao array, que é então escrito para um ficheiro `doencas.json`.  


## 3. Scripts
### 3.1. stealer.py 
Web Scrapper criado para extraír a informação alvo da página web.  
Esta ferramenta aplica a metodologia descrita anteriormente.  
> **Ficheiro relacionado:** [./stealer.py](./stealer.py)
### 3.2. autonav.py 
Web Scrapper para extraír o inventário de uma página de teste.  
Esta ferramenta utiliza a biblioteca Selenium para navegar e processar a página.  
> **Ficheiro relacionado:** [./autonav.py](./autonav.py)


