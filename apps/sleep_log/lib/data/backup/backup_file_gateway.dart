import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 백업 파일을 기기 밖으로 보내고, 고른 파일을 읽는다.
abstract interface class BackupFileGateway {
  /// 공유 시트를 연다 — 사용자가 드라이브·파일·메신저 중 어디에 둘지 고른다.
  /// 앱은 파일을 어디에도 자동으로 보내지 않는다 (PRD §9-1).
  Future<void> share(Uint8List bytes, String fileName);

  /// 파일을 고르게 한다. 취소하면 null.
  Future<Uint8List?> pick();
}

final class PlatformBackupFileGateway implements BackupFileGateway {
  const PlatformBackupFileGateway();

  @override
  Future<void> share(Uint8List bytes, String fileName) async {
    // 임시 폴더에 쓰고 공유한다. 공유가 끝나면 지운다 — 기기에 사본을 남기지 않는다.
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/octet-stream')],
          subject: '슬립로그 백업',
        ),
      );
    } finally {
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  @override
  Future<Uint8List?> pick() async {
    // 확장자로 거르면 일부 기기(클라우드 문서 제공자)에서 파일이 안 보인다.
    // 모든 파일을 보이게 하고 내용으로 판별한다.
    final picked = await FilePicker.pickFile(dialogTitle: '백업 파일 고르기');
    return picked?.xFile.readAsBytes();
  }
}
