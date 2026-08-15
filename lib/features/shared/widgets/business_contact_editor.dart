import 'package:flutter/material.dart';

import '../../../models/business_contact_draft.dart';
import '../../../models/business_contact_number.dart';

class BusinessContactEditor extends StatefulWidget {
  const BusinessContactEditor({
    required this.initialValue,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<BusinessContactDraft> initialValue;
  final ValueChanged<List<BusinessContactDraft>> onChanged;
  final bool enabled;

  @override
  State<BusinessContactEditor> createState() => _BusinessContactEditorState();
}

class _BusinessContactEditorState extends State<BusinessContactEditor> {
  late List<_ContactEditorRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = _createRows(widget.initialValue);
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  List<_ContactEditorRow> _createRows(List<BusinessContactDraft> source) {
    final values = BusinessContactDraft.normalizePrimaryForEditing(source);
    return <_ContactEditorRow>[
      for (final value in values) _ContactEditorRow(value),
    ];
  }

  List<BusinessContactDraft> _currentDrafts() {
    return <BusinessContactDraft>[
      for (var index = 0; index < _rows.length; index++)
        BusinessContactDraft(
          phoneNumber: _rows[index].controller.text,
          label: _rows[index].label,
          isPrimary: _rows[index].isPrimary,
          supportsWhatsApp: _rows[index].supportsWhatsApp,
          sortOrder: index,
        ),
    ];
  }

  void _emit() => widget.onChanged(_currentDrafts());

  void _addRow() {
    if (!widget.enabled ||
        _rows.length >= BusinessContactNumber.maxPerBusiness) {
      return;
    }
    setState(() {
      _rows.add(
        _ContactEditorRow(
          BusinessContactDraft(
            phoneNumber: '',
            label: 'جوال',
            isPrimary: false,
            supportsWhatsApp: false,
            sortOrder: _rows.length,
          ),
        ),
      );
    });
    _emit();
  }

  void _removeRow(int index) {
    if (!widget.enabled || _rows.length <= 1) return;
    final removedWasPrimary = _rows[index].isPrimary;
    final removed = _rows.removeAt(index);
    removed.dispose();
    if (removedWasPrimary) {
      _rows.first.isPrimary = true;
    }
    setState(() {});
    _emit();
  }

  void _setPrimary(int index) {
    if (!widget.enabled) return;
    setState(() {
      for (var rowIndex = 0; rowIndex < _rows.length; rowIndex++) {
        _rows[rowIndex].isPrimary = rowIndex == index;
      }
    });
    _emit();
  }

  void _setWhatsApp(int index, bool selected) {
    if (!widget.enabled) return;
    setState(() {
      if (selected) {
        for (var rowIndex = 0; rowIndex < _rows.length; rowIndex++) {
          _rows[rowIndex].supportsWhatsApp = rowIndex == index;
        }
      } else {
        _rows[index].supportsWhatsApp = false;
      }
    });
    _emit();
  }

  void _move(int from, int to) {
    if (!widget.enabled || to < 0 || to >= _rows.length) return;
    setState(() {
      final row = _rows.removeAt(from);
      _rows.insert(to, row);
    });
    _emit();
  }

  bool _isDuplicate(int index, String value) {
    final key = BusinessContactDraft.normalizePhoneKey(value);
    if (key.isEmpty) return false;
    for (var other = 0; other < _rows.length; other++) {
      if (other == index) continue;
      if (BusinessContactDraft.normalizePhoneKey(
            _rows[other].controller.text,
          ) ==
          key) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: const ValueKey<String>('business-contact-editor'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.contact_phone_rounded, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'أرقام التواصل',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${_rows.length}/${BusinessContactNumber.maxPerBusiness}',
                textDirection: TextDirection.ltr,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'أضف حتى 5 أرقام، وحدد رقمًا رئيسيًا ورقم واتساب واحدًا عند الحاجة.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < _rows.length; index++) ...[
            _buildRow(context, index),
            if (index != _rows.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey<String>('business-contact-add-number'),
            onPressed: widget.enabled &&
                    _rows.length < BusinessContactNumber.maxPerBusiness
                ? _addRow
                : null,
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة رقم آخر'),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    final row = _rows[index];
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: ValueKey<String>('business-contact-row-$index'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          TextFormField(
            key: ValueKey<String>('business-contact-phone-$index'),
            controller: row.controller,
            enabled: widget.enabled,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              labelText: 'رقم التواصل ${index + 1}',
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            onChanged: (_) => _emit(),
            validator: (value) {
              final text = value?.trim() ?? '';
              final digitCount = BusinessContactDraft.normalizePhoneKey(text)
                  .replaceAll('+', '')
                  .length;
              if (digitCount < 5) return 'أدخل رقمًا صحيحًا.';
              if (_isDuplicate(index, text)) return 'هذا الرقم مكرر.';
              return null;
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: row.label,
            decoration: const InputDecoration(
              labelText: 'نوع الرقم',
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
            items: BusinessContactDraft.allowedLabels
                .map(
                  (label) => DropdownMenuItem<String>(
                    value: label,
                    child: Text(label),
                  ),
                )
                .toList(growable: false),
            onChanged: widget.enabled
                ? (value) {
                    if (value == null) return;
                    setState(() => row.label = value);
                    _emit();
                  }
                : null,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                key: ValueKey<String>('business-contact-primary-$index'),
                selected: row.isPrimary,
                avatar: const Icon(Icons.star_rounded, size: 18),
                label: const Text('الرقم الرئيسي'),
                onSelected: widget.enabled
                    ? (selected) {
                        if (selected) _setPrimary(index);
                      }
                    : null,
              ),
              FilterChip(
                key: ValueKey<String>('business-contact-whatsapp-$index'),
                selected: row.supportsWhatsApp,
                avatar: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('واتساب'),
                onSelected: widget.enabled
                    ? (selected) => _setWhatsApp(index, selected)
                    : null,
              ),
              IconButton(
                tooltip: 'تحريك لأعلى',
                onPressed: widget.enabled && index > 0
                    ? () => _move(index, index - 1)
                    : null,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: 'تحريك لأسفل',
                onPressed: widget.enabled && index < _rows.length - 1
                    ? () => _move(index, index + 1)
                    : null,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton(
                tooltip: 'حذف الرقم',
                onPressed: widget.enabled && _rows.length > 1
                    ? () => _removeRow(index)
                    : null,
                icon: Icon(Icons.delete_outline_rounded, color: colors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactEditorRow {
  _ContactEditorRow(BusinessContactDraft draft)
      : controller = TextEditingController(text: draft.phoneNumber),
        label = BusinessContactDraft.allowedLabels.contains(draft.label)
            ? draft.label
            : draft.isPrimary
                ? 'الرئيسي'
                : 'جوال',
        isPrimary = draft.isPrimary,
        supportsWhatsApp = draft.supportsWhatsApp;

  final TextEditingController controller;
  String label;
  bool isPrimary;
  bool supportsWhatsApp;

  void dispose() => controller.dispose();
}
