# Plano de Evolução: Segurança, Federação e Autenticação (Server-Auth)

## Objetivo
Transformar a arquitetura para o modelo **"Servidor = Local Autônomo"**, onde cada servidor (com seu próprio DNS/Domain) atua como um nó federado legítimo. Proteção por senha (`.env`) e comunicação autenticada via Hub garantem integridade comercial.

## 1. O Modelo de Operação
- **Servidor como Local**: Cada instância de servidor é um estabelecimento único (ex: mercado, farmácia).
- **Acesso Global**: O app acessa servidores via DNS/NGROK, não limitado a Wi-Fi local. A rede é uma federação de estabelecimentos.
- **Isolamento de Dados**:
    - **Preços**: Apenas compartilhados no cluster se o servidor estiver autenticado e validado pelo Hub. Preços fora de locais registrados ficam restritos ao carrinho local.
    - **Chat**: O chat do servidor torna-se um canal oficial de divulgação do estabelecimento. Postagens exigem a senha do server (operador).

## 2. Infraestrutura e Segurança
- **Identidade Única**: `LOCATION_ID` + `LOCATION_PASSWORD` + `COORDINATES` definem o servidor no Hub.
- **Autenticação (Server-side)**: O servidor valida o operador via senha antes de aceitar postagens de promoções/ofertas no chat ou registros de preços.
- **Protocolo Federado (Segurança HMAC)**:
    - **Handshake de Prova de Posse**: Hub desafia servidores no registro para validar a senha.
    - **Legitimidade Federada**: Hub assina a autenticidade dos servidores. Promoções recebidas pelo app são verificadas via assinatura HMAC para garantir que vêm de um servidor legítimo e não de um impostor.

## 3. Impacto na Experiência do Usuário (UX)
- **Flexibilidade**: O App se conecta a qualquer servidor federado via URL.
- **Privacidade e Proteção**: Promoções e preços são "marcados" como oficiais pelo servidor. O App destaca visualmente o que é "Promoção Oficial" versus o que é "Preço de Usuário".
- **Acesso Seguro**: Senha do servidor armazenada de forma segura (Keychain/SharedPrefs) para postagens oficiais.

## 4. Plano de Implementação

### Passo 1: Refinamento do Protocolo
- Adicionar campos `signature` (HMAC) e `messageId` em mensagens de Promoção e Preço.
- Definir fluxo de Challenge-Response entre Servidor e Hub.

### Passo 2: Server-side Auth
- Implementar validador de HMAC no `ClusterService` do servidor.
- Hub passa a exigir validação HMAC para transmitir mensagens de um servidor para outros.

### Passo 3: Client-side Auth
- Atualizar `WebSocketService` e telas de Chat/Scan para gerenciar autenticação do operador (senha) e exibição de selos de "Promoção Oficial".

## 5. Cronograma e Verificação
1. **Segurança**: Testar Handshake contra impostores.
2. **Federação**: Validar se mensagens sem assinatura HMAC correta são descartadas pelo Hub.
3. **UX**: Validar fluxo de postagem oficial no chat com senha.

## 6. Rollback
- Em caso de falha na autenticação, o servidor mantém seu chat como "livre" (sem selo oficial) e os preços não são federados, protegendo a integridade do cluster.
