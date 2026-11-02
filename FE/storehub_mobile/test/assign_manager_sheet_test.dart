import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Assign manager sheet does not throw BoxConstraints forces an infinite width',
      (tester) async {
    final searchController = TextEditingController();
    final users = [
      {'id': '1', 'fullName': 'Manager One', 'email': 'm1@gmail.com', 'roleName': 'FACILITY_MANAGER'},
      {'id': '2', 'fullName': 'Manager Two', 'email': 'm2@gmail.com', 'roleName': 'FACILITY_MANAGER'},
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  builder: (ctx) => StatefulBuilder(
                    builder: (ctx, setSheet) {
                      final query = searchController.text.trim().toLowerCase();
                      final filtered = users.where((u) {
                        final rawRole = (u['roleName']?.toString() ?? '').toUpperCase();
                        if (rawRole != 'FACILITY_MANAGER') return false;
                        if (query.isEmpty) return true;
                        return u['fullName']!.toLowerCase().contains(query);
                      }).toList();

                      return SizedBox(
                        height: MediaQuery.of(ctx).size.height * 0.7,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Thêm Quản lý cơ sở (Facility Manager)',
                                      style: TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: searchController,
                                    decoration: const InputDecoration(
                                        hintText: 'Tìm theo tên hoặc email',
                                        prefixIcon: Icon(Icons.search)),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final u = filtered[index];
                                  return ListTile(
                                    title: Text(u['fullName']!),
                                    subtitle: Text(u['email']!),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Thêm Quản lý cơ sở (Facility Manager)'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Now tap the TextField to focus it (soft keyboard simulation)
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final ex = tester.takeException();
    expect(ex, isNull);
  });
}
