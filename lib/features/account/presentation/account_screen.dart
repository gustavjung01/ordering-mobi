import 'package:flutter/material.dart';

import '../../../core/network/customer_portal_models.dart';

typedef SignOutCallback = Future<void> Function();

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.profile,
    this.onSignOut,
  });

  final CustomerProfile profile;
  final SignOutCallback? onSignOut;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut || widget.onSignOut == null) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut!();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.person_rounded, size: 30),
                ),
                const SizedBox(height: 14),
                Text(
                  profile.displayName,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text('Mã khách hàng: ${profile.customerCode}'),
                if (profile.outletName.isNotEmpty)
                  Text('Điểm bán: ${profile.outletName}'),
                if (profile.phone.isNotEmpty)
                  Text('Điện thoại: ${profile.phone}'),
              ],
            ),
          ),
        ),
        if (widget.onSignOut != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: Text(_signingOut ? 'Đang đăng xuất...' : 'Đăng xuất'),
          ),
        ],
      ],
    );
  }
}
