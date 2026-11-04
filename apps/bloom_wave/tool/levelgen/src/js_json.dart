// JS 와 같은 숫자·JSON 문자열 표기. Dart 는 정수 값 double 을 "1.0" 으로 쓰지만 JS 는 "1" 로 쓴다.
import 'dart:convert';

/// JS 의 String(x) 과 같은 숫자 표기 (정수 값 double → 소수점 없이)
String jsNum(num x) => x is double && x.isFinite && x == x.truncateToDouble()
    ? (x == 0 ? '0' : x.toInt().toString())
    : x.toString();

/// JSON 트리 안의 정수 값 double 을 int 로 바꾼다
Object? jsify(Object? v) => switch (v) {
  double d when d.isFinite && d == d.truncateToDouble() => d.toInt(),
  Map<String, dynamic> m => {for (final e in m.entries) e.key: jsify(e.value)},
  List l => [for (final x in l) jsify(x)],
  _ => v,
};

/// JSON.stringify(v)
String jsStringify(Object? v) => jsonEncode(jsify(v));

/// JSON.stringify(v, null, 2)
String jsStringifyPretty(Object? v) =>
    const JsonEncoder.withIndent('  ').convert(jsify(v));
