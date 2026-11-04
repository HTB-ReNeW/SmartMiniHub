class CheckoutScheduleWindow {
  final DateTime earliest, latest;
  CheckoutScheduleWindow(this.earliest, this.latest);

  static DateTime vietnamNow() {
    final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(vn.year, vn.month, vn.day, vn.hour, vn.minute, vn.second);
  }

  factory CheckoutScheduleWindow.forRental(
      DateTime? end, int notice, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final expiry = end == null
        ? today.add(const Duration(days: 1))
        : DateTime(end.year, end.month, end.day);
    if (expiry.isBefore(today)) {
      return CheckoutScheduleWindow(today, today.add(const Duration(days: 1)));
    }
    final requested = today.add(Duration(days: notice < 0 ? 0 : notice));
    return CheckoutScheduleWindow(
        requested.isAfter(expiry) ? expiry : requested, expiry);
  }

  String? validate(DateTime value, DateTime now, String? open, String? close) {
    if (!value.isAfter(now)) {
      return 'Lịch hẹn đã qua. Vui lòng chọn giờ trả kho mới ở tương lai.';
    }
    final day = DateTime(value.year, value.month, value.day);
    if (day.isBefore(earliest) || day.isAfter(latest)) {
      return 'Ngày trả kho vượt khoảng cho phép. Vui lòng chọn ngày trong giới hạn, liên hệ cơ sở hoặc gia hạn nếu cần trả muộn hơn.';
    }
    int minutes(String? time, int fallback) {
      final parts = time?.split(':');
      return parts == null || parts.length < 2
          ? fallback
          : (int.tryParse(parts[0]) ?? fallback ~/ 60) * 60 +
              (int.tryParse(parts[1]) ?? 0);
    }

    final minute = value.hour * 60 + value.minute;
    if (minute < minutes(open, 480) || minute > minutes(close, 1200)) {
      return 'Giờ hẹn trả kho phải nằm trong khung giờ mở cửa của cơ sở.';
    }
    return null;
  }
}
