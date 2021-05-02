import 'package:tinode/src/models/access-mode.dart';
import 'package:test/test.dart';

void main() {
  test('decode(null) returns null', () {
    expect(AccessMode.decode(null), equals(null));
  });

  test('decode() bitmask for integer values', () {
    expect(AccessMode.decode(12345), equals(57));
  });

  test('decode() returns zero for N or n mode', () {
    expect(AccessMode.decode('N'), equals(0));
    expect(AccessMode.decode('n'), equals(0));
  });

  test('decode() decodes string to integer for mode', () {
    expect(AccessMode.decode('RWP'), equals(14));
  });

  test('encode() returns null for null value', () {
    expect(AccessMode.encode(null), equals(null));
  });

  test('encode() returns none for 0', () {
    expect(AccessMode.encode(0), equals('N'));
  });

  test('encode() encode integer to string for mode', () {
    expect(AccessMode.encode(14), equals('RWP'));
  });
}
