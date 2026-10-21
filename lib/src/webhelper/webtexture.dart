part of 'lib.dart';

Future<html.VideoElement?> makeVideoElementFromCamera() {
  logWarn("VideoElement/Camera requested");
  Completer<html.VideoElement?> c = Completer();
  // TODO: come up with better error handling signaling
  html.window.navigator
      .getUserMedia(video: true)
      .then((html.MediaStream stream) {
        logWarn("VideoElement construction");
        html.VideoElement video = html.VideoElement()..autoplay = true;
        video.onPlaying.first.then((_) => c.complete(video));
        video.srcObject = stream;
      })
      .catchError((Object error) {
        logError("Camera open error $error");
        c.complete(null);
      });
  return c.future;
}

html.CanvasElement makeSolidColorCanvas(String fillStyle) {
  html.CanvasElement canvas = html.CanvasElement(width: 2, height: 2);
  html.CanvasRenderingContext2D ctx =
      canvas.getContext('2d') as html.CanvasRenderingContext2D;
  ctx.fillStyle = fillStyle;
  ctx.fillRect(0, 0, canvas.width!, canvas.height!);
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
