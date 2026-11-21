import 'dart:typed_data';

import 'package:sleep_log/data/backup/backup_file_gateway.dart';

/// 공유 시트·파일 선택기 대신 메모리로 주고받는다.
final class FakeBackupFileGateway implements BackupFileGateway {
  FakeBackupFileGateway({this.toPick});

  Uint8List? toPick;
  Uint8List? shared;
  String? sharedName;

  @override
  Future<void> share(Uint8List bytes, String fileName) async {
    shared = bytes;
    sharedName = fileName;
  }

  @override
  Future<Uint8List?> pick() async => toPick;
}
