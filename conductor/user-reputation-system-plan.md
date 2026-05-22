# Plano: Sistema de Reputação (Web of Trust) e Gamificação Anônima

## 1. Objetivo
Estabelecer um mecanismo de confiança para dados colaborativos e estimular a participação ativa dos usuários através de gamificação (termômetro de confiança), mantendo a anonimidade total (LGPD).

## 2. A Identidade Anônima (Contributor ID)
- **Geração Local**: No primeiro acesso, o App gera uma chave secreta aleatória e armazena de forma segura no dispositivo.
- **Hash de Dispositivo**: Para todas as comunicações, o App envia apenas o `SHA-256(SecretKey)`, que chamaremos de `contributorHash`.
- **Privacidade**: Não há como reverter o hash para identificar o usuário. O usuário tem o "Direito ao Esquecimento" ao apagar os dados do app.

## 3. Mecanismo de Score (Prova de Acerto)
A reputação é baseada na convergência de fatos e frequência:
- **Gatilho de Incremento**: Quando um preço enviado pelo usuário coincide com um preço enviado por um **Operador (Oficial via NFC-e)**, o Hub emite um bônus (ex: +5 pontos).
- **Penalidade (Resfriamento)**:
    - **Divergência**: Se o preço informado pelo usuário for invalidado por uma Nota Fiscal oficial no mesmo dia (erro > 20%), o score sofre uma redução (ex: -10 pontos).
    - **Inatividade (Time Decay)**: A reputação é volátil. Se o usuário não fizer contribuições por mais de 15 dias, o score começa a "esfriar" (redução de 5% ao dia). Isso garante que o "Mestre da Economia" seja alguém ativo no presente.
- **Feedback Automático**: O Hub envia mensagens de `reputation_update`. O App monitora seu próprio hash para atualizar o termômetro.

## 4. Gamificação: O Termômetro de Confiança
Para estimular a colaboração, o App terá um indicador visual exclusivo para o usuário (em `OperatorSettingsScreen` ou no `ScanScreen`):
- **Nível Frio (0-10)**: "Colaborador Iniciante".
- **Nível Morno (11-50)**: "Informante Local". (Ícone de Termômetro azul/amarelo).
- **Nível Quente (51-100)**: "Vigilante de Preços". (Ícone de Fogo pequeno).
- **Nível Fogueira (100+)**: "Mestre da Economia". (Animação de Fogueira intensa).

## 5. Persistência e Sincronização
### A. Hub Nacional (Oráculo)
O Hub mantém o arquivo `config/reputation_db.json` com o mapeamento `{ contributorHash: score }`.
### B. Injeção de Confiança (Trust Injection)
Mensagens de preço recebem o campo `trustScore` injetado pelo Hub no momento do relay, informando à rede o nível de confiabilidade daquele dado.

## 6. Etapas de Execução
1. **Passo 1**: Atualizar o protocolo para incluir `fieldContributorHash` e `fieldTrustScore`.
2. **Passo 2**: Implementar `ReputationService` no Hub com lógica de persistência JSON.
3. **Passo 3**: Criar o widget `ConfidenceThermometer` no Flutter com animações baseadas no score.
4. **Passo 4**: Implementar lógica no `WebSocketService` para capturar `reputation_update` destinados ao próprio usuário.

## 7. Verificação de Excelência
- **Privacidade**: Validar que o score de outros usuários nunca é exibido de forma que permita rastreamento, apenas como um "selo de qualidade" no dado.
- **Engajamento**: Verificar se a transição visual (frio -> fogo) ocorre suavemente conforme os dados são validados por notas fiscais.
