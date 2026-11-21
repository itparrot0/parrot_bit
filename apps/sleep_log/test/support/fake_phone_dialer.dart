import 'package:sleep_log/data/phone_dialer.dart';

/// 전화를 열지 않고 누른 번호만 기록한다.
final class FakePhoneDialer implements PhoneDialer {
  FakePhoneDialer({this.canDial = true});

  final bool canDial;
  final List<String> dialed = [];

  @override
  Future<bool> dial(String number) async {
    dialed.add(number);
    return canDial;
  }
}
