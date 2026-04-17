import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  // 默认是夜间模式 (因为你的 App 原本就是深色调的)
  bool _isDarkMode = true; 
  
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  // 切换主题的函数
  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners(); // 通知全 App 更新 UI
    
    // 保存用户的选择到本地
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _isDarkMode);
  }

  // 加载保存的主题
  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    notifyListeners();
  }
}