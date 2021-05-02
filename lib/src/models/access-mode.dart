int NONE = 0x00;
int JOIN = 0x01;
int READ = 0x02;
int WRITE = 0x04;
int PRES = 0x08;
int APPROVE = 0x10;
int SHARE = 0x20;
int DELETE = 0x40;
int OWNER = 0x80;
int INVALID = 0x100000;

var AccessModePermissionsBITMASK = JOIN | READ | WRITE | PRES | APPROVE | SHARE | DELETE | OWNER;

/// Actual access and permission
class AccessMode {
  int _given;
  int _want;
  int mode;

  int operator [](other) {
    switch (other) {
      case 'mode':
        return mode;
      case 'want':
        return _want;
      case 'given':
        return _given;
      default:
        return 0;
    }
  }

  AccessMode(dynamic acs) {
    if (acs != null) {
      _given = acs['given'] is int ? acs['given'] : AccessMode.decode(acs['given']);
      _want = acs['want'] is int ? acs['want'] : AccessMode.decode(acs['given']);

      if (acs['mode'] != null) {
        if (acs['mode'] is int) {
          mode = acs['mode'];
        } else {
          mode = AccessMode.decode(acs['mode']);
        }
      } else {
        mode = _given & _want;
      }
    }
  }

  static int decode(dynamic mode) {
    if (mode == null) {
      return null;
    } else if (mode is int) {
      return mode & AccessModePermissionsBITMASK;
    } else if (mode == 'N' || mode == 'n') {
      return NONE;
    }

    var bitmask = {
      'J': JOIN,
      'R': READ,
      'W': WRITE,
      'P': PRES,
      'A': APPROVE,
      'S': SHARE,
      'D': DELETE,
      'O': OWNER,
    };

    var m0 = NONE;

    if (mode != null) {
      for (var i = 0; i < mode.length; i++) {
        var bit = bitmask[mode[i].toUpperCase()];
        if (bit == null) {
          // Unrecognized bit, skip.
          continue;
        }
        m0 |= bit;
      }
    }
    return m0;
  }

  static String encode(int val) {
    if (val == null || val == INVALID) {
      return null;
    } else if (val == NONE) {
      return 'N';
    }

    var bitmask = ['J', 'R', 'W', 'P', 'A', 'S', 'D', 'O'];
    var res = '';

    for (var i = 0; i < bitmask.length; i++) {
      if ((val & (1 << i)) != 0) {
        res = res + bitmask[i];
      }
    }
    return res;
  }

  static int update(int val, String upd) {
    if (upd == null || !(upd is String)) {
      return val;
    }

    var action = upd[0];

    if (action == '+' || action == '-') {
      var val0 = val;

      // Split delta-string like '+ABC-DEF+Z' into an array of parts including + and -.
      var parts = upd.split(RegExp(r'([-+])'));
      var actions = upd.split(RegExp(r'\w+'));
      var result = [];

      actions = actions.where((value) {
        return value != '';
      }).toList();

      parts = parts.where((value) {
        return value != '';
      }).toList();

      for (var i = 0; i < parts.length; i++) {
        var action = actions[i];
        var m0 = AccessMode.decode(parts[i]);
        if (m0 == INVALID) {
          return val;
        }
        if (m0 == null) {
          continue;
        }
        if (action == '+') {
          val0 |= m0;
        } else if (action == '-') {
          val0 &= ~m0;
        }
      }
      val = val0;
    } else {
      // The string is an explicit new value 'ABC' rather than delta.
      var val0 = AccessMode.decode(upd);
      if (val0 != INVALID) {
        val = val0;
      }
    }

    return val;
  }

  static int diff(dynamic a1, dynamic a2) {
    var a1d = AccessMode.decode(a1);
    var a2d = AccessMode.decode(a2);

    if (a1d == INVALID || a2d == INVALID) {
      return INVALID;
    }
    return a1d & ~a2d;
  }

  static bool checkFlag(AccessMode val, String side, int flag) {
    side ??= 'mode';
    var found = ['given', 'want', 'mode'].where((s) {
      return s == side;
    }).toList();

    if (found.isNotEmpty) {
      return ((val[side] & flag) != 0);
    }
    throw Exception('Invalid AccessMode component "' + side + '"');
  }

  AccessMode setMode(dynamic mode) {
    this.mode = AccessMode.decode(mode);
    return this;
  }

  AccessMode updateMode(String update) {
    mode = AccessMode.update(mode, update);
    return this;
  }

  String getMode() {
    return AccessMode.encode(mode);
  }

  AccessMode setGiven(dynamic given) {
    _given = AccessMode.decode(given);
    return this;
  }

  AccessMode updateGiven(String update) {
    _given = AccessMode.update(_given, update);
    return this;
  }

  String getGiven() {
    return AccessMode.encode(_given);
  }

  AccessMode setWant(dynamic want) {
    _want = AccessMode.decode(want);
    return this;
  }

  AccessMode updateWant(String update) {
    _want = AccessMode.update(_want, update);
    return this;
  }

  String getWant() {
    return AccessMode.encode(_want);
  }

  String getMissing() {
    return AccessMode.encode(_want & ~_given);
  }

  String getExcessive() {
    return AccessMode.encode(_given & ~_want);
  }

  AccessMode updateAll(AccessMode val) {
    if (val != null) {
      updateGiven(val.getGiven());
      updateWant(val.getWant());
      mode = _given & _want;
    }
    return this;
  }

  bool isOwner(String side) {
    return AccessMode.checkFlag(this, side, OWNER);
  }

  bool isPresencer(String side) {
    return AccessMode.checkFlag(this, side, PRES);
  }

  bool isMuted(String side) {
    return !isPresencer(side);
  }

  bool isJoiner(String side) {
    return AccessMode.checkFlag(this, side, JOIN);
  }

  bool isReader(String side) {
    return AccessMode.checkFlag(this, side, READ);
  }

  bool isWriter(String side) {
    return AccessMode.checkFlag(this, side, WRITE);
  }

  bool isApprover(String side) {
    return AccessMode.checkFlag(this, side, APPROVE);
  }

  bool isAdmin(String side) {
    return isOwner(side) || isApprover(side);
  }

  bool isSharer(String side) {
    return isAdmin(side) || AccessMode.checkFlag(this, side, SHARE);
  }

  bool isDeleter(String side) {
    return AccessMode.checkFlag(this, side, DELETE);
  }

  @override
  String toString() {
    return '{"mode": "' + AccessMode.encode(mode) + '", "given": "' + AccessMode.encode(_given) + '", "want": "' + AccessMode.encode(_want) + '"}';
  }

  Map<String, String> jsonHelper() {
    return {'mode': AccessMode.encode(mode), 'given': AccessMode.encode(_given), 'want': AccessMode.encode(_want)};
  }
}
