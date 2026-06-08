import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// ACS Profile Avatar with initials fallback and edit badge
class ACSProfileAvatar extends StatelessWidget {
  const ACSProfileAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = 48,
    this.showEditBadge = false,
    this.onEdit,
  });

  final String? imageUrl;
  final String? initials;
  final double size;
  final bool showEditBadge;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primaryContainer,
            border: Border.all(
              color: colorScheme.outlineVariant,
              width: 1.5,
            ),
          ),
          child: imageUrl != null
              ? ClipOval(
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                  ),
                )
              : initials != null
                  ? Center(
                      child: Text(
                        initials!,
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: size * 0.35,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: size * 0.6,
                      color: colorScheme.onPrimaryContainer,
                    ),
        ),
        if (showEditBadge)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: onEdit,
              child: Container(
                width: size * 0.35,
                height: size * 0.35,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.edit,
                  size: size * 0.2,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}