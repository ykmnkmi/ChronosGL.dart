@TestOn('chrome')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

web.KeyboardEvent _key(String type, int key) => web.KeyboardEvent(
  type,
  web.KeyboardEventInit(which: key, keyCode: key, cancelable: true),
);

web.MouseEvent _mouse(String type, [int button = Mouse.left]) => web.MouseEvent(
  type,
  web.MouseEventInit(
    button: button,
    clientX: 37,
    clientY: 49,
    movementX: 7,
    movementY: -3,
    cancelable: true,
  ),
);

web.WheelEvent _wheel() =>
    web.WheelEvent('wheel', web.WheelEventInit(deltaY: -12, cancelable: true));

List<web.Event> _events() => [
  _key('keydown', Keyboard.a),
  _key('keyup', Keyboard.b),
  _mouse('mousemove'),
  _mouse('mousedown'),
  _mouse('mouseup', Mouse.right),
  _wheel(),
];

void _expectKeyboardCleared(Keyboard keyboard) {
  for (final key in [Keyboard.a, Keyboard.b]) {
    expect(keyboard.currentlyPressedKey(key), isFalse);
    expect(keyboard.justPressedKey(key), isFalse);
    expect(keyboard.justReleasedKey(key), isFalse);
  }
}

void _expectMouseCleared(Mouse mouse) {
  for (final button in [Mouse.left, Mouse.right]) {
    expect(mouse.currentlyPressedButton(button), isFalse);
    expect(mouse.justPressedButton(button), isFalse);
    expect(mouse.justReleasedButton(button), isFalse);
  }
  expect(
    [
      mouse.currentX,
      mouse.currentY,
      mouse.moveDeltaX,
      mouse.moveDeltaY,
      mouse.wheelDeltaY,
    ],
    [0, 0, 0, 0, 0],
  );
}

void _expectMouseWritesRejected(Mouse mouse) {
  for (final write in <void Function()>[
    () => mouse.currentX = 1,
    () => mouse.currentY = 1,
    () => mouse.moveDeltaX = 1,
    () => mouse.moveDeltaY = 1,
    () => mouse.wheelDeltaY = 1,
  ]) {
    expect(
      write,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('Mouse'), contains('disposed')),
        ),
      ),
    );
  }
  mouse.afterFrameCleanup();
  _expectMouseCleared(mouse);
}

typedef _Listener = ({String type, JSFunction callback, JSAny? options});

// Instrument a real DOM target, retaining callbacks to simulate late delivery
// and failures during removal without replacing the browser event machinery.
class _ListenerProbe {
  _ListenerProbe() {
    _add = target.getProperty<JSFunction>('addEventListener'.toJS);
    _remove = target.getProperty<JSFunction>('removeEventListener'.toJS);
    target.setProperty(
      'addEventListener'.toJS,
      ((JSString type, JSFunction callback, [JSAny? options]) {
        beforeAdd?.call(type.toDart);
        _add.callAsFunction(target, type, callback, options);
        added.add((type: type.toDart, callback: callback, options: options));
      }).toJS,
    );
    target.setProperty(
      'removeEventListener'.toJS,
      ((JSString type, JSFunction callback, [JSAny? options]) {
        removed.add((type: type.toDart, callback: callback, options: options));
        beforeRemove?.call(type.toDart);
        _remove.callAsFunction(target, type, callback, options);
      }).toJS,
    );
    addTearDown(() {
      for (final listener in added) {
        _remove.callAsFunction(target, listener.type.toJS, listener.callback);
      }
      target.delete('addEventListener'.toJS);
      target.delete('removeEventListener'.toJS);
    });
  }

  final web.HTMLDivElement target = web.HTMLDivElement();
  late final JSFunction _add;
  late final JSFunction _remove;
  final List<_Listener> added = [];
  final List<_Listener> removed = [];
  void Function(String)? beforeAdd;
  void Function(String)? beforeRemove;

  void deliverSavedCallbacks() {
    for (final listener in added) {
      final event = _events().singleWhere((e) => e.type == listener.type);
      listener.callback.callAsFunction(target, event);
      expect(event.defaultPrevented, isFalse, reason: listener.type);
    }
  }

