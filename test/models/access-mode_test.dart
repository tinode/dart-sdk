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

  test('update() updates mode with given update', () {
    expect(AccessMode.update(14, '+S'), equals(46));
    expect(AccessMode.encode(46), 'RWPS');
  });

  test('diff() returns the diff between two modes', () {
    expect(AccessMode.diff('RWP', 'RW'), equals(8));
    expect(AccessMode.encode(8), equals('P'));
  });

  test('checkFlag() returns true if AccessNode has flag', () {
    var a = AccessMode({'mode': 'RWP', 'given': 'RWP', 'want': 'RWP'});
    expect(AccessMode.checkFlag(a, 'mode', READ), equals(true));
    expect(AccessMode.checkFlag(a, 'given', SHARE), equals(false));
    expect(AccessMode.checkFlag(a, 'want', WRITE), equals(true));
  });

  test('getMode() reads mode in instance', () {
    var a = AccessMode({'mode': 'RWP', 'given': 'RWP', 'want': 'RWP'});
    expect(a.getMode(), equals('RWP'));
  });

  test('setMode() changes the mode in instance', () {
    var a = AccessMode({'mode': 'RWP', 'given': 'RWP', 'want': 'RWP'});
    a.setMode('RWPS');
    expect(a.getMode(), equals('RWPS'));
  });

  test('updateMode() updates mode in instance', () {
    var a = AccessMode({'mode': 'RWP', 'given': 'RWP', 'want': 'RWP'});
    a.updateMode('+S');
    expect(a.getMode(), equals('RWPS'));
  });

  test('getGiven() reads the given in instance', () {
    var a = AccessMode({'mode': 'RWP', 'given': 'RWP', 'want': 'RWP'});
    expect(a.getGiven(), equals('RWP'));
  });

  test('setGiven() sets the given in instance', () {
    var a = AccessMode({'mode': 'RWP', 'given': 'RWP', 'want': 'RWP'});
    a.setGiven('RWPS');
    expect(a.getGiven(), equals('RWPS'));
  });

  test('updateGiven() updates the given in instance', () {
    var a = AccessMode({'mode': 'RWP', 'given': 'RWP', 'want': 'RWP'});
    a.updateGiven('+S');
    expect(a.getGiven(), equals('RWPS'));
  });

  test('getWant() reads the given in instance', () {
    var a = AccessMode({'mode': 'RWP', 'given': 'RWP', 'want': 'RWP'});
    expect(a.getWant(), equals('RWP'));
  });

  test('setWant() changes the want in instance', () {
    var a = AccessMode({'mode': 'RWP', 'given': 'RWP', 'want': 'RWP'});
    a.setWant('RWPS');
    expect(a.getWant(), equals('RWPS'));
  });

  test('updateWant() updates the given in instance', () {
    var a = AccessMode({'mode': 'RWP', 'given': 'RWP', 'want': 'RWP'});
    a.updateWant('+S');
    expect(a.getWant(), equals('RWPS'));
  });
}
