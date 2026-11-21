import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/backup/backup_codec.dart';
import '../data/providers.dart';
import '../domain/domain.dart';

/// 백업과 기기 이전 (PRD §9-4).
///
/// 서버가 없는 앱이라 폰을 바꾸면 기록이 사라진다. 그래서 **비밀번호로 잠근
/// 파일**을 만들어 사용자가 직접 옮긴다. 앱은 파일을 어디에도 자동으로 보내지
/// 않는다. 온보딩에서도 들어올 수 있다 — 새 폰에서 첫 화면부터 옮겨 올 수 있게.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  /// 오래 걸리는 일(키 만들기 1~3초)을 하는 동안 보여 줄 문구. null이면 쉬는 중.
  String? _busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('백업과 기기 이전')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            '슬립로그의 기록은 이 기기에만 있어요. 폰을 바꾸거나 앱을 지우기 전에 '
            '백업 파일을 만들어 두면, 새 기기에서 그대로 가져올 수 있어요.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _Action(
            key: const Key('backup.export'),
            icon: Icons.upload_file,
            title: '백업 파일 만들기',
            body:
                '기록·생각 돌아보기·설정을 비밀번호로 잠근 파일 하나로 만들어요. '
                '드라이브나 내 파일, 메신저 등 원하는 곳에 저장하세요.',
            onTap: _busy == null ? _export : null,
          ),
          const SizedBox(height: 12),
          _Action(
            key: const Key('backup.import'),
            icon: Icons.download,
            title: '백업 파일 가져오기',
            body: '이전 기기에서 만든 백업 파일을 골라 비밀번호를 넣으면 기록을 옮겨 와요.',
            onTap: _busy == null ? _import : null,
          ),
          const SizedBox(height: 24),
          if (_busy case final message?)
            Row(
              children: [
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(message),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            '· 비밀번호를 잊으면 누구도 파일을 열 수 없어요. 저희도 도와드릴 수 없어요.\n'
            '· 백업 파일에는 수면·기분 기록과 적어 둔 생각이 들어 있어요. '
            '믿을 수 있는 곳에만 보관해 주세요.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _PasswordDialog(confirm: true),
    );
    if (password == null || !mounted) {
      return;
    }
    setState(() => _busy = '백업 파일을 만드는 중이에요…');
    try {
      final bytes = await ref.read(backupServiceProvider).export(password);
      final today = ref.read(todayProvider);
      await ref
          .read(backupFileGatewayProvider)
          .share(
            bytes,
            'sleeplog-${today.toIso()}.${BackupCodec.fileExtension}',
          );
      _message('백업 파일을 만들었어요. 저장한 곳과 비밀번호를 꼭 기억해 두세요.');
    } on Object {
      _message('백업 파일을 만들지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  Future<void> _import() async {
    final bytes = await ref.read(backupFileGatewayProvider).pick();
    if (bytes == null || !mounted) {
      return;
    }
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _PasswordDialog(confirm: false),
    );
    if (password == null || !mounted) {
      return;
    }

    setState(() => _busy = '백업 파일을 여는 중이에요…');
    final BackupContents contents;
    try {
      contents = await BackupCodec.decode(bytes, password);
    } on BackupPasswordException {
      _message('비밀번호가 맞지 않아요. 백업을 만들 때 쓴 비밀번호를 넣어 주세요.');
      return;
    } on BackupFormatException catch (error) {
      _message(error.message);
      return;
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
    if (!mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _RestorePreview(contents: contents),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = '기록을 옮기는 중이에요…');
    try {
      final summary = await ref.read(backupServiceProvider).restore(contents);
      if (!mounted) {
        return;
      }
      setState(() => _busy = null);
      _message('기록 ${summary.entries}일, 생각 돌아보기 ${summary.checkIns}개를 가져왔어요.');
      // 옮겨 온 기록을 바로 보이게 달력으로. 온보딩에서 왔어도 목표가 생겼으니 간다.
      context.go('/');
    } on Object {
      if (mounted) {
        setState(() => _busy = null);
      }
      _message('기록을 옮기지 못했어요. 다시 시도해 주세요.');
    }
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(body),
        ),
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }
}

/// 비밀번호 입력. [confirm]이면 두 번 받아 같은지 확인한다(만들 때).
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.confirm});

  final bool confirm;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();
  final _again = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _password.text;
    if (widget.confirm) {
      if (password.length < BackupCodec.minPasswordLength) {
        setState(
          () => _error = '${BackupCodec.minPasswordLength}자 이상으로 정해 주세요.',
        );
        return;
      }
      if (password != _again.text) {
        setState(() => _error = '두 비밀번호가 달라요.');
        return;
      }
    } else if (password.isEmpty) {
      setState(() => _error = '비밀번호를 넣어 주세요.');
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.confirm ? '백업 비밀번호 정하기' : '백업 비밀번호'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.confirm)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('이 비밀번호를 잊으면 백업을 열 수 없어요.'),
            ),
          TextField(
            key: const Key('backup.password'),
            controller: _password,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: '비밀번호'),
            onSubmitted: (_) => widget.confirm ? null : _submit(),
          ),
          if (widget.confirm)
            TextField(
              key: const Key('backup.passwordAgain'),
              controller: _again,
              obscureText: true,
              decoration: const InputDecoration(labelText: '한 번 더'),
              onSubmitted: (_) => _submit(),
            ),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(onPressed: _submit, child: const Text('확인')),
      ],
    );
  }
}

/// 가져오기 전에 무엇이 들어오고 무엇이 바뀌는지 보여 준다.
class _RestorePreview extends StatelessWidget {
  const _RestorePreview({required this.contents});

  final BackupContents contents;

  @override
  Widget build(BuildContext context) {
    final created = contents.createdAt.toLocal();
    final createdDate = DiaryDate.fromDateTime(created);
    return AlertDialog(
      title: const Text('이 백업을 가져올까요?'),
      content: Text(
        '${createdDate.year}년 ${createdDate.month}월 ${createdDate.day}일에 만든 백업이에요.\n'
        '기록 ${contents.entries.length}일 · 생각 돌아보기 ${contents.checkIns.length}개\n\n'
        '같은 날짜의 기록은 백업 내용으로 바뀌고, 백업에 없는 날짜의 기록은 그대로 남아요. '
        '목표 수면시간 같은 설정은 백업에 맞춰져요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('가져오기'),
        ),
      ],
    );
  }
}
