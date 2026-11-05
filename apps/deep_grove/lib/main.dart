import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'economy/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  // 광고 SDK 준비는 기다리지 않는다 — 첫 광고 버튼을 누를 때쯤이면 끝나 있다.
  unawaited(container.read(rewardedAdsProvider).init());
  runApp(
    UncontrolledProviderScope(container: container, child: const GroveApp()),
  );
}
