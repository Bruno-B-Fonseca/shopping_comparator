# Plano de Melhorias: Carrinho de Compras

## Objetivo
Implementar controle de orçamento (valor limite, total, restante) e ajuste dinâmico de quantidade de itens na `CartScreen`.

## Mudanças Propostas

### 1. `client/lib/providers/cart_provider.dart`
- Adicionar `updateQuantity(int index, double delta)`: Método para alterar a quantidade de um `CartItem`.
- Adicionar um novo provider `budgetProvider` (StateNotifier) para gerenciar o valor limite.

### 2. `client/lib/screens/cart_screen.dart`
- **Novo Widget de Orçamento**: Criar seção superior com:
  - `TextFormField` para definir "Valor Limite".
  - Cards exibindo "Total Atual" e "Valor Restante" (Total - Limite, formatado).
- **Ajuste na Listagem**:
  - Na `trailing` do `ListTile` do produto, adicionar botões `-` e `+` (usando `IconButton`) para chamar `cartProvider.notifier.updateQuantity`.

## Verificação
- Verificar se o valor limite persiste ou se é resetado (será implementado com `StateProvider` temporário por sessão ou Hive se persistência for necessária).
- Validar se os cálculos de "Total" e "Restante" são reativos.
- Garantir que a `quantity` não se torne negativa.
