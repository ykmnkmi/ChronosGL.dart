part of 'lib.dart';

Future<String> loadRaw(String url) async {
  final request = web.XMLHttpRequest()..open('GET', url);
  final done = web.EventStreamProviders.loadEndEvent.forTarget(request).first;
  request.send();
  await done;
  if (request.status < 200 || request.status >= 300) {
    throw StateError('Failed to load $url (HTTP ${request.status})');
  }
  return request.responseText;
}

Future<Map<String, Object?>> loadJson(String url) async {
  return json.decode(await loadRaw(url)) as Map<String, Object?>;
}

// Remove both listeners on success or failure so failed media loads complete
// their Future and do not retain the element through an unused listener.
Future<void> _waitForLoadEvent(
  web.EventTarget target,
  String readyEvent,
  String description,
) {
  final completer = Completer<void>();
  late final JSFunction onReady;
  late final JSFunction onError;
  void finish([Object? error]) {
    target.removeEventListener(readyEvent, onReady);
    target.removeEventListener('error', onError);
    if (error == null) {
      completer.complete();
    } else {
      completer.completeError(error);
    }
  }

  onReady = ((web.Event event) => finish()).toJS;
  onError = ((web.Event event) {
    finish(StateError('Failed to load $description'));
  }).toJS;
  target.addEventListener(readyEvent, onReady);
  target.addEventListener('error', onError);
  return completer.future;
}

Future<web.HTMLImageElement> loadImage(String url) async {
  final image = web.HTMLImageElement();
  final ready = _waitForLoadEvent(image, 'load', url);
  image.src = url;
  await ready;
  return image;
}

Future<web.HTMLVideoElement> loadVideo(String url) async {
  final video = web.HTMLVideoElement()
    ..autoplay = true
    ..loop = true;
  // Textures must not use the video until it is playing.
  final ready = _waitForLoadEvent(video, 'playing', url);
  video.src = url;
  await ready;
  return video;
}

final List<String> _kUrlInfix = ["nx", "px", "ny", "py", "nz", "pz"];

List<Future<web.HTMLImageElement>> loadCubeImages(
  String urlPrefix,
  String urlSuffix,
) {
  return [
    for (final face in _kUrlInfix) loadImage('$urlPrefix$face$urlSuffix'),
  ];
}
