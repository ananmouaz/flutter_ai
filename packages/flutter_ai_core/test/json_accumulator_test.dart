import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:test/test.dart';

void main() {
  group('JsonAccumulator.tryParseComplete', () {
    test('returns null for an empty buffer', () {
      expect(JsonAccumulator().tryParseComplete(), isNull);
    });

    test('returns null while the JSON is incomplete', () {
      final acc = JsonAccumulator()..add('{"city":"Lon');
      expect(acc.tryParseComplete(), isNull);
    });

    test('decodes a complete document', () {
      final acc = JsonAccumulator()..add('{"city":"London","days":3}');
      expect(acc.tryParseComplete(), {'city': 'London', 'days': 3});
    });

    test('reassembles fragments added across calls', () {
      final acc = JsonAccumulator()
        ..add('{"ci')
        ..add('ty":"Lon')
        ..add('don"}');
      expect(acc.tryParseComplete(), {'city': 'London'});
    });
  });

  group('JsonAccumulator.parsePartial', () {
    test('returns null before anything is added', () {
      expect(JsonAccumulator().parsePartial(), isNull);
    });

    test('closes an object missing its final brace', () {
      final acc = JsonAccumulator()..add('{"city":"London"');
      expect(acc.parsePartial(), {'city': 'London'});
    });

    test('keeps complete members and drops a dangling key', () {
      final acc = JsonAccumulator()..add('{"a":1,"b":');
      expect(acc.parsePartial(), {'a': 1});
    });

    test('drops an unterminated trailing numeric literal', () {
      // `2` is not yet delimited, so it might be a prefix of `25` — surfacing
      // it would violate the prefix contract. It is dropped until terminated.
      final acc = JsonAccumulator()..add('{"a":1,"b":2');
      expect(acc.parsePartial(), {'a': 1});
    });

    test('keeps a numeric value once a delimiter terminates it', () {
      final acc = JsonAccumulator()..add('{"n": 1234');
      // No delimiter yet: the literal is treated as incomplete.
      expect(acc.parsePartial(), <String, Object?>{});
      // A comma terminates it: now it is safe to surface.
      acc.add(',');
      expect(acc.parsePartial(), {'n': 1234});
    });

    test('keeps a numeric value terminated by a closing brace', () {
      final acc = JsonAccumulator()..add('{"n": 1234}');
      expect(acc.parsePartial(), {'n': 1234});
    });

    test('drops an unterminated trailing keyword literal', () {
      // `tru` could complete to `true`; an undelimited keyword is incomplete.
      final acc = JsonAccumulator()..add('{"ok":tru');
      expect(acc.parsePartial(), <String, Object?>{});
      final acc2 = JsonAccumulator()..add('{"ok":true');
      // Still no delimiter after `true`, so it stays incomplete until one lands.
      expect(acc2.parsePartial(), <String, Object?>{});
      acc2.add('}');
      expect(acc2.parsePartial(), {'ok': true});
    });

    test('drops a partially streamed string value', () {
      final acc = JsonAccumulator()..add('{"city":"Lon');
      expect(acc.parsePartial(), <String, Object?>{});
    });

    test('closes a partial array dropping its undelimited last element', () {
      // `3` is not yet delimited, so it is excluded until a delimiter lands.
      final acc = JsonAccumulator()..add('[1,2,3');
      expect(acc.parsePartial(), [1, 2]);
      acc.add(']');
      expect(acc.parsePartial(), [1, 2, 3]);
    });

    test('handles nested objects', () {
      // `1` is undelimited, so the inner member is dropped until terminated.
      final acc = JsonAccumulator()..add('{"a":{"b":1');
      expect(acc.parsePartial(), {'a': <String, Object?>{}});
      acc.add('}');
      expect(acc.parsePartial(), {
        'a': {'b': 1},
      });
    });

    test('handles an array of objects with a trailing partial element', () {
      final acc = JsonAccumulator()..add('[{"x":1},{"y":');
      expect(acc.parsePartial(), [
        {'x': 1},
        <String, Object?>{},
      ]);
    });

    test('respects escaped quotes inside strings', () {
      final acc = JsonAccumulator()..add(r'{"msg":"he said \"hi\""');
      expect(acc.parsePartial(), {'msg': 'he said "hi"'});
    });

    test('returns the already-valid document unchanged', () {
      final acc = JsonAccumulator()..add('{"done":true}');
      expect(acc.parsePartial(), {'done': true});
    });

    test('falls back to the last good partial when a fragment regresses', () {
      final acc = JsonAccumulator()..add('{"a":1,"b":2,');
      expect(acc.parsePartial(), {'a': 1, 'b': 2});
      // A lone open quote cannot be repaired to anything new; the previous
      // partial is retained rather than regressing to {}.
      acc.add('"c":"');
      expect(acc.parsePartial(), {'a': 1, 'b': 2});
    });

    test('reset clears buffer and cached partial', () {
      final acc = JsonAccumulator()..add('{"a":1}');
      expect(acc.parsePartial(), {'a': 1});
      acc.reset();
      expect(acc.isEmpty, isTrue);
      expect(acc.parsePartial(), isNull);
    });
  });
}
