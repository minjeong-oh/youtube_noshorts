import 'dart:convert'; // JSON 파싱용
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

// 웹 지원을 위한 import
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';

import 'auth_service.dart'; // GoogleAuthService 가져오기
import 'package:google_sign_in/google_sign_in.dart';


void main() {
  // 웹 플랫폼 초기화
  WebViewPlatform.instance = WebWebViewPlatform();

  runApp(const MyApp());
}

// ------------------
// 1) 메인 검색 화면
// ------------------
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Youtube NoShorts',
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA), // 유튜브의 실제 배경색
      ),
      home: MainSearchScreen(), // 로그인된 경우 메인 화면
    );
  }
}



class MainSearchScreen extends StatefulWidget {
  const MainSearchScreen({Key? key}) : super(key: key);

  @override
  State<MainSearchScreen> createState() => _MainSearchScreenState();
}

class _MainSearchScreenState extends State<MainSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _searchCount = 0; // ✅ 오늘 검색 횟수
  int _videoViewCount = 0; // ✅ 오늘 본 영상 횟수
  String _lastDate = ''; // ✅ 마지막 기록 날짜
  bool _isLoading = false; // ✅ 로딩 상태 추가
  List<dynamic> _searchResults = []; // ✅ 검색 결과 리스트 추가
  static const _apiKey = String.fromEnvironment('API_KEY');

    final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: "328478700679-ejq47jsqb20lmurbac9tsnr651557mkc.apps.googleusercontent.com", // 여기에 클라이언트 ID 입력
    scopes: ['https://www.googleapis.com/auth/youtube.readonly'],
  );

  GoogleSignInAccount? _user;


  @override
  void initState() {
    super.initState();
    _loadCounts();
    _checkSignInStatus();

  }

  // 자동 로그인 확인
  void _checkSignInStatus() async {
    final user = await _googleSignIn.signInSilently();
    setState(() {
      _user = user;
    });
  }

  // 로그인 버튼 클릭 시 실행
  void _handleSignIn() async {
    try {
      final user = await _googleSignIn.signIn();
      setState(() {
        _user = user;
      });
    } catch (error) {
      print("로그인 오류: $error");
    }
  }


  Future<void> _loadCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD

    setState(() {
      _lastDate = prefs.getString('lastDate') ?? today;
      _searchCount = (_lastDate == today) ? prefs.getInt('searchCount') ?? 0 : 0;
      _videoViewCount = (_lastDate == today) ? prefs.getInt('videoViewCount') ?? 0 : 0;
    });

    if (_lastDate != today) {
      await prefs.setInt('searchCount', 0);
      await prefs.setInt('videoViewCount', 0);
      await prefs.setString('lastDate', today);
    }
  }

  Future<void> _incrementSearchCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchCount++;
    });
    await prefs.setInt('searchCount', _searchCount);
    await prefs.setString('lastDate', DateTime.now().toString().split(' ')[0]);
  }

  Future<void> _incrementVideoViewCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _videoViewCount++;
    });
    await prefs.setInt('videoViewCount', _videoViewCount);
  }

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색어를 입력하세요.')),
      );
      return;
    }

    _incrementSearchCount();
    _searchYouTube(query);
  }

  Future<void> _searchYouTube(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String? accessToken = await GoogleAuthService().getAccessToken();
      if (accessToken == null) {
        throw Exception("User not authenticated");
      }

      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/search'
        '?part=snippet'
        '&type=video'
        '&maxResults=25'
        '&q=$query'
        '&key=$_apiKey'
      );

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $accessToken", // OAuth 인증 추가
          "Accept": "application/json"
        },
      );

      //final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];

        final filtered = items.where((item) {
          final snippet = item['snippet'];
          if (snippet == null) return false;
          final title = (snippet['title'] ?? '').toString().toLowerCase();
          return !title.contains('shorts');
        }).toList();

        setState(() {
          _searchResults = filtered;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 중 오류가 발생했습니다: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openVideo(String videoId) {
    _incrementVideoViewCount();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YouTubeVideoPlayer(videoId: videoId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ✅ 오늘 검색 횟수 & 영상 횟수 표시
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                   const SizedBox(height: 30),

                  Text(
                    '오늘의 검색 횟수: $_searchCount',
                    style: const TextStyle(fontSize: 12,color:Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '오늘의 시청 횟수: $_videoViewCount',
                    style: const TextStyle(fontSize: 12,color:Colors.grey),
                  ),
                
                ],
              ),
              const SizedBox(height: 50),

              // 아이콘을 검색창 위에 배치
            Center(
              child: Column(
                children: [
                
                  // const Text(
                  //   'Dopamine Killer',
                  //   style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  // ),

                  const Text(
                    'Search Only What you need',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // 검색창 + 검색 버튼을 한 줄(Row)로 배치, 작은 화면에서는 자동 줄 바꿈
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 로고 이미지
                    Container(
                      margin: const EdgeInsets.only(right: 10), // 로고와 검색창 사이 간격
                      child: Image.asset(
                        'assets/images/icon_youtube.png',
                        width: 60, // 너비만 설정 (비율 유지)
                        fit: BoxFit.contain, // 원본 비율 유지하며 크기 조정
                        filterQuality: FilterQuality.high, // 화질 유지
                      ),
                    ),
                    const SizedBox(width: 10), // 검색창과 버튼 사이 간격
                    // 검색창
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: SizedBox(
                        width: 500,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'YouTube 검색어를 입력하세요',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          ),
                          onSubmitted: (_) => _onSearch(),
                        ),
                      ),
                    ),    
                    const SizedBox(width: 10), // 검색창과 버튼 사이 간격
                    // 검색 버튼 (돋보기 아이콘 추가)
                    Container(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _user == null ? _handleSignIn : _onSearch, // 로그인 여부에 따라 버튼 동작 변경
                        icon: Icon(
                          Icons.search, // 로그인 전에는 로그인 아이콘, 후에는 검색 아이콘
                          size: 20,
                          color: Colors.white,
                        ),
                        label: Text(
                          _user == null ? 'Google 로그인' : '검색', // 로그인 전에는 "Google 로그인", 후에는 "검색"
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF424242), // 버튼 색상
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
              const SizedBox(height: 20),

            // ✅ 검색 결과 표시
            Visibility(
              visible: _searchResults.isNotEmpty, // 검색 결과가 있을 때만 표시
              child: Expanded(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA), // 배경색 추가
                        borderRadius: BorderRadius.circular(12.0), // 모서리 둥글게
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      margin: const EdgeInsets.all(8.0), // 전체적인 여백 추가
                      padding: const EdgeInsets.all(4.0), // 내부 패딩 추가
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.0), // 내부 컨텐츠도 둥글게
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _searchResults.isEmpty
                                ? const Center(child: Text('검색 결과가 없습니다.'))
                                : ListView.builder(
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final item = _searchResults[index];
                                      final snippet = item['snippet'];
                                      final idInfo = item['id'];

                                      if (snippet == null || idInfo == null) {
                                        return const SizedBox.shrink();
                                      }

                                      final title = snippet['title'] ?? '제목 없음';
                                      final channelTitle = snippet['channelTitle'] ?? '채널정보 없음';
                                      final videoId = idInfo['videoId'] ?? '';

                                      // 썸네일 URL
                                      final thumbnails = snippet['thumbnails'] ?? {};
                                      final highThumb = thumbnails['high'] ?? {};
                                      final thumbUrl = highThumb['url'] ?? '';

                                      return ListTile(
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(8.0),
                                          child: thumbUrl.isNotEmpty
                                              ? Image.network(
                                                  thumbUrl,
                                                  width: 120,
                                                  height: 90,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      width: 120,
                                                      height: 90,
                                                      color: Colors.grey[300],
                                                      child: const Icon(Icons.error),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  width: 120,
                                                  height: 90,
                                                  color: Colors.grey[300],
                                                  child: const Icon(Icons.image_not_supported),
                                                ),
                                        ),
                                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text(channelTitle, style: TextStyle(color: Colors.grey[700])),
                                        onTap: () {
                                          if (videoId.isNotEmpty) {
                                            _openVideo(videoId);
                                          }
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ),
                    
                    // ❌ 닫기 버튼 (오른쪽 상단)
                   Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      margin: const EdgeInsets.only(right: 10, top: 10), // 여백 추가
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchResults.clear(); // 검색 결과 초기화
                          });
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey, // 닫기 버튼 색상
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                   
                 
                  ],
                ),
              ),
            ),
            // Add an Expanded widget to take up remaining space when there are no search results
            if (_searchResults.isEmpty) Expanded(child: Container()),

                  // Footer with creator's information
            Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Created By Minjeong',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
            

          
          
          ),
        ),
      
    );
  }
}


// ---------------------
// 3) 동영상 재생 화면
// ---------------------

class YouTubeVideoPlayer extends StatelessWidget {
  final String videoId;
  const YouTubeVideoPlayer({Key? key, required this.videoId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🌟 viewType 등록 (Flutter Web에서 iframe을 인식하게 함)
    final String viewType = 'youtube-iframe-$videoId';
    ui.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = 'https://www.youtube.com/embed/$videoId?autoplay=1&mute=1&rel=0' // ✅ 자동 재생  //rel=0: 관련동영상 추천 안보이게게
          ..style.border = 'none'
          ..width = '100%'
          ..height = '100%'
          ..allowFullscreen = true;

        return iframe;
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: HtmlElementView(viewType: viewType),  // ✅ viewType 동적으로 변경!
    );
  }
}