import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/core/network/http_client.dart';

void main() {
  test(
      'Collection loader reads every ten-item batch without losing later search results',
      () async {
    final calls = <int>[];
    final result = await collectCollectionPages((page) async {
      calls.add(page);
      return ApiResponse(statusCode: 200, data: {
        'success': true,
        'data': {
          'content':
              List.generate(page == 2 ? 3 : 10, (i) => {'id': page * 10 + i}),
          'page': page,
          'size': 10,
          'last': page == 2,
          'totalPages': 3,
        }
      });
    });
    expect(calls, [0, 1, 2]);
    expect(result.data['data'].length, 23);
    expect(result.data['data'].last['id'], 22);
  });
  test(
      'A failed later page is reported rather than silently truncating the list',
      () async {
    await expectLater(collectCollectionPages((page) async {
      if (page == 1) throw Exception('Network failed');
      return const ApiResponse(data: {
        'data': {
          'content': [
            {'id': 1}
          ],
          'last': false
        }
      });
    }), throwsException);
  });
  test('Empty collections terminate immediately', () async {
    var calls = 0;
    final result = await collectCollectionPages((page) async {
      calls++;
      return const ApiResponse(data: {
        'data': {'content': [], 'last': true, 'totalPages': 0}
      });
    });
    expect(calls, 1);
    expect(result.data['data'], isEmpty);
  });
}
