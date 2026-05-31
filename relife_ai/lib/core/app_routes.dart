import 'package:go_router/go_router.dart';

import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/store/store_main_screen.dart';
import '../screens/store/product_detail_screen.dart';
import '../screens/store/add_product_screen.dart';
import '../screens/ngo/ngo_main_screen.dart';
import '../providers/auth_provider.dart';

import '../screens/store/edit_profile_screen.dart';
import '../screens/store/help_support_screen.dart';
import '../screens/ngo/ngo_edit_profile_screen.dart';

class AppRouter {
// ... Skip standard stuff, put the changes inline in the routes block

  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isLoading = authProvider.isLoading;
        final isLoggedIn = authProvider.isLoggedIn;
        final profile = authProvider.profile;

        if (isLoading) return '/'; // Stay on splash while loading

        final isAuthRoute = state.uri.path == '/login' || state.uri.path == '/signup';
        
        if (!isLoggedIn) {
          return isAuthRoute ? null : '/login';
        }

        // If logged in but no profile (no role selected)
        if (profile == null) {
          return '/role_selection';
        } else if (profile.role.isEmpty) {
          return '/role_selection';
        }

        // Redirect based on role
        if (state.uri.path == '/' || isAuthRoute || state.uri.path == '/role_selection') {
          return profile.role == 'store_owner' ? '/store' : '/ngo';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: '/role_selection',
          builder: (context, state) => const RoleSelectionScreen(),
        ),
        GoRoute(
          path: '/store',
          builder: (context, state) => const StoreMainScreen(),
        ),
        GoRoute(
          path: '/product/add',
          builder: (context, state) => const AddProductScreen(),
        ),
        GoRoute(
          path: '/store/profile/edit',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/store/support',
          builder: (context, state) => const HelpSupportScreen(),
        ),
        GoRoute(
          path: '/product/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ProductDetailScreen(productId: id);
          },
        ),
        GoRoute(
          path: '/ngo/profile/edit',
          builder: (context, state) => const NGOEditProfileScreen(),
        ),
        GoRoute(
          path: '/ngo/support',
          builder: (context, state) => const HelpSupportScreen(),
        ),
        GoRoute(
          path: '/ngo',
          builder: (context, state) => const NGOMainScreen(),
        ),
      ],
    );
  }
}

