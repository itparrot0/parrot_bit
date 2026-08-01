/// 로컬 저장소 실패를 정규화한 예외.
final class StorageException implements Exception {
  const StorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'StorageException: $message${cause == null ? '' : ' ($cause)'}';
}
