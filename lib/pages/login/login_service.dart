// lib/pages/login/login_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 🔐 로그인 서비스
///
/// 역할:
/// - Spring Boot 인증 API 호출 (ID/PW 로그인, 카카오 로그인)
/// - JWT 토큰 저장 및 관리
/// - 유저 정보 저장
class LoginService {
  // ============================================================================
  // 🔹 서버 주소 설정
  // ============================================================================

  // Spring Boot 인증 서버 주소
  static const String _authBaseUrl =
      "https://semiconical-shela-loftily.ngrok-free.dev";

  // 로그인 엔드포인트
  static const String loginUrl = "$_authBaseUrl/api/v1/auth/login";
  static const String kakaoUrl = "$_authBaseUrl/api/v1/auth/kakao";

  // ============================================================================
  // 🔹 공통 헤더 생성
  // ============================================================================

  /// ngrok 브라우저 경고 우회 헤더 포함한 기본 헤더
  static Map<String, String> get _defaultHeaders => {
        "Content-Type": "application/json",
        "Accept": "application/json",

        // ✅ ngrok 브라우저 경고 우회 헤더
        "ngrok-skip-browser-warning": "69420",
        "Ngrok-Skip-Browser-Warning": "69420",
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      };

  // ============================================================================
  // 🔹 토큰 및 유저 정보 관리
  // ============================================================================

  /// JWT 토큰 저장
  ///
  /// [token]: JWT 토큰 문자열
  /// 만료 시간: 현재 시각 + 1시간
  static Future<void> saveToken(String token) async {
    print('[LOGIN_SERVICE] 💾 Attempting to save token...');
    print(
        '[LOGIN_SERVICE] Token (first 30 chars): ${token.length > 30 ? token.substring(0, 30) : token}...');

    final prefs = await SharedPreferences.getInstance();

    // 토큰 저장
    final tokenSaved = await prefs.setString('jwt_token', token);
    print('[LOGIN_SERVICE] Token save result: $tokenSaved');

    // 만료 시간 저장
    final expiryTimestamp =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
    final expirySaved = await prefs.setInt('token_expiry', expiryTimestamp);
    print('[LOGIN_SERVICE] Expiry save result: $expirySaved');

    // ✅ 저장 검증: 즉시 다시 읽어서 확인
    final savedToken = prefs.getString('jwt_token');
    final savedExpiry = prefs.getInt('token_expiry');

    if (savedToken == null || savedToken != token) {
      print('[LOGIN_SERVICE] ❌ ERROR: Token was not saved correctly!');
      print('[LOGIN_SERVICE] Expected: $token');
      print('[LOGIN_SERVICE] Got: $savedToken');
      throw Exception('Failed to save JWT token to SharedPreferences');
    }

    if (savedExpiry == null || savedExpiry != expiryTimestamp) {
      print('[LOGIN_SERVICE] ❌ ERROR: Expiry was not saved correctly!');
      throw Exception('Failed to save token expiry to SharedPreferences');
    }

    print('[LOGIN_SERVICE] ✅ Token saved and verified successfully!');
    print(
        '[LOGIN_SERVICE] Expiry: ${DateTime.fromMillisecondsSinceEpoch(savedExpiry)}');
  }

  /// 유저 정보 저장
  static Future<void> saveUserInfo({
    required String id,
    required String name,
    required String nickname,
    required String rank,
  }) async {
    print(
        '[LOGIN_SERVICE] 💾 Saving user info: id=$id, name=$name, nickname=$nickname, rank=$rank');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', id);
    await prefs.setString('user_name', name);
    await prefs.setString('user_nickname', nickname);
    await prefs.setString('user_rank', rank);

    print('[LOGIN_SERVICE] ✅ User info saved successfully');
  }

