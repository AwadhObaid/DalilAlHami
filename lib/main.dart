import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/hami_guide_app.dart';
import 'core/services/auth_session_store.dart';
import 'core/services/background_sync_service.dart';
import 'core/services/automatic_sync_coordinator.dart';
import 'core/services/firebase_push_notification_service.dart';
import 'core/services/supabase_service.dart';
import 'firebase_options.dart';

export 'app/hami_guide_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await SupabaseService.initializeIfConfigured();
  await AuthSessionStore.instance.initialize();
  await BackgroundSyncService.instance.initialize();
  await AutomaticSyncCoordinator.instance.initialize();
  await FirebasePushNotificationService.instance.initialize();

  runApp(const HamiGuideApp());
  FirebasePushNotificationService.instance.schedulePostLaunchRegistration();
}
