import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'providers/vault_provider.dart'; 
import 'screens/ai_creation_screen.dart';
import 'screens/ai_chat_screen.dart'; 
import 'screens/tutor_screen.dart'; // 🌟 新增：导入你的学习页面文件！
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/discover_screen.dart';
import 'screens/login_screen.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Activate the SSL bypass
  HttpOverrides.global = MyHttpOverrides(); 

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VaultProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()), 
      ],
      child: const OtakuUniverseApp(),
    ),
  );
}

class OtakuUniverseApp extends StatelessWidget {
  const OtakuUniverseApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 监听主题变化
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Otaku Universe',
      debugShowCheckedModeBanner: false,
      // 定义白天模式
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      // 定义夜间模式
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212), // 护眼深色
      ),
      // 核心开关：根据 Provider 决定用白天还是黑夜
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      home: const LoginScreen(), 
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // 🌟 修改点 1：把 TutorScreen（学习页面）加进屏幕列表里
  final List<Widget> _screens = [
    const AICreationScreen(),
    const AIChatScreen(),
    const TutorScreen(),    // 🌟 这是你的学习页面
    const DiscoverScreen(), // 这是你的小游戏页面
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed, // 确保有 4 个按钮时不会出现奇怪的缩放动画
        selectedItemColor: Colors.purpleAccent,
        unselectedItemColor: Colors.grey,
        // 🌟 修改点 2：底部导航栏加回第 4 个按钮 "Learn"
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Image'), 
          BottomNavigationBarItem(icon: Icon(Icons.art_track), label: 'Chat'),   
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Learn'), // 🌟 学习按钮 (使用了博士帽图标)
          BottomNavigationBarItem(icon: Icon(Icons.videogame_asset), label: 'Game'), // 顺便帮你把游戏图标换成了手柄，更直观！
        ],
      ),
    );
  }
}

// This class bypasses the strict SSL certificate checks on Android Emulators
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}