  /// 로그인 상태 확인
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null || token.isEmpty) {
      print('[LOGIN_SERVICE] ⚠️ No token found');
      return false;
    }

    final expiry = prefs.getInt('token_expiry') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch > expiry) {
      print('[LOGIN_SERVICE] ⚠️ Token expired');
      return false;
    }

    print('[LOGIN_SERVICE] ✅ Valid token found');
    return true;
  }

  /// JWT 토큰 가져오기
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  /// 유저 닉네임 가져오기
  static Future<String> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_nickname') ?? '';
  }

  /// 로그아웃 (토큰 및 유저 정보 삭제)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('token_expiry');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_nickname');
    await prefs.remove('user_rank');
    print('[LOGIN_SERVICE] ✅ Logged out successfully');
  }

  // ============================================================================
  // 🔹 rank 파싱 헬퍼 (DB rank_id → 문자열 랭크)
  // ============================================================================

  static String _extractRank(Map<String, dynamic> responseData) {
    // 서버가 줄 수 있는 여러 형태를 다 체크
    dynamic raw = responseData['rank'];

    // ✅ 지금 실제 응답 키: userRank
    raw ??= responseData['userRank'];

    // 혹시 추가로 rankId / rank_id 쓰는 경우 대비
    raw ??= responseData['rankId'];
    raw ??= responseData['rank_id'];

    if (raw == null) {
      print('[LOGIN_SERVICE] ❌ ERROR: rank field not found in response!');
      print('[LOGIN_SERVICE] Response keys: ${responseData.keys.toList()}');
      throw Exception('서버 응답에 rank 정보가 없습니다.');
    }

    // 문자열인 경우
    if (raw is String) {
      // "3" 같은 숫자 문자열이면 → 매핑
      final parsed = int.tryParse(raw);
      if (parsed != null) {
        final mapped = _mapRankId(parsed);
        print('[LOGIN_SERVICE] 🔎 Rank parsed from string id: $raw → $mapped');
        return mapped;
      }
      print('[LOGIN_SERVICE] 🔎 Rank string detected: $raw');
      return raw; // "Beginner", "B1", "C2" 등
    }

    // 숫자인 경우 (1~7)
    if (raw is int) {
      final mapped = _mapRankId(raw);
      print('[LOGIN_SERVICE] 🔎 Rank mapped from id: $raw → $mapped');
      return mapped;
    }

    // 그 외 타입이면 그냥 문자열로
    print(
        '[LOGIN_SERVICE] ⚠️ Rank type is ${raw.runtimeType}, using toString(): $raw');
    return raw.toString();
  }

  static String _mapRankId(int id) {
    const map = {
      1: 'Beginner',
      2: 'A1',
      3: 'A2',
      4: 'B1',
      5: 'B2',
      6: 'C1',
      7: 'C2',
    };

    if (!map.containsKey(id)) {
      print('[LOGIN_SERVICE] ⚠️ Unknown rank_id: $id, fallback to toString()');
      return id.toString();
    }
    return map[id]!;
  }

  // ============================================================================
  // 🔹 로그인 API
  // ============================================================================

  /// ID/비밀번호 로그인
  ///
  /// POST /api/v1/auth/login
  /// Request: { loginId, loginPw }
  /// Response 예시:
  ///   { loginId, name, nickname, userRank, token }
  static Future<Map<String, dynamic>?> loginWithId(String id, String pw) async {
    print('');
    print('╔════════════════════════════════════════════════════════════');
    print('║ [LOGIN_SERVICE] 🔐 Starting login process');
    print('╠════════════════════════════════════════════════════════════');
    print('║ URL: $loginUrl');
    print('║ Login ID: $id');
    print('╚════════════════════════════════════════════════════════════');

    try {
      final response = await http
          .post(
            Uri.parse(loginUrl),
            headers: _defaultHeaders,
            body: jsonEncode({
              "loginId": id,
              "loginPw": pw,
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('');
      print('╔════════════════════════════════════════════════════════════');
      print('║ [LOGIN_SERVICE] 📡 Response received');
      print('╠════════════════════════════════════════════════════════════');
      print('║ Status: ${response.statusCode}');
      print('║ Headers: ${response.headers}');
      print('╚════════════════════════════════════════════════════════════');

      if (response.statusCode == 200) {
        print('[LOGIN_SERVICE] ✅ Login successful (200 OK)');

        // ✅ 응답 전체 출력 (디버깅용)
        print('');
        print('╔════════════════════════════════════════════════════════════');
        print('║ [LOGIN_SERVICE] 📄 Full response body:');
        print('╠════════════════════════════════════════════════════════════');
        print(response.body);
        print('╚════════════════════════════════════════════════════════════');
        print('');

        final responseData = jsonDecode(response.body);
        print(
            '[LOGIN_SERVICE] 📋 Parsed response data keys: ${responseData.keys.toList()}');

        // ✅ 토큰 추출 (여러 가능한 키 시도)
        String? token;

        // 시도 1: 'token' 키
        if (responseData.containsKey('token') &&
            responseData['token'] != null) {
          token = responseData['token'] as String;
          print('[LOGIN_SERVICE] ✅ Token found at key: "token"');
        }
        // 시도 2: 'accessToken' 키
        else if (responseData.containsKey('accessToken') &&
            responseData['accessToken'] != null) {
          token = responseData['accessToken'] as String;
          print('[LOGIN_SERVICE] ✅ Token found at key: "accessToken"');
        }
        // 시도 3: 'data.token' 중첩 구조
        else if (responseData.containsKey('data') &&
            responseData['data'] is Map &&
            (responseData['data'] as Map).containsKey('token')) {
          token = (responseData['data'] as Map)['token'] as String;
          print('[LOGIN_SERVICE] ✅ Token found at nested key: "data.token"');
        }
        // 시도 4: 'jwt' 키
        else if (responseData.containsKey('jwt') &&
            responseData['jwt'] != null) {
          token = responseData['jwt'] as String;
          print('[LOGIN_SERVICE] ✅ Token found at key: "jwt"');
        } else {
          print('[LOGIN_SERVICE] ❌ ERROR: No token found in response!');
          print(
              '[LOGIN_SERVICE] Available keys: ${responseData.keys.toList()}');
          print('[LOGIN_SERVICE] Response data: $responseData');
          throw Exception(
              "서버 응답에 토큰이 없습니다. 응답 키: ${responseData.keys.toList()}");
        }

        if (token.isEmpty) {
          print('[LOGIN_SERVICE] ❌ ERROR: Token is empty string!');
          throw Exception("토큰이 빈 문자열입니다.");
        }

        // ✅ 토큰 저장 (검증 포함)
        await saveToken(token);

        // ✅ 랭크 파싱 (userRank / rank / rankId 등 → 문자열)
        final rankString = _extractRank(responseData);

        // ✅ 유저 정보 자동 저장 (기본값 없이 서버 값 / 입력값만 사용)
        await saveUserInfo(
          id: responseData['loginId']?.toString() ??
              responseData['id']?.toString() ??
              id,
          name: responseData['name']?.toString() ?? '',
          nickname: responseData['nickname']?.toString() ?? id,
          rank: rankString,
        );

        print('');
        print('╔════════════════════════════════════════════════════════════');
        print('║ [LOGIN_SERVICE] ✅ Login completed successfully!');
        print('╠════════════════════════════════════════════════════════════');
        print('║ Token saved: ✅');
        print('║ User info saved: ✅ (rank: $rankString)');
        print('╚════════════════════════════════════════════════════════════');
        print('');

        return responseData;
      } else if (response.statusCode == 400) {
        print('[LOGIN_SERVICE] ❌ User not found (400)');
        throw Exception("존재하지 않는 사용자입니다.");
      } else if (response.statusCode == 401) {
        print('[LOGIN_SERVICE] ❌ Unauthorized (401)');
        throw Exception("인증 실패: 아이디 또는 비밀번호를 확인하세요.");
      } else {
        print('[LOGIN_SERVICE] ❌ Login failed: ${response.statusCode}');
        print('[LOGIN_SERVICE] Response body: ${response.body}');
        throw Exception("로그인 실패: ${response.statusCode}");
      }
    } on TimeoutException {
      print('[LOGIN_SERVICE] ❌ Timeout');
      throw Exception("서버 응답 시간이 초과되었습니다.");
    } catch (e) {
      print('[LOGIN_SERVICE] ❌ Exception: $e');
      print('[LOGIN_SERVICE] Exception type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// 카카오 로그인
  static Future<Map<String, dynamic>?> loginWithKakao(
      String kakaoId, String kakaoName) async {
    print('[LOGIN_SERVICE] 🔐 Attempting Kakao login: $kakaoId ($kakaoName)');
    print('[LOGIN_SERVICE] URL: $kakaoUrl');

    try {
      final response = await http
          .post(
            Uri.parse(kakaoUrl),
            headers: _defaultHeaders,
            body: jsonEncode({
              "loginId": kakaoId,
              "name": kakaoName,
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('[LOGIN_SERVICE] Response status: ${response.statusCode}');
      print('[LOGIN_SERVICE] Full response body:');
      print(response.body);

      if (response.statusCode == 200) {
        print('[LOGIN_SERVICE] ✅ Kakao login successful');
        final responseData = jsonDecode(response.body);

        // ✅ 토큰 추출 (여러 가능한 키 시도)
        String? token;
        if (responseData.containsKey('token') &&
            responseData['token'] != null) {
          token = responseData['token'] as String;
        } else if (responseData.containsKey('accessToken')) {
          token = responseData['accessToken'] as String;
        } else if (responseData.containsKey('data') &&
            (responseData['data'] as Map).containsKey('token')) {
          token = (responseData['data'] as Map)['token'] as String;
        } else {
          print('[LOGIN_SERVICE] ❌ No token found in response');
          throw Exception("서버 응답에 토큰이 없습니다.");
        }

        if (token.isEmpty) {
          throw Exception("토큰이 빈 문자열입니다.");
        }

        // ✅ 토큰 저장 (검증 포함)
        await saveToken(token);

        // ✅ 랭크 파싱
        final rankString = _extractRank(responseData);

        // ✅ 유저 정보 자동 저장
        await saveUserInfo(
          id: responseData['loginId']?.toString() ??
              responseData['id']?.toString() ??
              kakaoId,
          name: responseData['name']?.toString() ?? kakaoName,
          nickname: responseData['nickname']?.toString() ?? kakaoName,
          rank: rankString,
        );

        print('[LOGIN_SERVICE] ✅ Kakao user info saved (rank: $rankString)');

        return responseData;
      } else {
        print('[LOGIN_SERVICE] ❌ Kakao login failed: ${response.statusCode}');
        print('[LOGIN_SERVICE] Response body: ${response.body}');
        throw Exception("카카오 로그인 실패: ${response.statusCode}");
      }
    } on TimeoutException {
      print('[LOGIN_SERVICE] ❌ Timeout');
      throw Exception("서버 응답 시간이 초과되었습니다.");
    } catch (e) {
      print('[LOGIN_SERVICE] ❌ Exception: $e');
      rethrow;
    }
  }
}
