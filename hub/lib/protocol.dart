/// Tipos de mensagem existentes
const String msgRegister = 'register';
const String msgSubscribe = 'subscribe';
const String msgPublish = 'publish';
const String msgUnregister = 'unregister';
const String msgRelay = 'relay';
const String msgPeersUpdate = 'peers_update';
const String msgPing = 'ping';
const String msgPong = 'pong';
const String msgError = 'error';
const String msgProductRequest = 'product_request';
const String msgSyncRequest = 'sync_request';
const String msgSyncResponse = 'sync_response';
const String msgReputationUpdate = 'reputation_update';

/// Mensagens do Global Product Index (GPI)
const String msgGpiLookup = 'gpi_lookup';
const String msgGpiResponse = 'gpi_response';
const String msgGpiPropose = 'gpi_propose';
const String msgGpiDelete = 'gpi_delete';

/// Novos tipos de mensagem para autenticação HMAC
const String msgAuthChallenge = 'auth_challenge';
const String msgAuthResponse = 'auth_response';

/// Campos comuns existentes
const String fieldType = 'type';
const String fieldServerId = 'serverId';
const String fieldRegion = 'region';
const String fieldWsUrl = 'wsUrl';
const String fieldTopics = 'topics';
const String fieldTopic = 'topic';
const String fieldPayload = 'payload';
const String fieldMessageId = 'messageId';
const String fieldTimestamp = 'timestamp';
const String fieldOriginServerId = 'originServerId';
const String fieldPeers = 'peers';
const String fieldMessage = 'message';

/// Novos campos para autenticação
const String fieldNonce = 'nonce';
const String fieldSignature = 'signature';
const String fieldLocationId = 'locationId';
const String fieldBarcode = 'barcode';
const String fieldContributorHash = 'contributorHash';
const String fieldTrustScore = 'trustScore';
const String fieldBonus = 'bonus';
