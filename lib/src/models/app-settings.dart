/// Settings defined for the library
class AppSettings {
  /// Current value of locally issued seqId, used for pending messages
  final int localSeqId;

  /// Default network error
  final int networkError;

  /// Periodicity of garbage collection of unresolved futures.
  final int expireFuturesPeriod;

  /// Reject unresolved futures after this many milliseconds.
  final int expireFuturesTimeout;

  AppSettings(
    this.localSeqId,
    this.networkError,
    this.expireFuturesPeriod,
    this.expireFuturesTimeout,
  );
}
