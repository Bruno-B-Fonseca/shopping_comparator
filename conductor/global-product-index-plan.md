# Plan: Global Product Index (GPI) & Normalização Federada

## 1. Objetivo
Garantir que um produto identificado pelo mesmo código de barras (EAN/GTIN) possua metadados idênticos (nome, marca, unidade, categoria) em toda a federação, permitindo comparações de preço precisas. Além disso, gerenciar produtos locais (artesanais/padaria) via categorização canônica para permitir a comparação de itens sem EAN global.

## 2. Arquitetura do Índice (Hierarquia L1/L2/L3)
- **L3 (Hub Nacional)**: Fonte da Verdade (SSOT). Mantém o banco de dados mestre de produtos validados.
- **L2 (Hubs Regionais)**: Caches de leitura e validadores regionais.
- **L1 (Servidores de Estabelecimento)**: Consultam o Hub antes de aceitar um novo cadastro. Adotam obrigatoriamente o nome canônico para produtos EAN.

## 3. Diferenciação de Escopo: Global vs Local

### A. Produtos Globais (Escopo: `global`)
- **Critério**: Códigos EAN-13/GTIN válidos (ex: iniciados em 789 para Brasil).
- **Chave Única**: `barcode`.
- **Regra**: Uma única entrada no GPI para toda a federação.

### B. Produtos Locais / Artesanais (Escopo: `local`)
- **Critério**: Códigos internos, PLUs de balança (ex: iniciados em 2) ou produtos sem código de barras.
- **Chave Única**: `namespace` (formato: `local:[location_id]:[barcode]`).
- **Regra**: Cada estabelecimento mantém sua versão, mas **DEVE** vincular a uma **Categoria Canônica**.

## 4. Normalização e Categorização Canônica
Para comparar o "Pão de Sal" da Padaria A com a Padaria B:
- **Ontologia de Categorias**: O Hub Nacional mantém uma árvore de categorias (ex: `ALIMENTOS > PADARIA > PAO_FRANCES`).
- **Ponte de Comparação**: A busca no App (`ProductSearchScreen`) agrupa resultados por:
    1. Mesma `barcode` (para globais).
    2. Mesma `canonical_category` (para locais).

## 5. Fluxo de Registro de Produto (O Protocolo GPI)

1. **Scan**: O usuário bipa o código.
2. **Identificação de Escopo**:
    - Se EAN global -> `gpi_lookup(barcode)`.
    - Se código local/balança -> Inicia fluxo de produto local vinculado à `location_id`.
3. **Consulta ao Hub**:
    - Se o Hub possui o dado (encontrado): Retorna metadados validados.
    - Se não possui (não encontrado): L1 propõe metadados via `gpi_propose`.
4. **Intervenção de IA (Hub Side)**:
    - O Hub usa LLM (Gemini/Qwen) para limpar o nome proposto (ex: "Coca 2L" -> "Refrigerante Coca-Cola 2L") e sugerir a categoria correta para itens locais.

## 6. Importação em Lote (JSON Import)
A funcionalidade de importação de produtos via JSON (`OperatorSettingsScreen`) deve ser integrada ao GPI para evitar a entrada de dados inconsistentes na federação:
- **Fluxo de Importação Inteligente**:
    1. O sistema itera sobre os produtos do JSON.
    2. Para produtos com **barcode global (EAN)**: O App realiza um `gpi_lookup` no Hub. Se o produto já existir no GPI, o App adota os dados canônicos do Hub, ignorando as variações do JSON.
    3. Para produtos com **barcode local**: O App aplica o namespace `local:[location_id]:[barcode]` e permite a importação.
- **Sincronização de Imagens**: Se o JSON contiver URLs de imagens, o App fará o download para o MinIO local e registrará a nova URL como proposta no GPI.

## 7. Mudanças no Protocolo (`protocol.dart`)
Novos tipos de mensagens:
- `msgGpiLookup`: Pedido de metadados.
- `msgGpiResponse`: Resposta com `ProductModel` validado e `is_verified: true`.
- `msgGpiPropose`: Proposta de novo cadastro/correção.

## 8. Impacto na UI (Frontend)
- **Badges de Confiança**: 
    - Selo "Verificado" para produtos vindos do GPI.
    - Selo "Produção Própria" para produtos locais.
- **Busca por Categoria**: A busca por texto agora prioriza a `canonical_category` para oferecer listas de comparação entre diferentes padarias.

## 9. Verificação e Excelência
- **Integridade**: "Coca-Cola" deve ter o mesmo nome em todos os servidores.
- **Comparabilidade**: Buscar "Coxinha" deve retornar preços da Padaria A e B simultaneamente.
- **Importação Limpa**: Validar que ao importar "Coke 2L", o sistema corrige para o nome canônico do GPI.
- **Performance**: Latência de lookup < 500ms.
