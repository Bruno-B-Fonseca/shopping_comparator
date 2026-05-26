# Plano de Correção de Metadados e Refinamento de IA

Este plano descreve as ações necessárias para resolver o problema de correspondência incorreta de produtos (ex: EAN de Ovos resultando em Protetor Solar) e permitir que usuários corrijam dados corrompidos.

## 1. Refinamento do Prompt da IA (Backend)
**Arquivo:** `server/lib/ai_service.dart`
**Ação:** Atualizar o prompt para instruir explicitamente a IA a rejeitar resultados que não correspondam ao código de barras fornecido.

- Adicionar regra de "Barcode Match": Se os resultados de busca forem claramente de outro produto, retornar um erro ou nulo.
- Reforçar a extração de unidades brasileiras (ex: "12 unidades", "30 ovos").

## 2. Opção de "Forçar Re-cadastro" (Frontend)
**Arquivo:** `client/lib/screens/scan_screen.dart` e `client/lib/screens/product_search_screen.dart`
**Ação:** Adicionar um botão ou opção para descartar os dados atuais e forçar uma nova busca no cluster/IA.

- Adicionar ícone de "Refresh/Reset" no diálogo de edição de produto.
- Ao clicar:
    1. Remover o produto da box local `StorageService.products.delete(barcode)`.
    2. Disparar uma nova mensagem `product_request` para o servidor.
    3. Exibir feedback visual de "Re-processando...".

## 3. Mecanismo de Purga no Hub (Opcional/Futuro)
**Ação:** Implementar uma mensagem `msgGpiDelete` (restrita a operadores) para que, ao corrigir localmente, a informação errada também seja sugerida para remoção no Hub.

## 4. Validação de Resultados no Nó (Backend)
**Arquivo:** `server/lib/product_metadata_service.dart`
**Ação:** Adicionar uma verificação pós-IA. Se a IA retornar algo que pareça genérico demais ou se o usuário enviar um "hint" que conflita totalmente com o resultado da IA, priorizar o hint ou pedir revisão.

## Verificação
1. Tentar pesquisar novamente o EAN `7896935605006`.
2. Usar a opção "Forçar Re-cadastro".
3. Validar se o novo resultado (via prompt atualizado) ignora o protetor solar internacional e tenta buscar os ovos.
