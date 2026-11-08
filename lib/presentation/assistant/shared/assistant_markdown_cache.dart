import 'dart:collection';
import 'dart:convert';

import 'package:markdown/markdown.dart' as md;

/// Markdown 语法树的有界内存缓存；主题变化只重建样式和 Widget。
class AssistantMarkdownAstCache {
  AssistantMarkdownAstCache({
    this.maxEntries = 8,
    this.maxWeight = 128 * 1024,
    this.maxSourceLength = 32 * 1024,
  }) : assert(maxEntries > 0),
       assert(maxWeight > 0),
       assert(maxSourceLength > 0);

  final int maxEntries;
  final int maxWeight;
  final int maxSourceLength;
  final LinkedHashMap<String, _CachedAst> _entries = LinkedHashMap();
  int _weight = 0;

  int get entryCount => _entries.length;
  int get estimatedWeight => _weight;

  List<md.Node> parse(String source) {
    final cached = _entries.remove(source);
    if (cached != null) {
      _entries[source] = cached;
      return cached.nodes;
    }

    final parsed = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    ).parseLines(const LineSplitter().convert(source));
    final nodes = _promoteChartFences(parsed);
    final weight = source.length + _countNodes(nodes) * 48;
    if (source.length > maxSourceLength || weight > maxWeight) return nodes;

    while (_entries.isNotEmpty &&
        (_entries.length >= maxEntries || _weight + weight > maxWeight)) {
      final oldestKey = _entries.keys.first;
      _weight -= _entries.remove(oldestKey)!.weight;
    }
    _entries[source] = _CachedAst(nodes, weight);
    _weight += weight;
    return nodes;
  }

  List<md.Node> _promoteChartFences(List<md.Node> nodes) => [
    for (final node in nodes)
      if (node is md.Element && node.tag == 'pre')
        _chartNode(node) ?? _rebuildElement(node)
      else if (node is md.Element)
        _rebuildElement(node)
      else
        node,
  ];

  md.Element? _chartNode(md.Element pre) {
    for (final child in pre.children ?? const <md.Node>[]) {
      if (child is! md.Element || child.tag != 'code') continue;
      if (child.attributes['class'] != 'language-missionbook-chart') {
        return null;
      }
      if (child.textContent.length > 4096) return null;
      return md.Element.text('missionbook-chart', child.textContent);
    }
    return null;
  }

  md.Element _rebuildElement(md.Element element) {
    final rebuilt = md.Element(
      element.tag,
      element.children == null ? null : _promoteChartFences(element.children!),
    )..attributes.addAll(element.attributes);
    rebuilt.generatedId = element.generatedId;
    rebuilt.footnoteLabel = element.footnoteLabel;
    return rebuilt;
  }

  int _countNodes(Iterable<md.Node> nodes) {
    var count = 0;
    final pending = List<md.Node>.of(nodes);
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      count++;
      if (node is md.Element) pending.addAll(node.children ?? const []);
    }
    return count;
  }
}

class _CachedAst {
  const _CachedAst(this.nodes, this.weight);

  final List<md.Node> nodes;
  final int weight;
}
