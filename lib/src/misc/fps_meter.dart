part of 'lib.dart';

const int _numBars = 90;
const int _graphHeight = 30;
const int _maxFps = 90;

web.HTMLElement _makeText(String initial) {
  final text = web.HTMLDivElement();
  text.style.fontWeight = "bold";
  text.textContent = initial;
  return text;
}

web.HTMLElement _makeGraph(String fg, String bg, int bars, int height) {
  final graph = web.HTMLDivElement();
  graph.style
    ..width = "${bars}px"
    ..height = "${height}px"
    ..color = fg
    ..background = fg;

  for (int i = 0; i < bars; i++) {
    final e = web.HTMLSpanElement();
    e.style
      ..width = "1px"
      ..height = "${height}px"
      ..float = "left"
      ..opacity = "0.9"
      ..background = bg;
    graph.appendChild(e);
  }
  return graph;
}

class Stats {
  Stats(Object root, String fg, String bg)
    : _root = JSObject.fromInteropObject(root) as web.HTMLElement,
      _graph = _makeGraph(fg, bg, _numBars, _graphHeight) {
    _root.style
      ..color = fg
      ..fontFamily = "Helvetica,Arial,sans-serif"
      ..fontSize = "9px"
      ..lineHeight = "15px"
      ..padding = "0 0 3px 3px"
      ..textAlign = "left"
      ..background = bg;

    _root.appendChild(_text);
    _root.appendChild(_graph);
    _root.appendChild(_extra);
  }

  final web.HTMLElement _root;
  final web.HTMLElement _text = _makeText("@@@@");
  final web.HTMLElement _extra = web.HTMLDivElement();
  final web.HTMLElement _graph;

  void changeExtra(String s) {
    _extra.innerHTML = s.toJS;
  }

  void addRawValue(int v) {
    if (v < 0) v = 0;
    if (v > _graphHeight) v = _graphHeight;
    final e = _graph.firstChild! as web.HTMLElement;
    e.style.height = "${v}px";
    _graph.appendChild(e);
  }
}

const double _sampleRateMs = 1000.0;

class StatsFps extends Stats {
  StatsFps(super.root, super.fg, super.bg);

  int _frames = 0;
  double _lastSample = 0.0;

  void updateFrameCount(double now, [String extra = ""]) {
    _frames++;
    if ((now - _lastSample) < _sampleRateMs) return;
    double fps = _frames * 1000.0 / _sampleRateMs;
    //print("${fps}");
    _frames = 0;
    _lastSample = now;
    _text.textContent = "${fps.toStringAsFixed(2)} fps";
    _extra.innerHTML = extra.toJS;
    addRawValue(_graphHeight * fps.ceil() ~/ _maxFps);
  }
}
