import 'package:flutter/material.dart';

import '../storage/db_config.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> openDbSettings(BuildContext context) => showBristolSheet(
      context,
      maxHeightFactor: .92,
      builder: (_) => const DbSettingsSheet(),
    );

/// Connexion à la base PostgreSQL (hôte, port, base, utilisateur, mot de passe).
class DbSettingsSheet extends StatefulWidget {
  const DbSettingsSheet({super.key});

  @override
  State<DbSettingsSheet> createState() => _DbSettingsSheetState();
}

class _DbSettingsSheetState extends State<DbSettingsSheet> {
  late final DbConfig? _initial = StoreScope.read(context).dbConfig;
  late final _host = TextEditingController(text: _initial?.host ?? '');
  late final _port = TextEditingController(text: '${_initial?.port ?? 5432}');
  late final _db = TextEditingController(text: _initial?.database ?? 'mes_fiches');
  late final _user = TextEditingController(text: _initial?.username ?? 'postgres');
  late final _pass = TextEditingController(text: _initial?.password ?? '');
  late bool _ssl = _initial?.ssl ?? false;
  bool _busy = false;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    for (final c in [_host, _port, _db, _user, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _connect() async {
    final port = int.tryParse(_port.text.trim());
    if (_host.text.trim().isEmpty || port == null || _db.text.trim().isEmpty || _user.text.trim().isEmpty) {
      setState(() {
        _message = 'Renseignez l’hôte, le port, la base et l’utilisateur.';
        _error = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final err = await StoreScope.read(context).configureDb(DbConfig(
      host: _host.text.trim(),
      port: port,
      database: _db.text.trim(),
      username: _user.text.trim(),
      password: _pass.text,
      ssl: _ssl,
    ));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err != null;
      _message = err == null ? 'Connecté et synchronisé.' : 'Échec de connexion : $err';
    });
  }

  Future<void> _disconnect() async {
    await StoreScope.read(context).configureDb(null);
    if (!mounted) return;
    setState(() {
      _message = 'Base déconnectée. Les données restent sur le téléphone.';
      _error = false;
    });
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    final store = StoreScope.read(context);
    await store.reconcile();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = store.status != SyncStatus.synced;
      _message = _error ? 'Échec : ${store.syncError}' : 'Synchronisé.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final statusText = switch (store.status) {
      SyncStatus.notConfigured => 'Non configurée · données uniquement sur le téléphone',
      SyncStatus.syncing => 'Synchronisation…',
      SyncStatus.synced => 'Synchronisée',
      SyncStatus.offline =>
        store.pendingChanges ? 'Hors ligne · changements en attente d’envoi' : 'Hors ligne',
    };

    Widget field(String label, TextEditingController c,
            {TextInputType? type, bool obscure = false, String? hint}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(label, style: TextStyle(fontSize: 12, color: p.cardMuted)),
            const SizedBox(height: 6),
            TextField(
              controller: c,
              keyboardType: type,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(fontSize: 16, color: p.cardInk),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: p.cardMuted.withValues(alpha: .7)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: p.rule),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: p.cardAccent),
                ),
              ),
            ),
          ]),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: Row(children: [
            const Expanded(
              child: Text('Base de données', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: p.cardMuted, minimumSize: const Size(44, 40)),
              child: const Text('Fermer', style: TextStyle(fontSize: 14)),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('PostgreSQL · $statusText', style: TextStyle(fontSize: 13, color: p.cardMuted)),
                const SizedBox(height: 14),
                field('Hôte', _host, type: TextInputType.url, hint: 'ex. 192.168.1.20'),
                Row(children: [
                  SizedBox(width: 100, child: field('Port', _port, type: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: field('Base', _db)),
                ]),
                field('Utilisateur', _user),
                field('Mot de passe', _pass, obscure: true),
                SwitchListTile(
                  value: _ssl,
                  onChanged: (v) => setState(() => _ssl = v),
                  contentPadding: EdgeInsets.zero,
                  activeColor: p.cardAccent,
                  title: Text('Connexion SSL', style: TextStyle(fontSize: 15, color: p.cardInk)),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_message!,
                        style: TextStyle(fontSize: 13, color: _error ? p.red : p.doneInk)),
                  ),
                OutlineAction(
                  color: p.cardAccent,
                  enabled: !_busy,
                  onTap: _connect,
                  child: _busy
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: p.cardAccent))
                      : Text('Tester et enregistrer',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.cardAccent)),
                ),
                if (store.dbConfig != null) ...[
                  const SizedBox(height: 8),
                  OutlineAction(
                    color: p.rule,
                    height: 46,
                    enabled: !_busy,
                    onTap: _syncNow,
                    child: Text('Synchroniser maintenant', style: TextStyle(fontSize: 15, color: p.cardInk)),
                  ),
                  const SizedBox(height: 6),
                  OutlineAction(
                    color: Colors.transparent,
                    height: 46,
                    enabled: !_busy,
                    onTap: _disconnect,
                    child: Text('Déconnecter la base', style: TextStyle(fontSize: 15, color: p.red)),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Les données sont toujours gardées sur le téléphone. Avec une base configurée, '
                  'chaque changement y est envoyé ; hors connexion, tout est renvoyé à la '
                  'prochaine synchronisation.',
                  style: TextStyle(fontSize: 12, color: p.cardMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
