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

  test('getMissing() returns missing permission', () {
    var a = AccessMode({'mode': 'RW', 'given': 'RW', 'want': 'RWS'});
    expect(a.getMissing(), equals('S'));
  });

  test('getExcessive() returns excessive permission', () {
    var a = AccessMode({'mode': 'RW', 'given': 'RWS', 'want': 'RW'});
    expect(a.getExcessive(), equals('S'));
  });

  test('updateAll() updates all mode, given, want permissions', () {
    var a = AccessMode({'mode': 'RW', 'given': 'RW', 'want': 'RW'});
    var b = AccessMode({'mode': 'RWS', 'given': 'RWS', 'want': 'RWS'});
    a.updateAll(b);
    expect(a.getMode(), equals('RWS'));
    expect(a.getWant(), equals('RWS'));
    expect(a.getGiven(), equals('RWS'));
  });

  test('isOwner() returns true if has OWNER flag', () {
    var a = AccessMode({'mode': 'ORW', 'given': 'RWS', 'want': 'RW'});
    expect(a.isOwner('mode'), equals(true));
    expect(a.isOwner('given'), equals(false));
  });

  test('isPresencer() returns true if has PRES flag', () {
    var a = AccessMode({'mode': 'PRW', 'given': 'RWS', 'want': 'RW'});
    expect(a.isPresencer('mode'), equals(true));
  });

  test('isMuted() returns true if has no PRES flag', () {
    var a = AccessMode({'mode': 'RW', 'given': 'RWS', 'want': 'RW'});
    expect(a.isMuted('mode'), equals(true));
  });

  test('isJoiner() returns true if has no JOIN flag', () {
    var a = AccessMode({'mode': 'JRW', 'given': 'RWS', 'want': 'RW'});
    expect(a.isJoiner('mode'), equals(true));
  });

  test('isReader() returns true if has READ flag', () {
    var a = AccessMode({'mode': 'JRW', 'given': 'RWS', 'want': 'RW'});
    expect(a.isReader('mode'), equals(true));
  });

  test('isWriter() returns true if has WRITE flag', () {
    var a = AccessMode({'mode': 'JRW', 'given': 'RWS', 'want': 'RW'});
    expect(a.isWriter('mode'), equals(true));
  });

  test('isAdmin() returns true if has OWNER and APPROVE flag', () {
    var a = AccessMode({'mode': 'OAR', 'given': 'RWS', 'want': 'RW'});
    expect(a.isAdmin('mode'), equals(true));
  });

  test('isSharer() returns true if has SHARE flag', () {
    var a = AccessMode({'mode': 'OAS', 'given': 'RWS', 'want': 'RW'});
    expect(a.isSharer('mode'), equals(true));
  });

  test('isDeleter() returns true if has DELETE flag', () {
    var a = AccessMode({'mode': 'OAD', 'given': 'RWS', 'want': 'RW'});
    expect(a.isDeleter('mode'), equals(true));
  });
}
