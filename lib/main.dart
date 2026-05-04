import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const FakeyArApp());

class FakeyArApp extends StatelessWidget {
  const FakeyArApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مترجم المانهوا',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const BrowserScreen(),
    );
  }
}

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});
  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  InAppWebViewController? _web;
  final _urlCtrl = TextEditingController();
  bool _translating = false;
  String _status = 'جاهز';
  String _apiKey = 'YOUR_OPENROUTER_KEY_HERE';

  void _loadUrl(String url) {
    if (!url.startsWith('http')) url = 'https://$url';
    _web?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<void> _translate() async {
    if (_translating) return;
    setState(() { _translating = true; _status = 'جاري التحليل...'; });
    try {
      final imgs = await _web?.evaluateJavascript(source: '''
(function(){
  return Array.from(document.querySelectorAll('img')).filter(i=>i.naturalWidth>200&&i.naturalHeight>300).map(i=>{
    var c=document.createElement('canvas');
    var w=Math.min(i.naturalWidth,800);
    var h=i.naturalHeight*(w/i.naturalWidth);
    c.width=w;c.height=h;
    c.getContext('2d').drawImage(i,0,0,w,h);
    return {src:i.src,b64:c.toDataURL('image/jpeg',0.7).split(',')[1]};
  }).filter(i=>i.b64&&i.b64.length>100);
})()''');
      if (imgs == null || (imgs as List).isEmpty) {
        setState(() { _status = 'لا توجد صور'; _translating = false; });
        return;
      }
      for (var img in imgs) {
        setState(() => _status = 'ترجمة...');
        final res = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {'Authorization':'Bearer $_apiKey','Content-Type':'application/json'},
          body: jsonEncode({
            'model': 'anthropic/claude-sonnet-4-5',
