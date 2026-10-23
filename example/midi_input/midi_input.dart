import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const midiNoteOff = 8;
const midiNoteOn = 9;
const midiControlChange = 11;

final web.HTMLTableSectionElement gTab =
    web.document.getElementById('tab') as web.HTMLTableSectionElement;
final web.HTMLButtonElement gConnect =
    web.document.getElementById('connect') as web.HTMLButtonElement;
final web.HTMLElement gInfo =
    web.document.getElementById('info') as web.HTMLElement;
final Map<String, int> gMidiIdToPortIndex = {};
web.MIDIAccess? gMidiAccess;

// package:web exposes MIDIInputMap without its maplike iteration members.
@JS()
extension type _MidiInputMap(JSObject _) implements JSObject {
  external void forEach(JSFunction callback);
}

void logEvent(String kind, String deviceChannel, Object data) {
  print('$kind $deviceChannel $data');
  while (gTab.children.length >= 20) {
    gTab.firstElementChild!.remove();
  }
  final row = web.HTMLTableRowElement();
  for (final text in [kind, deviceChannel, data.toString()]) {
    row.appendChild(web.document.createElement('td')..textContent = text);
  }
  gTab.appendChild(row);
}

void eventHandler(int device, web.MIDIMessageEvent message) {
  final data = message.data?.toDart;
  if (data == null || data.isEmpty) return;
  final kind = data[0] >> 4;
  final channel = data[0] & 0xf;
  final name = switch (kind) {
    midiNoteOn when data.length >= 3 && data[2] == 0 => 'NoteOff',
    midiNoteOn => 'NoteOn',
    midiNoteOff => 'NoteOff',
    midiControlChange => 'ControlChange',
    _ => 'Unknown',
  };
  logEvent(name, '$device.$channel', data);
}

void initMidiInput(web.MIDIInput input) {
  if (input.state != 'connected') {
    logEvent('Disconnected', input.id, input.name ?? 'MIDI input');
    return;
  }
  final index = gMidiIdToPortIndex.putIfAbsent(
    input.id,
    () => gMidiIdToPortIndex.length,
  );
  input.onmidimessage = ((web.MIDIMessageEvent event) {
    eventHandler(index, event);
  }).toJS;
  logEvent('Input', '$index', input.name ?? input.id);
}

Future<void> initMidi() async {
  gConnect.disabled = true;
  gInfo.textContent = 'Connecting to MIDI inputs...';
  try {
    final access = await web.window.navigator
        .requestMIDIAccess(web.MIDIOptions(sysex: false, software: true))
        .toDart;
    gMidiAccess = access;
    access.onstatechange = ((web.MIDIConnectionEvent event) {
      final port = event.port;
      if (port != null && port.type == 'input') {
        initMidiInput(port as web.MIDIInput);
      }
    }).toJS;
    (access.inputs as _MidiInputMap).forEach(initMidiInput.toJS);
    gInfo.textContent = 'MIDI connected. Play a note on an input device.';
  } catch (error) {
    gInfo.textContent = 'Could not connect to MIDI: $error';
  } finally {
    gConnect.disabled = false;
  }
}

void main() {
  gConnect.onClick.listen((_) {
    unawaited(initMidi());
  });
}
