import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:http/http.dart' as http;

const oatesMode = String.fromEnvironment('OATES_MODE');
const oatesEnabled = oatesMode == 'session' || oatesMode == 'resident';
const oatesSession = oatesMode == 'session';

class OatesSupportCard extends StatefulWidget {
  const OatesSupportCard({super.key});

  @override
  State<OatesSupportCard> createState() => _OatesSupportCardState();
}

class _OatesSupportCardState extends State<OatesSupportCard> {
  final _invite = TextEditingController();
  final _smsCode = TextEditingController();
  bool _busy = false;
  bool _consent = false;
  bool _sent = false;
  String? _enrollmentPassword;
  String _status = '';

  @override
  void initState() {
    super.initState();
    // The Windows portable launcher preserves the downloaded filename.
    final filename = Platform.environment['RUSTDESK_APPNAME'] ??
        Platform.resolvedExecutable.split(Platform.pathSeparator).last;
    final match = RegExp(r'^OfficeOates-(session|resident)-([a-f0-9]{64})(?: \([0-9]+\))?\.exe$',
        caseSensitive: false).firstMatch(filename);
    if (match != null && match.group(1)!.toLowerCase() == oatesMode) {
      _invite.text = match.group(2)!.toLowerCase();
    }
  }

  @override
  void dispose() {
    _invite.dispose();
    _smsCode.dispose();
    super.dispose();
  }

  Future<void> _submit(
      http.Client client, Map<String, String> fields, int expectedStatus) async {
    final request = http.Request(
        'POST', Uri.parse('https://oates.xbiz.jp/support/api/request.php'))
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(fields);
    final streamed = await client.send(request).timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 10));
    if (response.statusCode == expectedStatus) return;
    if (response.statusCode == 403) {
      final body = jsonDecode(response.body);
      if (body is Map && body['status'] == 'invalid_sms_code') {
        throw StateError('SMSのコードが一致しません。入力を確認してください。');
      }
      throw StateError('受付情報を確認できません。Office Oatesへ新しいリンクとコードをご依頼ください。');
    }
    throw StateError('送信を確認できませんでした。受付コードの状態をOffice Oatesへお問い合わせください。');
  }

  Future<void> _send() async {
    if (_busy || _sent || !_consent) return;
    final invite = _invite.text.trim();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(invite)) {
      setState(() => _status = 'Office Oatesから届いた受付コードを貼り付けてください。');
      return;
    }
    final smsCode = _smsCode.text.trim();
    if (!RegExp(r'^[A-HJ-NP-Z2-9!+@#]{8}$').hasMatch(smsCode)) {
      setState(() => _status = 'SMSに届いた8文字のコードを入力してください。');
      return;
    }
    setState(() { _busy = true; _status = '接続情報を準備しています。'; });
    http.Client? client;
    try {
      if (!oatesSession && !bind.mainIsInstalled()) {
        throw StateError('常駐版は、先にこの画面のインストール案内を完了してください。');
      }
      final id = await bind.mainGetMyId();
      if (!RegExp(r'^[0-9]{6,16}$').hasMatch(id)) {
        throw StateError('接続IDの準備ができていません。ネットワーク接続を確認してください。');
      }
      client = http.Client();
      final enrollment = {'invite': invite, 'sms_code': smsCode, 'mode': oatesMode};
      await _submit(client, {...enrollment, 'action': 'verify_sms'}, 200);
      if (!mounted) return;
      String password;
      if (oatesSession) {
        await bind.mainSetOption(key: 'temporary-password-length', value: '10');
        await bind.mainSetOption(key: 'verification-method', value: 'use-temporary-password');
        password = await bind.mainGetTemporaryPassword();
        if (password.length < 6) throw StateError('一時パスワードを取得できませんでした。');
      } else {
        final random = Random.secure();
        _enrollmentPassword ??= base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
        password = _enrollmentPassword!;
        if (!await bind.mainSetPermanentPasswordWithResult(password: password)) {
          throw StateError('端末専用パスワードを設定できませんでした。');
        }
        await bind.mainSetOption(key: 'verification-method', value: 'use-permanent-password');
      }
      await bind.mainSetOption(key: 'approve-mode', value: 'password');
      await _submit(client, {...enrollment, 'id': id, 'password': password}, 202);
      if (mounted) {
        setState(() {
          _sent = true;
          _status = '接続情報を送信しました。担当者からの接続をお待ちください。';
        });
        _smsCode.clear();
      }
    } catch (error) {
      if (mounted) setState(() => _status = error is StateError
          ? '${error.message}' : '通信結果を確認できませんでした。再送信前にOffice Oatesへお問い合わせください。');
    } finally {
      client?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset('assets/office_oates_logo.png', height: 96, fit: BoxFit.contain),
        const SizedBox(height: 12),
        Text('Office Oates リモートサポート', style: Theme.of(context).textTheme.titleMedium),
        Text(oatesSession ? '都度サポート版' : '常駐サポート版'),
        Text(oatesSession
          ? 'サポート中は画面を開いたままにしてください。閉じると接続受付を停止します。'
          : 'インストール後は再起動後も接続可能です。登録すると、この端末の接続パスワードを更新します。'),
        const SizedBox(height: 12),
        if (_invite.text.isNotEmpty) const Text('専用リンクの受付情報を読み込みました。'),
        if (_invite.text.isEmpty) TextField(controller: _invite, enabled: !_busy && !_sent,
          autocorrect: false, enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Office Oatesの受付コードを貼り付け')),
        if (!_sent)
          TextField(
            controller: _smsCode,
            enabled: !_busy,
            maxLength: 8,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'SMSで届いた8文字のコード'),
          ),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: _consent,
          onChanged: _busy || _sent ? null : (value) => setState(() => _consent = value ?? false),
          title: const Text('Office Oatesによる遠隔操作と、接続ID・パスワードのメール送信に同意します。')),
        ElevatedButton(onPressed: _busy || _sent || !_consent ? null : _send,
          child: Text(_busy ? '送信中…' : '接続情報をOffice Oatesへ送信')),
        if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_status)),
      ],
    )),
  );
}
