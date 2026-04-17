import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final List<String> _builtInAvatars = [
  'assets/27431.png',
  'assets/OIP.webp',
];
  
  void _showAvatarPicker() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      height: 300,
      child: Column(
        children: [
          const Text("Select Anime Avatar", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // 一行显示4个
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _builtInAvatars.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _avatarUrl = _builtInAvatars[index]; // 将选中的路径存入原本的 avatarUrl 变量
                    });
                    Navigator.pop(context);
                  },
                  child: CircleAvatar(
                    backgroundImage: AssetImage(_builtInAvatars[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  String _selectedCharacter = "Tanjiro Kamado";
  final List<String> _characters = ["Tanjiro Kamado", "Nezuko Kamado", "Monkey D. Luffy"];
  
  String? _avatarUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // 从数据库读取现有的用户资料
  Future<void> _loadUserData() async {
    if (user == null) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _dobController.text = data['dob'] ?? '';
          _avatarUrl = data['avatarUrl'];
          if (_characters.contains(data['favoriteCharacter'])) {
            _selectedCharacter = data['favoriteCharacter'];
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }


  // 选择出生日期
  Future<void> _selectDOB() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.deepPurpleAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // 保存资料到 Firebase (包括上传图片到 Storage)
  // 修改后的保存逻辑（简化版）
Future<void> _saveProfile() async {
  if (user == null) return;
  setState(() { _isLoading = true; });

  try {
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'username': _usernameController.text.trim(),
      'dob': _dobController.text.trim(),
      'favoriteCharacter': _selectedCharacter,
      'avatarUrl': _avatarUrl, // 存入的是 'assets/images/avatar1.png' 这种路径
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
  } finally {
    setState(() { _isLoading = false; });
  }
}

  // 退出登录
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false, // 清除所有页面栈，防止按返回键又回到主页
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 目前先写死黑色，第二阶段做主题切换时再改
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.deepPurple[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 头像区域
                GestureDetector(
                  onTap: _showAvatarPicker,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[800],
                          // 核心修改：只判断 _avatarUrl 是否为空
                          backgroundImage: _avatarUrl != null 
                              ? AssetImage(_avatarUrl!) as ImageProvider 
                              : null,
                          child: _avatarUrl == null
                              ? const Icon(Icons.person, size: 60, color: Colors.white54)
                              : null,
                        ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.deepPurpleAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // 用户名输入框
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.deepPurpleAccent),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // 出生日期选择框 (只读，点击触发日历)
                TextField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: _selectDOB,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.deepPurpleAccent),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // 最喜欢的角色下拉框
                DropdownButtonFormField<String>(
                  value: _selectedCharacter,
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Favorite Character',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.star_border, color: Colors.deepPurpleAccent),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                  items: _characters.map((String char) {
                    return DropdownMenuItem<String>(value: char, child: Text(char));
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() { _selectedCharacter = newValue!; });
                  },
                ),
                const SizedBox(height: 30),

                // 保存按钮
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: _saveProfile,
                    child: const Text('Save Profile', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 40),

                // 退出登录按钮 (移到了这里)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                ),
              ],
            ),
          ),
    );
  }
}