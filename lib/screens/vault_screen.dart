import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 导入数据库
import 'package:url_launcher/url_launcher.dart'; // 用于在浏览器打开链接
import 'profile_screen.dart';

// 1. 帮你升级成了 StatefulWidget！
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  // 2. 加上了头像变量
  String? _userAvatar; 

  // 3. 加上了初始化读取功能
  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
  }

  void _loadUserAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && doc.exists && doc.data() != null) {
        setState(() {
          _userAvatar = doc.data()!['avatarUrl'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前正在登录的用户
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Images'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 4. 替换成了全新的动态动漫头像！
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ).then((_) => _loadUserAvatar()); // 返回时自动刷新
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.deepPurpleAccent,
                backgroundImage: _userAvatar != null && _userAvatar!.isNotEmpty
                    ? AssetImage(_userAvatar!)
                    : null,
                child: (_userAvatar == null || _userAvatar!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
            ),
          ),
        ],
      ),
      // 如果没登录，显示提示（安全起见）
      body: user == null
          ? const Center(child: Text("Please login first.", style: TextStyle(color: Colors.white)))
          // StreamBuilder：实时监听数据库的通道
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_images') // 查找刚才创建的那个“大文件夹”
                  .where('userId', isEqualTo: user.uid) // 核心：只过滤出当前用户的图片！
                  .snapshots(),
              builder: (context, snapshot) {
                // 1. 正在连接云端时的加载圈
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
                }

                // 2. 如果没有任何数据
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Your cloud vault is empty. Go create something!',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                // 3. 成功获取数据！把它变成一个列表
                final images = snapshot.data!.docs;

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final doc = images[index]; // 获取整个文档对象（为了拿到 ID）
                    final data = doc.data() as Map<String, dynamic>;
                    final imageUrl = data['imageUrl'] ?? '';

                    return InkWell(
                      // 点击图片弹出选项菜单
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.grey[900],
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (context) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.open_in_browser, color: Colors.blueAccent),
                                  title: const Text('Open in Browser to Save', style: TextStyle(color: Colors.white)),
                                  onTap: () async {
                                    Navigator.pop(context); // 关掉菜单
                                    final Uri url = Uri.parse(imageUrl);
                                    if (!await launchUrl(url)) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch browser')));
                                    }
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.delete, color: Colors.redAccent),
                                  title: const Text('Delete from Cloud', style: TextStyle(color: Colors.redAccent)),
                                  onTap: () async {
                                    Navigator.pop(context); // 关掉菜单
                                    await FirebaseFirestore.instance.collection('user_images').doc(doc.id).delete();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image deleted!')));
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      // 原本的图片显示逻辑包裹在 InkWell 里面
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}