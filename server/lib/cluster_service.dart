import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';
import 'protocol.dart';

final Logger _log = Logger('ClusterService');

class ClusterService {
  final String hubUrl;
  final String region;
  final String serverId;
  final String publicWsUrl;

  late WebSocketChannel _hubChannel;
  final Function(Map<String, dynamic> payload, String originServerId)
  onRelayMessage;

  ClusterService({
    required this.hubUrl,
    required this.region,
    required this.publicWsUrl,
    required this.onRelayMessage,
  }) : serverId = const Uuid().v4();

  void connect() {
    _log.info('Connecting to Hub: $hubUrl');
    _hubChannel = WebSocketChannel.connect(Uri.parse(hubUrl));

    _hubChannel.sink.add(
      jsonEncode({
        fieldType: msgRegister,
        fieldServerId: serverId,
        fieldRegion: region,
        fieldWsUrl: publicWsUrl,
      }),
    );

    _hubChannel.stream.listen(
      (message) {
        final msg = jsonDecode(message as String);
        _handleHubMessage(msg);
      },
      onDone: () => _log.warning('Disconnected from Hub'),
      onError: (e) => _log.severe('Hub error: $e'),
    );
  }

  void _handleHubMessage(Map<String, dynamic> msg) {
    final type = msg[fieldType];
    switch (type) {
      case msgPing:
        _hubChannel.sink.add(jsonEncode({fieldType: msgPong}));
        break;
      case msgRelay:
        onRelayMessage(msg[fieldPayload], msg[fieldOriginServerId] as String);
        break;
      case msgPeersUpdate:
        _log.info('Peers updated: ${msg[fieldPeers]}');
        break;
    }
  }

  void publish(String topic, Map<String, dynamic> payload) {
    _hubChannel.sink.add(
      jsonEncode({
        fieldType: msgPublish,
        fieldTopic: topic,
        fieldPayload: payload,
      }),
    );
  }

  void subscribe(List<String> topics) {
    _hubChannel.sink.add(
      jsonEncode({fieldType: msgSubscribe, fieldTopics: topics}),
    );
  }
}
