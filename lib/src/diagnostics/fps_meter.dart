import 'dart:js_interop';

import 'package:web/web.dart' as web;

const int _numBars = 90;
const int _graphHeight = 30;
const int _maxFps = 90;

web.HTMLElement _makeText(String initial) {
  final text = web.HTMLDivElement();
  text.style.fontWeight = 'bold';
  text.textContent = initial;
  return text;
}

web.HTMLElement _makeGraph(String fg, String bg, int bars, int height) {
  final graph = web.HTMLDivElement();
  graph.style
    ..width = '${bars}px'
    ..height = '${height}px'
    ..color = fg
    ..background = fg;
  for (var i = 0; i < bars; i++) {
    final element = web.HTMLSpanElement();
    element.style
      ..width = '1px'
      ..height = '${height}px'
      ..float = 'left'
      ..opacity = '0.9'
      ..background = bg;
    graph.appendChild(element);
  }
  return graph;
}

/// Owns the styled wrapper and child elements it adds to a borrowed DOM root.
///
/// The root can be a `package:web` or legacy DOM element. [dispose] removes
/// this panel while preserving the root's styles and unrelated children.
class StatsPanel {
  /// Attaches an owned panel to a borrowed typed DOM root; colors use CSS.
  StatsPanel.attach({
    required web.HTMLElement root,
    String foreground = '#0ff',
    String background = '#002',
  }) : this(root, foreground, background);

  /// Legacy SDK DOM roots work only in JavaScript builds.
  @Deprecated('Use StatsPanel.attach with package:web.')
  StatsPanel(Object root, String fg, String bg)
    : _graph = _makeGraph(fg, bg, _numBars, _graphHeight) {
    _panel.style
      ..color = fg
      ..fontFamily = 'Helvetica,Arial,sans-serif'
      ..fontSize = '9px'
      ..lineHeight = '15px'
      ..padding = '0 0 3px 3px'
      ..textAlign = 'left'
      ..background = bg;
    _panel.appendChild(_text);
    _panel.appendChild(_graph);
    _panel.appendChild(_extra);
    final target = JSObject.fromInteropObject(root) as web.HTMLElement;
    target.appendChild(_panel);
  }

  final web.HTMLElement _panel = web.HTMLDivElement();
  final web.HTMLElement _text = _makeText('@@@@');
  final web.HTMLElement _extra = web.HTMLDivElement();
  final web.HTMLElement _graph;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  void _checkNotDisposed() {
    if (_isDisposed) throw StateError('StatsPanel has been disposed');
  }

  void changeExtra(String text) {
    _checkNotDisposed();
    _extra.innerHTML = text.toJS;
  }

  void addRawValue(int value) {
    _checkNotDisposed();
    final height = value.clamp(0, _graphHeight);
    final element = _graph.firstChild! as web.HTMLElement;
    element.style.height = '${height}px';
    _graph.appendChild(element);
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _text.remove();
    _graph.remove();
    _extra.remove();
    _panel.remove();
  }
}

const double _sampleRateMs = 1000.0;

/// Samples frame timestamps in milliseconds and displays FPS.
class FpsPanel extends StatsPanel {
  /// Attaches an FPS panel. Pass frame timestamps in milliseconds.
  FpsPanel.attach({required super.root, super.foreground, super.background})
    : super.attach();

  @Deprecated('Use FpsPanel.attach with package:web.')
  FpsPanel(super.root, super.fg, super.bg);

  int _frames = 0;
  double _lastSample = 0.0;

  void updateFrameCount(double now, [String extra = '']) {
    _checkNotDisposed();
    if (!now.isFinite || now < _lastSample) {
      throw ArgumentError.value(
        now,
        'now',
        'Timestamp must be finite and monotonic',
      );
    }
    _frames++;
    final elapsed = now - _lastSample;
    if (elapsed < _sampleRateMs) return;
    final fps = _frames * 1000.0 / elapsed;
    _frames = 0;
    _lastSample = now;
    _text.textContent = '${fps.toStringAsFixed(2)} fps';
    _extra.innerHTML = extra.toJS;
    addRawValue(_graphHeight * fps.ceil() ~/ _maxFps);
  }
}

@Deprecated('Use StatsPanel instead.')
typedef Stats = StatsPanel;

@Deprecated('Use FpsPanel instead.')
typedef StatsFps = FpsPanel;
