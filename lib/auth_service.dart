import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
 
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: "328478700679-ejq47jsqb20lmurbac9tsnr651557mkc.apps.googleusercontent.com", // 여기에 클라이언트 ID 입력
    scopes: <String>[
    'email'
    ],
  );

  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      return await _googleSignIn.signIn();
    } catch (error) {
      print("Google Sign-In Error: $error");
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    
    final auth = await account.authentication;
    return auth.accessToken; // OAuth 액세스 토큰 반환
  }
}
