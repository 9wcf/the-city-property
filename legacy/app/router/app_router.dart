import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:the_city_property/features/auth/presentation/screens/login_screen.dart';
import 'package:the_city_property/features/tenants/presentation/screens/add_tenant_screen.dart';
import 'package:the_city_property/features/owner_dashboard/presentation/screens/owner_dashboard_screen.dart';
import 'package:the_city_property/features/manager_dashboard/presentation/screens/manager_dashboard_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseProvider);
  
  return GoRouter(
    initialLocation: '/owner',
    debugLogDiagnostics: true,
    routes: [
      GoRoute(path: '/login', name: 'login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/owner', name: 'owner', builder: (_, __) => const OwnerDashboardScreen()),
      GoRoute(path: '/manager', name: 'manager', builder: (_, __) => const ManagerDashboardScreen()),
      GoRoute(path: '/add-tenant', name: 'add-tenant', builder: (_, __) => const AddTenantScreen()),
    ],
  );
});

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
