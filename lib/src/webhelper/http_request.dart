part of 'lib.dart';

Future<String> loadRaw(String url) {
  Completer<String> c = Completer();
  html.HttpRequest hr = html.HttpRequest();
  hr.open("GET", url);
  hr.onLoadEnd.listen((e) {
    c.complete(hr.responseText);
  });
  hr.send('');
  return c.future;
}

Future<Map<String, Object?>> loadJson(String url) {
  Completer<Map<String, Object?>> c = Completer();
  html.HttpRequest hr = html.HttpRequest();
  hr.open("GET", url);
  hr.onLoadEnd.listen((e) {
    c.complete(json.decode(hr.responseText!) as Map<String, Object?>);
  });
  hr.send('');
  return c.future;
}

Future<html.ImageElement> loadImage(String url) {
  Completer<html.ImageElement> c = Completer();
  html.ImageElement image = html.ImageElement();
  image.onLoad.first.then((_) => c.complete(image));
  image.src = url;
  return c.future;
}

Future<html.VideoElement> loadVideo(String url) {
  Completer<html.VideoElement> c = Completer();
  html.VideoElement video = html.VideoElement();
  // this is crucial since we are waiting for "onplaying"
  video.autoplay = true;
  video.loop = true;
  video.onPlaying.first.then((_) => c.complete(video));
  video.src = url;
  return c.future;
}

final List<String> _kUrlInfix = ["nx", "px", "ny", "py", "nz", "pz"];

List<Future<html.ImageElement>> loadCubeImages(
  String urlPrefix,
  String urlSuffix,
) {
  List<Future<html.ImageElement>> out = List.generate(_kUrlInfix.length, (i) {
    Completer<html.ImageElement> c = Completer();
    html.ImageElement image = html.ImageElement();
    image.onLoad.first.then((_) => c.complete(image));
    image.src = urlPrefix + _kUrlInfix[i] + urlSuffix;
    return c.future;
  });
  return out;
}
