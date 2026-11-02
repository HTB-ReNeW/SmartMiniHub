class PagedResult<T> {
  final List<T> content;
  final int page;
  final bool last;

  const PagedResult({required this.content, required this.page, required this.last});

  factory PagedResult.fromApi(dynamic body, T Function(dynamic) parse) {
    Map? data;
    if (body is Map) {
      if (body['data'] is Map) {
        data = body['data'] as Map;
      } else if (body['content'] is List) {
        data = body;
      }
    }
    if (data == null || data['content'] is! List) {
      throw const FormatException('Dữ liệu phân trang không hợp lệ');
    }
    return PagedResult(
      content: (data['content'] as List).map(parse).toList(),
      page: (data['page'] as num?)?.toInt() ?? 0,
      last: data['last'] == true,
    );
  }
}
