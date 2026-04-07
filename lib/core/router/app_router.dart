import 'package:go_router/go_router.dart';
import '../../presentation/auth/auth_gate.dart';
import '../../presentation/auth/login_screen.dart';
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
import 'route_names.dart';

/// Centralized GoRouter configuration for DocsVault AI
final appRouter = GoRouter(
  initialLocation: RouteNames.authGate,
  routes: [
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
    GoRoute(
      path: RouteNames.scan,
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: RouteNames.scanResult,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ScanResultScreen(scanData: extra);
      },
    ),
    GoRoute(
      path: RouteNames.search,
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: RouteNames.assistant,
      builder: (context, state) => const AssistantScreen(),
    ),
    GoRoute(
      path: RouteNames.eligibility,
      builder: (context, state) => const EligibilityScreen(),
    ),
    GoRoute(
      path: '${RouteNames.documentViewer}/:docId',
      builder: (context, state) => DocumentViewerScreen(
        docId: state.pathParameters['docId']!,
      ),
    ),
    GoRoute(
      path: RouteNames.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
