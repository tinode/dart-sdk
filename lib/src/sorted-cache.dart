/// Sorted cache is a cache manager for sorted data
class SortedCache<T> {
  /// Data will be stored here
  List<T> buffer = [];

  /// This function will be used to sort elements
  final int Function(T, T) compare;

  /// Enforce element uniqueness: replace existing element with a new one on conflict
  final bool unique;

  /// Creates a new instance of Sorted cache
  SortedCache(this.compare, this.unique);

  /// Find nearest element index
  dynamic findNearest(T element, List<T> array, bool exact) {
    var diff = 0;
    var start = 0;
    var pivot = 0;
    var found = false;
    var end = array.length - 1;

    while (start <= end) {
      pivot = ((start + end) / 2).roundToDouble().toInt();
      diff = compare(array[pivot], element);
      if (diff < 0) {
        start = pivot + 1;
      } else if (diff > 0) {
        end = pivot - 1;
      } else {
        found = true;
        break;
      }
    }

    if (found) {
      return {'idx': pivot, 'exact': true};
    }

    if (exact) {
      return {'idx': -1};
    }

    // Not exact - insertion point
    return {'idx': diff < 0 ? pivot + 1 : pivot};
  }

  /// Insert element into a sorted array
  List<T> insertSorted(T element, List<T> array) {
    var found = findNearest(element, array, false);
    final int idx = found['idx'];
    if (idx >= 0 && idx <= array.length) {
      if (idx < array.length && found['exact'] == true && unique) {
        // replace element
        array[idx] = element;
      } else {
        array.insert(idx, element);
      }
    } else {
      array.add(element);
    }
    return array;
  }

  /// Get an element at the given position
  T getAt(int at) {
    return buffer[at];
  }

  /// Convenience method for getting the last element of the buffer
  T getLast() {
    return buffer.last;
  }

  /// Add new elements to the buffer
  void put(List<T> elements) {
    elements.forEach((insert) {
      insertSorted(insert, buffer);
    });
  }

  /// Remove element at the given position
  T deleteAt(int at) {
    return buffer.removeAt(at);
  }

  /// Remove elements between two positions
  void deleteRange(int since, int before) {
    return buffer.removeRange(since, before);
  }

  /// Return the number of elements the buffer holds
  int get length {
    return buffer.length;
  }

  /// Reset the buffer discarding all elements
  void reset() {
    buffer = [];
  }

  /// Apply given function `callback` to all elements of the buffer
  void forEach(Function(T, int) callback, int? startIndex, int? beforeIdx) {
    startIndex = startIndex ?? 0;
    beforeIdx = beforeIdx ?? buffer.length;
    for (var i = startIndex; i < beforeIdx; i++) {
      callback(buffer[i], i);
    }
  }

  ///  Find element in buffer using buffer's comparison function
  int find(T element, bool nearest) {
    var found = findNearest(element, buffer, !nearest);
    return found['idx'];
  }
}
