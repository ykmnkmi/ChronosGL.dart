part of 'lib.dart';

/// Interactive Camera focused on a specific point.
class OrbitCamera extends Spatial {
  /// OrbitCamera initializes an orbiting camera
  ///
  /// @param this._radius blah
  /// @param this._polar blah
  OrbitCamera(this._radius, this.azimuth, this.polar, html.Element eventElement)
    : keyboard = Keyboard(null),
      mouse = Mouse(eventElement),
      super("camera:orbit");

  double _radius;
  double azimuth;
  double polar;
  double roll = 0.0;
  final vm.Vector3 _lookAtPos = vm.Vector3.zero();
  num mouseWheelFactor = -0.02;
  final Keyboard keyboard;
  final Mouse mouse;

  void setLookAt(vm.Vector3 v) {
    _lookAtPos.setFrom(v);
  }

  void setRadius(double v) {
    _radius = v;
  }

  void animate(double elapsed) {
    if (mouse.currentlyPressedButton(Mouse.left) ||
        mouse.currentlyPressedButton(Mouse.middle)) {
      //azimuth += e.movement.x*0.01;
      //polar += e.movement.y*0.01;
      azimuth += mouse.moveDeltaX * 0.01;
      polar += mouse.moveDeltaY * 0.01;
    }

    if (keyboard.currentlyPressedKey(Keyboard.left)) {
      azimuth += (0.03);
    } else if (keyboard.currentlyPressedKey(Keyboard.right)) {
      azimuth -= (0.03);
    }

    if (keyboard.currentlyPressedKey(Keyboard.up)) {
      polar += (0.03);
    } else if (keyboard.currentlyPressedKey(Keyboard.down)) {
      polar -= (0.03);
    }

    if (keyboard.currentlyPressedKey(Keyboard.pageUp)) {
      _radius *= 0.99;
    } else if (keyboard.currentlyPressedKey(Keyboard.pageDown)) {
      _radius *= 1.01;
    }

    if (keyboard.currentlyPressedKey(Keyboard.space)) {
      azimuth = 0.0;
      polar = 0.0;
    }

    double d = mouse.wheelDeltaY.toDouble() * mouseWheelFactor;
    if (_radius - d > 0) _radius -= d;

    polar = polar.clamp(-math.pi / 2 + 0.1, math.pi / 2 - 0.1);
    setPosFromSpherical(_radius, azimuth, polar);
    addPosFromVec(_lookAtPos);
    lookAt(_lookAtPos);
    rollLeft(roll);
    keyboard.afterFrameCleanup();
    mouse.afterFrameCleanup();
  }
}

/*
class FlyingCamera extends Camera {
  vm.Vector3 momentum_ = new vm.Vector3.zero();

  FlyingCamera() : super("camera:flying");

  void animate(double elapsed) {
    Map<int, bool> cpk = currentlyPressedKeys;
    //Map<String, bool> cpmb = currentlyPressedMouseButtons;

    if (cpk[Key.A] != null) {
      moveLeft(0.03);
    } else if (cpk[Key.D] != null) {
      moveRight(0.03);
    }
    if (cpk[Key.W] != null) {
      moveForward(0.03);
    } else if (cpk[Key.S] != null) {
      moveBackward(0.03);
    }

    if (cpk[Key.SPACE] != null) {
      momentum_.scale(0.92);
    }

    if (mouseY != 0) lookUp(mouseY * 0.00006);
    if (mouseX != 0) lookLeft(-mouseX * 0.00003);

    translateFromVec(momentum_);
  }

  @override
  void moveForward(double amount) {
    vm.Vector3 t = getBack();
    t.negate();
    vm.Vector3.mix(momentum_, t, amount, momentum_);
  }

  @override
  void moveBackward(double amount) {
    vm.Vector3 t = getBack();
    vm.Vector3.mix(momentum_, t, amount, momentum_);
  }

  @override
  void moveUp(num amount) {
    vm.Vector3 t = getUp();
    vm.Vector3.mix(momentum_, t, amount, momentum_);
  }

  @override
  void moveDown(num amount) {
    vm.Vector3 t = getUp();
    t.negate();
    vm.Vector3.mix(momentum_, t, amount, momentum_);
  }

  @override
  void moveLeft(num amount) {
    vm.Vector3 t = getRight();
    t.negate();
    vm.Vector3.mix(momentum_, t, amount, momentum_);
  }

  @override
  void moveRight(num amount) {
    vm.Vector3 t = getRight();
    vm.Vector3.mix(momentum_, t, amount, momentum_);
  }
}

class FPSCamera extends Camera {
  vm.Vector3 momentum = new vm.Vector3.zero();
  vm.Vector3 movement = new vm.Vector3.zero();
  vm.Vector3 tmp = new vm.Vector3.zero();

  vm.Vector3 traceStart = new vm.Vector3.zero();
  vm.Vector3 traceEnd = new vm.Vector3.zero();

  vm.Vector3 up = new vm.Vector3(0.0, 0.0, 1.0);

  int movementX = 0;
  int movementY = 0;

  FPSCamera([html.Element eventElement]) : super("camera:fps") {
    if (eventElement == null) eventElement = html.document.body;
    eventElement.onMouseDown.listen((html.MouseEvent e) {
      e.preventDefault();
      eventElement.requestPointerLock();
    });

    eventElement.onMouseMove.listen((html.MouseEvent e) {
      e.preventDefault();
      movementX += e.movement.x;
      movementY += e.movement.y;
    });
  }

  void animate(double elapsed) {
    Map<int, bool> cpk = currentlyPressedKeys;
    //Map<String, bool> cpmb = currentlyPressedMouseButtons;

    movement.scale(0.0);

    if (cpk[Key.W] != null) {
      movement.sub(getBack());
    }
    if (cpk[Key.A] != null) {
      movement.sub(getRight());
    }
    if (cpk[Key.S] != null) {
      movement.add(getBack());
    }
    if (cpk[Key.D] != null) {
      movement.add(getRight());
    }

    movement.z = 0.0;
    movement.normalize();
    momentum.add(movement);
    tmp.setFrom(momentum);
    tmp.scale(0.02);

    traceStart.setFrom(getPos());
    traceEnd.setFrom(getPos());
    traceEnd.add(tmp);

    //Output output = level.trace( traceStart, traceEnd, 10.0);
    //if( output.fraction == 1.0 || output.startSolid || output.allSolid )

    translateFromVec(tmp);
    momentum.scale(0.85);

    if (cpk[Key.SPACE] != null) {}

    if (movementY != 0) transform.rotate(getRight(), movementY * 0.006);
    if (movementX != 0) transform.rotate(up, movementX * 0.006);

    movementX = 0;
    movementY = 0;
  }
}

*/
