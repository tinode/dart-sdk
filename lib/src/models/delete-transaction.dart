class DeleteTransactionRange {
  final int? hi;
  final int? low;

  DeleteTransactionRange({this.hi, this.low});

  static DeleteTransactionRange fromMessage(Map<String, dynamic> msg) {
    return DeleteTransactionRange(
      low: msg['low'],
      hi: msg['hi'],
    );
  }
}

class DeleteTransaction {
  /// Id of the latest applicable 'delete' transaction
  final int? clear;

  /// Ranges of Ids of deleted messages
  final List<DeleteTransactionRange>? delseq;

  DeleteTransaction({this.clear, this.delseq});

  static DeleteTransaction fromMessage(Map<String, dynamic> msg) {
    return DeleteTransaction(
      clear: msg['clear'],
      delseq:
          msg['delseq'] != null && msg['delseq'].length != null ? msg['delseq'].map((del) => DeleteTransactionRange.fromMessage(del)).toList() : [],
    );
  }
}
