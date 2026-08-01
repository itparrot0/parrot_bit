import 'package:core_utils/core_utils.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('success holds value', () {
      const result = Result.success(42);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 42);
    });

    test('failure holds error', () {
      final result = Result<int>.failure(StateError('boom'));

      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('when branches by state', () {
      const success = Result.success('ok');

      final label = success.when(
        success: (value) => 'success:$value',
        failure: (error, _) => 'failure',
      );

      expect(label, 'success:ok');
    });

    test('map transforms success and passes failure through', () {
      const success = Result.success(2);
      final failure = Result<int>.failure(StateError('boom'));

      expect(success.map((v) => v * 10).valueOrNull, 20);
      expect(failure.map((v) => v * 10).isFailure, isTrue);
    });
  });
}
