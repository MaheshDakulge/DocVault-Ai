import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/route_names.dart';
import '../../core/security/biometric_auth.dart';
import '../../core/security/secure_storage.dart';
import '../../core/theme/colors.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pin = '';
  String _actualPin = '';
  String _errorMsg = '';
  bool _canUseBiometrics = false;
  bool _authenticatingBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    _actualPin = await SecureStorage.getAppPin() ?? '';
    final biometricEnabled = await SecureStorage.isBiometricLockEnabled();
    _canUseBiometrics = biometricEnabled && await BiometricAuth.isAvailable();
    if (mounted) {
      setState(() {});
      if (_actualPin.isEmpty && !_canUseBiometrics) {
        context.go(RouteNames.home);
        return;
      }
      if (_canUseBiometrics) {
        _promptBiometrics();
      }
    }
  }

  Future<void> _promptBiometrics() async {
    if (_authenticatingBiometrics) return;
    _authenticatingBiometrics = true;
    final success = await BiometricAuth.authenticate(
      reason: 'Unlock DocVault with your device biometrics',
    );
    _authenticatingBiometrics = false;
    if (success && mounted) {
      context.go(RouteNames.home);
    }
  }

  void _onKeypadTap(String value) {
    setState(() {
      _errorMsg = '';
      if (_pin.length < 4) {
        _pin += value;
      }
      if (_pin.length == 4) {
        _verifyPin();
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _errorMsg = '';
      if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _verifyPin() async {
    // Small delay to show the 4th dot filled
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    if (_pin == _actualPin) {
      context.go(RouteNames.home);
    } else {
      setState(() {
        _errorMsg = 'Incorrect PIN. Try again.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Welcome Back', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Enter your PIN to unlock', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 48),
            
            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _pin.length;
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
                  // Bottom left: Biometrics if available, else empty
                  _canUseBiometrics 
                      ? _buildDynamicButton(onTap: _promptBiometrics, icon: Icons.fingerprint_rounded)
                      : const SizedBox(),
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
              : Icon(icon, size: 36, color: AppColors.primary),
        ),
      ),
    );
  }
}
