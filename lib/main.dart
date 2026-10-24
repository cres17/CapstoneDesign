import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_auth.dart';
import 'screens/splash/splash_screen.dart';
import 'constants/app_theme.dart';
import 'screens/main/main_screen.dart';
import 'screens/analysis/analysis_screen.dart';
import 'package:provider/provider.dart';
import 'providers/analysis_prediction_provider.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 외부 API 키는 서버에만 둔다. 저장된 로그인 토큰만 미리 읽어 둔다
  await ApiAuth.load();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AnalysisPredictionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '다온',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/main': (context) => const MainScreen(),
        '/analysis': (context) => AnalysisScreen(),
      },
      navigatorObservers: [routeObserver],
    );
  }
}
