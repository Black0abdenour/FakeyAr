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
    setState(() {
      _translating = true;
      _status = 'جاري التحليل...';
    });
    try {
      final imgs = await _web?.evaluateJavascript(source: '''
(function(){
  return Array.from(document.querySelectorAll('img')).filter(function(i){
    return i.naturalWidth>200 && i.naturalHeight>300;
  }).map(function(i){
    var c=document.createElement('canvas');
    var w=Math.min(i.naturalWidth,800);
    var h=i.naturalHeight*(w/i.naturalWidth);
    c.width=w; c.height=h;
    c.getContext('2d').drawImage(i,0,0,w,h);
    return {src:i.src, b64:c.toDataURL('image/jpeg',0.7).split(',')[1]};
  }).filter(function(i){ return i.b64 && i.b64.length>100; });
})()
''');

      if (imgs == null || (imgs as List).isEmpty) {
        setState(() {
          _status = 'لا توجد صور';
          _translating = false;
        });
        return;
      }

      for (var img in imgs) {
        setState(() => _status = 'ترجمة...');
        final res = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'anthropic/claude-sonnet-4-5',
            'max_tokens': 800,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:image/jpeg;base64,${img['b64']}'
                    }
                  },
                  {
                    'type': 'text',
                    'text': 'ترجم النصوص في فقاعات الكلام للعربية. أرجع JSON فقط: {"has_text":true,"translations":[{"original":"","translated":"","position":"top"}]}'
                  }
                ]
              }
            ],
          }),
        ).timeout(const Duration(seconds: 30));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final content = data['choices'][0]['message']['content'] as String;
          final clean = content
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();
          final parsed = jsonDecode(clean);
          if (parsed['has_text'] == true) {
            final tr = jsonEncode(parsed['translations']);
            final src = img['src'] as String;
            await _web?.evaluateJavascript(source: '''
(function(){
  var tr=$tr;
  document.querySelectorAll('img').forEach(function(img){
    if(img.src==="$src"){
      var d=document.createElement('div');
      d.style.cssText='position:absolute;top:'+img.offsetTop+'px;left:'+img.offsetLeft+'px;width:'+img.offsetWidth+'px;height:'+img.offsetHeight+'px;pointer-events:none;z-index:9999;';
      tr.forEach(function(t){
        var p=document.createElement('div');
        var pos=t.position==='top'?'top:5%':t.position==='bottom'?'bottom:5%':'top:40%';
        p.style.cssText='position:absolute;'+pos+';left:10%;right:10%;background:rgba(255,255,255,0.93);color:#111;font-size:13px;font-weight:bold;text-align:center;padding:5px;border-radius:10px;direction:rtl;';
        p.textContent=t.translated;
        d.appendChild(p);
      });
      img.parentElement.style.position='relative';
      img.insertAdjacentElement('afterend',d);
    }
  });
})()
''');
          }
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      setState(() {
        _status = 'تمت الترجمة!';
        _translating = false;
      });
    } catch (e) {
      setState(() {
        _status = 'خطأ: $e';
        _translating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(children: [
          Container(
            color: const Color(0xFF1A1A2E),
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => _web?.goBack(),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.white70),
                onPressed: () => _web?.goForward(),
              ),
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: 'أدخل رابط المانهوا...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF252540),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: _loadUrl,
                ),
              ),
            ]),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://manhuaus.com'),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                supportZoom: true,
                builtInZoomControls: true,
                displayZoomControls: false,
                mixedContentMode:
                    MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                userAgent:
                    'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/112.0.0.0 Mobile Safari/537.36',
              ),
              onWebViewCreated: (c) => _web = c,
              onLoadStop: (c, url) => setState(
                () => _urlCtrl.text = url.toString(),
              ),
            ),
          ),
          Container(
            color: const Color(0xFF1A1A2E),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(
                child: Text(
                  _status,
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _translating ? null : _translate,
                icon: _translating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.translate, size: 18),
                label: Text(_translating ? 'جاري...' : 'ترجم'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
