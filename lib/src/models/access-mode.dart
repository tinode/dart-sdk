/// This numeric value represents `N` or `n` access mode flag.
const int NONE = 0x00;

/// This numeric value represents `J` access mode flag.
const int JOIN = 0x01;

/// This numeric value represents `R` access mode flag.
const int READ = 0x02;

/// This numeric value represents `W` access mode flag.
const int WRITE = 0x04;

/// This numeric value represents `P` access mode flag.
const int PRES = 0x08;

/// This numeric value represents `A` access mode flag.
const int APPROVE = 0x10;

/// This numeric value represents `S` access mode flag.
const int SHARE = 0x20;

/// This numeric value represents `D` access mode flag.
const int DELETE = 0x40;

/// This numeric value represents `O` access mode flag.
const int OWNER = 0x80;

/// This numeric value represents `invalid` access mode flag.
const int INVALID = 0x100000;

/// Bitmask for validating access modes
const int AccessModePermissionsBITMASK = JOIN | READ | WRITE | PRES | APPROVE | SHARE | DELETE | OWNER;

/// Access control is mostly usable for group topics. Its usability for me and P2P topics is
/// limited to managing presence notifications and banning uses from initiating or continuing P2P conversations.
class AccessMode {
  /// Permissions granted to user by topic's manager
  late int _given;

  /// User's desired permissions
  late int _want;

  /// Combination of want and given
  late int mode;

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

  /// Create new instance by passing an `AccessMode` or `Map<String, dynamic>`
  AccessMode(dynamic acs) {
    if (acs != null) {
      _given = acs['given'] is int ? acs['given'] : AccessMode.decode(acs['given']);
      _want = acs['want'] is int ? acs['want'] : AccessMode.decode(acs['want']);

      if (acs['mode'] != null) {
        if (acs['mode'] is int) {
          mode = acs['mode'];
        } else {
          mode = AccessMode.decode(acs['mode']) ?? 0;
        }
      } else {
        mode = _given & _want;
      }
    }
    
  }
     Map<String, dynamic> toJson() {
    return {
      'given': encode(_given),
      'want': encode(_want),
      'mode': encode(mode),
    };
  }


  /// Decodes string access mode to integer
  static int? decode(dynamic mode) {
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

  /// Decodes integer access mode to string
  static String? encode(int val) {
    if (val == INVALID) {
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

  /// Updates mode with newly given permissions
  static int update(int val, String upd) {
    if (!(upd is String)) {
      return val;
    }

    var action = upd[0];

    if (action == '+' || action == '-') {
      var val0 = val;

      // Split delta-string like '+ABC-DEF+Z' into an array of parts including + and -.
      var parts = upd.split(RegExp(r'([-+])'));
      var actions = upd.split(RegExp(r'\w+'));

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
        val = val0 ?? 0;
      }
    }

    return val;
  }

  /// Get diff from two modes
  static int diff(dynamic a1, dynamic a2) {
    var a1d = AccessMode.decode(a1) ?? 0;
    var a2d = AccessMode.decode(a2) ?? 0;

    if (a1d == INVALID || a2d == INVALID) {
      return INVALID;
    }
    return a1d & ~a2d;
  }

  /// Returns true if AccessNode has x flag
  ///
  /// side: `mode` / `want` / `given`
  static bool checkFlag(AccessMode val, String? side, int flag) {
    side ??= 'mode';
    var found = ['given', 'want', 'mode'].where((s) {
      return s == side;
    }).toList();

    if (found.isNotEmpty) {
      return ((val[side] & flag) != 0);
    }
    throw Exception('Invalid AccessMode component "' + side + '"');
  }

  /// Returns encoded `mode`
  String? getMode() {
    return AccessMode.encode(mode);
  }

  AccessMode setMode(dynamic mode) {
    this.mode = AccessMode.decode(mode) ?? 0;
    return this;
  }

  AccessMode updateMode(String update) {
    mode = AccessMode.update(mode, update);
    return this;
  }

  /// Returns encoded `given`
  String? getGiven() {
    return AccessMode.encode(_given);
  }

  AccessMode setGiven(dynamic given) {
    _given = AccessMode.decode(given) ?? 0;
    return this;
  }

  AccessMode updateGiven(String update) {
    _given = AccessMode.update(_given, update);
    return this;
  }

  /// Returns encoded `want`
  String? getWant() {
    return AccessMode.encode(_want);
  }

  AccessMode setWant(dynamic want) {
    _want = AccessMode.decode(want) ?? 0;
    return this;
  }

  AccessMode updateWant(String update) {
    _want = AccessMode.update(_want, update);
    return this;
  }

  /// What user `want` that is not `given`
  String? getMissing() {
    return AccessMode.encode(_want & ~_given);
  }

  /// What permission is `given` and user does not `want`
  String? getExcessive() {
    return AccessMode.encode(_given & ~_want);
  }

  AccessMode updateAll(AccessMode? val) {
    if (val != null) {
      var g = val.getGiven();
      if (g != null) {
        updateGiven(g);
      }

      var w = val.getWant();
      if (w != null) {
        updateWant(w);
      }
      mode = _given & _want;
    }
    return this;
  }

  bool isOwner(String side) {
    return AccessMode.checkFlag(this, side, OWNER);
  }

  bool isPresencer(String? side) {
    return AccessMode.checkFlag(this, side, PRES);
  }

  bool isMuted(String? side) {
    return !isPresencer(side);
  }

  /// Can this user subscribe on topic?
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
    return '{"mode": "' +
        (AccessMode.encode(mode) ?? 'invalid') +
        '", "given": "' +
        (AccessMode.encode(_given) ?? 'invalid') +
        '", "want": "' +
        (AccessMode.encode(_want) ?? 'invalid') +
        '"}';
  }

  Map<String, String> jsonHelper() {
    return {
      'mode': AccessMode.encode(mode) ?? 'invalid',
      'given': AccessMode.encode(_given) ?? 'invalid',
      'want': AccessMode.encode(_want) ?? 'invalid',
    };
  }
}
