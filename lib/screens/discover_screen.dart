import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final PageController _pageController = PageController();
   // 你的类名可能叫别的
  // 1. 声明头像变量
  String? _userAvatar; 

  // 2. 页面一打开就去读取头像
  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
  }

  // 3. 去云端抓取头像路径的函数
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
  
  // ... 下面是你原本的代码 (比如 @override Widget build)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
     
      appBar: AppBar(
        title: const Text('Mini Game'),
        backgroundColor: Colors.transparent,
        elevation: 0,
       actions: [
          // 动态显示选中的动漫头像
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ).then((_) => _loadUserAvatar()); // 重点：从个人主页返回时自动刷新头像！
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
     
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            children: const [
              BountyClickerGame(), // Luffy
              BreathingTrainerGame(), // Tanjiro
              HeadpatSimulatorGame(), // Nezuko
            ],
          ),
          // Swipe Indicator
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Swipe to switch games ➔',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- GAME 1: LUFFY'S BOUNTY CLICKER ---
class BountyClickerGame extends StatefulWidget {
  const BountyClickerGame({super.key});

  @override
  State<BountyClickerGame> createState() => _BountyClickerGameState();
}

class _BountyClickerGameState extends State<BountyClickerGame> with SingleTickerProviderStateMixin {
  int _score = 0;
  String _rank = "Civilian";
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 100), vsync: this);
    _animation = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
  }

  void _increment() {
    _controller.forward().then((_) => _controller.reverse());
    setState(() {
      _score += 100000;
      if (_score >= 5000000) _rank = "Pirate King";
      else if (_score >= 1000000) _rank = "Warlord";
      else if (_score >= 100000) _rank = "Rookie";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Bounty Clicker', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        Text('Rank: $_rank', style: const TextStyle(color: Colors.amberAccent)),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: _increment,
          child: ScaleTransition(scale: _animation, child: const Text('👒', style: TextStyle(fontSize: 100))),
        ),
        const SizedBox(height: 40),
        Text('฿ ${_score.toString()}', style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }
}

// --- GAME 2: TANJIRO'S BREATHING TRAINER ---
class BreathingTrainerGame extends StatefulWidget {
  const BreathingTrainerGame({super.key});

  @override
  State<BreathingTrainerGame> createState() => _BreathingTrainerGameState();
}

class _BreathingTrainerGameState extends State<BreathingTrainerGame> with SingleTickerProviderStateMixin {
  double _breathLevel = 0.0;
  late AnimationController _breathingController;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Total Concentration', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        const Text('Tap to maintain breathing!', style: TextStyle(color: Colors.lightBlueAccent)),
        const SizedBox(height: 40),
        AnimatedBuilder(
          animation: _breathingController,
          builder: (context, child) {
            return Container(
              width: 150 + (50 * _breathingController.value),
              height: 150 + (50 * _breathingController.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue, width: 4),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 20)],
              ),
              child: const Center(child: Text('🌊', style: TextStyle(fontSize: 60))),
            );
          },
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => setState(() => _breathLevel += 0.1),
          child: const Text('INHALE'),
        ),
        const SizedBox(height: 20),
        Text('Breathing Power: ${(_breathLevel * 10).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  @override
  void dispose() { _breathingController.dispose(); super.dispose(); }
}

// --- GAME 3: NEZUKO'S HEADPAT SIMULATOR ---
class HeadpatSimulatorGame extends StatefulWidget {
  const HeadpatSimulatorGame({super.key});

  @override
  State<HeadpatSimulatorGame> createState() => _HeadpatSimulatorGameState();
}

class _HeadpatSimulatorGameState extends State<HeadpatSimulatorGame> {
  int _pats = 0;
  String _mood = "Sleepy";

  void _patNezuko() {
    setState(() {
      _pats++;
      if (_pats > 50) _mood = "Super Happy!";
      else if (_pats > 10) _mood = "Cozy";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Headpat Simulator', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        Text('Nezuko is: $_mood', style: const TextStyle(color: Colors.pinkAccent)),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: _patNezuko,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.pink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('🍱', style: TextStyle(fontSize: 100)), // Nezuko placeholder
          ),
        ),
        const SizedBox(height: 40),
        Text('Total Headpats: $_pats', style: const TextStyle(fontSize: 24, color: Colors.white)),
        const Text('💖 Tap to pat Nezuko 💖', style: TextStyle(color: Colors.white54)),
      ],
    );
  }
}