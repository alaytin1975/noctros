import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/permission_entities.dart';
import '../providers/permission_providers.dart';

class PermissionPromptSheet extends ConsumerWidget {
  const PermissionPromptSheet({
    super.key,
    required this.permission,
  });

  final NoctrosPermission permission;

  static Future<void> show(
    BuildContext context, {
    required NoctrosPermission permission,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PermissionPromptSheet(permission: permission),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snapshot = ref.watch(permissionsControllerProvider)[permission];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${permissionLabel(permission)} access needed',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              permissionRationale(permission),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (snapshot?.requiresSettings ?? false) ...[
              Text(
                'Permission was permanently denied. Open system settings to enable it.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(permissionsControllerProvider.notifier)
                        .openSettings();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await ref
                        .read(permissionsControllerProvider.notifier)
                        .request(permission);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Allow'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PermissionTile extends ConsumerWidget {
  const PermissionTile({
    super.key,
    required this.permission,
  });

  final NoctrosPermission permission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(permissionsControllerProvider)[permission];
    final isGranted = snapshot?.isGranted ?? false;
    final requiresSettings = snapshot?.requiresSettings ?? false;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(permissionLabel(permission)),
      subtitle: Text(
        isGranted
            ? 'Granted'
            : requiresSettings
                ? 'Blocked — open settings'
                : 'Not granted',
      ),
      trailing: isGranted
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : const Icon(Icons.chevron_right),
      onTap: isGranted
          ? null
          : () => PermissionPromptSheet.show(context, permission: permission),
    );
  }
}
