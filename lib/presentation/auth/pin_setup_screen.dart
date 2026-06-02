import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/route_names.dart';
import '../../core/security/secure_storage.dart';
import '../../core/theme/colors.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _errorMsg = '';

  void _onKeypadTap(String value) {
    setState(() {
      _errorMsg = '';
      if (_isConfirming) {
        if (_confirmPin.length < 4) _confirmPin += value;
        if (_confirmPin.length == 4) _verifyPin();
      } else {
        if (_pin.length < 4) _pin += value;
        if (_pin.length == 4) {
          _isConfirming = true;
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _errorMsg = '';
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          // Go back to first step
          _isConfirming = false;
          _pin = '';
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _verifyPin() async {
    if (_pin == _confirmPin) {
      await SecureStorage.saveAppPin(_pin);
      if (mounted) {
        if (context.canPop()) {
          context.pop(); // Return to Settings
        } else {
          context.go(RouteNames.home); // Fresh setup from auth flow
        }
      }
    } else {
      setState(() {
        _errorMsg = 'PINs do not match. Try again.';
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activePin = _isConfirming ? _confirmPin : _pin;
    final title = _isConfirming ? 'Confirm PIN' : 'Set App PIN';
    final subtitle = _isConfirming
        ? 'Re-enter your 4-digit PIN'
        : 'Protect your vault with a 4-digit PIN';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => context.go(RouteNames.home),
            child: const Text('Skip', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 48),
            
            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < activePin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? AppColors.primary : AppColors.surfaceContainerHigh,
                    border: Border.all(
                      color: isFilled ? AppColors.primary : AppColors.outlineVariant,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            
            if (_errorMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(_errorMsg, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error)),
              ),
              
            const Spacer(),
            
            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 1; i <= 9; i++) _buildNumpadButton(i.toString()),
                  const SizedBox(), // Empty bottom left
                  _buildNumpadButton('0'),
                  _buildDynamicButton(
                    onTap: _onBackspace,
                    icon: Icons.backspace_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadButton(String number) {
    return _buildDynamicButton(
      onTap: () => _onKeypadTap(number),
      text: number,
    );
  }

  Widget _buildDynamicButton({required VoidCallback onTap, String? text, IconData? icon}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: text != null
              ? Text(text, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.onSurface))
              : Icon(icon, size: 28, color: AppColors.onSurface),
        ),
      ),
    );
  }
}
