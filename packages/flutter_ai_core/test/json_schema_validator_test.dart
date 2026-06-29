import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:test/test.dart';

void main() {
  group('validateJsonSchema', () {
    const objectSchema = {
      'type': 'object',
      'properties': {
        'city': {'type': 'string'},
        'days': {'type': 'integer', 'minimum': 1, 'maximum': 14},
        'unit': {
          'type': 'string',
          'enum': ['c', 'f'],
        },
      },
      'required': ['city'],
      'additionalProperties': false,
    };

    test('accepts a valid object', () {
      expect(
        validateJsonSchema(
            {'city': 'Lisbon', 'days': 3, 'unit': 'c'}, objectSchema),
        isEmpty,
      );
    });

    test('an empty schema imposes no constraints', () {
      expect(validateJsonSchema({'anything': true}, const {}), isEmpty);
    });

    test('reports a missing required property', () {
      final errors = validateJsonSchema({'days': 2}, objectSchema);
      expect(errors, hasLength(1));
      expect(errors.single, contains('missing required property "city"'));
    });

    test('reports a type mismatch with a path', () {
      final errors = validateJsonSchema({'city': 123}, objectSchema);
      expect(errors, contains(contains('args.city: expected type string')));
    });

    test('reports an out-of-range number', () {
      final errors =
          validateJsonSchema({'city': 'x', 'days': 99}, objectSchema);
      expect(errors, contains(contains('args.days: must be <= 14')));
    });

    test('reports an enum violation', () {
      final errors =
          validateJsonSchema({'city': 'x', 'unit': 'k'}, objectSchema);
      expect(errors, contains(contains('args.unit: must be one of')));
    });

    test('rejects unexpected properties when additionalProperties is false',
        () {
      final errors =
          validateJsonSchema({'city': 'x', 'extra': 1}, objectSchema);
      expect(errors, contains(contains('unexpected property "extra"')));
    });

    test('validates array items and bounds', () {
      const arraySchema = {
        'type': 'array',
        'minItems': 1,
        'items': {'type': 'string'},
      };
      expect(validateJsonSchema(['a', 'b'], arraySchema), isEmpty);
      expect(validateJsonSchema(const [], arraySchema),
          contains(contains('at least 1 items')));
      expect(
        validateJsonSchema(['a', 2], arraySchema),
        contains(contains('args[1]: expected type string')),
      );
    });

    test('integer vs number: a double is not an integer', () {
      expect(
        validateJsonSchema(1.5, const {'type': 'integer'}),
        isNotEmpty,
      );
      expect(validateJsonSchema(1.5, const {'type': 'number'}), isEmpty);
    });

    test('accepts a union type list', () {
      const schema = {
        'type': ['string', 'null']
      };
      expect(validateJsonSchema(null, schema), isEmpty);
      expect(validateJsonSchema('x', schema), isEmpty);
      expect(validateJsonSchema(5, schema), isNotEmpty);
    });

    test('string length bounds', () {
      const schema = {'type': 'string', 'minLength': 2, 'maxLength': 4};
      expect(validateJsonSchema('ab', schema), isEmpty);
      expect(validateJsonSchema('a', schema),
          contains(contains('at least 2 characters')));
      expect(validateJsonSchema('abcde', schema),
          contains(contains('at most 4 characters')));
    });
  });
}
