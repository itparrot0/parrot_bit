import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('light/dark 테마가 올바른 밝기로 생성된다', () {
      expect(AppTheme.light().colorScheme.brightness, Brightness.light);
      expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
    });

    test('테마는 시드 컬러 기반 ColorScheme을 가진다', () {
      final lightScheme = AppTheme.light().colorScheme;
      final directScheme = ColorScheme.fromSeed(seedColor: AppColors.seed);

      expect(lightScheme.primary, directScheme.primary);
    });
  });
}
