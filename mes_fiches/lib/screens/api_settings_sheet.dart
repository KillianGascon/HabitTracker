import 'package:flutter/material.dart';

import '../storage/api_config.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> openApiSettings(BuildContext context) => showBristolSheet(
      context,
      maxHeightFactor: .92,
      builder: (_) => const ApiSettingsSheet(),
    );

/// Association du téléphone à l'API de synchronisation.
class ApiSettingsSheet extends StatefulWidget {
  const ApiSettingsSheet({super.key});

  @override
  State<ApiSettingsSheet> createState() => _ApiSettingsSheetState();
}

class _ApiSettingsSheetState extends State<ApiSettingsSheet> {
  late final ApiConfig? _initial = StoreScope.read(context).apiConfig;
  late final _url = TextEditingController(text: _initial?.baseUrl ?? '');
  late final _cfId = TextEditingController(text: _initial?.cfClientId ?? '');
  final _cfSecret = TextEditingController();
  late final _name = TextEditingController(text: _initial?.deviceName ?? 'Mon téléphone');
  final _code = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    for (final c in [_url, _cfId, _cfSecret, _name, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  void _say(String message, {bool error = false}) => setState(() {
        _busy = false;
        _message = message;
        _error = error;
      });

  Future<void> _pair() async {
    final url = _url.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) {
      return _say('Adresse invalide (ex. https://api.mondomaine.fr).', error: true);
    }
    if (_name.text.trim().isEmpty || _code.text.trim().isEmpty) {
      return _say('Renseignez le nom du téléphone et le code d’association.', error: true);
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final err = await StoreScope.read(context).pair(
      ApiConfig(baseUrl: url, cfClientId: _cfId.text.trim(), deviceName: _name.text.trim()),
      cfClientSecret: _cfSecret.text.trim(),
      code: _code.text,
    );
    if (!mounted) return;
    _code.clear();
    _say(err == null ? 'Téléphone associé et synchronisé.' : 'Échec : $err', error: err != null);
  }

  Future<void> _sync() async {
    setState(() => _busy = true);
    final store = StoreScope.read(context);
    await store.sync();
    if (!mounted) return;
    final ok = store.status == SyncStatus.synced;
    _say(ok ? 'Synchronisé.' : 'Échec : ${store.syncError}', error: !ok);
  }

  Future<void> _unpair() async {
    await StoreScope.read(context).unpair();
    if (mounted) _say('Association oubliée. Les données restent sur le téléphone.');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final paired = store.apiConfig != null;
    final pending = store.pendingCount;
    final statusText = switch (store.status) {
      SyncStatus.notConfigured => 'Non associé · données uniquement sur le téléphone',
      SyncStatus.syncing => 'Synchronisation…',
      SyncStatus.synced => 'Synchronisé',
      SyncStatus.offline => store.syncError ?? 'Hors ligne',
    };

    Widget field(String label, TextEditingController c,
            {TextInputType? type, bool obscure = false, String? hint, String? help}) =>
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
            if (help != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(help, style: TextStyle(fontSize: 11, color: p.cardMuted)),
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
              child: Text('Synchronisation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
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
                Text(
                  statusText + (pending > 0 && paired ? ' · $pending changement(s) en attente' : ''),
                  style: TextStyle(
                    fontSize: 13,
                    color: store.status == SyncStatus.offline ? p.red : p.cardMuted,
                  ),
                ),
                const SizedBox(height: 14),
                if (paired) ...[
                  Text('Associé à ${store.apiConfig!.baseUrl} (${store.apiConfig!.deviceName})',
                      style: TextStyle(fontSize: 14, color: p.cardInk)),
                  const SizedBox(height: 14),
                  OutlineAction(
                    color: p.cardAccent,
                    enabled: !_busy,
                    onTap: _sync,
                    child: Text('Synchroniser maintenant',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.cardAccent)),
                  ),
                  const SizedBox(height: 6),
                  OutlineAction(
                    color: Colors.transparent,
                    height: 46,
                    enabled: !_busy,
                    onTap: _unpair,
                    child: Text('Oublier l’association', style: TextStyle(fontSize: 15, color: p.red)),
                  ),
                  const SizedBox(height: 18),
                  Text('Associer à nouveau', style: TextStyle(fontSize: 12, color: p.cardMuted)),
                  const SizedBox(height: 10),
                ],
                field('Adresse de l’API', _url,
                    type: TextInputType.url,
                    hint: 'https://api.mondomaine.fr',
                    help: 'En dev sur l’émulateur : http://10.0.2.2:3000'),
                field('Nom de ce téléphone', _name),
                field('Code d’association', _code, obscure: true, help: 'La variable PAIRING_CODE du serveur.'),
                field('Cloudflare Access · Client ID', _cfId, help: 'Laisser vide sans Cloudflare Access.'),
                field('Cloudflare Access · Client Secret', _cfSecret, obscure: true),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_message!, style: TextStyle(fontSize: 13, color: _error ? p.red : p.doneInk)),
                  ),
                OutlineAction(
                  color: p.cardAccent,
                  enabled: !_busy,
                  onTap: _pair,
                  child: _busy
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: p.cardAccent))
                      : Text('Associer ce téléphone',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.cardAccent)),
                ),
                const SizedBox(height: 10),
                Text(
                  'Les données sont toujours gardées sur le téléphone. Chaque changement est envoyé à '
                  'l’API ; hors connexion, il attend la prochaine synchronisation. Le jeton du téléphone '
                  'et le secret Cloudflare sont rangés dans le coffre sécurisé d’Android.',
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
