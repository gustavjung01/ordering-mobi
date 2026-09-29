import 'dart:convert';

import '../../../core/idempotency/canonical_idempotency.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_account_api.dart';
import '../../../core/network/customer_portal_account_models.dart';
import '../../../core/session/session_store.dart';

class CustomerAccountRepository {
  CustomerAccountRepository(
    this._api,
    this._secureStore, {
    required String userId,
  }) : _userScope = Uri.encodeComponent(userId.trim());

  static const _pendingRegistrationKey = 'pending-registration.v1';
  static const _pendingResubmitPrefix = 'pending-registration-resubmit.v1.';
  static const _pendingProfileUpdateKey = 'pending-profile-update.v1';

  final CustomerPortalAccountApi _api;
  final SecureStringStore _secureStore;
  final String _userScope;

  String _secureKey(String name) => 'ordering.user.$_userScope.$name';

  Future<PortalLifecycleSnapshot> getLifecycle() => _api.getLifecycle();

  Future<PortalProfile> getProfile() => _api.getProfile();

  Future<PortalLifecycleSnapshot> submitRegistration(
    PortalRegistrationInput input,
  ) {
    final signature = jsonEncode(input.toJson());
    return _runMutation(
      storageName: _pendingRegistrationKey,
      operation: 'customer-registration-submit',
      signature: signature,
      action: (key) => _api.submitRegistration(
        input: input,
        idempotencyKey: key,
      ),
    );
  }

  Future<PortalLifecycleSnapshot> resubmitRegistration(
    PortalRegistration registration,
    PortalRegistrationInput input,
  ) {
    final signature = jsonEncode({
      'registrationId': registration.id,
      'expectedVersion': registration.version,
      ...input.toJson(),
    });
    return _runMutation(
      storageName:
          '$_pendingResubmitPrefix${Uri.encodeComponent(registration.id)}',
      operation: 'customer-registration-resubmit',
      signature: signature,
      action: (key) => _api.resubmitRegistration(
        registration: registration,
        input: input,
        idempotencyKey: key,
      ),
    );
  }

  Future<PortalProfile> updateProfile(PortalProfileUpdateInput input) {
    final signature = jsonEncode(input.toJson());
    return _runMutation(
      storageName: _pendingProfileUpdateKey,
      operation: 'customer-profile-update',
      signature: signature,
      action: (key) => _api.updateProfile(
        input: input,
        idempotencyKey: key,
      ),
    );
  }

  Future<T> _runMutation<T>({
    required String storageName,
    required String operation,
    required String signature,
    required Future<T> Function(String idempotencyKey) action,
  }) async {
    final storageKey = _secureKey(storageName);
    final pending = _decodePendingMutation(
      await _secureStore.read(storageKey),
    );
    final key =
        pending != null &&
            pending.signature == signature &&
            CanonicalIdempotencyKey.isValid(pending.key)
        ? pending.key
        : CanonicalIdempotencyKey.create(operation);

    if (pending == null ||
        pending.signature != signature ||
        pending.key != key) {
      await _secureStore.write(
        storageKey,
        jsonEncode({'key': key, 'signature': signature}),
      );
    }

    try {
      final result = await action(key);
      try {
        await _secureStore.delete(storageKey);
      } on Object {
        // A stale key is replaced when a different payload is submitted.
      }
      return result;
    } on ApiFailure catch (error) {
      if (!error.retryable && error.code != 'IDEMPOTENCY_IN_PROGRESS') {
        try {
          await _secureStore.delete(storageKey);
        } on Object {
          // Keep the original business error instead of masking it.
        }
      }
      rethrow;
    }
  }

  _PendingMutation? _decodePendingMutation(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final key = decoded['key']?.toString() ?? '';
      final signature = decoded['signature']?.toString() ?? '';
      if (key.isEmpty || signature.isEmpty) return null;
      return _PendingMutation(key: key, signature: signature);
    } on Object {
      return null;
    }
  }
}

class _PendingMutation {
  const _PendingMutation({
    required this.key,
    required this.signature,
  });

  final String key;
  final String signature;
}
