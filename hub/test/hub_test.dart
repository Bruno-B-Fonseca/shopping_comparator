import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../bin/hub.dart';
import '../lib/protocol.dart';

void main() {
  late HttpServer server;
  late String url;

  setUp(() async {
    resetHubState();
    server = await serveHub(InternetAddress.loopbackIPv4, 0);
    url = 'ws://localhost:${server.port}';
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('Server registration and peers_update', () async {
    final clientA = WebSocketChannel.connect(Uri.parse(url));
    final clientB = WebSocketChannel.connect(Uri.parse(url));

    final iterA = StreamIterator(clientA.stream);
    final iterB = StreamIterator(clientB.stream);

    // Register A
    clientA.sink.add(jsonEncode({
      fieldType: msgRegister,
      fieldServerId: 'server-a',
      fieldRegion: 'us-east',
      fieldWsUrl: 'ws://a:3000'
    }));

    expect(await iterA.moveNext(), isTrue);
    var msgA = jsonDecode(iterA.current as String);
    expect(msgA[fieldType], msgPeersUpdate);
    expect((msgA[fieldPeers] as List).length, 1);
    
    // Register B
    clientB.sink.add(jsonEncode({
      fieldType: msgRegister,
      fieldServerId: 'server-b',
      fieldRegion: 'us-east',
      fieldWsUrl: 'ws://b:3000'
    }));

    // B should get its own peers_update
    expect(await iterB.moveNext(), isTrue);
    var msgB = jsonDecode(iterB.current as String);
    expect(msgB[fieldType], msgPeersUpdate);
    expect((msgB[fieldPeers] as List).length, 2);

    // A should get update now too
    expect(await iterA.moveNext(), isTrue);
    var msgA2 = jsonDecode(iterA.current as String);
    expect(msgA2[fieldType], msgPeersUpdate);
    expect((msgA2[fieldPeers] as List).length, 2);

    await clientA.sink.close();
    await clientB.sink.close();
  });

  test('Message relay between regions', () async {
    final clientA = WebSocketChannel.connect(Uri.parse(url));
    final clientB = WebSocketChannel.connect(Uri.parse(url));

    final iterA = StreamIterator(clientA.stream);
    final iterB = StreamIterator(clientB.stream);

    clientA.sink.add(jsonEncode({
      fieldType: msgRegister,
      fieldServerId: 'server-a',
      fieldRegion: 'region-a',
      fieldWsUrl: 'ws://a:3000'
    }));
    expect(await iterA.moveNext(), isTrue); // Skip register peers_update

    clientB.sink.add(jsonEncode({
      fieldType: msgRegister,
      fieldServerId: 'server-b',
      fieldRegion: 'region-b',
      fieldWsUrl: 'ws://b:3000'
    }));
    expect(await iterB.moveNext(), isTrue); // Skip register peers_update

    // Client A subscribes to region/region-b
    clientA.sink.add(jsonEncode({
      fieldType: msgSubscribe,
      fieldTopics: ['region/region-b']
    }));

    // Client B publishes to its own region
    final payload = {'price': 10.5};
    clientB.sink.add(jsonEncode({
      fieldType: msgPublish,
      fieldTopic: 'region/region-b',
      fieldPayload: payload
    }));

    // Client A should receive relay
    expect(await iterA.moveNext(), isTrue);
    var relayMsg = jsonDecode(iterA.current as String);
    expect(relayMsg[fieldType], msgRelay);
    expect(relayMsg[fieldTopic], 'region/region-b');
    expect(relayMsg[fieldPayload]['price'], 10.5);

    await clientA.sink.close();
    await clientB.sink.close();
  });

  test('Validation - missing fields', () async {
    final client = WebSocketChannel.connect(Uri.parse(url));
    final iter = StreamIterator(client.stream);
    
    // Send register without region
    client.sink.add(jsonEncode({
      fieldType: msgRegister,
      fieldServerId: 'test'
      // missing region and wsUrl
    }));

    expect(await iter.moveNext(), isTrue);
    var msg = jsonDecode(iter.current as String);
    expect(msg[fieldType], msgError);
    expect(msg[fieldMessage], contains('Missing required field'));

    await client.sink.close();
  });

  test('Validation - payload size', () async {
    final client = WebSocketChannel.connect(Uri.parse(url));
    final iter = StreamIterator(client.stream);
    
    final largePayload = 'x' * 3000;
    client.sink.add(jsonEncode({
      fieldType: msgPublish,
      fieldTopic: 'region/test',
      fieldPayload: {'data': largePayload}
    }));

    expect(await iter.moveNext(), isTrue);
    var msg = jsonDecode(iter.current as String);
    expect(msg[fieldType], msgError);
    expect(msg[fieldMessage], contains('Payload too large'));

    await client.sink.close();
  });
}
