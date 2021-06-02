class AppSettings {
  final int localSeqId;
  final int networkUser;
  final int networkError;
  final String errorText;
  final String networkUserText;
  final int expireFuturesPeriod;
  final int expireFuturesTimeout;

  AppSettings(
    this.localSeqId,
    this.networkUser,
    this.networkError,
    this.errorText,
    this.networkUserText,
    this.expireFuturesPeriod,
    this.expireFuturesTimeout,
  );
}
