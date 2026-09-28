import 'package:flutter_test/flutter_test.dart';
import 'package:ordering_mobile/core/idempotency/canonical_idempotency.dart';

void main() {
  group('CanonicalIdempotencyKey', () {
    test('normalizes operation and creates canonical key', () {
      const uuid = '123e4567-e89b-42d3-a456-426614174000';
      final key = CanonicalIdempotencyKey.create(
        ' Submit Customer Order ',
        uuid: uuid,
      );

      expect(key, 'submit-customer-order-$uuid');
      expect(CanonicalIdempotencyKey.isValid(key), isTrue);
      expect(key.length, lessThanOrEqualTo(128));
    });

    test('rejects invalid uuid', () {
      expect(
        () => CanonicalIdempotencyKey.create(
          'submit-order',
          uuid: 'not-a-uuid',
        ),
        throwsArgumentError,
      );
    });

    test('uses only canonical characters', () {
      const uuid = '123e4567-e89b-42d3-a456-426614174000';
      final key = CanonicalIdempotencyKey.create(
        'Đặt đơn / retry @ customer',
        uuid: uuid,
      );

      expect(RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(key), isTrue);
    });
  });
}
