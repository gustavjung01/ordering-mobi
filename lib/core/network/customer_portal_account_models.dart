class PortalLifecycleStates {
  const PortalLifecycleStates._();

  static const unregistered = 'unregistered';
  static const submitted = 'submitted';
  static const underReview = 'under_review';
  static const needMoreInfo = 'need_more_info';
  static const approved = 'approved';
  static const linkedExisting = 'linked_existing';
  static const activationPending = 'activation_pending';
  static const activeCustomer = 'active_customer';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
  static const suspended = 'suspended';

  static const all = <String>{
    unregistered,
    submitted,
    underReview,
    needMoreInfo,
    approved,
    linkedExisting,
    activationPending,
    activeCustomer,
    rejected,
    cancelled,
    suspended,
  };
}

class PortalCustomerAddress {
  const PortalCustomerAddress({
    required this.label,
    required this.addressLine1,
    required this.addressLine2,
    required this.ward,
    required this.district,
    required this.province,
    required this.postalCode,
    required this.countryCode,
  });

  factory PortalCustomerAddress.fromJson(Map<String, dynamic> json) {
    return PortalCustomerAddress(
      label: _string(json, 'label'),
      addressLine1: _string(json, 'addressLine1'),
      addressLine2: _optionalString(json['addressLine2']),
      ward: _optionalString(json['ward']),
      district: _optionalString(json['district']),
      province: _optionalString(json['province']),
      postalCode: _optionalString(json['postalCode']),
      countryCode: _string(json, 'countryCode'),
    );
  }

  final String label;
  final String addressLine1;
  final String? addressLine2;
  final String? ward;
  final String? district;
  final String? province;
  final String? postalCode;
  final String countryCode;
}

class PortalProposedCustomer {
  const PortalProposedCustomer({
    required this.name,
    required this.phone,
    required this.businessType,
    required this.address,
  });

  factory PortalProposedCustomer.fromJson(Map<String, dynamic> json) {
    return PortalProposedCustomer(
      name: _string(json, 'name'),
      phone: _optionalString(json['phone']),
      businessType: _optionalString(json['businessType']),
      address: PortalCustomerAddress.fromJson(_map(json['address'])),
    );
  }

  final String name;
  final String? phone;
  final String? businessType;
  final PortalCustomerAddress address;
}

class PortalRegistration {
  const PortalRegistration({
    required this.id,
    required this.status,
    required this.version,
    required this.proposedCustomer,
    required this.reviewReason,
    required this.submittedAt,
    required this.updatedAt,
  });

  factory PortalRegistration.fromJson(Map<String, dynamic> json) {
    return PortalRegistration(
      id: _string(json, 'id'),
      status: _string(json, 'status'),
      version: _integer(json, 'version'),
      proposedCustomer: PortalProposedCustomer.fromJson(
        _map(json['proposedCustomer']),
      ),
      reviewReason: _optionalString(json['reviewReason']),
      submittedAt: _dateTime(json['submittedAt']),
      updatedAt: _dateTime(json['updatedAt']),
    );
  }

  final String id;
  final String status;
  final int version;
  final PortalProposedCustomer proposedCustomer;
  final String? reviewReason;
  final DateTime submittedAt;
  final DateTime updatedAt;
}

class PortalLifecycleProfileSummary {
  const PortalLifecycleProfileSummary({
    required this.customerCode,
    required this.outletName,
  });

  factory PortalLifecycleProfileSummary.fromJson(Map<String, dynamic> json) {
    return PortalLifecycleProfileSummary(
      customerCode: _optionalString(json['customerCode']),
      outletName: _optionalString(json['outletName']),
    );
  }

  final String? customerCode;
  final String? outletName;
}

class PortalLifecycleSnapshot {
  const PortalLifecycleSnapshot({
    required this.state,
    required this.registration,
    required this.profile,
  });

  factory PortalLifecycleSnapshot.fromJson(Map<String, dynamic> json) {
    final state = _string(json, 'state');
    if (!PortalLifecycleStates.all.contains(state)) {
      throw FormatException('Unknown portal lifecycle state: $state');
    }
    return PortalLifecycleSnapshot(
      state: state,
      registration: json['registration'] == null
          ? null
          : PortalRegistration.fromJson(_map(json['registration'])),
      profile: json['profile'] == null
          ? null
          : PortalLifecycleProfileSummary.fromJson(_map(json['profile'])),
    );
  }

  final String state;
  final PortalRegistration? registration;
  final PortalLifecycleProfileSummary? profile;

  bool get isActiveCustomer => state == PortalLifecycleStates.activeCustomer;
}

