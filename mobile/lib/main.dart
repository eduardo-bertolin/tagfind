import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/config/constants.dart';
import 'src/config/theme.dart';
import 'src/views/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: TagFindApp()));
}

class TagFindApp extends StatelessWidget {
  const TagFindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TagFind',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomePage(),
    );
  }
}
