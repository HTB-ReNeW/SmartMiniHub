import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/widgets/paged_list_view.dart';

void main() {
  testWidgets('Only ten results are rendered and both directions are reachable',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PagedListView.builder(
                itemCount: 23, itemBuilder: (_, i) => Text('Result $i')))));
    expect(find.text('Result 0'), findsOneWidget);
    expect(find.text('Result 9'), findsOneWidget);
    expect(find.text('Result 10'), findsNothing);
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    expect(find.text('Result 10'), findsOneWidget);
    expect(find.text('Result 19'), findsOneWidget);
    expect(find.text('Result 0'), findsNothing);
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    expect(find.text('Result 22'), findsOneWidget);
    expect(find.text('Trang 3 / 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Trang trước'));
    await tester.pumpAndSettle();
    expect(find.text('Result 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Next remote batch opens as a new page, not twenty visible rows',
      (tester) async {
    var rows = 10;
    var more = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, update) => PagedListView.builder(
                    itemCount: rows + (more ? 1 : 0),
                    hasTrailingItem: more,
                    itemBuilder: (_, i) => i == rows
                        ? TextButton(
                            onPressed: () => update(() {
                                  rows = 20;
                                  more = false;
                                }),
                            child: const Text('Load more'))
                        : Text('Result $i'))))));
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('Result 10'), findsOneWidget);
    expect(find.text('Result 0'), findsNothing);
    expect(find.text('Trang 2 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Changed query resets to page one even with the same result count',
      (tester) async {
    var query = 'old';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, update) => Column(children: [
                      TextButton(
                          onPressed: () => update(() => query = 'new'),
                          child: const Text('Search')),
                      Expanded(
                          child: PagedListView.builder(
                              dataKey: query,
                              itemCount: 20,
                              itemBuilder: (_, i) => Text('$query $i'))),
                    ])))));
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('new 0'), findsOneWidget);
    expect(find.text('new 10'), findsNothing);
  });
}
