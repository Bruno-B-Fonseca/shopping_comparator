# Plano de Implementação: Tela de Pesquisa de Produtos

Este plano descreve a substituição da tela de Chat pela nova tela de Pesquisa de Produtos, permitindo consultas por nome, fabricante, local e código de barras, exibindo o menor preço e sua localização.

## Objetivo
- Implementar a tela `ProductSearchScreen`.
- Integrar a nova tela no `HomeScreen`, substituindo o acesso ao Chat.
- Prover uma busca reativa e eficiente nos dados locais do Hive.

## Arquivos Afetados
- `client/lib/screens/product_search_screen.dart` (Novo)
- `client/lib/screens/home_screen.dart` (Modificado)

## Etapas de Implementação

### 1. Criação da Tela `ProductSearchScreen`
- Criar o arquivo `client/lib/screens/product_search_screen.dart`.
- Implementar um `ConsumerStatefulWidget` com um `TextEditingController` para a busca.
- Utilizar `ValueListenableBuilder` aninhados (ou combinados) para observar as boxes `products`, `prices` e `locations`.
- Implementar a lógica de filtragem:
    - Buscar no nome, fabricante e código de barras do produto.
    - Buscar em nomes de locais que possuam atualizações de preço para o produto.
- Para cada produto resultante, identificar o menor preço (`PriceUpdate`) e o respectivo local (`LocationModel`).
- Exibir os resultados em uma `ListView` com cards detalhados.

### 2. Integração no `HomeScreen`
- Importar `ProductSearchScreen`.
- Substituir `ChatScreen()` por `ProductSearchScreen()` na lista `_screens`.
- Descomentar a `NavigationDestination` correspondente, alterando o ícone para `Icons.search` e o rótulo para 'Pesquisa'.

## Verificação e Testes
- **Busca por Nome**: Digitar parte do nome de um produto e verificar se ele aparece.
- **Busca por Fabricante**: Digitar o nome de um fabricante e verificar os produtos associados.
- **Busca por Local**: Digitar o nome de um estabelecimento e verificar se aparecem produtos que tiveram preços registrados lá.
- **Busca por Barcode**: Digitar o código de barras exato.
- **Menor Preço**: Validar se o preço exibido é realmente o menor entre os registros do produto.
- **Sincronização**: Verificar se novos produtos ou preços recebidos via WebSocket aparecem na busca em tempo real.
