# Plano: Atualização de Preços em Lote via NFC-e (Privacy-First) [CONCLUÍDO]

## Status: Implementado
- [x] Modelo `PriceUpdate` atualizado com `verificationLevel`.
- [x] `InvoiceService` com parser genérico e deduplicação anônima.
- [x] Rota `POST /bulk-import/invoice` com autenticação HMAC.
- [x] UI no `OperatorSettingsScreen` com suporte a scan de QR Code.
- [x] Selos de confiança na UI de pesquisa e scan.
Permitir que operadores de estabelecimentos atualizem o catálogo de preços de forma massiva e incontestável através do escaneamento de Notas Fiscais (NFC-e), garantindo integridade total dos dados sem violar a privacidade dos consumidores (LGPD) ou o modelo P2P anônimo.

## 2. Princípios de Privacidade (Zero-Knowledge)
- **Processamento Efêmero**: A URL da SEFAZ e os dados brutos da nota fiscal são processados apenas na memória RAM e descartados imediatamente após a extração dos preços.
- **Descarte de PII**: CPF do comprador, número da nota, chave de acesso e IDs de transação **NUNCA** são armazenados ou transmitidos para a rede.
- **Deduplicação Anônima**: O sistema armazena apenas um `hash(URL_Nota)` para evitar que a mesma nota seja processada múltiplas vezes, sem identificar a origem.

## 3. Fluxo de Trabalho do Operador
1. **Captura**: O operador acessa uma nova seção "Carga de Preços" (protegida por senha em `OperatorSettingsScreen`).
2. **Scan**: O app lê o QR Code de uma NFC-e emitida pelo próprio estabelecimento.
3. **Extração Local (L1)**:
    - O Servidor L1 acessa o portal da SEFAZ e extrai apenas: `barcode`, `unit_price`, `product_name` e `timestamp`.
4. **Verificação e Assinatura**:
    - O sistema cruza os dados com o `Global Product Index` para garantir nomes canônicos.
    - O Servidor L1 emite um broadcast federado de `price_update` com o selo `verified_by: "establishment"` e assinado via **HMAC**.

## 4. Arquitetura Técnica

### A. Módulo `SefazParser` (Backend L1)
- Implementar adaptadores para os diferentes padrões estaduais de portais NFC-e.
- Priorizar a extração via scraping de HTML direto na memória do servidor para evitar persistência de arquivos.

### B. Mudanças no Modelo `PriceUpdate` (Client)
- Adicionar campo `verificationLevel`: 
    - `0`: Manual (Usuário Comum)
    - `1`: Prova de Nota (Usuário com Scan de Cupom)
    - `2`: Oficial (Operador do Local com HMAC)

## 5. Implementação de Excelência: Filtro de Confiabilidade
A UI de busca (`ProductSearchScreen`) passará a priorizar a exibição dos preços de `Nível 2 (Oficial)` no topo, oferecendo ao comprador corporativo e à dona-de-casa a segurança de que o preço exibido é o praticado no caixa.

## 6. Etapas de Execução
1. **Passo 1**: Criar o serviço `InvoiceService` no `server/` para processamento de URLs SEFAZ.
2. **Passo 2**: Implementar lógica de descarte de PII agressiva no parser.
3. **Passo 3**: Adicionar botão "Importar via Nota Fiscal" na tela de configurações do operador.
4. **Passo 4**: Atualizar o protocolo de broadcast para incluir o nível de verificação.

## 7. Verificação
- Validar que, ao processar uma nota, nenhum dado sensível (como CPF) apareça nos logs do servidor ou nos pacotes WebSocket.
- Validar que a atualização de 10 produtos de uma nota fiscal ocorra em menos de 5 segundos no cluster.
