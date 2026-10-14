import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final String scanMode; // 'add' or 'sell'
  const BarcodeScannerScreen({super.key, required this.scanMode});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> with TickerProviderStateMixin {
  late AnimationController _laserController;
  late AnimationController _successController;
  final TextEditingController _manualInputController = TextEditingController();
  late final MobileScannerController _scannerController;

  bool _flashOn = false;
  bool _isSuccess = false;
  String _detectedCode = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scannerController = MobileScannerController();
  }

  void _onCodeScanned(String code) {
    if (_isSuccess) return;

    setState(() {
      _isSuccess = true;
      _detectedCode = code;
    });

    _laserController.stop();
    _successController.forward();

    // Haptic Feedback simulation
    HapticFeedback.mediumImpact();

    // Return the code after showing a success animation for 1.2 seconds
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.pop(context, _detectedCode);
      }
    });
  }

  @override
  void dispose() {
    _laserController.dispose();
    _successController.dispose();
    _manualInputController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Mock Camera Viewport
          _buildCameraViewport(),

          // 2. Dark Overlay Cutout
          _buildDarkOverlayCutout(),

          // 3. Scanning Box & Bracket Marks
          _buildScanningFrame(),

          // 4. Back Arrow & Header Info
          _buildHeader(),

          // 5. Controls Overlay (Flashlight, Manual Entry, Mode Banner)
          _buildControlsOverlay(),

          // 6. Success Modal Pop-up
          if (_isSuccess) _buildSuccessModal(),
        ],
      ),
    );
  }

  Widget _buildCameraViewport() {
    return Positioned.fill(
      child: MobileScanner(
        controller: _scannerController,
        fit: BoxFit.cover,
        onDetect: (capture) {
          if (_isProcessing || _isSuccess) return;
          final barcode = capture.barcodes.first.rawValue;
          if (barcode != null && barcode.isNotEmpty) {
            _isProcessing = true;
            _onCodeScanned(barcode);
          }
        },
      ),
    );
  }

  Widget _buildDarkOverlayCutout() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.6),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              height: 260,
              width: 260,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningFrame() {
    return Center(
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          children: [
            // Custom Focus Brackets
            _buildBracket(Alignment.topLeft, top: true, left: true),
            _buildBracket(Alignment.topRight, top: true, left: false),
            _buildBracket(Alignment.bottomLeft, top: false, left: true),
            _buildBracket(Alignment.bottomRight, top: false, left: false),

            // Animated Laser Line
            if (!_isSuccess)
              AnimatedBuilder(
                animation: _laserController,
                builder: (context, child) {
                  return Positioned(
                    top: 10 + (_laserController.value * 240),
                    left: 10,
                    right: 10,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBracket(Alignment alignment, {required bool top, required bool left}) {
    const double size = 24;
    const double thickness = 4;
    const Color bracketColor = Colors.white;

    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(
              top: top ? 0 : null,
              bottom: top ? null : 0,
              left: left ? 0 : null,
              right: left ? null : 0,
              child: Container(
                width: size,
                height: thickness,
                color: bracketColor,
              ),
            ),
            Positioned(
              top: top ? 0 : null,
              bottom: top ? null : 0,
              left: left ? 0 : null,
              right: left ? null : 0,
              child: Container(
                width: thickness,
                height: size,
                color: bracketColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.scanMode == 'add' ? 'Scan to Add Product' : 'Scan to Sell Product',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Align the barcode inside the frame',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: Column(
        children: [
          if (!_isSuccess)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Scanning for barcode...',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Flashlight Button
              _buildOverlayCircleButton(
                _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                'Flashlight',
                onTap: () {
                  setState(() => _flashOn = !_flashOn);
                  _scannerController.toggleTorch();
                  HapticFeedback.lightImpact();
                },
                active: _flashOn,
              ),

              // Manual Code Button
              _buildOverlayCircleButton(
                Icons.keyboard_rounded,
                'Manual Input',
                onTap: () => _showManualInputDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayCircleButton(IconData icon, String label, {required VoidCallback onTap, bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: active ? Colors.greenAccent : Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            ),
            child: Icon(icon, color: active ? Colors.black : Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.grey.shade900,
        title: const Text('Enter Barcode Manually', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the numeric code printed beneath the barcode.', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: _manualInputController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. 123456789',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.greenAccent, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Quick Test Barcodes:\n- 123456789 (Dell Laptop)\n- 987654321 (Ergonomic Chair)\n- 111111111 (Wireless Mouse)',
              style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final code = _manualInputController.text.trim();
              Navigator.pop(context); // close dialog
              if (code.isNotEmpty) {
                _onCodeScanned(code);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessModal() {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _successController,
        curve: Curves.elasticOut,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.greenAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.black, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'CODE DETECTED',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _detectedCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
