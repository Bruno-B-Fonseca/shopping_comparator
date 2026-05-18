# Plano: Estabelecimentos Geofenciados e Edição Autenticada

## Objetivo
Implementar uma infraestrutura de estabelecimentos (supermercados, farmácias, etc.) onde os dados são públicos para consulta global (via cluster federado), mas a edição das informações do servidor/local é restrita ao operador autenticado.

## 1. Modelo de Acesso
- **Consulta Pública**: Qualquer usuário do sistema pode visualizar a lista de estabelecimentos, navegar pela lista de produtos/preços e ler o canal de comunicação oficial do local.
- **Edição Autenticada**: A modificação de dados (nome, logo, geofence) é uma operação protegida. Apenas o operador do servidor, validado via senha e autenticação HMAC (assinatura), pode realizar estas alterações.

## 2. Mudanças na Estrutura

### A. Edição (Restrita ao Operador)
- **UI (`EstablishmentsScreen`)**: O botão de edição apenas será exibido se o operador estiver autenticado (possuir `location_password` configurada no App).
- **Protocolo de Edição**: Toda solicitação de `update_location` enviada ao servidor deve conter a assinatura `HMAC` gerada pela `LOCATION_PASSWORD`. O servidor validará a assinatura antes de persistir a mudança no `LocationModel` e federar a atualização para o Hub.

### B. Consulta (Pública)
- **Sincronização Federada**: O servidor mantém os dados do local (nome, perímetro, logo) e os replica via `Hub` para que outros clientes possam acessar as informações via cluster.
- **Canais Oficiais**: O chat do servidor é lido como canal público de comunicados do estabelecimento, com destaque visual (selo oficial) caso a mensagem possua assinatura HMAC válida.

## 3. Plano de Implementação

### Passo 1: UI Condicional
- Refatorar a lista de estabelecimentos para verificar `operator_settings` antes de exibir botões de edição.

### Passo 2: API de Edição Segura
- Criar endpoint/tipo de mensagem `update_location` que exija `signature`, `timestamp` e `messageId` (idêntico ao protocolo de chat/promoção).

### Passo 3: Federação
- Garantir que o Hub propague a lista de locais atualizada para o cluster sempre que o servidor for autenticado.

## 4. Verificação
- **Usuário Comum**: Valida acesso total à leitura (locais, preços, produtos e chat oficial).
- **Operador**: Valida que edições só ocorrem após autenticação bem-sucedida e assinatura da mensagem.
