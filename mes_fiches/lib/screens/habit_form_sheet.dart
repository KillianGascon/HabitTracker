import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';

Future<void> openHabitForm(BuildContext context, {Habit? habit}) => showBristolSheet(
      context,
      maxHeightFactor: .92,
      builder: (_) => HabitFormSheet(habit: habit),
    );

class HabitFormSheet extends StatefulWidget {
  const HabitFormSheet({super.key, this.habit});
  final Habit? habit;

  @override
  State<HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends State<HabitFormSheet> {
  late final _name = TextEditingController(text: widget.habit?.name ?? '');
  late String _emoji = widget.habit?.emoji ?? '✨';
  late Period _period = widget.habit?.period ?? Period.day;
  late int _target = widget.habit?.target ?? 1;
  // Nouvelle habitude : la catégorie affichée sur l'écran du jour.
  late String _category = widget.habit?.category ?? StoreScope.read(context).category ?? '';
  late final _custom = TextEditingController();
  bool _customOpen = false;
  bool _confirmDelete = false;

  bool get _isEdit => widget.habit != null;
  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _save() {
    if (!_valid) return;
    StoreScope.read(context).saveHabit(
      id: widget.habit?.id,
      name: _name.text,
      emoji: _emoji,
      period: _period,
      target: _target,
      category: _category,
    );
    Navigator.pop(context);
  }

  void _delete() {
    if (!_confirmDelete) return setState(() => _confirmDelete = true);
    StoreScope.read(context).deleteHabit(widget.habit!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final label = TextStyle(fontSize: 12, color: p.cardMuted);
    final emojis = kEmojis.contains(_emoji) ? kEmojis : [_emoji, ...kEmojis.take(15)];
    final categories = [
      for (final (_, name) in kCategories) name,
      for (final c in StoreScope.read(context).categories)
        if (categoryEmoji(c) == null) c,
    ];
    if (!_customOpen && _category.isNotEmpty && !categories.contains(_category)) categories.add(_category);

    Widget section(String title, Widget child, {double gap = 6}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text(title, style: label), SizedBox(height: gap), child],
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isEdit ? 'Modifier l’habitude' : 'Nouvelle habitude',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: p.cardMuted, minimumSize: const Size(44, 40)),
                child: const Text('Annuler', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                section(
                  'Nom',
                  _field(
                    p,
                    controller: _name,
                    hint: 'Ex. Arroser les plantes',
                    autofocus: !_isEdit,
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(height: 18),
                section(
                  'Catégorie',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _categoryChip(p, 'Aucune', !_customOpen && _category.isEmpty, () => _pickCategory('')),
                          for (final c in categories)
                            _categoryChip(
                              p,
                              categoryLabel(c),
                              !_customOpen && _category == c,
                              () => _pickCategory(c),
                            ),
                          _categoryChip(p, '+ Autre', _customOpen, () {
                            setState(() {
                              _customOpen = true;
                              _category = _custom.text.trim();
                            });
                          }),
                        ],
                      ),
                      if (_customOpen) ...[
                        const SizedBox(height: 8),
                        _field(
                          p,
                          controller: _custom,
                          hint: 'Ex. Jardin, Musique…',
                          autofocus: true,
                          maxLength: 40,
                          onChanged: (v) => setState(() => _category = v.trim()),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                section(
                  'Icône',
                  Column(children: [
                    for (var row = 0; row < 2; row++)
                      Padding(
                        padding: EdgeInsets.only(top: row == 0 ? 0 : 4),
                        child: Row(children: [
                          for (var k = 0; k < 8; k++) ...[
                            if (k > 0) const SizedBox(width: 4),
                            Expanded(child: _emojiButton(p, emojis[row * 8 + k])),
                          ],
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 18),
                section(
                  'Fréquence',
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: p.rule),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(children: [
                      for (final per in Period.values) ...[
                        if (per.index > 0) Container(width: 1, color: p.rule),
                        Expanded(child: _periodButton(p, per)),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                section(
                  'Nombre de fois',
                  gap: 8,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        SquareButton(
                          icon: AppIconKind.minus,
                          label: 'Moins',
                          size: 48,
                          borderColor: p.rule,
                          dimmed: _target <= 1,
                          onTap: () => setState(() => _target = (_target - 1).clamp(1, _period.maxTarget)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(children: [
                            Text('$_target',
                                style: const TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.w500, height: 1, fontFeatures: tabular)),
                            const SizedBox(height: 6),
                            Text('$_target fois par ${_period.word}',
                                style: TextStyle(fontSize: 13, color: p.cardMuted)),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        SquareButton(
                          icon: AppIconKind.plus,
                          label: 'Plus',
                          size: 48,
                          borderColor: p.cardInk,
                          dimmed: _target >= _period.maxTarget,
                          onTap: () => setState(() => _target = (_target + 1).clamp(1, _period.maxTarget)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Segments(total: _target, filled: 0),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                OutlineAction(
                  color: p.cardAccent,
                  enabled: _valid,
                  onTap: _save,
                  child: Text(
                    _isEdit ? 'Enregistrer' : 'Créer l’habitude',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.cardAccent),
                  ),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 6),
                  OutlineAction(
                    height: 46,
                    color: _confirmDelete ? p.red : Colors.transparent,
                    onTap: _delete,
                    child: Text(
                      _confirmDelete ? 'Confirmer la suppression' : 'Supprimer cette habitude',
                      style: TextStyle(fontSize: 15, color: p.red),
                    ),
                  ),
                  if (_confirmDelete)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'L’historique de cette habitude sera aussi supprimé.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: p.cardMuted),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    Palette p, {
    required TextEditingController controller,
    required String hint,
    bool autofocus = false,
    int? maxLength,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) =>
      TextField(
        controller: controller,
        autofocus: autofocus,
        maxLength: maxLength,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(fontSize: 17, color: p.cardInk),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: p.cardMuted.withValues(alpha: .7)),
          counterText: '',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          filled: true,
          fillColor: p.card,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: p.rule),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: p.cardAccent),
          ),
        ),
      );

  void _pickCategory(String c) => setState(() {
        _customOpen = false;
        _category = c;
      });

  Widget _categoryChip(Palette p, String label, bool sel, VoidCallback onTap) => Semantics(
        button: true,
        selected: sel,
        child: Material(
          color: sel ? p.seg : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: sel ? p.cardAccent : p.rule, width: sel ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: sel ? p.cardAccent : p.cardInk,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _emojiButton(Palette p, String e) {
    final sel = e == _emoji;
    return Semantics(
      button: true,
      selected: sel,
      label: e,
      child: Material(
        color: sel ? p.seg : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: sel ? BorderSide(color: p.cardAccent, width: 1.5) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _emoji = e),
          child: SizedBox(height: 40, child: Center(child: Text(e, style: const TextStyle(fontSize: 20)))),
        ),
      ),
    );
  }

  Widget _periodButton(Palette p, Period per) {
    final sel = per == _period;
    return Semantics(
      button: true,
      selected: sel,
      child: InkWell(
        onTap: () => setState(() {
          _period = per;
          _target = _target.clamp(1, per.maxTarget);
        }),
        child: Container(
          alignment: Alignment.center,
          decoration: sel
              ? BoxDecoration(border: Border.all(color: p.cardAccent, width: 1.5))
              : null,
          child: Text(
            per.optionLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: sel ? p.cardAccent : p.cardInk,
            ),
          ),
        ),
      ),
    );
  }
}
