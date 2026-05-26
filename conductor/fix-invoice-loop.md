# Plano: Correção de Loop NFC-e e Persistência de Sessão

Este plano resolve o erro de recursão infinita no `InvoiceService` e melhora a chance de sucesso na extração de dados da SEFAZ.

## Mudanças Propostas

### 1. `server/lib/invoice_service.dart`
- **Remover Recursão**: Alterar a lógica para que o fallback de URL original seja feito sequencialmente, sem chamar a função `processInvoiceUrl` novamente.
- **Persistent Client**: Mudar de `http.get` para `_client.get` usando uma instância persistente da classe `http.Client`. Isso permite que o servidor mantenha cookies entre as requisições (útil para portais que exigem sessão).
- **Log Amigável**: Melhorar as mensagens de log para diferenciar tentativas de redirecionamento.

## Verificação e Testes
1.  Executar `make node-up` com reconstrução do servidor.
2.  Escanear a nota fiscal de Goiás.
3.  Verificar no log se ele tenta a URL detalhada, falha com 403, tenta a original e **para**, sem entrar em loop.

## Rollback
- Reverter o arquivo `invoice_service.dart` para a versão inicial.
