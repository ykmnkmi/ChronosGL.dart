part of 'lib.dart';

const int _numBars = 90;
const int _graphHeight = 30;
const int _maxFps = 90;

html.Element _makeText(String initial) {
  html.Element text = html.Element.div();
  text.style.fontWeight = "bold";
  text.text = initial;
  return text;
}

html.Element _makeGraph(String fg, String bg, int bars, int height) {
  html.Element graph = html.Element.div();
  graph.style
    ..width = "${bars}px"
    ..height = "${height}px"
    ..color = fg
    ..background = fg;

  for (int i = 0; i < bars; i++) {
    html.Element e = html.Element.span();
    e.style
      ..width = "1px"
      ..height = "${height}px"
      ..float = "left"
      ..opacity = "0.9"
      ..background = bg;
    graph.append(e);
  }
  return graph;
}

class Stats {
  Stats(this._root, String fg, String bg)
    : _graph = _makeGraph(fg, bg, _numBars, _graphHeight) {
    _root.style
      ..color = fg
      ..fontFamily = "Helvetica,Arial,sans-serif"
      ..fontSize = "9px"
      ..lineHeight = "15px"
      ..padding = "0 0 3px 3px"
      ..textAlign = "left"
      ..background = bg;

    _root.append(_text);
    _root.append(_graph);
    _root.append(_extra);
  }

  final html.Element _root;
  final html.Element _text = _makeText("@@@@");
  final html.Element _extra = html.Element.div();
  final html.Element _graph;

  void changeExtra(String s) {
    _extra.innerHtml = s;
  }

  void addRawValue(int v) {
    if (v < 0) v = 0;
    if (v > _graphHeight) v = _graphHeight;
    html.Element e = _graph.firstChild! as html.Element;
    e.style.height = "${v}px";
    _graph.append(e);
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
    _text.text = "${fps.toStringAsFixed(2)} fps";
    _extra.innerHtml = extra;
    addRawValue(_graphHeight * fps.ceil() ~/ _maxFps);
  }
}
