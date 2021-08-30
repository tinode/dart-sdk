class DelRange {
  int? low;
  int? hi;
  bool? all;

  DelRange({
    this.low,
    this.hi,
    this.all,
  });

  Map<String, dynamic> toJson() {
    return {
      'low': low,
      'hi': hi,
      'all': all
    };
  }
}
