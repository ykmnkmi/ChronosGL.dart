part of 'lib.dart';

/// HTML keyboard handling
class Keyboard {
  Keyboard(Object? elem) {
    final target = elem == null
        ? web.document
        : JSObject.fromInteropObject(elem) as web.EventTarget;

    web.EventStreamProviders.keyDownEvent.forTarget(target).listen((e) {
      _currentlyPressedKeys.add(e.which);
      _justPressedKeys.add(e.which);
    });

    web.EventStreamProviders.keyUpEvent.forTarget(target).listen((e) {
      _currentlyPressedKeys.remove(e.which);
      _justReleasedKeys.add(e.which);
    });
  }

  final Set<int> _currentlyPressedKeys = <int>{};
  final Set<int> _justPressedKeys = <int>{};
  final Set<int> _justReleasedKeys = <int>{};

  bool currentlyPressedKey(int key) => _currentlyPressedKeys.contains(key);

  // if you use this function make sure you call AfterFrameCleanup
  bool justPressedKey(int key) => _justPressedKeys.contains(key);

  // if you use this function make sure you call AfterFrameCleanup
  bool justReleasedKey(int key) => _justReleasedKeys.contains(key);

  void afterFrameCleanup() {
    _justReleasedKeys.clear();
    _justPressedKeys.clear();
  }

  // See http://keycode.info/
  static const int pageUp = 33;
  static const int pageDown = 34;
  static const int end = 35;
  static const int home = 36;
  static const int left = 37;
  static const int right = 39;
  static const int up = 38;
  static const int down = 40;
  static const int space = 32;
  static const int shift = 16;
  static const int ctrl = 17;
  static const int alt = 18;
  static const int tab = 9;
  static const int a = 65;
  static const int b = 66;
  static const int c = 67;
  static const int d = 68;
  static const int e = 69;
  static const int f = 70;
  static const int g = 71;
  static const int h = 72;
  static const int i = 73;
  static const int j = 74;
  static const int k = 75;
  static const int l = 76;
  static const int m = 77;
  static const int n = 78;
  static const int o = 79;
  static const int p = 80;
  static const int q = 81;
  static const int r = 82;
  static const int s = 83;
  static const int t = 84;
  static const int u = 85;
  static const int v = 86;
  static const int w = 87;
  static const int x = 88;
  static const int y = 89;
  static const int z = 90;

  //
  static const int f1 = 112;
  static const int f2 = 113;
  static const int f3 = 114;
  static const int f4 = 115;
  static const int f5 = 116;
  static const int f6 = 117;
  static const int f7 = 118;
  static const int f8 = 119;
  static const int f9 = 120;
  static const int f10 = 121;
  static const int f11 = 122;
  static const int f12 = 123;
}

/// HTML mouse handling
class Mouse {
  Mouse(Object? elem) {
    final target = elem == null
        ? web.document
        : JSObject.fromInteropObject(elem) as web.EventTarget;

    web.EventStreamProviders.mouseMoveEvent.forTarget(target).listen((e) {
      e.preventDefault();

      currentX = e.offsetX.toInt();
      currentY = e.offsetY.toInt();

      moveDeltaX = e.movementX.toInt();
      moveDeltaY = e.movementY.toInt();
      //print ("MOVE ${moveDeltaX}x${moveDeltaY}");
    });

    web.EventStreamProviders.mouseDownEvent.forTarget(target).listen((e) {
      e.preventDefault();
      print("BUTTON ${e.button}");
      _currentlyPressedButtons.add(e.button);
      _justPressedButtons.add(e.button);
    });

    web.EventStreamProviders.mouseUpEvent.forTarget(target).listen((e) {
      e.preventDefault();
      _currentlyPressedButtons.remove(e.button);
      _justReleasedButtons.add(e.button);
    });

    target.addEventListener(
      'wheel',
      ((web.WheelEvent e) {
        e.preventDefault();
        wheelDeltaY = e.deltaY.toInt();
      }).toJS,
      web.AddEventListenerOptions(passive: false),
    );

    /*
  canvas.onContextMenu.listen((html.MouseEvent e) {
    e.preventDefault();
    //e.stopPropagation();
    //e.cancelBubble = true;
  });

    canvas.onDragStart.listen((html.MouseEvent event) {
      event.preventDefault();
    });
    */
    /*

    eventElement.onTouchStart.listen((html.TouchEvent e) {
      mouseDownX = e.touches[0].client.x;
      mouseDownY = e.touches[0].client.y;
    });

    eventElement.onTouchMove.listen((html.TouchEvent e) {
      //azimuth += e.movement.x*0.01;
      //polar += e.movement.y*0.01;
      html.Point p = e.touches[0].client;
      azimuth += (p.x - mouseDownX) * 0.01;
      polar += (mouseDownY - p.y) * 0.01;
      mouseDownX = p.x;
      mouseDownY = p.y;
    });

    setUpEventCapture(null);
    */
  }

  static const int right = 2;
  static const int middle = 1;
  static const int left = 0;

  final Set<int> _currentlyPressedButtons = <int>{};
  final Set<int> _justPressedButtons = <int>{};
  final Set<int> _justReleasedButtons = <int>{};

  int moveDeltaX = 0;
  int moveDeltaY = 0;
  int wheelDeltaY = 0;
  int currentX = 0;
  int currentY = 0;

  bool currentlyPressedButton(int key) =>
      _currentlyPressedButtons.contains(key);

  // if you use this function make sure you call AfterFrameCleanup
  bool justPressedButton(int key) => _justPressedButtons.contains(key);

  // if you use this function make sure you call AfterFrameCleanup
  bool justReleasedButton(int key) => _justReleasedButtons.contains(key);

  void afterFrameCleanup() {
    moveDeltaY = 0;
    moveDeltaX = 0;
    wheelDeltaY = 0;
    _justReleasedButtons.clear();
    _justPressedButtons.clear();
  }
}
