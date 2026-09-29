import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/customer_portal_account_models.dart';
import '../../../core/network/customer_portal_models.dart';
import '../data/customer_account_repository.dart';

typedef SignOutCallback = Future<void> Function();

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.lifecycle,
    required this.repository,
    this.profile,
    this.onLifecycleChanged,
    this.onProfileChanged,
    this.onSignOut,
  });

  final PortalLifecycleSnapshot lifecycle;
  final CustomerProfile? profile;
  final CustomerAccountRepository repository;
  final ValueChanged<PortalLifecycleSnapshot>? onLifecycleChanged;
  final ValueChanged<PortalProfile>? onProfileChanged;
  final SignOutCallback? onSignOut;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const _businessTypes = <String>[
    'Cửa hàng bán lẻ',
    'Trà sữa / đồ uống',
    'Mỳ cay / quán ăn',
    'Tiệm bánh',
    'Nhà hàng',
    'Nhà phân phối',
    'Khác',
  ];

  static const _provinces = <String>[
    'Thành phố Hà Nội',
    'Tỉnh Cao Bằng',
    'Tỉnh Tuyên Quang',
    'Tỉnh Điện Biên',
    'Tỉnh Lai Châu',
    'Tỉnh Sơn La',
    'Tỉnh Lào Cai',
    'Tỉnh Thái Nguyên',
    'Tỉnh Lạng Sơn',
    'Tỉnh Quảng Ninh',
    'Tỉnh Bắc Ninh',
    'Tỉnh Phú Thọ',
    'Thành phố Hải Phòng',
    'Tỉnh Hưng Yên',
    'Tỉnh Ninh Bình',
    'Tỉnh Thanh Hóa',
    'Tỉnh Nghệ An',
    'Tỉnh Hà Tĩnh',
    'Tỉnh Quảng Trị',
    'Thành phố Huế',
    'Thành phố Đà Nẵng',
    'Tỉnh Quảng Ngãi',
    'Tỉnh Gia Lai',
    'Tỉnh Khánh Hòa',
    'Tỉnh Đắk Lắk',
    'Tỉnh Lâm Đồng',
    'Tỉnh Đồng Nai',
    'Thành phố Hồ Chí Minh',
    'Tỉnh Tây Ninh',
    'Tỉnh Đồng Tháp',
    'Tỉnh Vĩnh Long',
    'Tỉnh An Giang',
    'Thành phố Cần Thơ',
    'Tỉnh Cà Mau',
  ];

  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _wardController = TextEditingController();
  final _addressLineController = TextEditingController();

  PortalProfile? _editableProfile;
  String _businessType = _businessTypes.first;
  String _province = '';
  bool _loadingProfile = false;
  bool _refreshing = false;
  bool _saving = false;
  bool _signingOut = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _applyLifecycleForm(widget.lifecycle);
    if (widget.lifecycle.isActiveCustomer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadProfile();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lifecycle, widget.lifecycle)) {
      _applyLifecycleForm(widget.lifecycle);
      if (widget.lifecycle.isActiveCustomer &&
          !oldWidget.lifecycle.isActiveCustomer) {
        _loadProfile();
      }
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _phoneController.dispose();
    _wardController.dispose();
    _addressLineController.dispose();
    super.dispose();
  }

  void _applyLifecycleForm(PortalLifecycleSnapshot lifecycle) {
    if (lifecycle.isActiveCustomer) return;
    final customer = lifecycle.registration?.proposedCustomer;
    _shopNameController.text = customer?.name ?? '';
    _phoneController.text = customer?.phone ?? '';
    _businessType = _businessTypes.contains(customer?.businessType)
        ? customer!.businessType!
        : _businessTypes.first;
    _province = customer?.address.province ?? '';
    _wardController.text = customer?.address.ward ?? '';
    _addressLineController.text = customer?.address.addressLine1 ?? '';
    _editableProfile = null;
  }

  void _applyProfileForm(PortalProfile profile) {
    _editableProfile = profile;
    _shopNameController.text = profile.outletName;
    _phoneController.text = profile.phone;
    _province = profile.address?.province ?? '';
    _wardController.text = profile.address?.ward ?? '';
    _addressLineController.text = profile.address?.addressLine1 ?? '';
  }

  Future<void> _loadProfile() async {
    if (_loadingProfile || !widget.lifecycle.isActiveCustomer) return;
    setState(() {
      _loadingProfile = true;
      _error = null;
    });
    try {
      final profile = await widget.repository.getProfile();
      if (!mounted) return;
      setState(() {
        _applyProfileForm(profile);
        _loadingProfile = false;
      });
      widget.onProfileChanged?.call(profile);
    } on ApiFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _error = error.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _error = 'Không tải được thông tin điểm bán.';
      });
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
      _notice = null;
    });
    try {
      final lifecycle = await widget.repository.getLifecycle();
      if (!mounted) return;
      _applyLifecycleForm(lifecycle);
      widget.onLifecycleChanged?.call(lifecycle);
      setState(() {
        _refreshing = false;
      });
      if (lifecycle.isActiveCustomer) {
        await _loadProfile();
      }
    } on ApiFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _error = error.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _error = 'Không tải được trạng thái điểm bán.';
      });
    }
  }

  PortalRegistrationInput? _registrationInput() {
    final name = _shopNameController.text.trim();
    final phone = _phoneController.text.trim();
    final province = _province.trim();
    final ward = _wardController.text.trim();
    final addressLine = _addressLineController.text.trim();
    if (name.isEmpty ||
        phone.isEmpty ||
        province.isEmpty ||
        ward.isEmpty ||
        addressLine.isEmpty ||
        _businessType.trim().isEmpty) {
      setState(() {
        _error = 'Vui lòng nhập đầy đủ thông tin điểm bán.';
      });
      return null;
    }
    return PortalRegistrationInput(
      name: name,
      phone: phone,
      businessType: _businessType,
      addressLine1: addressLine,
      ward: ward,
      province: province,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });

    try {
      final state = widget.lifecycle.state;
      if (state == PortalLifecycleStates.unregistered) {
        final input = _registrationInput();
        if (input == null) return;
        final lifecycle = await widget.repository.submitRegistration(input);
        if (!mounted) return;
        _applyLifecycleForm(lifecycle);
        widget.onLifecycleChanged?.call(lifecycle);
        setState(() {
          _notice = 'Đã gửi đăng ký điểm bán về Hưng Phát.';
        });
      } else if (state == PortalLifecycleStates.needMoreInfo) {
        final registration = widget.lifecycle.registration;
        final input = _registrationInput();
        if (registration == null || input == null) {
          if (registration == null && mounted) {
            setState(() {
              _error = 'Không xác định được đăng ký cần bổ sung.';
            });
          }
          return;
        }
        final lifecycle = await widget.repository.resubmitRegistration(
          registration,
          input,
        );
        if (!mounted) return;
        _applyLifecycleForm(lifecycle);
        widget.onLifecycleChanged?.call(lifecycle);
        setState(() {
          _notice = 'Đã gửi lại thông tin bổ sung.';
        });
      } else if (state == PortalLifecycleStates.activeCustomer) {
        final profile = _editableProfile;
        final address = profile?.address;
        if (profile == null || address == null) {
          setState(() {
            _error = 'Điểm bán chưa có địa chỉ đang hoạt động. Vui lòng liên hệ Hưng Phát.';
          });
          return;
        }
        final outletName = _shopNameController.text.trim();
        final phone = _phoneController.text.trim();
        final province = _province.trim();
        final ward = _wardController.text.trim();
        final addressLine = _addressLineController.text.trim();
        if (outletName.isEmpty ||
            phone.isEmpty ||
            province.isEmpty ||
            ward.isEmpty ||
            addressLine.isEmpty) {
          setState(() {
            _error = 'Vui lòng nhập đầy đủ thông tin điểm bán.';
          });
          return;
        }

        final updated = await widget.repository.updateProfile(
          PortalProfileUpdateInput(
            outletName: outletName,
            phone: phone,
            expectedCustomerUpdatedAt: profile.customerUpdatedAt,
            expectedAddressUpdatedAt: address.updatedAt,
            addressId: address.id,
            addressLine1: addressLine,
            ward: ward,
            province: province,
            countryCode: address.countryCode,
          ),
        );
        if (!mounted) return;
        setState(() {
          _applyProfileForm(updated);
          _notice = 'Đã cập nhật thông tin điểm bán của Công Ty.';
        });
        widget.onProfileChanged?.call(updated);
      }
    } on ApiFailure catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409 && error.code != 'IDEMPOTENCY_IN_PROGRESS') {
        await _refresh();
        if (!mounted) return;
        setState(() {
          _error = 'Dữ liệu Công Ty đã thay đổi. Hãy kiểm tra dữ liệu mới rồi gửi lại.';
        });
      } else {
        setState(() {
          _error = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _error = 'Không lưu được thông tin điểm bán.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    if (_signingOut || widget.onSignOut == null) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut!();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  bool get _editable {
    final state = widget.lifecycle.state;
    if (state == PortalLifecycleStates.unregistered ||
        state == PortalLifecycleStates.needMoreInfo) {
      return true;
    }
    return state == PortalLifecycleStates.activeCustomer &&
        _editableProfile?.address != null;
  }

  String get _submitLabel => switch (widget.lifecycle.state) {
    PortalLifecycleStates.activeCustomer => 'Lưu lên Công Ty',
    PortalLifecycleStates.needMoreInfo => 'Gửi lại thông tin',
    _ => 'Gửi đăng ký điểm bán',
  };

  List<String> get _provinceOptions {
    final values = <String>[..._provinces];
    final current = _province.trim();
    if (current.isNotEmpty && !values.contains(current)) {
      values.insert(0, current);
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final copy = _stateCopy(widget.lifecycle.state);
    final customerCode =
        _editableProfile?.customerCode ??
        widget.profile?.customerCode ??
        widget.lifecycle.profile?.customerCode ??
        '';
    final displayName =
        _editableProfile?.displayName ??
        widget.profile?.displayName ??
        'Khách hàng Hưng Phát';
    final clerkUser = ClerkAuth.userOf(context);
    final clerkName = clerkUser?.name.trim() ?? '';
    final identityName = clerkName.isEmpty ? displayName : clerkName;
    final identityEmail = clerkUser?.email?.trim() ?? '';
    final imageUrl = clerkUser?.imageUrl?.trim();
    final profileImageUrl = clerkUser?.profileImageUrl?.trim();
    final identityImageUrl = imageUrl?.isNotEmpty == true
        ? imageUrl
        : profileImageUrl;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AccountAvatar(
                    name: identityName,
                    imageUrl: identityImageUrl,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          identityName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        if (identityEmail.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.mail_outline_rounded,
                                size: 16,
                                color: Color(0xFF6C757D),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  identityEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (customerCode.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Mã khách Công Ty: $customerCode'),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBF5E9),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.key_rounded,
                          color: Color(0xFF0F6B3D),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bảo mật & đăng nhập',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Quản lý ảnh đại diện, tên, email và liên kết Google của tài khoản Clerk.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const ClerkUserButton(showName: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.storefront_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Điểm bán / Công Ty',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              copy.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(copy.description),
                          ],
                        ),
                      ),
                      Chip(label: Text(copy.badge)),
                    ],
                  ),
                  if (widget.lifecycle.registration?.reviewReason
                          ?.trim()
                          .isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.lifecycle.registration!.reviewReason!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _refreshing ? null : _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      _refreshing ? 'Đang tải...' : 'Tải lại trạng thái',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loadingProfile) ...[
            const SizedBox(height: 12),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
          if (_editable && !_loadingProfile) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.lifecycle.isActiveCustomer
                          ? 'Chỉnh sửa thông tin điểm bán'
                          : widget.lifecycle.state ==
                                PortalLifecycleStates.needMoreInfo
                          ? 'Bổ sung thông tin điểm bán'
                          : 'Đăng ký điểm bán',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _shopNameController,
                      enabled: !_saving,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tên quán hoặc điểm bán',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      enabled: !_saving,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (!widget.lifecycle.isActiveCustomer) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_businessType),
                        initialValue: _businessType,
                        decoration: const InputDecoration(
                          labelText: 'Mô hình quán / loại hình kinh doanh',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final item in _businessTypes)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _businessType = value);
                                }
                              },
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_province),
                      initialValue: _province.isEmpty ? null : _province,
                      decoration: const InputDecoration(
                        labelText: 'Tỉnh / thành phố',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final item in _provinceOptions)
                          DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() => _province = value ?? '');
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _wardController,
                      enabled: !_saving,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Xã / phường / đặc khu',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressLineController,
                      enabled: !_saving,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Số nhà, tên đường',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        _saving ? 'Đang lưu...' : _submitLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (widget.lifecycle.isActiveCustomer &&
              !_loadingProfile &&
              _editableProfile?.address == null) ...[
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Điểm bán chưa có địa chỉ đang hoạt động. Vui lòng liên hệ Hưng Phát để khôi phục địa chỉ trước khi chỉnh sửa.',
                ),
              ),
            ),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_notice!),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
          ],
          if (widget.onSignOut != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _signingOut ? null : _signOut,
              icon: const Icon(Icons.logout_rounded),
              label: Text(
                _signingOut ? 'Đang đăng xuất...' : 'Đăng xuất',
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.name, required this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final initial = name.trim().isEmpty
        ? 'H'
        : name.trim().characters.first.toUpperCase();

    return Container(
      width: 58,
      height: 58,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEBF5E9),
        border: Border.all(color: const Color(0xFFD7E4D9), width: 1.5),
      ),
      child: url.isEmpty
          ? Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Color(0xFF0F6B3D),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Color(0xFF0F6B3D),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    );
  }
}

