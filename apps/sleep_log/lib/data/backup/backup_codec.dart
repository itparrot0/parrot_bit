import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../domain/domain.dart';

/// 백업 파일에 담는 것 — 기록·체크인·설정 전부 (PRD §9-4).
///
/// 안전 안내를 마지막으로 띄운 날 같은 내부 상태는 담지 않는다. 새 기기에서
/// 다시 세는 편이 낫다.
final class BackupContents {
  BackupContents({
    required this.createdAt,
    required this.entries,
    required this.checkIns,
    required this.target,
    required this.safetyNoticeEnabled,
    required this.checkInSettings,
  });

  final DateTime createdAt;
  final List<DiaryEntry> entries;
  final List<ThoughtCheckIn> checkIns;
  final SleepTarget? target;
  final bool safetyNoticeEnabled;
  final CheckInSettings checkInSettings;

  Map<String, Object?> toJson() => {
    'createdAt': createdAt.toUtc().toIso8601String(),
    'entries': [
      for (final entry in entries)
        {
          'date': entry.date.toIso(),
          'bed': entry.sleep?.bedTime.totalMinutes,
          'wake': entry.sleep?.wakeTime.totalMinutes,
          'tags': [for (final tag in entry.tags) tag.id],
          'rested': entry.rested?.name,
        },
    ],
    'checkIns': [
      for (final checkIn in checkIns)
        {
          'date': checkIn.date.toIso(),
          'slot': checkIn.slot.name,
          'pace': checkIn.pace?.name,
          'senses': checkIn.senses?.name,
          'thought': checkIn.thought,
          'reframe': checkIn.reframe,
        },
    ],
    'settings': {
      'targetMinutes': target?.duration.inMinutes,
      'safetyNotice': safetyNoticeEnabled,
      'checkIn': {
        'enabled': checkInSettings.enabled,
        'morning': checkInSettings.morningTime.totalMinutes,
        'afternoon': checkInSettings.afternoonTime.totalMinutes,
      },
    },
  };

  /// 읽을 수 없는 줄은 건너뛴다 — 한 줄이 깨졌다고 나머지를 버리지 않는다.
  /// 모르는 태그 id는 버린다(이후 버전의 커스텀 태그 등).
  factory BackupContents.fromJson(Map<String, Object?> json) {
    final settings = _map(json['settings']);
    final checkInJson = _map(settings['checkIn']);
    final targetMinutes = settings['targetMinutes'];

    return BackupContents(
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      entries: [for (final raw in _list(json['entries'])) ?_entry(_map(raw))],
      checkIns: [
        for (final raw in _list(json['checkIns'])) ?_checkIn(_map(raw)),
      ],
      target:
          targetMinutes is int &&
              targetMinutes >= SleepTarget.minDuration.inMinutes &&
              targetMinutes <= SleepTarget.maxDuration.inMinutes
          ? SleepTarget(Duration(minutes: targetMinutes))
          : null,
      safetyNoticeEnabled: settings['safetyNotice'] as bool? ?? true,
      checkInSettings: CheckInSettings(
        enabled: checkInJson['enabled'] as bool? ?? false,
        morningTime: _clock(checkInJson['morning']),
        afternoonTime: _clock(checkInJson['afternoon']),
      ),
    );
  }

  static DiaryEntry? _entry(Map<String, Object?> json) {
    final date = DiaryDate.tryParseIso(json['date'] as String? ?? '');
    if (date == null) {
      return null;
    }
    final bed = _clock(json['bed']);
    final wake = _clock(json['wake']);
    final sleep =
        bed != null && wake != null && SleepSession.isValidRange(bed, wake)
        ? SleepSession(bedTime: bed, wakeTime: wake)
        : null;
    return DiaryEntry(
      date: date,
      sleep: sleep,
      tags: {
        for (final id in _list(json['tags']))
          if (id is String) ?DefaultMoodTags.byId(id),
      },
      rested: RestFeeling.tryParse(json['rested'] as String?),
    );
  }

  static ThoughtCheckIn? _checkIn(Map<String, Object?> json) {
    final date = DiaryDate.tryParseIso(json['date'] as String? ?? '');
    final slot = CheckInSlot.tryParse(json['slot'] as String? ?? '');
    if (date == null || slot == null) {
      return null;
    }
    return ThoughtCheckIn(
      date: date,
      slot: slot,
      pace: _byName(MindPace.values, json['pace']),
      senses: _byName(SenseShift.values, json['senses']),
      thought: json['thought'] as String?,
      reframe: json['reframe'] as String?,
    );
  }

  static ClockTime? _clock(Object? minutes) =>
      minutes is int && minutes >= 0 && minutes < 24 * 60
      ? ClockTime(minutes ~/ 60, minutes % 60)
      : null;

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  static Map<String, Object?> _map(Object? value) =>
      value is Map<String, Object?> ? value : const {};

