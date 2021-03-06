class CacheManager {
  final Map<String, dynamic> _cache = {};

  void cachePut(String type, String name, dynamic obj) {
    _cache[type + ':' + name] = obj;
  }

  dynamic cacheGet(String type, String name) {
    return _cache[type + ':' + name];
  }

  void cacheDel(String type, String name) {
    _cache.remove(type + ':' + name);
  }

  void map(Function(String, dynamic) function) {
    _cache.map(function);
  }

  dynamic cacheGetUser(String userId) {
    var pub = cacheGet('user', userId);
    if (pub != null) {
      return {
        'user': userId,
        'public': pub,
      };
    }
  }
}
