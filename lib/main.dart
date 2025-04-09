import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'viewmodels/estoque_viewmodel.dart';
import 'viewmodels/producao_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url:
        'https://yemuwbrmonyowwvavsrd.supabase.co', // Substitua pela sua URL do Supabase
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InllbXV3YnJtb255b3d3dmF2c3JkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQxMzg1MzYsImV4cCI6MjA1OTcxNDUzNn0.Ev2P7ZphWh7sw4mryBrDs0mHuWxJEMdRhzfVI1Uu024', // Substitua pela sua chave anon
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EstoqueViewModel()),
        ChangeNotifierProvider(create: (_) => ProducaoViewModel()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CooperNeo',
        theme: AppTheme.lightTheme,
        home: AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return const DashboardScreen();
    } else {
      return const LoginScreen();
    }
  }
}
