import 'package:go_router/go_router.dart';
import '../../presentation/auth/auth_gate.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/pin_setup_screen.dart';
import '../../presentation/auth/pin_login_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/home/timeline_screen.dart';
import '../../presentation/scan/scan_screen.dart';
import '../../presentation/scan/scan_result_screen.dart';
import '../../presentation/search/search_screen.dart';
import '../../presentation/assistant/assistant_screen.dart';
import '../../presentation/assistant/eligibility_screen.dart';
import '../../presentation/document_viewer/document_viewer_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/common_widgets/app_shell.dart';
import 'route_names.dart';

/// Centralized GoRouter configuration for DocVault AI
final appRouter = GoRouter(
  initialLocation: RouteNames.authGate,
  routes: [
    // ── Auth / Onboarding routes (no shell) ──────────────────────────────
    GoRoute(
      path: RouteNames.authGate,
      builder: (context, state) => const AuthGate(),
    ),
    GoRoute(
      path: RouteNames.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: RouteNames.pinSetup,
      builder: (context, state) => const PinSetupScreen(),
    ),
    GoRoute(
      path: RouteNames.pinLogin,
      builder: (context, state) => const PinLoginScreen(),
    ),

    // ── Fullscreen routes (no nav bar) ────────────────────────────────────
    GoRoute(
      path: RouteNames.scan,
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: RouteNames.scanResult,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ScanResultScreen(scanData: extra);
      },
    ),
    GoRoute(
      path: '${RouteNames.documentViewer}/:docId',
      builder: (context, state) => DocumentViewerScreen(
        docId: state.pathParameters['docId']!,
      ),
    ),
    GoRoute(
      path: RouteNames.eligibility,
      builder: (context, state) => const EligibilityScreen(),
    ),

    // ── Main app shell with persistent bottom navigation ──────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        // Branch 0 — Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.home,
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'timeline',
                  name: 'timeline',
                  builder: (context, state) => const TimelineScreen(),
                ),
              ],
            ),
          ],
        ),

        // Branch 1 — Search
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.search,
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),

        // Branch 2 — AI Assistant
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.assistant,
              builder: (context, state) => const AssistantScreen(),
            ),
          ],
        ),

        // Branch 3 — Settings
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteNames.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
