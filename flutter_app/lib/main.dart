import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/lesson_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/profile_screen.dart';
import 'screens/dashboard_screen.dart';
import 'providers/auth_provider.dart';
import 'services/lesson_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await AuthService.initialize();

  runApp(
    ProviderScope(
      child: TranslatorApp(),
    ),
  );
}

class TranslatorApp extends ConsumerWidget {
  const TranslatorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoApp(
      title: 'Lebanese Arabic Translator',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGuard(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Auth guard that redirects to login or dashboard based on auth state
class AuthGuard extends ConsumerWidget {
  const AuthGuard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return switch (authState.status) {
      AuthStatus.loading => const Center(
          child: CupertinoActivityIndicator(radius: 20),
        ),
      AuthStatus.authenticated => const DashboardScreen(),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.initial => const Center(
          child: CupertinoActivityIndicator(radius: 20),
        ),
    };
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check API health on startup
    final healthCheck = ref.watch(apiHealthProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Translator Tool'),
      ),
      child: SafeArea(
        child: healthCheck.when(
          data: (isHealthy) => isHealthy
              ? _buildMainContent(context, ref)
              : _buildOfflineContent(context, ref),
          loading: () => _buildLoadingContent(context),
          error: (_, __) => _buildOfflineContent(context, ref),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, WidgetRef ref) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App icon/logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: CupertinoTheme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                CupertinoIcons.textformat_alt,
                size: 64,
                color: CupertinoTheme.of(context).primaryColor,
              ),
            ),

            const SizedBox(height: 32),

            // Welcome text
            Text(
              'Welcome to Translator Tool',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              'Practice Lebanese Arabic with dual language toggle',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            // Quick start options
            _buildQuickStartOptions(context, ref),

            const SizedBox(height: 32),

            // Features overview
            _buildFeaturesOverview(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartOptions(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Generate new lesson
        SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => const LessonScreen(),
                ),
              );
            },
            child: Text('Start Learning'),
          ),
        ),

        const SizedBox(height: 16),

        // Quick practice options
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                onPressed: () {
                  _navigateToLesson(context, 'coffee_chat', 'beginner');
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: CupertinoTheme.of(context).primaryColor,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.chat_bubble_2,
                        color: CupertinoTheme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Coffee Chat',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoTheme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CupertinoButton(
                onPressed: () {
                  _navigateToLesson(context, 'restaurant', 'intermediate');
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: CupertinoTheme.of(context).primaryColor,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.house,
                        color: CupertinoTheme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Restaurant',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoTheme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturesOverview(BuildContext context) {
    final features = [
      {
        'icon': CupertinoIcons.arrow_2_circlepath,
        'title': 'Dual Toggle',
        'description': 'Switch between English and Arabic instantly',
      },
      {
        'icon': CupertinoIcons.location_solid,
        'title': 'Position Memory',
        'description': 'Maintains your reading position during toggle',
      },
      {
        'icon': CupertinoIcons.speedometer,
        'title': 'Fast Performance',
        'description': 'Toggle latency under 200ms',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Features',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...features.map((feature) => _buildFeatureItem(
          context,
          feature['icon'] as IconData,
          feature['title'] as String,
          feature['description'] as String,
        )),
      ],
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CupertinoTheme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: CupertinoTheme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingContent(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(radius: 20),
          SizedBox(height: 16),
          Text('Connecting to server...'),
        ],
      ),
    );
  }

  Widget _buildOfflineContent(BuildContext context, WidgetRef ref) {
    final cachedLessons = ref.watch(lessonCacheProvider);

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.wifi_slash,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            Text(
              'Offline Mode',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cannot connect to server. You can still access cached lessons.',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (cachedLessons.isNotEmpty) ...[
              Text(
                '${cachedLessons.length} cached lessons available',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  color: CupertinoColors.systemGreen,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (context) => const LessonScreen(),
                    ),
                  );
                },
                child: Text('View Cached Lessons'),
              ),
            ] else ...[
              Text(
                'No cached lessons available',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
            const SizedBox(height: 16),
            CupertinoButton(
              onPressed: () {
                ref.invalidate(apiHealthProvider);
              },
              child: Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLesson(BuildContext context, String topic, String level) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => LessonScreen(
          storyRequest: StoryRequest(
            topic: topic,
            level: level,
          ),
        ),
      ),
    );
  }
}