  void expectRemovedExactlyOnce() {
    expect(removed.length, added.length);
    for (final listener in added) {
      final matches = removed.where(
        (other) =>
            other.type == listener.type &&
            other.callback.strictEquals(listener.callback).toDart,
      );
      expect(matches.length, 1, reason: listener.type);
      // Omitted capture and explicit false both select the bubbling listener.
      final options = matches.single.options;
      expect(options == null || (options as JSBoolean).toDart == false, isTrue);
    }
  }
}

void main() {
  test('Mouse scalar writes stop immediately when disposal starts', () async {
    final mouse = Mouse(web.HTMLDivElement());
    addTearDown(mouse.dispose);
    mouse.currentX = 1;
    mouse.currentY = 2;
    mouse.moveDeltaX = 3;
    mouse.moveDeltaY = 4;
    mouse.wheelDeltaY = 5;
    expect(
      [
        mouse.currentX,
        mouse.currentY,
        mouse.moveDeltaX,
        mouse.moveDeltaY,
        mouse.wheelDeltaY,
      ],
      [1, 2, 3, 4, 5],
    );
    final pending = mouse.dispose();
    _expectMouseWritesRejected(mouse);
    await pending;
    _expectMouseWritesRejected(mouse);
    expect(identical(pending, mouse.dispose()), isTrue);
  });

  test(
    'Keyboard disposal immediately clears held keys and transitions',
    () async {
      final target = web.HTMLDivElement();
      final keyboard = Keyboard(target);
      addTearDown(keyboard.dispose);
      expect(keyboard.isDisposed, isFalse);
      target.dispatchEvent(_key('keydown', Keyboard.a));
      target.dispatchEvent(_key('keydown', Keyboard.b));
      target.dispatchEvent(_key('keyup', Keyboard.b));
      expect(keyboard.currentlyPressedKey(Keyboard.a), isTrue);
      expect(keyboard.justPressedKey(Keyboard.b), isTrue);
      expect(keyboard.justReleasedKey(Keyboard.b), isTrue);

      final done = keyboard.dispose();
      expect(keyboard.isDisposed, isTrue);
      _expectKeyboardCleared(keyboard);
      expect(identical(keyboard.dispose(), done), isTrue);
      await done;
      expect(identical(keyboard.dispose(), done), isTrue);
      keyboard.afterFrameCleanup();
      _expectKeyboardCleared(keyboard);
    },
  );

  test(
    'Mouse disposal immediately clears buttons, positions and deltas',
    () async {
      final target = web.HTMLDivElement()
        ..style.position = 'absolute'
        ..style.left = '20px'
        ..style.top = '30px';
      web.document.body!.appendChild(target);
      addTearDown(() => target.remove());
      final mouse = Mouse(target);
      addTearDown(mouse.dispose);
      expect(mouse.isDisposed, isFalse);
      target.dispatchEvent(_mouse('mousemove'));
      target.dispatchEvent(_mouse('mousedown'));
      target.dispatchEvent(_mouse('mousedown', Mouse.right));
      target.dispatchEvent(_mouse('mouseup', Mouse.right));
      target.dispatchEvent(_wheel());
      expect([mouse.currentX, mouse.currentY], [17, 19]);
      expect(
        [mouse.moveDeltaX, mouse.moveDeltaY, mouse.wheelDeltaY],
        [7, -3, -12],
      );
      expect(mouse.currentlyPressedButton(Mouse.left), isTrue);
      expect(mouse.justPressedButton(Mouse.right), isTrue);
      expect(mouse.justReleasedButton(Mouse.right), isTrue);

      final done = mouse.dispose();
      expect(mouse.isDisposed, isTrue);
      _expectMouseCleared(mouse);
      expect(identical(mouse.dispose(), done), isTrue);
      await done;
      expect(identical(mouse.dispose(), done), isTrue);
      expect(target.isConnected, isTrue);
      mouse.afterFrameCleanup();
      _expectMouseCleared(mouse);
    },
  );

  for (final useDocument in [false, true]) {
    test(
      'Disposed input ignores events on ${useDocument ? 'document' : 'element'}',
      () async {
        final web.EventTarget target = useDocument
            ? web.document
            : web.HTMLDivElement();
        final keyboard = Keyboard(useDocument ? null : target);
        final mouse = Mouse(useDocument ? null : target);
        addTearDown(keyboard.dispose);
        addTearDown(mouse.dispose);
        final pending = [keyboard.dispose(), mouse.dispose()];

        void check() {
          for (final event in _events()) {
            expect(target.dispatchEvent(event), isTrue);
            expect(event.defaultPrevented, isFalse, reason: event.type);
          }
          _expectKeyboardCleared(keyboard);
          _expectMouseCleared(mouse);
        }

        check();
        await Future.wait(pending);
        check();
      },
    );
  }

  test('Disposal removes the exact six callbacks once, including non-passive wheel', () async {
    final probe = _ListenerProbe();
    final keyboard = Keyboard(probe.target);
    final mouse = Mouse(probe.target);
    addTearDown(keyboard.dispose);
    addTearDown(mouse.dispose);
    expect(probe.added.map((e) => e.type), [
      'keydown',
      'keyup',
      'mousemove',
      'mousedown',
      'mouseup',
      'wheel',
    ]);
    final wheel = _wheel();
    probe.target.dispatchEvent(wheel);
    expect(wheel.defaultPrevented, isTrue);
    expect(mouse.wheelDeltaY, -12);
    final pending = [keyboard.dispose(), mouse.dispose()];
    // Actual removal occurs before the futures complete.
    probe.expectRemovedExactlyOnce();
    await Future.wait(pending);
    await keyboard.dispose();
    await mouse.dispose();
    probe.expectRemovedExactlyOnce();
    probe.deliverSavedCallbacks();
    _expectKeyboardCleared(keyboard);
    _expectMouseCleared(mouse);
  });

  test(
    'Keyboard disposal leaves another keyboard and external listener active',
    () async {
      final target = web.HTMLDivElement();
      final first = Keyboard(target);
      final second = Keyboard(target);
      var externalEvents = 0;
      final subscription = web.EventStreamProviders.keyDownEvent
          .forTarget(target)
          .listen((_) => externalEvents++);
      addTearDown(subscription.cancel);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      target.dispatchEvent(_key('keydown', Keyboard.a));
      await first.dispose();
      expect(second.currentlyPressedKey(Keyboard.a), isTrue);
      target.dispatchEvent(_key('keydown', Keyboard.b));
      expect(second.justPressedKey(Keyboard.b), isTrue);
      target.dispatchEvent(_key('keyup', Keyboard.a));
      expect(second.justReleasedKey(Keyboard.a), isTrue);
      expect(externalEvents, 2);
      _expectKeyboardCleared(first);
    },
  );

  test(
    'Mouse disposal leaves another mouse and external listener active',
    () async {
      final target = web.HTMLDivElement();
      final first = Mouse(target);
      final second = Mouse(target);
      var externalEvents = 0;
      final subscription = web.EventStreamProviders.mouseDownEvent
          .forTarget(target)
          .listen((_) => externalEvents++);
      addTearDown(subscription.cancel);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      target.dispatchEvent(_mouse('mousedown'));
      await first.dispose();
      expect(second.currentlyPressedButton(Mouse.left), isTrue);
      target.dispatchEvent(_mouse('mousedown', Mouse.right));
      target.dispatchEvent(_mouse('mousemove'));
      final wheel = _wheel();
      target.dispatchEvent(wheel);
      expect(second.justPressedButton(Mouse.right), isTrue);
      expect(second.moveDeltaX, 7);
      expect(second.wheelDeltaY, -12);
      expect(wheel.defaultPrevented, isTrue);
      expect(externalEvents, 2);
      _expectMouseCleared(first);
    },
  );

  test(
    'Repeated creation and disposal on one target does not retain listeners',
    () async {
      final probe = _ListenerProbe();
      for (var cycle = 0; cycle < 5; cycle++) {
        final keyboard = Keyboard(probe.target);
        final mouse = Mouse(probe.target);
        addTearDown(keyboard.dispose);
        addTearDown(mouse.dispose);
        probe.target.dispatchEvent(_key('keydown', Keyboard.a));
        probe.target.dispatchEvent(_mouse('mousedown'));
        expect(keyboard.currentlyPressedKey(Keyboard.a), isTrue);
        expect(mouse.currentlyPressedButton(Mouse.left), isTrue);
        await Future.wait([keyboard.dispose(), mouse.dispose()]);
        probe.expectRemovedExactlyOnce();
        probe.deliverSavedCallbacks();
        _expectKeyboardCleared(keyboard);
        _expectMouseCleared(mouse);
      }
    },
  );

  for (final useMouse in [false, true]) {
    test(
      '${useMouse ? 'Mouse' : 'Keyboard'} ignores reentrant callbacks during disposal',
      () async {
        final probe = _ListenerProbe();
        final keyboard = useMouse ? null : Keyboard(probe.target);
        final mouse = useMouse ? Mouse(probe.target) : null;
        final dispose = mouse?.dispose ?? keyboard!.dispose;
        addTearDown(dispose);
        Future<void>? reentrant;
        probe.beforeRemove = (_) {
          expect(mouse?.isDisposed ?? keyboard!.isDisposed, isTrue);
          reentrant = dispose();
          probe.deliverSavedCallbacks();
        };
        final done = dispose();
        expect(identical(done, reentrant), isTrue);
        await done;
        if (mouse != null) _expectMouseCleared(mouse);
        if (keyboard != null) _expectKeyboardCleared(keyboard);
        probe.expectRemovedExactlyOnce();
      },
    );

    test(
      '${useMouse ? 'Mouse' : 'Keyboard'} attempts every removal after failure and retains the failed future',
      () async {
        final probe = _ListenerProbe();
        final keyboard = useMouse ? null : Keyboard(probe.target);
        final mouse = useMouse ? Mouse(probe.target) : null;
        final dispose = mouse?.dispose ?? keyboard!.dispose;
        final failure = StateError('First removal failed');
        probe.beforeRemove = (_) => throw failure;
        final done = dispose();
        expect(mouse?.isDisposed ?? keyboard!.isDisposed, isTrue);
        probe.expectRemovedExactlyOnce();
        expect(identical(done, dispose()), isTrue);
        await expectLater(done, throwsA(same(failure)));
        await expectLater(dispose(), throwsA(same(failure)));
        probe.expectRemovedExactlyOnce();
        // Failed native removals may leave callbacks attached; they are inert.
        for (final event in _events()) {
          probe.target.dispatchEvent(event);
          expect(event.defaultPrevented, isFalse);
        }
        probe.deliverSavedCallbacks();
        if (mouse != null) _expectMouseWritesRejected(mouse);
        if (keyboard != null) _expectKeyboardCleared(keyboard);
      },
    );
  }

  for (final failingType in ['keyup', 'mousedown', 'mouseup', 'wheel']) {
    test('Failed $failingType registration cleans earlier listeners', () async {
      final probe = _ListenerProbe();
      final failure = StateError('Cannot register $failingType');
      probe.beforeAdd = (type) {
        if (type == failingType) throw failure;
      };
      expect(
        () => failingType == 'keyup'
            ? Keyboard(probe.target)
            : Mouse(probe.target),
        throwsA(same(failure)),
      );
      probe.expectRemovedExactlyOnce();
      probe.deliverSavedCallbacks();
      // Let constructor cleanup finish, including asynchronous cancellations.
      await Future<void>.delayed(Duration.zero);
    });
  }

  test(
    'Constructor preserves registration failure when rollback also fails',
    () async {
      final probe = _ListenerProbe();
      final failure = StateError('Cannot register wheel');
      probe.beforeAdd = (type) {
        if (type == 'wheel') throw failure;
      };
      probe.beforeRemove = (_) => throw StateError('Cannot remove listener');
      expect(() => Mouse(probe.target), throwsA(same(failure)));
      probe.expectRemovedExactlyOnce();
      probe.deliverSavedCallbacks();
      await Future<void>.delayed(Duration.zero);
    },
  );
}
