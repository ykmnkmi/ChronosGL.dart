import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

Future<void> hybridMain(StreamChannel<Object?> channel, Object? message) async {
  final image = await File('test/goldens/texture.png').readAsBytes();
  final video = await File('test/fixtures/helper.webm').readAsBytes();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final response = request.response;
    response.headers.set('Access-Control-Allow-Origin', '*');
    switch (request.uri.path) {
      case '/text':
        response.write('ChronosGL assets');
      case '/json':
        response.write('{"name":"scene","vertices":[1,2,3]}');
      case '/broken-json':
        response.write('{broken');
      case '/disconnect':
        final socket = await response.detachSocket(writeHeaders: false);
        socket.destroy();
        return;
      case '/image.png':
      case '/cube_nx.png':
      case '/cube_px.png':
      case '/cube_ny.png':
      case '/cube_py.png':
      case '/cube_nz.png':
      case '/cube_pz.png':
        response.headers.contentType = ContentType('image', 'png');
        response.add(image);
      case '/video.webm':
        response.headers.contentType = ContentType('video', 'webm');
        response.add(video);
      default:
        response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  });
  channel.sink.add('http://${server.address.address}:${server.port}');
  try {
    await channel.stream.first;
  } finally {
    await server.close(force: true);
    await channel.sink.close();
  }
}
