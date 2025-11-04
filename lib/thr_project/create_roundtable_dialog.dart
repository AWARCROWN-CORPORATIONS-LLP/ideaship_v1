// File: lib/create_roundtable_dialog.dart
import 'dart:math';
import 'package:flutter/material.dart';

// --- Constants for a cleaner design ---
const Color kPrimaryColor = Color(0xFF007AFF);
const Color kPrimaryLight = Color(0xFFE6F2FF);
const Color kBackgroundColor = Color(0xFFF8F9FA);
const Color kBorderColor = Color(0xFFE5E7EB);
const Color kTextColor = Color(0xFF1D1D1F);
const Color kTextSecondaryColor = Color(0xFF6B7280);
const Color kSuccessColor = Color(0xFF34C759);
const Color kErrorColor = Color(0xFFFF3B30); // Added for failure state
const Color kWarningColor = Color(0xFFFF9500); // Added for tag limit

// --- (RoundTablePainter & AnimatedRoundTableIcon are unchanged) ---
class RoundTablePainter extends CustomPainter {
  final double rotation;
  final Color color;
  final int chairCount;

  RoundTablePainter({
    this.rotation = 0.0,
    this.color = kPrimaryColor,
    this.chairCount = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final tableRadius = size.width / 2 - 4;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    final tablePaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, tableRadius, tablePaint);

    final edgePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, tableRadius, edgePaint);

    final chairPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < chairCount; i++) {
      final angle = (2 * pi / chairCount) * i;
      final chairRadius = 2.0;
      final chairDistance = tableRadius + 6;
      final chairX = center.dx + chairDistance * cos(angle);
      final chairY = center.dy + chairDistance * sin(angle);
      canvas.drawCircle(Offset(chairX, chairY), chairRadius, chairPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RoundTablePainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.color != color;
}

class AnimatedRoundTableIcon extends StatefulWidget {
  final double size;
  final Color color;
  const AnimatedRoundTableIcon({
    super.key,
    this.size = 54.0,
    this.color = kPrimaryColor,
  });
  @override
  State<AnimatedRoundTableIcon> createState() => _AnimatedRoundTableIconState();
}

class _AnimatedRoundTableIconState extends State<AnimatedRoundTableIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: RoundTablePainter(
            rotation: _rotationAnimation.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

// --- Reusable decoration helper ---
InputDecoration _buildInputDecoration({
  required String labelText,
  String? hintText,
  IconData? icon,
  Widget? suffixIcon,
  bool? enabled,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: icon != null ? Icon(icon, color: kTextSecondaryColor) : null,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: (enabled ?? true) ? kBackgroundColor : kBorderColor.withOpacity(0.5),
    enabled: enabled ?? true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBorderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kPrimaryColor, width: 2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: kBorderColor.withOpacity(0.5)),
    ),
  );
}

