import 'dart:async';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'golden_image.dart';

class GoldenSession {
  GoldenSession._(this.name, this._channel, this._messages, this._config);

  static Future<GoldenSession> open(String name) async {
    final channel = spawnHybridUri('support/golden_files.dart', message: name);
    final messages = StreamIterator<Object?>(channel.stream);
    addTearDown(() async {
      await channel.sink.close();
      await messages.cancel();
    });
    if (!await messages.moveNext()) {
      throw StateError('Golden file helper exited');
    }
    return GoldenSession._(
      name,
      channel,
      messages,
      Map<String, dynamic>.from(messages.current as Map),
    );
  }

  final String name;
  final StreamChannel<dynamic> _channel;
  final StreamIterator<Object?> _messages;
  final Map<String, dynamic> _config;

  bool get mutate => _config['mutate'] == true;

  Future<void> expectImage(
    GoldenImage actual,
    Map<String, Object> environment,
  ) async {
    final actualPng = actual.encodePng();
    if (_config['update'] == true) {
      await _save({
        'status': 'updated',
        'actual': actualPng,
        'environment': environment,
      });
      print('Updated test/goldens/$name.png');
      return;
    }
    final expectedPng = _config['expected'] as String?;
    if (expectedPng == null) {
      await _save({
        'status': 'missing',
        'actual': actualPng,
        'summary': {'error': 'Missing test/goldens/$name.png'},
      });
      fail(
        'Missing test/goldens/$name.png. Review '
        'build/golden_failures/$name/actual.png, then run '
        'dart run tool/goldens.dart --update.',
      );
    }
    final expected = await GoldenImage.decodePng(expectedPng);
    final comparison = GoldenComparison(expected, actual);
    await _save({
      'status': comparison.matches ? 'matched' : 'mismatch',
      if (!comparison.matches) ...{
        'actual': actualPng,
        'expected': expectedPng,
        'diff': comparison.diff.encodePng(),
        'summary': {
          ...comparison.summary,
          'expectedSize': [expected.width, expected.height],
          'actualSize': [actual.width, actual.height],
          'baselineEnvironment': _config['environment'],
          'actualEnvironment': {
            ...environment,
            'operatingSystem': _config['operatingSystem'],
          },
        },
      },
    });
    expect(
      comparison.matches,
      isTrue,
      reason:
          '${comparison.differentPixels} pixels differ from '
          'test/goldens/$name.png (max channel delta '
          '${comparison.maximumChannelDelta}). See '
          'build/golden_failures/$name/{expected,actual,diff}.png.',
    );
  }

  Future<void> _save(Map<String, Object?> result) async {
    _channel.sink.add(result);
    if (!await _messages.moveNext() ||
        (_messages.current as Map)['saved'] != true) {
      throw StateError('Golden file helper did not save the result');
    }
  }
}