class _StateCopy {
  const _StateCopy({
    required this.title,
    required this.description,
    required this.badge,
  });

  final String title;
  final String description;
  final String badge;
}

_StateCopy _stateCopy(String state) => switch (state) {
  PortalLifecycleStates.unregistered => const _StateCopy(
    title: 'Chưa đăng ký điểm bán',
    description: 'Gửi thông tin điểm bán để Hưng Phát xác minh trước khi mở danh mục và đặt hàng.',
    badge: 'Chưa đăng ký',
  ),
  PortalLifecycleStates.submitted => const _StateCopy(
    title: 'Đã gửi đăng ký',
    description: 'Hưng Phát đã nhận thông tin và đang chờ xử lý.',
    badge: 'Đã gửi',
  ),
  PortalLifecycleStates.underReview => const _StateCopy(
    title: 'Đang xác minh',
    description: 'Thông tin điểm bán đang được bộ phận phụ trách kiểm tra.',
    badge: 'Đang xác minh',
  ),
  PortalLifecycleStates.needMoreInfo => const _StateCopy(
    title: 'Cần bổ sung thông tin',
    description: 'Cập nhật lại thông tin theo ghi chú xử lý rồi gửi lại.',
    badge: 'Cần bổ sung',
  ),
  PortalLifecycleStates.approved ||
  PortalLifecycleStates.linkedExisting ||
  PortalLifecycleStates.activationPending => const _StateCopy(
    title: 'Đã duyệt, đang kích hoạt',
    description:
        'Hệ thống đang hoàn tất liên kết khách hàng và quyền đặt hàng.',
    badge: 'Đang kích hoạt',
  ),
  PortalLifecycleStates.activeCustomer => const _StateCopy(
    title: 'Điểm bán đã liên thông Công Ty',
    description: 'Danh mục và đặt hàng đã được mở. Thông tin bên dưới là dữ liệu chính thức của Công Ty.',
    badge: 'Đã kích hoạt',
  ),
  PortalLifecycleStates.rejected => const _StateCopy(
    title: 'Đăng ký chưa được chấp thuận',
    description: 'Xem ghi chú xử lý và liên hệ Hưng Phát nếu cần hỗ trợ.',
    badge: 'Chưa chấp thuận',
  ),
  PortalLifecycleStates.cancelled => const _StateCopy(
    title: 'Đăng ký đã kết thúc',
    description:
        'Yêu cầu này đã kết thúc. Liên hệ Hưng Phát nếu cần mở lại quy trình.',
    badge: 'Đã kết thúc',
  ),
  PortalLifecycleStates.suspended => const _StateCopy(
    title: 'Liên kết điểm bán tạm khóa',
    description: 'Tài khoản hoặc liên kết điểm bán hiện không sử dụng được. Vui lòng liên hệ Hưng Phát.',
    badge: 'Tạm khóa',
  ),
  _ => const _StateCopy(
    title: 'Trạng thái điểm bán',
    description: 'Vui lòng tải lại trạng thái để tiếp tục.',
    badge: 'Đang kiểm tra',
  ),
};