  static List<Object?> _list(Object? value) =>
      value is List<Object?> ? value : const [];
}

/// 백업 파일이 아니거나, 이 앱이 모르는 판이다.
final class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// 비밀번호가 틀렸거나 파일이 손상됐다. AES-GCM은 둘을 구분하지 못한다.
final class BackupPasswordException implements Exception {
  const BackupPasswordException();
}

/// 백업 파일 형식 (암호화 봉투).
///
/// ```json
/// {"format": "sleep_log.backup", "version": 1,
///  "kdf": {"name": "pbkdf2-hmac-sha256", "iterations": 120000, "salt": "…"},
///  "cipher": {"name": "aes-256-gcm", "nonce": "…", "mac": "…"},
///  "data": "…"}
/// ```
///
/// - 내용 전체를 비밀번호로 암호화한다. 파일을 클라우드에 올리거나 메신저로
///   보내도 비밀번호 없이는 읽을 수 없다 (PRD §9-1: 건강 데이터).
/// - 봉투(형식·판·KDF 값)는 평문이지만 AAD로 묶어 바꿔치기하면 풀리지 않는다.
/// - 비밀번호를 잊으면 **누구도 풀 수 없다** — 서버가 없고 복구 키도 없다.
abstract final class BackupCodec {
  static const String format = 'sleep_log.backup';
  static const int version = 1;

  /// 휴대폰에서 1초 안팎이 되도록 고른 값. 추측 공격을 늦추는 비용이다.
  static const int defaultIterations = 120000;

  /// 비밀번호 최소 길이. 짧으면 추측으로 풀린다.
  static const int minPasswordLength = 6;

  static const String fileExtension = 'sleeplog';

  static Future<Uint8List> encode(
    BackupContents contents,
    String password, {
    int iterations = defaultIterations,
    Random? random,
  }) async {
    final rng = random ?? Random.secure();
    final salt = List<int>.generate(16, (_) => rng.nextInt(256));
    final nonce = List<int>.generate(12, (_) => rng.nextInt(256));
    final key = await _deriveKey(password, salt, iterations);
    final header = {
      'format': format,
      'version': version,
      'kdf': {
        'name': 'pbkdf2-hmac-sha256',
        'iterations': iterations,
        'salt': base64Encode(salt),
      },
    };
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(contents.toJson())),
      secretKey: key,
      nonce: nonce,
      aad: _aad(header),
    );
    final envelope = {
      ...header,
      'cipher': {
        'name': 'aes-256-gcm',
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
      },
      'data': base64Encode(box.cipherText),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  /// 파일을 풀어 내용을 돌려준다.
  ///
  /// 백업 파일이 아니면 [BackupFormatException], 비밀번호가 틀리면
  /// [BackupPasswordException].
  static Future<BackupContents> decode(List<int> bytes, String password) async {
    final Map<String, Object?> envelope;
    try {
      envelope = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    } on Object {
      throw const BackupFormatException('슬립로그 백업 파일이 아니에요.');
    }
    if (envelope['format'] != format) {
      throw const BackupFormatException('슬립로그 백업 파일이 아니에요.');
    }
    final fileVersion = envelope['version'];
    if (fileVersion is! int || fileVersion > version) {
      throw const BackupFormatException('더 새 버전의 앱에서 만든 백업이에요. 앱을 업데이트해 주세요.');
    }

    final List<int> salt;
    final int iterations;
    final SecretBox box;
    try {
      final kdf = envelope['kdf']! as Map<String, Object?>;
      final cipher = envelope['cipher']! as Map<String, Object?>;
      salt = base64Decode(kdf['salt']! as String);
      iterations = kdf['iterations']! as int;
      box = SecretBox(
        base64Decode(envelope['data']! as String),
        nonce: base64Decode(cipher['nonce']! as String),
        mac: Mac(base64Decode(cipher['mac']! as String)),
      );
    } on Object {
      throw const BackupFormatException('백업 파일이 손상됐어요.');
    }

    final header = {
      'format': envelope['format'],
      'version': envelope['version'],
      'kdf': envelope['kdf'],
    };
    final List<int> clear;
    try {
      clear = await AesGcm.with256bits().decrypt(
        box,
        secretKey: await _deriveKey(password, salt, iterations),
        aad: _aad(header),
      );
    } on SecretBoxAuthenticationError {
      throw const BackupPasswordException();
    }
    try {
      return BackupContents.fromJson(
        jsonDecode(utf8.decode(clear)) as Map<String, Object?>,
      );
    } on Object {
      throw const BackupFormatException('백업 파일이 손상됐어요.');
    }
  }

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: password, nonce: salt);

  /// 봉투 머리를 정해진 순서로 직렬화해 AAD로 쓴다.
  static List<int> _aad(Map<String, Object?> header) =>
      utf8.encode(jsonEncode(header));
}
