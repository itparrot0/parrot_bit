import 'package:url_launcher/url_launcher.dart';

/// 전화 앱을 번호가 채워진 채로 연다. **바로 걸지 않는다** — 사용자가 전화
/// 앱에서 한 번 더 누른다(CALL_PHONE 권한도 필요 없다).
abstract interface class PhoneDialer {
  /// 열었으면 true. 전화가 안 되는 기기(태블릿 등)면 false.
  Future<bool> dial(String number);
}

final class UrlLauncherPhoneDialer implements PhoneDialer {
  const UrlLauncherPhoneDialer();

  @override
  Future<bool> dial(String number) async {
    try {
      return await launchUrl(Uri(scheme: 'tel', path: number));
    } on Object {
      return false;
    }
  }
}
