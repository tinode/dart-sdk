import 'package:tinode/src/topic.dart';

/// This is a data structure for user's data in cache
class CacheUser {
  final Map<String, dynamic> public;
  final String userId;

  /// Creates a new instance of cache user
  CacheUser(this.public, this.userId);

  /// Create a copy of this instance
  CacheUser copy() {
    return CacheUser(public, userId);
  }
}

/// Cache manager is responsible for reading and writing data into cache
class CacheManager {
  /// This map holds the cached data
  final Map<String, dynamic> _cache = {};

  /// Put a new data into cache, if the data already exists, replace it
  void put(String type, String name, dynamic obj) {
    _cache[type + ':' + name] = obj;
  }

  /// Get a specific data from cache using type and name
  dynamic get(String type, String name) {
    return _cache[type + ':' + name];
  }

  /// Delete a specific key-value from cache map
  void delete(String type, String name) {
    _cache.remove(type + ':' + name);
  }

  /// Executes a function for each element in cache, just like map method on `Map`
  void map(Function(String, dynamic) function) {
    _cache.map(function);
  }

  /// This is a wrapper for `get` function which gets a user from cache by userId
  CacheUser getUser(String userId) {
    var pub = get('user', userId);
    if (pub != null) {
      return CacheUser(pub, userId);
    }
    return null;
  }

  /// This is a wrapper for `put` function which puts a user into cache by userId
  void putUser(String userId, CacheUser user) {
    return put('user', userId, user.copy());
  }

  /// This is a wrapper for `delete` function which deletes a user from cache by userId
  void deleteUser(String userId) {
    return delete('user', userId);
  }

  /// This is a wrapper for `put` function which puts a topic into cache
  void putTopic(Topic topic) {
    return put('topic', topic.name, topic);
  }

  /// This is a wrapper for `delete` function which deletes a topic from cache by topic name
  void deleteTopic(String topicName) {
    return delete('topic', topicName);
  }
}
