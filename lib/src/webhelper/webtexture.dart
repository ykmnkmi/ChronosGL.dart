part of 'lib.dart';

Future<web.HTMLVideoElement?> makeVideoElementFromCamera() async {
  logWarn("VideoElement/Camera requested");
  web.MediaStream? stream;
  try {
    stream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(video: true.toJS))
        .toDart;
    logWarn("VideoElement construction");
    final video = web.HTMLVideoElement()
      ..autoplay = true
      ..muted = true
      ..playsInline = true;
    final ready = _waitForLoadEvent(video, 'playing', 'camera video');
    video.srcObject = stream;
    await ready;
    return video;
  } catch (error) {
    if (stream != null) {
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
    }
    logError("Camera open error $error");
    return null;
  }
}

web.HTMLCanvasElement makeSolidColorCanvas(String fillStyle) {
  final canvas = web.HTMLCanvasElement()
    ..width = 2
    ..height = 2;
  final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
  ctx.fillStyle = fillStyle.toJS;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  return canvas;
}

Texture makeSolidColorTexture(ChronosGL cgl, String url, String fillStyle) {
  return ImageTexture(cgl, url, makeSolidColorCanvas(fillStyle));
}

Texture makeSolidColorTextureRGB(ChronosGL cgl, String url, vm.Vector3 rgb) {
  int r = (255.0 * rgb.r).round();
  int g = (255.0 * rgb.g).round();
  int b = (255.0 * rgb.b).round();
  return ImageTexture(cgl, url, makeSolidColorCanvas("rgb($r, $g, $b)"));
}

Texture makeSolidColorTextureRGBA(ChronosGL cgl, String url, vm.Vector4 rgba) {
  int r = (255.0 * rgba.r).round();
  int g = (255.0 * rgba.g).round();
  int b = (255.0 * rgba.b).round();
  return ImageTexture(
    cgl,
    url,
    makeSolidColorCanvas("rgba($r, $g, $b, ${rgba.a})"),
  );
}
