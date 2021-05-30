class ServerConfiguration {
  final String? build;
  final int? maxFileUploadSize;
  final int? maxMessageSize;
  final int? maxSubscriberCount;
  final int? maxTagCount;
  final int? maxTagLength;
  final int? minTagLength;
  final String? ver;

  ServerConfiguration({
    this.build,
    this.maxFileUploadSize,
    this.maxMessageSize,
    this.maxSubscriberCount,
    this.maxTagCount,
    this.maxTagLength,
    this.minTagLength,
    this.ver,
  });
}
