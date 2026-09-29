String formatVnd(num amount) {
  final negative = amount < 0;
  final digits = amount.abs().round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[index]);
  }
  return '${negative ? '-' : ''}${buffer.toString()} ₫';
}

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String orderStatusLabel(String status) {
  return switch (status) {
    'DRAFT' => 'Bản nháp',
    'SUBMITTED' => 'Đã gửi',
    'RECEIVED' => 'Đã tiếp nhận',
    'CONFIRMED' => 'Đã xác nhận',
    'PROCESSING' => 'Đang xử lý',
    'DELIVERING' => 'Đang giao',
    'COMPLETED' => 'Hoàn tất',
    'REJECTED' => 'Từ chối',
    'CANCELLED' => 'Đã hủy',
    _ => status,
  };
}
