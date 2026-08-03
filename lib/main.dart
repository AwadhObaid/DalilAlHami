import 'package:flutter/material.dart';

import 'app/hami_guide_app.dart';
import 'core/services/auth_session_store.dart';
import 'core/services/supabase_service.dart';

export 'app/hami_guide_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initializeIfConfigured();
  await AuthSessionStore.instance.initialize();

  runApp(const HamiGuideApp());
}
