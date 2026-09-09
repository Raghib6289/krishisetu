import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'farmer_chatbot_sheet.dart';

/// An unobtrusive, modern side-docked assistant button featuring a leaf icon logo.
/// It sits cleanly on the screen edge without capturing unnecessary screen space,
/// and only opens the chatbot when tapped.
class KrishiAssistantSideButton extends StatefulWidget {
  final VoidCallback? onTap;

  const KrishiAssistantSideButton({super.key, this.onTap});

  @override
  State<KrishiAssistantSideButton> createState() => _KrishiAssistantSideButtonState();
}

class _KrishiAssistantSideButtonState extends State<KrishiAssistantSideButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Krishi Sahayak (Agri AI Assistant)',
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isHovered ? 1.06 : _scaleAnimation.value,
              child: child,
            );
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap ?? () => FarmerChatbotSheet.show(context),
              borderRadius: BorderRadius.circular(24),
              splashColor: AppTheme.accentGold.withValues(alpha: 0.3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F3D24),
                      Color(0xFF1B5E20),
                      Color(0xFF2E7D32),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F3D24).withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: AppTheme.accentGold.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.green.shade300.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Leaf Icon Assistant Logo
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Compact text label
                    const Text(
                      'Sahayak',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Live AI indicator dot
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF81C784),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
