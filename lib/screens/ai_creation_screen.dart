import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; 
import '../providers/vault_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart'; 

class AICreationScreen extends StatefulWidget {
  const AICreationScreen({super.key});

  @override
  State<AICreationScreen> createState() => _AICreationScreenState();
}

class _AICreationScreenState extends State<AICreationScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ImagePicker _picker = ImagePicker(); // 图片选择器实例

  String? _userAvatar; 

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
  }

  void _loadUserAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      // 加上 if (mounted) 保护，防止报错
      if (mounted && doc.exists && doc.data() != null) {
        setState(() {
          _userAvatar = doc.data()!['avatarUrl'];
        });
      }
    }
  }
  
  bool _isLoading = false; 
  String? _generatedImageUrl; 
  String? _errorMessage; 
  File? _uploadedImage; // 保存用户上传的参考图
  
  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  // 新增功能：从相册选择图片
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _uploadedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to pick image.";
      });
    }
  }

  // 移除选择的图片
  void _clearUploadedImage() {
    setState(() {
      _uploadedImage = null;
    });
  }

  // 连接真实的 AI 图像生成 API
  Future<void> _generateImage() async {
    if (_promptController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Please enter a prompt first.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedImageUrl = null;
    });

    try {
      // 构建真实的 API URL
      // 我们在用户的提示词后面隐式加入 'anime style' 以确保生成动漫风格
      String finalPrompt = "${_promptController.text}, high quality anime style, masterpiece";
      
      // 使用 Pollinations.ai 的真实绘图 API (基于 Stable Diffusion)
      // 使用 Uri.encodeComponent 确保文本能够安全地在网址中传输
      String encodedPrompt = Uri.encodeComponent(finalPrompt);
      
      // 我们加上一个随机数(seed)来确保每次生成的图片都不一样
      int randomSeed = DateTime.now().millisecondsSinceEpoch;
      String realApiUrl = 'https://image.pollinations.ai/prompt/$encodedPrompt?seed=$randomSeed&width=512&height=512&nologo=true'; // 这里替换成真正的 AI 图像生成 API URL，附带 prompt 参数

      // 模拟网络等待时间（因为图片生成需要几秒钟）
      await Future.delayed(const Duration(seconds: 3));

      setState(() {
        _generatedImageUrl = realApiUrl;
        _isLoading = false;
      });

      try {
        final user = FirebaseAuth.instance.currentUser; // 获取当前登录的用户
        if (user != null) {
          // 在数据库中创建一个叫做 'user_images' 的集合（像是一个大文件夹）
          await FirebaseFirestore.instance.collection('user_images').add({
            'userId': user.uid, // 绑定用户的专属 ID
            'imageUrl': realApiUrl, // 保存生成的图片网址
            'prompt': _promptController.text, // 保存对应的提示词
            'timestamp': FieldValue.serverTimestamp(), // 记录生成的时间
          });
        }
      } catch (e) {
        // 如果保存失败，可以在终端看到报错信息
        debugPrint("Error saving to cloud: $e"); 
      }
      
      
      if (mounted) {
        Provider.of<VaultProvider>(context, listen: false).addImageToVault(realApiUrl);
      }

    } catch (error) {
      setState(() {
        _errorMessage = "Failed to generate image. Please try again.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, 
      appBar: AppBar(
        title: const Text('Otaku Universe'), // 标题移到了这里
        backgroundColor: Colors.transparent,
        elevation: 0,

        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ).then((_) => _loadUserAvatar()); // 从 Profile 返回后刷新头像
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // 如果用户上传了图片，显示预览图
          if (_uploadedImage != null)
            Stack(
              children: [
                Container(
                  height: 100,
                  width: 100,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepPurple, width: 2),
                    image: DecorationImage(
                      image: FileImage(_uploadedImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // 关闭按钮
                Positioned(
                  top: -10,
                  right: -10,
                  child: IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    onPressed: _clearUploadedImage,
                  ),
                ),
              ],
            ),

          TextField(
            controller: _promptController,
            decoration: InputDecoration(
              labelText: 'Enter your prompt (e.g., Cyberpunk Samurai)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              prefixIcon: const Icon(Icons.brush),
              // 新增：输入框里的上传图片按钮
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_photo_alternate, color: Colors.deepPurpleAccent),
                onPressed: _pickImage,
                tooltip: 'Upload reference image',
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _generateImage, 
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Generate AI Image', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepPurple, width: 2),
              ),
              child: _buildResultArea(),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildResultArea() {
    if (_isLoading) {
      return const Center(child: Text('Generating AI magic...', style: TextStyle(color: Colors.deepPurpleAccent)));
    } else if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)));
    } else if (_generatedImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          _generatedImageUrl!, 
          
          // --- THE MAGIC DISGUISE ---
          // This tells the AI server: "I am a normal Google Chrome browser on Windows, please let me in!"
          headers: const {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
          },
          // --------------------------

          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.grey, size: 50),
                  SizedBox(height: 8),
                  Text('Network issue: Could not load image.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          },
        ),
      );
    } else {
      return const Center(
        child: Text(
          'Your generated artwork will appear here',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
  }
}