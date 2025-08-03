import 'package:GitSync/api/manager/premium_manager.dart';
import 'package:GitSync/ui/dialog/onboarding_controller.dart';

import '../api/manager/repo_manager.dart';
import '../api/manager/settings_manager.dart';
import '../gitsync_service.dart';

// TODO: Must be false for release
const demo = false;

final repoManager = RepoManager();
final uiSettingsManager = SettingsManager();
final gitSyncService = GitsyncService();
final premiumManager = PremiumManager();

OnboardingController? onboardingController;