void showCreateRoundtableDialog({
  required BuildContext context,
  required Future<bool> Function(
    String title,
    String body,
    String category,
    List<String> tags,
    String visibility,
  ) onCreate,
}) {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  final tagController = TextEditingController();

  String selectedCategory = 'Idea';
  List<String> selectedTags = [];
  bool isPrivate = false;
  bool canSubmit = false;
  bool isSubmitting = false;
  bool showSuccess = false;
  bool showFailure = false;
  const int tagLimit = 10;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        void addTag(String tag) {
          // --- UPDATED: Show dialog on tag limit ---
          if (selectedTags.length >= tagLimit) {
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: kWarningColor),
                    SizedBox(width: 10),
                    Text('Tag Limit Reached'),
                  ],
                ),
                content: Text('You can only add up to $tagLimit tags.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
            return;
          }

          final trimmedTag = tag.trim().replaceAll(',', '');
          if (trimmedTag.isNotEmpty && !selectedTags.contains(trimmedTag)) {
            setDialogState(() {
              selectedTags.add(trimmedTag);
            });
            tagController.clear();
          }
        }

        void validateForm() {
          setDialogState(() {
            canSubmit = formKey.currentState?.validate() ?? false;
          });
        }

        // --- Success UI Widget ---
        Widget buildSuccessContent() {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                    color: kSuccessColor, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'Roundtable Created!',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kTextColor),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your discussion is now live.',
                  style: TextStyle(fontSize: 16, color: kTextSecondaryColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSuccessColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Done',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }

        // --- Failure UI Widget ---
        Widget buildFailureContent() {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: kErrorColor, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'Oh No!',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kTextColor),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Something went wrong. Please check your connection and try again.',
                  style: TextStyle(fontSize: 16, color: kTextSecondaryColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      setDialogState(() {
                        showFailure = false;
                        isSubmitting = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kErrorColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Try Again',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }

        // --- Main Form UI Widget ---
        Widget buildFormContent({required ValueKey<String> key}) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                decoration: const BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start a New Roundtable',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Gather ideas around the table',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const AnimatedRoundTableIcon(size: 50, color: Colors.white),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: titleController,
                          decoration: _buildInputDecoration(
                            labelText: 'Topic Title *',
                            hintText: 'What\'s the discussion about?',
                            icon: Icons.title,
                          ),
                          style: const TextStyle(
                              fontSize: 16, color: kTextColor),
                          onChanged: (_) => validateForm(),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Please enter a title'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: bodyController,
                          maxLines: 4,
                          decoration: _buildInputDecoration(
                            labelText: 'Opening Thoughts *',
                            hintText: 'Share your initial ideas...',
                            icon: Icons.description,
                          )..applyDefaults(
                             Theme.of(context).inputDecorationTheme
                           ).copyWith(alignLabelWithHint: true),
                          style: const TextStyle(
                              fontSize: 16, color: kTextColor),
                          onChanged: (_) => validateForm(),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Please share your thoughts'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: _buildInputDecoration(
                            labelText: 'Theme *',
                            icon: Icons.category,
                          ),
                          items: ['Idea', 'Problem', 'Build', 'Event', 'Collab']
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (val) =>
                              setDialogState(() => selectedCategory = val!),
                          validator: (value) =>
                              value == null ? 'Select a theme' : null,
                          style: const TextStyle(
                              fontSize: 16, color: kTextColor),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: tagController,
                          enabled: selectedTags.length < tagLimit,
                          decoration: _buildInputDecoration(
                            labelText: selectedTags.length < tagLimit
                                ? 'Add Tags (up to $tagLimit)'
                                : 'Tag limit reached',
                            hintText: 'Type and press comma or enter',
                            icon: Icons.tag,
                            enabled: selectedTags.length < tagLimit,
                            suffixIcon: (tagController.text.isNotEmpty &&
                                    selectedTags.length < tagLimit)
                                ? IconButton(
                                    icon: const Icon(
                                        Icons.add_circle_outline,
                                        color: kTextSecondaryColor),
                                    onPressed: () =>
                                        addTag(tagController.text),
                                  )
                                : null,
                          ),
                          style: const TextStyle(
                              fontSize: 16, color: kTextColor),
                          onChanged: (value) {
                            setDialogState(() {});
                            if (value.endsWith(',')) {
                              addTag(value);
                            }
                          },
                          onFieldSubmitted: (value) => addTag(value),
                        ),
                        if (selectedTags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: selectedTags
                                .map((t) => Chip(
                                      label: Text(t),
                                      onDeleted: () => setDialogState(
                                          () => selectedTags.remove(t)),
                                    ))
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Private Discussion'),
                          subtitle: const Text('Require invite code to join'),
                          value: isPrivate,
                          onChanged: (val) =>
                              setDialogState(() => isPrivate = val),
                          secondary: const Icon(Icons.lock_outline,
                              color: kTextSecondaryColor),
                          controlAffinity: ListTileControlAffinity.trailing,
                          activeColor: kPrimaryColor,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (canSubmit && !isSubmitting)
                                ? () async {
                                    if (!(formKey.currentState?.validate() ??
                                        false)) {
                                      return;
                                    }

                                    setDialogState(
                                        () => isSubmitting = true);

                                    final success = await onCreate(
                                      titleController.text,
                                      bodyController.text,
                                      selectedCategory,
                                      selectedTags,
                                      isPrivate ? 'private' : 'public',
                                    );

                                    setDialogState(() {
                                      if (success) {
                                        showSuccess = true;
                                      } else {
                                        showFailure = true;
                                      }
                                      isSubmitting = false;
                                    });
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  kPrimaryColor.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              shadowColor: kPrimaryColor.withOpacity(0.3),
                            ),
                            child: isSubmitting
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    'Start Discussion',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: showSuccess
                ? Padding(
                    key: const ValueKey('success'),
                    padding: const EdgeInsets.all(24.0),
                    child: buildSuccessContent(),
                  )
                : showFailure
                    ? Padding(
                        key: const ValueKey('failure'),
                        padding: const EdgeInsets.all(24.0),
                        child: buildFailureContent(),
                      )
                    : buildFormContent(key: const ValueKey('form')),
          ),
        );
      },
    ),
  );
}