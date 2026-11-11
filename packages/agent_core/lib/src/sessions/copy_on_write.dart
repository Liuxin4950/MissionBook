import 'dart:collection';

// 会话投影的暂存分支共享未修改的集合。任一分支首次写入才复制，
// 因此持久化失败时可以丢弃整个分支，不污染已经接受的状态。
final class CowList<T> extends ListBase<T> {
  CowList() : _items = [];
  CowList._(this._items);
  List<T> _items;
  bool _shared = false;
  CowList<T> fork() {
    _shared = true;
    return CowList._(_items).._shared = true;
  }

  List<T> get _writable {
    if (_shared) {
      _items = List.of(_items);
      _shared = false;
    }
    return _items;
  }

  @override
  int get length => _items.length;
  @override
  set length(int value) => _writable.length = value;
  @override
  T operator [](int index) => _items[index];
  @override
  void operator []=(int index, T value) => _writable[index] = value;
  @override
  void add(T element) => _writable.add(element);
  @override
  void addAll(Iterable<T> iterable) => _writable.addAll(iterable);
  @override
  void clear() => _writable.clear();
}

final class CowMap<K, V> extends MapBase<K, V> {
  CowMap() : _items = {};
  CowMap._(this._items);
  Map<K, V> _items;
  bool _shared = false;
  CowMap<K, V> fork() {
    _shared = true;
    return CowMap._(_items).._shared = true;
  }

  Map<K, V> get _writable {
    if (_shared) {
      _items = Map.of(_items);
      _shared = false;
    }
    return _items;
  }

  @override
  V? operator [](Object? key) => _items[key];
  @override
  void operator []=(K key, V value) => _writable[key] = value;
  @override
  Iterable<K> get keys => _items.keys;
  @override
  V? remove(Object? key) => _writable.remove(key);
  @override
  void clear() => _writable.clear();
}

final class CowSet<T> extends SetBase<T> {
  CowSet() : _items = {};
  CowSet._(this._items);
  Set<T> _items;
  bool _shared = false;
  CowSet<T> fork() {
    _shared = true;
    return CowSet._(_items).._shared = true;
  }

  Set<T> get _writable {
    if (_shared) {
      _items = Set.of(_items);
      _shared = false;
    }
    return _items;
  }

  @override
  bool add(T value) => _writable.add(value);
  @override
  bool remove(Object? value) => _writable.remove(value);
  @override
  bool contains(Object? element) => _items.contains(element);
  @override
  T? lookup(Object? element) => _items.lookup(element);
  @override
  int get length => _items.length;
  @override
  Iterator<T> get iterator => _items.iterator;
  @override
  Set<T> toSet() => _items.toSet();
  @override
  void clear() => _writable.clear();
}
