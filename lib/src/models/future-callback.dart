import 'dart:async';

class FeatureCallback {
  final DateTime ts;
  final Completer completer;

  FeatureCallback({this.ts, this.completer});
}
