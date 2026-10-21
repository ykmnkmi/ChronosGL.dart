import 'dart:html' as html;

// import 'dart:web' as JS;

// https://users.cs.cf.ac.uk/dave/Multimedia/node158.html
const midiNoteOff = 8;
const midiNoteOn = 9;
const midiPolyphonicKeyPressure = 10;
const midiControlChange = 11;
const midiProgramChange = 12;
const midiChannelPressure = 13;
const midiPitchBend = 14;

html.Element gTab = html.document.getElementById("tab")!;

void logEvent(String kind, String deviceChannel, dynamic data) {
  print("$kind $deviceChannel $data");
  if (gTab.children.length > 20) {
    gTab.children.removeAt(0);
  }
  gTab.innerHtml =
      "${gTab.innerHtml!}<tr><td>$kind</td><td>$deviceChannel</td><td>$data</td></tr>";
}

// MIDI NOT CURRENTLY AVAILABLE VIA dart:web

// final List<MIDIPort> gMidiPorts = [];
final Map<String, int> gMidiIdToPortIndex = {};

void eventHandler(int device, dynamic msg) {
  final data = msg.data as List<int>;
  final int kind = data[0] >> 4;
  final int channel = data[0] & 0xf;
  if (kind == midiNoteOn) {
    logEvent("NoteOn", "$device.$channel", data);
  } else if (kind == midiNoteOff) {
    logEvent("NoteOff", "$device.$channel", data);
  } else if (kind == midiControlChange) {
    logEvent("ControlChange", "$device.$channel", data);
  } else {
    logEvent("Unknown", "$device", data);
  }
}

dynamic makeHandler(int device) {
  print("init");
  // MIDI NOT CURRENTLY AVAILABLE VIA dart:web
  /*
  logEvent("Registering", "${device}", "${gMidiPorts[device]}");
  return (dynamic msg) => eventHandler(device, msg);
  */
}

// MIDI NOT CURRENTLY AVAILABLE VIA dart:web
/*
void InitMidiDevice(js.MIDIPort port) {
  print("init");

  if (!gMidiIdToPortIndex.containsKey(port.id)) {
    logEvent("InitDevice", "${port.type}", "${port.name}: ${port.id}");
    int index = gMidiPorts.length;
    gMidiIdToPortIndex[port.id] = index;
    gMidiPorts.add(port);

    //bool has_thru = port.name?.contains("Midi Through Port") ?? false;
    //if (!has_thru) {
    port.addEventListener('midimessage', makeHandler(index));
    // }
  } else {
    logEvent("IgnoredDevice", "${port.type}", "${port.name}: ${port.id}");
  }
}
*/

void initMidi() async {
  // MIDI NOT CURRENTLY AVAILABLE VIA dart:web
  /*
  final opts = js.MIDIOptions(sysex: false, software: true);
  final js.MIDIAccess gMidiAccess =
      await js.window.navigator.requestMIDIAccess(opts);

  gMidiAccess.addEventListener("statechange", (dynamic event) {
    js.MIDIPort port = event.port;
    InitMidiDevice(port);
  });

  gMidiAccess.inputs.forEach((MIDIPort port, var k, var m) {
    InitMidiDevice(port);
  });

  gMidiAccess.outputs.forEach((MIDIPort port, var k, var m) {
    InitMidiDevice(port);
  });
  */
}

void main() async {
  print("entering main");
  initMidi();
  print("exiting main");
}
