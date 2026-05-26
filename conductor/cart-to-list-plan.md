# Plano: Salvar Carrinho como Lista

Este plano permite que o usuário transforme os itens bipados no carrinho em uma lista de compras persistente.

## Mudanças Propostas

### 1. `client/lib/providers/shopping_list_provider.dart`
- Implementar `createListFromCart(String name, List<CartItem> cartItems)`.
- Converter `CartItem` (que tem preço real) para `ShoppingListItem` (que foca no vínculo do produto para otimização futura).

### 2. `client/lib/screens/cart_screen.dart`
- Adicionar ícone `Icons.save_as` no `appBar.actions`.
- Exibir diálogo solicitando o nome da nova lista.
- Chamar o provider para salvar e mostrar uma confirmação (SnackBar).

## Verificação e Testes
1.  Bipar 2 ou 3 produtos no carrinho.
2.  Clicar em "Salvar como Lista".
3.  Dar o nome "Teste Carrinho".
4.  Navegar até a aba "Minhas Listas" e verificar se ela apareceu com os itens corretos.

## Rollback
- Remover o botão do `CartScreen` e a função do provider.
