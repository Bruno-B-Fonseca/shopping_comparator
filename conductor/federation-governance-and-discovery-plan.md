# Plano: Governança e Descoberta Automática de Nós (Service Discovery)

## 1. Objetivo
Garantir que o aplicativo encontre automaticamente os servidores e hubs mais próximos sem intervenção manual do usuário, estabelecendo uma rede de confiança (Web of Trust) que previna impostores e garanta a perenidade da federação.

## 2. O Problema das "Páginas Amarelas"
Para ser uma infraestrutura nacional, o ShopComp não pode depender de URLs fixas no código. O sistema precisa de um diretório dinâmico.

## 3. Descoberta baseada em Geolocalização (Geo-Discovery)

### A. O Geo-Registry (Hub L3)
O Hub Nacional (`shopcomp.org`) manterá um índice geoespacial simplificado:
1. **Registro**: Quando um Servidor L1 ou Hub L2 sobe, ele envia suas coordenadas e URL pública para o L3.
2. **Consulta**: O App envia sua Lat/Long para `https://api.shopcomp.org/discover`.
3. **Resposta**: O L3 retorna os Hubs Regionais e Servidores Locais ativos em um raio de proximidade (ex: 50km).

### B. Descoberta Local (In-Store Discovery)
Para locais com sinal de internet ruim (subsolos):
- **QR Code de Entrada**: O estabelecimento exibe um QR Code com a URL do servidor local e a senha de visitante (opcional).
- **DNS Local**: Se o usuário estiver no Wi-Fi do mercado, o app tenta resolver `shopcomp.local` para encontrar o servidor sem sair para a internet.

## 4. Governança e Cadeia de Confiança (Chain of Trust)

### A. Validação de Identidade (Níveis de Selo)
- **Nível Bronze (Não Verificado)**: Servidor auto-declarado. Sem validação oficial.
- **Nível Prata (Regional)**: Validado por um Hub L2 (ex: uma associação comercial local que atesta que o mercado existe).
- **Nível Ouro (Nacional)**: Validado pelo Hub L3 via prova de posse de domínio (DNS TXT record) ou certificado e-CNPJ.

### B. Sistema de Reputação de Nós
Hubs Regionais monitoram o "uptime" e a qualidade dos dados dos Servidores L1. Servidores que propagam preços fora da realidade de mercado (detectados via IA de anomalia no Hub) perdem reputação e podem ser suspensos da federação automática.

## 5. Sustentabilidade e Incentivos
- **Nós Institucionais**: Encorajar Prefeituras a manterem Hubs Regionais (L2) como serviço de transparência de preços à população.
- **Consórcio de Dados**: Grandes compradores (restaurantes) podem patrocinar nós em troca de acesso prioritário a dashboards de análise de tendência (sempre anonimizados).

## 6. Mudanças Técnicas Necessárias
1. **Hub Nacional**: Implementar API REST de Geo-Registry e banco de dados de mapeamento dinâmico `locationId -> currentUrl`.
2. **Servidores L1/L2**: Incluir metadados de localização (Lat/Long) e a URL pública atual no payload de registro e nas mensagens de heartbeat.
3. **Frontend**: Implementar lógica de "Auto-Switch" e consulta periódica ao Geo-Registry para atualizar URLs de servidores conhecidos.

## 7. Verificação de Excelência
- **Fricção Zero**: O usuário abre o app em uma cidade nova e vê os preços locais instantaneamente, sem configurar nada.
- **Segurança**: Tentar subir um servidor "fake" com o nome de uma grande rede e validar que ele não recebe o selo "Ouro" sem a prova de domínio.
- **Resiliência**: Se o Hub Nacional cair, o app deve usar o último cache de servidores conhecidos (Offline-Discovery).
e registro.
3. **Frontend**: Implementar lógica de "Auto-Switch": se o usuário se mover mais de 20km, o app sugere trocar de servidor de cluster.

## 7. Verificação de Excelência
- **Fricção Zero**: O usuário abre o app em uma cidade nova e vê os preços locais instantaneamente, sem configurar nada.
- **Segurança**: Tentar subir um servidor "fake" com o nome de uma grande rede e validar que ele não recebe o selo "Ouro" sem a prova de domínio.
- **Resiliência**: Se o Hub Nacional cair, o app deve usar o último cache de servidores conhecidos (Offline-Discovery).
