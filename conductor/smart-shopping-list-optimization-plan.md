# Plano: Lista de Compras Inteligente e Otimização de Rota

## 1. Objetivo
Transformar o Shopping Comparator em um assistente de economia ativa, permitindo que usuários criem listas de compras e recebam automaticamente a melhor estratégia de compra (quais estabelecimentos visitar para obter o menor valor total, considerando proximidade).

## 2. Cenários de Uso (Excelência em Utilidade)
- **Dona de Casa**: "Quero comprar os 20 itens da minha feira mensal gastando o mínimo possível, mas não quero ir em mais de 2 supermercados."
- **Dono de Restaurante**: "Preciso de 50kg de carne e 100L de leite. Qual atacado na região tem o melhor preço de lote hoje?"
- **Compra Coletiva**: "Minha família compartilha uma lista. Quem passar perto do mercado X traz os itens que estão mais baratos lá."

## 3. O Algoritmo de Otimização (Local-First)
Para respeitar a privacidade, o cálculo de otimização ocorre inteiramente no dispositivo do usuário:
1. **Entrada**: Lista de produtos (EAN ou Categoria Canônica).
2. **Filtro Geográfico**: Seleciona estabelecimentos num raio de X km (configurável).
3. **Cruzamento de Preços**: Busca na `Box<PriceUpdate>` local os preços mais recentes de cada item nos locais filtrados.
4. **Resolução de Cesta**:
    - **Cenário A (Econômico Total)**: O menor preço de cada item, ignorando o número de paradas.
    - **Cenário B (Equilibrado)**: Sugere até 2 ou 3 estabelecimentos que, combinados, cobrem a lista com o maior desconto possível.

## 4. Novas Funcionalidades e UI

### A. Nova Aba: "Minhas Listas"
- Interface para criação de múltiplas listas (ex: "Churrasco", "Limpeza", "Mensal").
- Suporte a itens genéricos (ex: "Tomate") que usam a `canonical_category` para busca.

### B. Painel de Otimização ("Sugestão de Compra")
- Um widget que exibe:
    - "Vá ao **Mercado A** para comprar 12 itens (Economia de R$ 30,00)."
    - "Vá à **Padaria B** para comprar 3 itens (Economia de R$ 5,00)."
    - Itens não encontrados na região.

### C. Integração com Mapas
- Rota sugerida no mapa ligando os pontos de venda escolhidos.

## 5. Colaboração P2P de Listas
- Utilizar o `WebSocketService` para permitir que usuários "assinem" a mesma lista.
- Quando o Usuário A marca um item como "comprado", o Usuário B recebe a atualização em tempo real (Sync de estado via Hive).

## 6. Mudanças Técnicas
1. **Modelos**: Criar `ShoppingList` e `ListItem` (vinculado a `barcode` ou `category`).
2. **Providers**: Implementar `OptimizationProvider` (computação pesada via Isolate para não travar a UI).
3. **Persistência**: Nova Box Hive `shopping_lists`.

## 7. Verificação de Excelência
- **Precisão**: Validar se a soma dos preços sugeridos bate com o total real dos estabelecimentos.
- **Performance**: O cálculo para uma lista de 50 itens em 10 mercados deve levar menos de 2 segundos.
- **Offline**: A otimização deve funcionar mesmo sem internet, usando os preços cacheados na última sincronização.

## 8. Etapas de Execução
1. **Passo 0 (Fundação Inteligente)**:
    - Implementar `Autocomplete` na adição de itens buscando no banco de produtos local.
    - Se um código EAN desconhecido for digitado, disparar `product_request` para o Hub/IA.
    - Vincular itens da lista ao `barcode` oficial para garantir a precisão da otimização.
2. **Passo 1**: Implementar o CRUD de `ShoppingList`.
2. **Passo 2**: Criar o motor de busca por categoria canônica na base de preços.
3. **Passo 3**: Desenvolver a lógica de agrupamento por estabelecimento (Otimizador).
4. **Passo 4**: Adicionar visualização de economia e rotas.
