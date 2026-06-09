import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';

class OutsidePunchBottomSheet extends StatefulWidget {
  const OutsidePunchBottomSheet({
    super.key,
    this.distance,
    this.allowedRadius,
  });

  final double? distance;
  final double? allowedRadius;

  @override
  State<OutsidePunchBottomSheet> createState() => _OutsidePunchBottomSheetState();
}

class _OutsidePunchBottomSheetState extends State<OutsidePunchBottomSheet> {
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();

  final List<Map<String, String>> _reasons = [
    {'value': 'WFH', 'label': 'WFH'},
    {'value': 'INSPECTION_SITE_VISIT', 'label': 'Inspection / Site Visit'},
    {'value': 'CLIENT_MEETING', 'label': 'Client Meeting'},
    {'value': 'VENDOR_VISIT', 'label': 'Vendor Visit'},
    {'value': 'COMPANY_OUTDOOR_WORK', 'label': 'Company Outdoor Work'},
    {'value': 'OTHER', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason type'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_detailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter reason details'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'type': _selectedReason,
      'details': _detailsController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final viewInsets = EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl).add(viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Title
          Text(
            'Outside Office Punch',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Subtitle / Distance Info
          Text(
            'You are outside the allowed office location. Please select a reason for this punch.',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          
          if (widget.distance != null && widget.allowedRadius != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_off_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Distance: ${widget.distance!.toStringAsFixed(1)}m (Allowed: ${widget.allowedRadius!.toStringAsFixed(1)}m)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: AppSpacing.md),

          // Reasons List
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._reasons.map((reason) {
                    final isSelected = _selectedReason == reason['value'];
                    return InkWell(
                      onTap: () => setState(() => _selectedReason = reason['value']),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: isSelected ? cs.primary : cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              reason['label']!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  // Text Area
                  TextField(
                    controller: _detailsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Reason / Work Details',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Submit Button
          AppButton(
            label: 'Submit Punch for Approval',
            onPressed: _submit,
            isMainCTA: true,
          ),
        ],
      ),
    );
  }
}
