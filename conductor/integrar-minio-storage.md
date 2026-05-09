# Plano: Integração de Storage de Imagens com MinIO

  Objetivo: Implementar uma solução de armazenamento de imagens para produtos, utilizando o MinIO como serviço de storage (compatível com S3) no Docker Compose, visando remover a
  dependência de Base64 no Hive e garantir escalabilidade e performance na sincronização de dados entre clientes.

  Escopo:

- Integração do serviço MinIO ao ecossistema existente.
- Refatoração do modelo Product e da lógica de armazenamento.
- Implementação de upload de imagens no Backend e Frontend.

  Implementação:

   1. Infraestrutura (Docker Compose): [x]
       - Adicionar serviço minio no docker-compose.yml. [x]
       - Mapear volume persistente para dados do MinIO. [x]
       - Configurar ambiente (ROOT_USER, ROOT_PASSWORD). [x]
       - Configurar redes para comunicação com os demais serviços. [x]

   2. Backend (Server): [x]
       - Adicionar dependência minio no server/pubspec.yaml. [x]
       - Criar serviço de interação com MinIO (Singleton/Service). [x]
       - Adicionar rota POST /products/upload-photo para receber o arquivo. [x]
       - Ajustar a API para fornecer a URL de acesso à imagem (resolver URL pública/presigned). [x]

   3. Frontend (Client): [x]
       - Refatorar lib/models/product.dart: substituir photoBase64 por photoUrl (String). [x]
       - Rodar build_runner para regenerar adapters e JSON serializers. [x]
       - Implementar ImageService na camada de serviço. [x]
       - Criar widget ProductImagePicker integrado à câmera/galeria. [x]
       - Atualizar HomeScreen e ScanScreen para exibir a imagem via Image.network. [x]

       Verificação e Testes:

- Infra: Validar se o container MinIO sobe corretamente e se o bucket é acessível. [x]
- Upload: Testar fluxo de upload da imagem pelo cliente e persistência no MinIO. [x]
- Sincronização: Validar se, após o upload, a URL da imagem é persistida no Hive e atualizada entre dispositivos via WebSocket. [x]
- UI: Validar a renderização da imagem no app utilizando os novos campos. [x]
