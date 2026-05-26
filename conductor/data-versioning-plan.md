# Plano de Versionamento e Resolução de Conflitos

Este plano resolve o problema de regressão de dados, onde dispositivos com cadastros antigos sobrescrevem atualizações recentes (como novas imagens ou info nutricional) durante a sincronização.

## 1. Alterações nos Modelos (Frontend)
**Arquivos:** `client/lib/models/product.dart` e `client/lib/models/location_model.dart`
**Ação:** Adicionar o campo `updatedAt` (DateTime) aos modelos para rastrear a "frescura" do dado.

- `Product`: Adicionar `@HiveField(8) final DateTime? updatedAt;`
- `LocationModel`: Adicionar `@HiveField(9) final DateTime? updatedAt;`
- Atualizar construtores e factory `fromJson/toJson`.

## 2. Lógica de Resolução de Conflitos (Frontend)
**Arquivo:** `client/lib/services/sync_service.dart`
**Ação:** Implementar uma estratégia de "O Dado Mais Novo Vence".

- Ao receber `product_registration` ou `location_registration`:
    1. Buscar o item local no Hive pelo ID/Barcode.
    2. Se não existir localmente, salvar o item recebido.
    3. Se existir localmente:
        - Comparar `incoming.updatedAt` com `local.updatedAt`.
        - Se `incoming.updatedAt` for posterior ao local, atualizar o Hive.
        - Caso contrário (item recebido é antigo), ignorar a mensagem.
- Adicionar regra de ouro: Dados com `isVerified: true` sempre vencem dados não verificados, a menos que ambos sejam verificados (aí o timestamp decide).

## 3. Manutenção do Timestamp (Frontend/UI)
**Arquivos:** `client/lib/screens/product_search_screen.dart`, `client/lib/screens/scan_screen.dart`, `client/lib/screens/establishments_screen.dart`
**Ação:** Garantir que o timestamp seja atualizado em qualquer edição manual.

- Ao salvar um produto ou local, definir `updatedAt: DateTime.now()`.

## 4. Alinhamento no Backend (Server/Hub)
**Arquivos:** `server/lib/product_metadata_service.dart`, `hub/lib/services/gpi_service.dart`
**Ação:** Garantir que cadastros automáticos via IA também tragam o timestamp inicial.

## 5. Geração de Código
Executar `dart run build_runner build --delete-conflicting-outputs` no diretório `client/` para atualizar os adaptadores Hive e serializers JSON.

## Verificação
1. Dispositivo A (Operador): Atualizar a imagem de um produto.
2. Dispositivo B (Novo): Conectar e sincronizar.
3. Verificar no log se o Dispositivo B recebeu a imagem nova.
4. Tentar simular o Dispositivo B enviando um dado antigo e verificar se o Dispositivo A o ignora corretamente.
