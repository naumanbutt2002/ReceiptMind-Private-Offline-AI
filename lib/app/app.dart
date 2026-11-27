import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/settings_providers.dart';
import '../l10n/generated/app_localizations.dart';
import 'router.dart';
import 'startup.dart';
import 'theme.dart';

class ReceiptMindApp extends ConsumerStatefulWidget {
  const ReceiptMindApp({super.key});

  @override
  ConsumerState<ReceiptMindApp> createState() => _ReceiptMindAppState();
}

class _ReceiptMindAppState extends ConsumerState<ReceiptMindApp> {
  @override
  void initState() {
    super.initState();
    // Orphan images and scanner temp files are cleaned after the first frame,
    // so start-up isn't slowed down.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(startupHousekeepingProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(
        settingsControllerProvider.select((s) => s.themeMode),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
