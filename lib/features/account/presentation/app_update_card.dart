import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/update/app_update_service.dart';

class AppUpdateCard extends StatefulWidget {
  const AppUpdateCard({
    super.key,
    this.updateService,
  });

  final AppUpdateService? updateService;

  @override
  State<AppUpdateCard> createState() => _AppUpdateCardState();
}

class _AppUpdateCardState extends State<AppUpdateCard> {
  late final AppUpdateService _updates;
  late final bool _ownsUpdateService;

  String _currentVersion = '...';
  AppUpdateCheck? _check;
  String? _message;
  bool? _directInstallSupported;
  bool _checking = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _ownsUpdateService = widget.updateService == null;
    _updates = widget.updateService ?? AppUpdateService();
    _loadCurrentVersion();
  }

  @override
  void dispose() {
    if (_ownsUpdateService) {
      _updates.close();
    }
    super.dispose();
  }

  Future<void> _loadCurrentVersion() async {
    var version = 'Không xác định';
    var directInstallSupported = false;

    try {
      final current = await _updates.currentVersion();
      if (current.trim().isNotEmpty) {
        version = current.trim();
      }
    } on AppUpdateFailure {
      version = 'Không xác định';
    }

    try {
      directInstallSupported = await _updates.supportsDirectInstall();
    } on AppUpdateFailure {
      directInstallSupported = false;
    }

    if (!mounted) return;
    setState(() {
      _currentVersion = version;
      _directInstallSupported = directInstallSupported;
    });
  }

  Future<void> _checkUpdate() async {
    if (_directInstallSupported != true || _checking || _installing) return;

    setState(() {
      _checking = true;
      _message = null;
    });

    try {
      final check = await _updates.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _check = check;
        _currentVersion = check.currentVersion;
        _message = check.updateAvailable
            ? 'Có bản ${check.release.version} mới.'
            : 'Ứng dụng đang ở bản mới nhất.';
      });
    } on AppUpdateFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _check = null;
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _installUpdate() async {
    final release = _check?.release;
    if (_directInstallSupported != true || release == null || _installing) {
      return;
    }

    setState(() {
      _installing = true;
      _message = null;
    });

    try {
      final allowed = await _updates.canInstallPackages();
      if (!allowed) {
        await _updates.openInstallPermissionSettings();
        if (!mounted) return;
        setState(() {
          _message =
              'Bật “Cho phép từ nguồn này”, quay lại Hưng Phát Đặt Hàng rồi bấm Cài bản cập nhật.';
        });
        return;
      }

      await _updates.install(release);
      if (!mounted) return;
      setState(() {
        _message =
            'Đã tải và kiểm tra gói cập nhật. Android đang mở màn hình cài đặt.';
      });
    } on AppUpdateFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _installing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = _check?.release;
    final updateAvailable = _check?.updateAvailable == true;
    final directInstallSupported = _directInstallSupported == true;

    return Card(
      key: const Key('app-update-card'),
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
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.brandSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.system_update_alt_rounded,
                    color: AppTheme.brandDark,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cập nhật ứng dụng',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Kiểm tra và cài phiên bản Hưng Phát Đặt Hàng mới nhất.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _UpdateInfoRow(
              label: 'Bản đang dùng',
              value: _currentVersion,
            ),
            if (_directInstallSupported == false) ...[
              const Divider(height: 24),
              const Text(
                'Thiết bị này không hỗ trợ cập nhật trực tiếp trong ứng dụng.',
                key: Key('update-unsupported-message'),
                style: TextStyle(color: AppTheme.muted),
              ),
            ],
            if (directInstallSupported && release != null) ...[
              const Divider(height: 24),
              _UpdateInfoRow(
                label: 'Bản phát hành',
                value: release.version,
              ),
              if (release.size > 0) ...[
                const Divider(height: 24),
                _UpdateInfoRow(
                  label: 'Dung lượng',
                  value: _formatBytes(release.size),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  release.releaseNotes,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            if ((_message ?? '').isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _message!,
                key: const Key('update-message'),
                style: TextStyle(
                  color: updateAvailable
                      ? AppTheme.brandDark
                      : AppTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_directInstallSupported == null) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (directInstallSupported) ...[
              const SizedBox(height: 14),
              updateAvailable
                  ? FilledButton.icon(
                      key: const Key('install-update-button'),
                      onPressed: _installing || _checking
                          ? null
                          : _installUpdate,
                      icon: _installing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_for_offline_outlined),
                      label: Text(
                        _installing
                            ? 'Đang tải bản cập nhật...'
                            : 'Tải và cài bản ${release!.version}',
                      ),
                    )
                  : OutlinedButton.icon(
                      key: const Key('check-update-button'),
                      onPressed: _checking || _installing
                          ? null
                          : _checkUpdate,
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(
                        _checking
                            ? 'Đang kiểm tra...'
                            : 'Kiểm tra cập nhật',
                      ),
                    ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    color: AppTheme.brandDark,
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Nếu Android yêu cầu quyền cài ứng dụng từ nguồn này, hãy bật quyền cho Hưng Phát Đặt Hàng rồi quay lại bấm cài lần nữa.',
                      key: Key('update-install-guide'),
                      style: TextStyle(
                        color: AppTheme.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: AppTheme.brandDark,
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Ứng dụng kiểm tra gói cập nhật trước khi mở trình cài đặt Android.',
                      style: TextStyle(
                        color: AppTheme.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpdateInfoRow extends StatelessWidget {
  const _UpdateInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}
