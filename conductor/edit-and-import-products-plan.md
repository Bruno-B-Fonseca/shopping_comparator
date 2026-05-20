# Plano de Implementação: Edição de Produtos e Importação JSON

Este plano descreve as alterações necessárias para permitir que usuários operadores editem produtos na tela de pesquisa e realizem a importação de produtos via arquivo JSON nas configurações.

## 1. Alterações nas Dependências
- Adicionar `file_picker` ao `client/pubspec.yaml` para permitir a seleção de arquivos JSON no navegador/dispositivo.

## 2. Tela de Pesquisa de Produtos (`client/lib/screens/product_search_screen.dart`)
- Converter `_ProductResultTile` em um `ConsumerWidget` para acessar o `authProvider`.
- Adicionar um botão de edição (`Icons.edit`) no card do produto, visível apenas para operadores.
- Implementar a função `_showEditProductDialog` que:
    - Abre um `AlertDialog` com campos de texto para: Nome, Fabricante, Unidade e Informações Nutricionais.
    - Ao salvar, cria uma nova instância de `Product` com os dados atualizados e salva no Hive (`StorageService.products.put(product.barcode, updatedProduct)`).
    - Exibe um feedback de sucesso.

## 3. Tela de Configurações do Operador (`client/lib/screens/operator_settings_screen.dart`)
- Adicionar uma nova seção "Importação de Dados" visível para operadores.
- Adicionar um botão "Importar Produtos (JSON)".
- Implementar a lógica de importação:
    - Utilizar `FilePicker` para selecionar um arquivo `.json`.
    - Ler e decodificar o conteúdo do arquivo.
    - Iterar sobre a lista de produtos no JSON.
    - Verificar se o código de barras (`barcode`) já existe no box `products`.
    - Se não existir, adicionar o novo produto.
    - Se existir, pular (conforme solicitado).
    - Exibir um resumo ao final (ex: "X produtos importados, Y já existiam").

## 4. Verificação
- Logar como operador e pesquisar um produto. Verificar se o botão de edição aparece e funciona.
- Logar como usuário comum e verificar se o botão de edição NÃO aparece.
- Nas configurações de operador, testar a importação de um arquivo JSON válido.
- Verificar se produtos duplicados são realmente pulados.
- Verificar se a persistência no Hive funciona após fechar e abrir o app.
