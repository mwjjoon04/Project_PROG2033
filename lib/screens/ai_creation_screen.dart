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
  final ImagePicker _picker = ImagePicker(); 

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
  File? _uploadedImage; 
  
  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

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

  void _clearUploadedImage() {
    setState(() {
      _uploadedImage = null;
    });
  }

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
      String cleanPrompt = _promptController.text.replaceAll('\n', ' ');
      String finalPrompt = "$cleanPrompt, high quality anime style, masterpiece";
      String encodedPrompt = Uri.encodeComponent(finalPrompt);
      int randomSeed = DateTime.now().millisecondsSinceEpoch;
      
      String realApiUrl = 'https://image.pollinations.ai/prompt/$encodedPrompt?seed=$randomSeed&width=512&height=512'; 

      setState(() {
        _generatedImageUrl = realApiUrl;
        _isLoading = false;
      });

      try {
        final user = FirebaseAuth.instance.currentUser; 
        if (user != null) {
          await FirebaseFirestore.instance.collection('user_images').add({
            'userId': user.uid, 
            'imageUrl': realApiUrl, 
            'prompt': _promptController.text, 
            'timestamp': FieldValue.serverTimestamp(), 
          });
        }
      } catch (e) {
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

  void _showHistoryBottomSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login first.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      isDismissible: true, 
      enableDrag: true,    
      backgroundColor: Colors.transparent, 
      builder: (BuildContext context) {
        return HistorySheetContent(userId: user.uid);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, 
      appBar: AppBar(
        title: const Text('Otaku Universe'), 
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ).then((_) => _loadUserAvatar()); 
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
            
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.history, color: Colors.deepPurpleAccent),
              label: const Text(
                'View History', 
                style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 16, fontWeight: FontWeight.bold)
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.deepPurpleAccent, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _showHistoryBottomSheet(context),
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
          headers: const {"User-Agent": "Mozilla/5.0"},
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
        child: Text('Your generated artwork will appear here', style: TextStyle(color: Colors.grey)),
      );
    }
  }
}

class HistorySheetContent extends StatefulWidget {
  final String userId;
  const HistorySheetContent({super.key, required this.userId});

  @override
  State<HistorySheetContent> createState() => _HistorySheetContentState();
}

class _HistorySheetContentState extends State<HistorySheetContent> {
  late Stream<QuerySnapshot> _historyStream;

  @override
  void initState() {
    super.initState();
    _historyStream = FirebaseFirestore.instance
        .collection('user_images')
        .where('userId', isEqualTo: widget.userId)
        .snapshots();
  }

  Future<void> _deleteImage(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('user_images').doc(docId).delete();
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }

  Future<void> _downloadImage(BuildContext context, String url) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading image to gallery... (Requires image_gallery_saver package)'),
        backgroundColor: Colors.deepPurpleAccent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pop(); 
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.6, 
        minChildSize: 0.4,     
        maxChildSize: 0.9,     
        builder: (BuildContext context, ScrollController scrollController) {
          return GestureDetector(
            onTap: () {}, 
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Text('My Generation History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const SizedBox(height: 10),
                  
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _historyStream, 
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                          ));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text('No images generated yet.', style: TextStyle(color: Colors.grey)));
                        }

                        final List<DocumentSnapshot> docs = snapshot.data!.docs.toList();
                        
                        docs.sort((a, b) {
                          final Map<String, dynamic>? aData = a.data() as Map<String, dynamic>?;
                          final Map<String, dynamic>? bData = b.data() as Map<String, dynamic>?;
                          
                          final Timestamp? aTime = aData?['timestamp'] as Timestamp?;
                          final Timestamp? bTime = bData?['timestamp'] as Timestamp?;
                          
                          if (aTime == null && bTime == null) return 0; 
                          if (aTime == null) return 1;
                          if (bTime == null) return -1;
                          return bTime.compareTo(aTime); 
                        });

                        return GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, 
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            var data = docs[index].data() as Map<String, dynamic>;
                            String docId = docs[index].id;
                            String imageUrl = data['imageUrl'] ?? '';
                            String prompt = data['prompt'] ?? 'No prompt';

                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrl, 
                                    fit: BoxFit.cover,
                                    // 🌟 终极核心优化：强行在解码阶段下采样压缩为 200x200，斩断显卡内存 ANR 卡死！
                                    cacheWidth: 200,
                                    cacheHeight: 200,
                                    headers: const {"User-Agent": "Mozilla/5.0"},
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(child: CircularProgressIndicator());
                                    },
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.download, color: Colors.white, size: 20),
                                          onPressed: () => _downloadImage(context, imageUrl),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                          onPressed: () => _deleteImage(docId),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  left: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      prompt, 
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                                )
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}