# Plano: Resiliência, Manutenção e Economia de Dados (Estratégia Nacional)

## 1. Objetivo
Garantir a sustentabilidade técnica e econômica da federação ShopComp, prevenindo a obesidade de dados nos dispositivos, reduzindo o consumo de banda dos usuários e protegendo a rede contra extração predatória de dados (scraping).

## 2. Gestão de Ciclo de Vida do Dado (Anti-Obesidade)

### A. Poda de Preços (Pruning de 15 dias)
- **Regra**: Registros de `PriceUpdate` com mais de **15 dias** de antiguidade serão removidos da base ativa (Hive) nos dispositivos móveis e nos servidores de cache L1/L2.
- **Fluxo de Arquivamento Histórico (Cold Storage)**:
    1. Antes da exclusão, o Servidor L1 (Estabelecimento) consolida os preços expirados em arquivos JSONL compactados.
    2. Esses arquivos são enviados para um bucket dedicado no **MinIO da Federação** (`history-analytics`).
    3. **Finalidade**: Permitir análises de tendência de inflação e histórico de preços para utilidade pública, sem onerar o banco de dados de tempo real.

## 3. Defesa da Rede (Anti-Scraping e Integridade Comercial)

### A. Política de Freshness (Apenas 1 Hora)
- O sistema de sincronização prioriza e processa apenas mensagens geradas na **última hora**.
- **Análise Técnica**: Sincronizar apenas a última hora é suficiente para a "frescura" do dado de consumo (UX), mas não impede o scraping de dados em tempo real.
- **Sanções Propostas**:
    - **Monitoramento de Volume**: O Hub Nacional (L3) monitorará o volume de requisições por ID/IP.
    - **Bloqueio de Robôs**: Usuários que solicitarem metadados de mais de X produtos (ex: 500 itens) em um curto intervalo serão banidos temporariamente do broadcast.

## 4. Economia de Banda (Sync Geofenciado e Temporal)

### A. O Filtro "7km / 1h"
Para garantir que o app funcione bem em conexões 4G/5G limitadas, o `sync_request` passará a aceitar parâmetros de filtro:
1. **Raio Geográfico**: O Hub apenas enviará atualizações de preços de estabelecimentos em um raio de **7km** das coordenadas atuais do usuário.
2. **Janela Temporal**: Apenas dados da **última hora** serão transmitidos no handshake inicial de conexão.
3. **Delta Sync**: O app solicitará apenas o que mudou desde seu último `last_sync_timestamp`.

## 5. Resiliência: Mecanismo de Outbox (Sinal de Subsolo)
- Implementar uma fila de saída (`Box<PendingUploads>`) para salvar preços capturados em locais sem sinal.
- O `SyncService` tentará transmitir esses dados em background assim que detectar uma conexão estável, garantindo que o esforço colaborativo do usuário não seja perdido.

## 6. Verificação de Excelência
- **Eficiência**: O banco de dados Hive não deve ultrapassar 100MB de armazenamento total, independente do tempo de uso.
- **Performance**: O tempo de sincronização inicial (handshake) não deve exceder 2 segundos em conexões móveis.
- **Proteção**: Validar que um script automatizado tentando baixar toda a base de preços seja bloqueado pelo Hub em menos de 30 segundos.
