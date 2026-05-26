# Shopping Comparator

O Shopping Comparator é um ecossistema colaborativo e descentralizado de comparação de preços. Desenvolvido com foco em dispositivos móveis (Flutter Web/PWA) e infraestrutura baseada em Dart, o projeto permite que usuários colaborem em tempo real na manutenção de preços, registrem produtos via escaneamento e recebam estratégias de economia baseadas em geolocalização.

## Módulos Principais
- **Cliente (`client/`)**: Aplicação Flutter Web. Focada em offline-first (Hive), mapas interativos e sincronização via WebSockets.
- **Hub (`hub/`)**: Servidor de Federação em camadas. Gerencia registros regionais, tópicos de sincronização e retransmissão de mensagens entre clusters.
- **Servidor (`server/`)**: Proxy de WebSocket e Armazenamento (BFF). Responsável pela extração de produtos via IA, processamento de Notas Fiscais (NFC-e) e integração com MinIO para armazenamento de imagens.

## Funcionalidades Chave

### 1. Federação e Colaboração
- **Arquitetura Federada**: Servidores de estabelecimentos conectam-se a Hubs Regionais e Nacionais, criando uma malha de dados resiliente.
- **Sincronização P2P**: Clientes sincronizam automaticamente estados de produtos e preços ao se conectarem, usando uma lógica de "Sync Request" para recuperar dados perdidos enquanto offline.
- **Offline-first**: Dados são persistidos localmente (Hive) e sincronizados assim que a conectividade é detectada.

### 2. Coleta Inteligente e Automação
- **Registro Automático via IA**: Quando um código de barras é escaneado e não encontrado, o servidor busca automaticamente metadados (nome, marca) e imagens na web, utilizando modelos de IA (Gemini/Ollama) para estruturar os dados.
- **Atualização de Preços via NFC-e**: Operadores podem processar lotes de preços escaneando o QR Code de Notas Fiscais, com descarte rigoroso de PII (dados sensíveis) em memória, garantindo integridade dos dados e conformidade com LGPD.

### 3. Integração com MinIO
- **Storage de Imagens**: Migração completa do armazenamento Base64 para MinIO (compatível com S3). Imagens são hospedadas e servidas via URLs internas, reduzindo a carga de sincronização e o consumo de memória do dispositivo.

### 4. Inteligência de Consumo
- **Otimização de Lista de Compras**: Motor local (dispositivo) que calcula a melhor estratégia de compra (menor valor total e menor número de deslocamentos) baseado nos preços registrados na região.
- **Reputação (Web of Trust)**: Sistema de gamificação anônima que pontua colaboradores baseando-se na convergência de preços informados com dados oficiais (NFC-e).

## Infraestrutura e Segurança
- **Identidade HMAC**: Ações oficiais (promoções, registros de preço) são assinadas com chaves HMAC, garantindo a autenticidade dos dados e prevenindo spoofing ou injeções maliciosas.
- **Geo-Discovery**: Os nós da rede se auto-descobrem baseados em geolocalização, facilitando a adesão de novos estabelecimentos sem configuração manual pesada.
- **Resiliência**: Mecanismo de outbox (fila de uploads pendentes) para garantir que contribuições feitas em locais sem sinal não sejam perdidas.

## Desenvolvimento

### Pré-requisitos
- Docker e Docker Compose
- Flutter SDK (Web) e Dart SDK

### Execução (Docker Compose)
```bash
docker-compose up -d --build
```
- **App**: http://localhost:8081

### Código
Para trabalhar no projeto:
1. Sincronize dependências (`pub get`).
2. Utilize `build_runner` para regenerar adaptadores e serializadores após modificar modelos:
   ```bash
   cd client && dart run build_runner build --delete-conflicting-outputs
   ```
3. Rode o servidor e hub localmente para testes de federação.

---
*Status: MVP em evolução constante com foco em resiliência e integridade de dados federados.*
