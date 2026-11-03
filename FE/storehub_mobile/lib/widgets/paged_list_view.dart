import 'package:flutter/material.dart';

/// Ten visible results per page, applied after local searching/filtering.
class PagedListView extends StatefulWidget {
  final int itemCount;
  final Object? dataKey;
  final bool hasTrailingItem;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final bool shrinkWrap;
  final bool? primary;
  const PagedListView.builder(
      {super.key,
      required this.itemCount,
      required this.itemBuilder,
      this.hasTrailingItem = false,
      this.dataKey,
      this.padding,
      this.physics,
      this.controller,
      this.shrinkWrap = false,
      this.primary})
      : separatorBuilder = null;
  const PagedListView.separated(
      {super.key,
      required this.itemCount,
      required this.itemBuilder,
      this.hasTrailingItem = false,
      this.dataKey,
      required this.separatorBuilder,
      this.padding,
      this.physics,
      this.controller,
      this.shrinkWrap = false,
      this.primary});
  @override
  State<PagedListView> createState() => _PagedListViewState();
}

class _PagedListViewState extends State<PagedListView> {
  int _page = 0;
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PagedListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCount = oldWidget.itemCount - (oldWidget.hasTrailingItem ? 1 : 0);
    final newCount = widget.itemCount - (widget.hasTrailingItem ? 1 : 0);
    if (oldWidget.dataKey != widget.dataKey || oldCount != newCount) {
      _page = oldWidget.dataKey == widget.dataKey &&
              oldWidget.hasTrailingItem &&
              newCount > oldCount
          ? oldCount ~/ 10
          : 0;
    }
  }

  void _go(int page) {
    setState(() => _page = page);
    final controller = widget.controller ?? _scroll;
    if (controller.hasClients) controller.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final dataCount = widget.itemCount - (widget.hasTrailingItem ? 1 : 0);
    final pages = (dataCount / 10).ceil();
    final start = _page * 10;
    final count = (dataCount - start).clamp(0, 10);
    Widget item(BuildContext context, int index) =>
        widget.itemBuilder(context, start + index);
    final list = widget.separatorBuilder == null
        ? ListView.builder(
            itemCount: count,
            itemBuilder: item,
            padding: widget.padding,
            physics: widget.physics,
            controller:
                widget.controller ?? (widget.primary == true ? null : _scroll),
            shrinkWrap: widget.shrinkWrap,
            primary: widget.primary)
        : ListView.separated(
            itemCount: count,
            itemBuilder: item,
            separatorBuilder: (context, index) =>
                widget.separatorBuilder!(context, start + index),
            padding: widget.padding,
            physics: widget.physics,
            controller:
                widget.controller ?? (widget.primary == true ? null : _scroll),
            shrinkWrap: widget.shrinkWrap,
            primary: widget.primary);
    if (pages <= 1 && !widget.hasTrailingItem) return list;
    return Column(
        mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                tooltip: 'Trang trước',
                onPressed: _page > 0 ? () => _go(_page - 1) : null,
                icon: const Icon(Icons.chevron_left)),
            Flexible(
                child: Text(
                    widget.hasTrailingItem
                        ? 'Trang ${_page + 1}'
                        : 'Trang ${_page + 1} / $pages',
                    style: const TextStyle(fontSize: 12))),
            IconButton(
                tooltip: 'Trang sau',
                onPressed: _page + 1 < pages ? () => _go(_page + 1) : null,
                icon: const Icon(Icons.chevron_right)),
          ]),
          if (widget.shrinkWrap) list else Expanded(child: list),
          if (widget.hasTrailingItem && (pages == 0 || _page == pages - 1))
            widget.itemBuilder(context, widget.itemCount - 1),
        ]);
  }
}

/// Paginates ten records before a caller groups them into sections.
class PagedCollection<T> extends StatefulWidget {
  final List<T> items;
  final Object? dataKey;
  final Widget Function(BuildContext, List<T>) builder;
  final bool shrinkWrap;
  const PagedCollection(
      {super.key,
      required this.items,
      required this.builder,
      this.dataKey,
      this.shrinkWrap = false});
  @override
  State<PagedCollection<T>> createState() => _PagedCollectionState<T>();
}

class _PagedCollectionState<T> extends State<PagedCollection<T>> {
  int _page = 0;
  @override
  void didUpdateWidget(covariant PagedCollection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataKey != widget.dataKey ||
        oldWidget.items.length != widget.items.length) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = (widget.items.length / 10).ceil();
    final child = widget.builder(
        context, widget.items.skip(_page * 10).take(10).toList());
    if (pages <= 1) return child;
    return Column(
        mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                tooltip: 'Trang trước',
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left)),
            Flexible(
                child: Text('Trang ${_page + 1} / $pages',
                    style: const TextStyle(fontSize: 12))),
            IconButton(
                tooltip: 'Trang sau',
                onPressed:
                    _page + 1 < pages ? () => setState(() => _page++) : null,
                icon: const Icon(Icons.chevron_right)),
          ]),
          if (widget.shrinkWrap) child else Expanded(child: child),
        ]);
  }
}
