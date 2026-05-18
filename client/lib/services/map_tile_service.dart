import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class HiveTileProvider extends TileProvider {
  final Box<Uint8List> tileBox;

  HiveTileProvider(this.tileBox);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final key = '${coordinates.z}_${coordinates.x}_${coordinates.y}';
    
    // 1. Tenta obter do cache local (Hive)
    final cachedTile = tileBox.get(key);
    if (cachedTile != null) {
      return MemoryImage(cachedTile);
    }

    // 2. Se não estiver no cache, retorna NetworkImage e inicia download em background para cache futuro
    final url = getTileUrl(coordinates, options);
    _downloadAndCache(url, key);
    return NetworkImage(url);
  }

  Future<void> _downloadAndCache(String url, String key) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await tileBox.put(key, response.bodyBytes);
      }
    } catch (e) {
      debugPrint('HiveTileProvider: Falha ao baixar tile para cache: $e');
    }
  }

  @override
  String getTileUrl(TileCoordinates coordinates, TileLayer options) {
    return options.urlTemplate!
        .replaceAll('{z}', coordinates.z.toString())
        .replaceAll('{x}', coordinates.x.toString())
        .replaceAll('{y}', coordinates.y.toString());
  }
}