class PortalEditableAddress {
  const PortalEditableAddress({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.locationUrl,
    required this.addressLine1,
    required this.addressLine2,
    required this.ward,
    required this.district,
    required this.province,
    required this.postalCode,
    required this.countryCode,
    required this.isDefault,
    required this.updatedAt,
  });

  factory PortalEditableAddress.fromJson(Map<String, dynamic> json) {
    return PortalEditableAddress(
      id: _string(json, 'id'),
      label: _stringOrEmpty(json['label']),
      recipientName: _stringOrEmpty(json['recipientName']),
      phone: _stringOrEmpty(json['phone']),
      locationUrl: _stringOrEmpty(json['locationUrl']),
      addressLine1: _stringOrEmpty(json['addressLine1']),
      addressLine2: _stringOrEmpty(json['addressLine2']),
      ward: _stringOrEmpty(json['ward']),
      district: _stringOrEmpty(json['district']),
      province: _stringOrEmpty(json['province']),
      postalCode: _stringOrEmpty(json['postalCode']),
      countryCode: _stringOrEmpty(json['countryCode']),
      isDefault: json['isDefault'] == true,
      updatedAt: _dateTime(json['updatedAt']),
    );
  }

  final String id;
  final String label;
  final String recipientName;
  final String phone;
  final String locationUrl;
  final String addressLine1;
  final String addressLine2;
  final String ward;
  final String district;
  final String province;
  final String postalCode;
  final String countryCode;
  final bool isDefault;
  final DateTime updatedAt;
}

class PortalProfile {
  const PortalProfile({
    required this.customerCode,
    required this.displayName,
    required this.outletName,
    required this.phone,
    required this.customerUpdatedAt,
    required this.address,
  });

  factory PortalProfile.fromJson(Map<String, dynamic> json) {
    return PortalProfile(
      customerCode: _string(json, 'customerCode'),
      displayName: _string(json, 'displayName'),
      outletName: _string(json, 'outletName'),
      phone: _string(json, 'phone'),
      customerUpdatedAt: _dateTime(json['customerUpdatedAt']),
      address: json['address'] == null
          ? null
          : PortalEditableAddress.fromJson(_map(json['address'])),
    );
  }

  final String customerCode;
  final String displayName;
  final String outletName;
  final String phone;
  final DateTime customerUpdatedAt;
  final PortalEditableAddress? address;
}

class PortalRegistrationInput {
  const PortalRegistrationInput({
    required this.name,
    required this.phone,
    required this.businessType,
    required this.addressLine1,
    required this.ward,
    required this.province,
  });

  final String name;
  final String phone;
  final String businessType;
  final String addressLine1;
  final String ward;
  final String province;

  Map<String, dynamic> toJson() => {
    'proposedCustomer': {
      'name': name.trim(),
      'phone': phone.trim(),
      'businessType': businessType.trim(),
      'address': {
        'label': 'Địa chỉ chính',
        'addressLine1': addressLine1.trim(),
        'ward': ward.trim(),
        'province': province.trim(),
        'countryCode': 'VN',
      },
    },
  };
}

class PortalProfileUpdateInput {
  const PortalProfileUpdateInput({
    required this.outletName,
    required this.phone,
    required this.expectedCustomerUpdatedAt,
    required this.expectedAddressUpdatedAt,
    required this.addressId,
    required this.addressLine1,
    required this.ward,
    required this.province,
    required this.countryCode,
    this.locationUrl,
  });

  final String outletName;
  final String phone;
  final DateTime expectedCustomerUpdatedAt;
  final DateTime expectedAddressUpdatedAt;
  final String addressId;
  final String addressLine1;
  final String ward;
  final String province;
  final String countryCode;
  final String? locationUrl;

  Map<String, dynamic> toJson() => {
    'outletName': outletName.trim(),
    'phone': phone.trim(),
    'expectedCustomerUpdatedAt': expectedCustomerUpdatedAt
        .toUtc()
        .toIso8601String(),
    'expectedAddressUpdatedAt': expectedAddressUpdatedAt
        .toUtc()
        .toIso8601String(),
    'address': {
      'id': addressId,
      if (locationUrl?.trim().isNotEmpty == true)
        'locationUrl': locationUrl!.trim(),
      'addressLine1': addressLine1.trim(),
      'ward': ward.trim(),
      'province': province.trim(),
      'countryCode': countryCode.trim().isEmpty ? 'VN' : countryCode.trim(),
    },
  };
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Missing or invalid $key');
}

String _stringOrEmpty(Object? value) => value is String ? value : '';

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.parse(value);
  throw FormatException('Missing or invalid $key');
}

DateTime _dateTime(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw const FormatException('Expected ISO-8601 date');
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Expected object');
}
