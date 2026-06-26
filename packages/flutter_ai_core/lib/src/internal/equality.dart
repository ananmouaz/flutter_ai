/// Structural equality and hashing for JSON-like values.
///
/// The core models carry decoded JSON (`Map<String, Object?>`, `List<Object?>`,
/// and scalars) in fields such as tool-call arguments and data payloads. Value
/// equality on those models therefore needs deep, structural comparison rather
/// than identity. These helpers provide it without depending on
/// `package:collection`, honoring the package's dependency-free contract.
library;

/// Returns whether [a] and [b] are structurally equal.
///
/// Scalars are compared with `==`. [List]s are compared element-wise and in
/// order. [Map]s are compared by key set and per-key values, independent of
/// insertion order. Comparison recurses through nested lists and maps.
bool deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || !deepEquals(entry.value, b[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}

/// Returns a hash code for [value] consistent with [deepEquals].
///
/// Lists hash in order; maps hash independent of insertion order so that two
/// equal maps with different orderings produce the same hash.
int deepHash(Object? value) {
  if (value is List) {
    return Object.hashAll(value.map(deepHash));
  }
  if (value is Map) {
    var hash = 0;
    for (final entry in value.entries) {
      // XOR makes the combination commutative, so ordering does not matter.
      hash ^= Object.hash(deepHash(entry.key), deepHash(entry.value));
    }
    return hash;
  }
  return value.hashCode;
}
