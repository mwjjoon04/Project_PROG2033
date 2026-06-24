import 'dart:async';
import 'package:flutter/material.dart';

class SignLanguageTranslator extends StatefulWidget {
  final String text;       // 课程英文翻译文本
  final bool isPlaying;    // 是否激活手语
  final VoidCallback? onComplete; // 播放结束后的回调

  const SignLanguageTranslator({
    Key? key,
    required this.text,
    this.isPlaying = false,
    this.onComplete,
  }) : super(key: key);

  @override
  _SignLanguageTranslatorState createState() => _SignLanguageTranslatorState();
}

class _SignLanguageTranslatorState extends State<SignLanguageTranslator> {
  Timer? _timer;
  
  // 明天报告固定展示的高频手语整词字典
  final Map<String, String> _fixedWordDictionary = {
    "hello": "assets/sign_language/words/hello_word.png",
    "thank you": "assets/sign_language/words/thank_you_word.png",
  };

  bool _isWholeWord = false;
  String _displayAssetPath = 'assets/sign_language/space.png';
  String _statusText = '';

  List<String> _letters = [];
  int _currentLetterIndex = 0;

  @override
  void initState() {
    super.initState();
    _processText();
    if (widget.isPlaying) {
      _startTranslation();
    }
  }

  @override
  void didUpdateWidget(SignLanguageTranslator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.isPlaying != widget.isPlaying) {
      _processText();
      if (widget.isPlaying) {
        _startTranslation();
      } else {
        _timer?.cancel();
      }
    }
  }

  void _processText() {
    // 过滤掉标点符号，转换为纯小写格式进行匹配
    String cleanText = widget.text.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
    
    if (_fixedWordDictionary.containsKey(cleanText)) {
      _isWholeWord = true;
      _displayAssetPath = _fixedWordDictionary[cleanText]!;
      _statusText = "Nezuko 正在使用真实手语 (整词表达)";
    } else {
      _isWholeWord = false;
      _letters = cleanText.replaceAll(' ', '').split('');
      _currentLetterIndex = 0;
      _statusText = "教学释义转译中 (指拼字母模式)";
      if (_letters.isNotEmpty) {
        _updateLetterAsset(_letters[_currentLetterIndex]);
      }
    }
  }

  void _updateLetterAsset(String letter) {
    if (RegExp(r'[a-z]').hasMatch(letter)) {
      _displayAssetPath = 'assets/sign_language/$letter.png';
    } else {
      _displayAssetPath = 'assets/sign_language/space.png';
    }
  }

  void _startTranslation() {
    _timer?.cancel();
    
    if (_isWholeWord) {
      _timer = Timer(const Duration(milliseconds: 2500), () {
        if (widget.onComplete != null) widget.onComplete!();
      });
    } else {
      if (_letters.isEmpty) {
        if (widget.onComplete != null) widget.onComplete!();
        return;
      }
      _timer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
        if (_currentLetterIndex < _letters.length - 1) {
          setState(() {
            _currentLetterIndex++;
            _updateLetterAsset(_letters[_currentLetterIndex]);
          });
        } else {
          _timer?.cancel();
          if (widget.onComplete != null) widget.onComplete!();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.pink.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.pink.shade200, width: 3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: widget.isPlaying
                ? Image.asset(
                    _displayAssetPath,
                    fit: BoxFit.contain,
                    // 🌟 防翻车占位：如果没有物理图片资产，直接完美显示当前拼写的文本大字
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          _isWholeWord ? widget.text : _letters[_currentLetterIndex].toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: _isWholeWord ? 18 : 44,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink.shade400,
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Icon(Icons.back_hand_rounded, size: 54, color: Colors.pink.shade200),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        if (widget.isPlaying)
          Text(
            _statusText,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.pink),
          ),
      ],
    );
  }
}