import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

Future<void> hybridMain(StreamChannel<Object?> channel, Object? message) async {
  final path = switch (message) {
    'assimp' => 'example/asset/monster/monster.json',
    'threejs' => 'example/asset/knight/knight.js',
    _ => throw ArgumentError.value(message, 'asset'),
  };
  channel.sink.add(await File(path).readAsString());
  await channel.sink.close();
}
