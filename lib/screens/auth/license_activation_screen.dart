import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/license_service.dart';
import '../../core/providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class LicenseActivationScreen extends ConsumerStatefulWidget {
  const LicenseActivationScreen({super.key});

  @override
  ConsumerState<LicenseActivationScreen> createState() => _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends ConsumerState<LicenseActivationScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isError = false;

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licenseProvider);
    final lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_person, color: Colors.orangeAccent, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                "SOLID POS ACTIVATION",
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Your software is currently locked. Please contact support with your Request Code to activate.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 32),

              // Request Code Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Text("REQUEST CODE", style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          license.machineId,
                          style: GoogleFonts.sourceCodePro(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white38, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: license.machineId));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied to clipboard!")));
                          },
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Key Input
              TextField(
                controller: _keyController,
                style: const TextStyle(color: Colors.white, letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: "XXXX-XXXX-XXXX-XXXX",
                  hintStyle: const TextStyle(color: Colors.white24),
                  labelText: "ACTIVATION KEY",
                  labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orangeAccent)),
                  errorText: _isError ? "Invalid activation key" : null,
                ),
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() => _isError = false),
              ),
              const SizedBox(height: 24),

              // Activate Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    final success = await ref.read(licenseProvider.notifier).activate(_keyController.text);
                    if (!success) {
                      setState(() => _isError = true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("ACTIVATE NOW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text("Exit Application", style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
