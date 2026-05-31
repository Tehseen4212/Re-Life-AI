import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../services/ai_assistant_service.dart';
import '../../../core/app_theme.dart';

class AIAssistantBottomSheet extends StatefulWidget {
  final String userId;
  const AIAssistantBottomSheet({super.key, required this.userId});

  @override
  State<AIAssistantBottomSheet> createState() => _AIAssistantBottomSheetState();
}

class _AIAssistantBottomSheetState extends State<AIAssistantBottomSheet> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Hi! How can I help with your store today?';
  String _assistantResponse = '';
  bool _isLoading = false;
  bool _isSpeaking = false;
  String _selectedLanguage = "en-US"; // Default to English
  final TextEditingController _textCtrl = TextEditingController();
  final List<Map<String, String>> _chatHistory = [];

  late AIAssistantService _aiService;
  late AnimationController _animCtrl;
  late FlutterTts _flutterTts;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    try {
      _aiService = AIAssistantService();
    } catch(e) {
      _assistantResponse = "Error: Missed API Key in .env file.";
    }
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    
    _flutterTts = FlutterTts();
    _setupTts();
  }

  Future<void> _setupTts() async {
    await _flutterTts.setLanguage(_selectedLanguage);
    await _flutterTts.setSpeechRate(0.5);
    _flutterTts.setStartHandler(() => setState(() => _isSpeaking = true));
    _flutterTts.setCompletionHandler(() => setState(() => _isSpeaking = false));
    _flutterTts.setErrorHandler((msg) => setState(() => _isSpeaking = false));
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _animCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _toggleLanguage() async {
    setState(() {
      _selectedLanguage = _selectedLanguage == "en-US" ? "hi-IN" : "en-US";
    });
    await _flutterTts.setLanguage(_selectedLanguage);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Language switched to ${_selectedLanguage == "en-US" ? "English" : "Hindi"}'), duration: const Duration(seconds: 1))
    );
  }

  void _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() => _isSpeaking = false);
  }

  void _listen() async {
    if (!_isListening) {
      var status = await Permission.microphone.status;
      if (status.isDenied) {
        status = await Permission.microphone.request();
      }
      
      if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Microphone Permission'),
              content: const Text('Microphone access is required for voice commands. Please enable it in settings.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                TextButton(onPressed: () => openAppSettings(), child: const Text('Settings')),
              ],
            ),
          );
        }
        return;
      }

      if (!status.isGranted) {
         setState(() => _text = 'Microphone permission denied.');
         return;
      }

      bool available = await _speech.initialize(
        onStatus: (val) {
           if (val == 'done' || val == 'notListening') {
              setState(() => _isListening = false);
              if (_text.isNotEmpty && _text != 'Listening...' && _text != 'Microphone permission denied.') {
                 _processQuery(_text);
              }
           }
        },
        onError: (val) {
          setState(() {
            _isListening = false;
            _text = 'Error listening. Try typing?';
          });
        },
      );
      if (available) {
        setState(() {
          _isListening = true;
          _text = 'Listening...';
          _assistantResponse = '';
        });
        _speech.listen(
          localeId: _selectedLanguage,
          onResult: (val) {
             setState(() {
               _text = val.recognizedWords;
             });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_text.isNotEmpty && _text != 'Listening...' && _text != 'Microphone permission denied.') {
         _processQuery(_text);
      }
    }
  }

  void _processQuery(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
       _isLoading = true;
       _assistantResponse = 'Thinking...';
       _textCtrl.clear();
    });
    
    final ans = await _aiService.askQuestion(widget.userId, query);
    
    if (mounted) {
      setState(() {
         _isLoading = false;
         _assistantResponse = ans;
         _text = query;
         _chatHistory.add({'query': query, 'response': ans});
      });
      _flutterTts.speak(ans);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32))
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(_selectedLanguage == "en-US" ? Icons.language : Icons.translate, color: AppTheme.primaryColor),
                  onPressed: _toggleLanguage,
                  tooltip: 'Switch Language',
                ),
                Container(width: 48, height: 6, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                _isSpeaking 
                  ? IconButton(icon: const Icon(Icons.stop_circle, color: AppTheme.errorColor), onPressed: _stopSpeaking, tooltip: 'Stop Speaking')
                  : const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 16),
            
            // Interaction Area
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_chatHistory.isNotEmpty) ...[
                      ..._chatHistory.map((chat) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(chat['query']!, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w500), textAlign: TextAlign.right),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                              child: Text(chat['response']!, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMainColor)),
                            ),
                          ],
                        ),
                      )),
                      const Divider(),
                    ],
                    if (_assistantResponse.isNotEmpty && !_isLoading)
                      Container(
                         padding: const EdgeInsets.all(20),
                         decoration: BoxDecoration(
                           color: AppTheme.surfaceColor, 
                           borderRadius: BorderRadius.circular(24),
                           boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]
                         ),
                         child: Text(_assistantResponse, style: GoogleFonts.inter(color: AppTheme.primaryColor, fontSize: 16, fontWeight: FontWeight.w600, height: 1.5)),
                      )
                    else if (_isLoading)
                      const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    else
                      Text(_text, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textMainColor), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
              
            const SizedBox(height: 24),

            // Mic Button with glow
            GestureDetector(
              onTap: _listen,
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (context, child) {
                  return Container(
                    padding: EdgeInsets.all(_isListening ? 20 + (_animCtrl.value * 10) : 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? AppTheme.errorColor.withValues(alpha: 0.2) : AppTheme.primaryColor.withValues(alpha: 0.15),
                    ),
                    child: Container(
                       padding: const EdgeInsets.all(24),
                       decoration: BoxDecoration(
                         shape: BoxShape.circle,
                         gradient: _isListening ? const LinearGradient(colors: [Colors.redAccent, Colors.red]) : AppTheme.primaryGradient,
                         boxShadow: _isListening ? null : [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                       ),
                       child: Icon(_isListening ? Icons.mic : Icons.graphic_eq_rounded, color: Colors.white, size: 36),
                    )
                  );
                }
              ),
            ),
            const SizedBox(height: 16),
            Text(_isListening ? 'Sshhh... listening' : 'Tap to start magic', style: GoogleFonts.inter(color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
            
            const SizedBox(height: 24),
            
            // Text Fallback
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: AppTheme.hintColor.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                    child: TextField(
                      controller: _textCtrl,
                      style: GoogleFonts.inter(color: AppTheme.textMainColor),
                      decoration: InputDecoration(
                         hintText: 'Or type your question...',
                         hintStyle: GoogleFonts.inter(color: AppTheme.hintColor),
                         filled: true,
                         fillColor: Colors.transparent,
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                         contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                           _text = val.trim();
                           _processQuery(val.trim());
                        }
                      },
                    ),
                  )
                ),
                const SizedBox(width: 12),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     gradient: AppTheme.primaryGradient,
                     boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: IconButton(
                     icon: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                     onPressed: () {
                        if (_textCtrl.text.trim().isNotEmpty) {
                           _text = _textCtrl.text.trim();
                           _processQuery(_textCtrl.text.trim());
                        }
                     }
                  )
                )
              ]
            )
          ],
        ),
      ),
    );
  }
}
