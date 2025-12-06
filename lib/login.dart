import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  bool _sending = false;

  // NEW: keep resend token and a fallback timer
  int? _resendToken;
  Timer? _otpTimer;

  // NEW: phone validation error
  String? _phoneError;

  @override
  void dispose() {
    _otpTimer?.cancel();
    phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String raw) {
    if (raw.isEmpty) return 'Please enter phone number';
    // allow only digits in controller (input formatter enforces), check length
    if (raw.length != 10) return 'Enter a valid 10-digit phone number';
    return null;
  }

  Future<void> _sendOtp() async {
    final raw = phoneController.text.trim();

    // validate before sending
    final validationError = _validatePhone(raw);
    if (validationError != null) {
      setState(() {
        _phoneError = validationError;
        _sending = false;
      });
      return;
    }

    // clear any previous error
    setState(() {
      _phoneError = null;
      _sending = true;
    });

    final fullPhone = raw.startsWith('+') ? raw : '+91$raw';

    // cancel any previous timer and start a new one
    _otpTimer?.cancel();

    // fallback: stop spinner and show message if nothing happens within 60s
    _otpTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timeout sending OTP. Please try again.'),
          ),
        );
      }
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken, // use stored token for resends
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Cancel fallback timer and reset UI
          _otpTimer?.cancel();
          if (mounted) setState(() => _sending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Phone verified automatically — please enter OTP if prompted.',
              ),
            ),
          );
          // auto sign-in intentionally disabled
        },
        verificationFailed: (FirebaseAuthException e) {
          _otpTimer?.cancel();
          if (mounted) setState(() => _sending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          _otpTimer?.cancel();
          _resendToken = resendToken; // store resend token for future calls
          if (mounted) setState(() => _sending = false);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VerifyOtpPage(
                phoneNumber: fullPhone,
                verificationId: verificationId,
                onVerified: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Called when auto-retrieval times out
          _otpTimer?.cancel();
          if (mounted) setState(() => _sending = false);
        },
      );
    } catch (e) {
      _otpTimer?.cancel();
      if (mounted) setState(() => _sending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // top half gradient
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: height * 0.5, // gradient covers top half of screen
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      // darkened bluish tint (updated)
                      const Color(0xFFD0EAFF), // stronger bluish top
                      Colors.white.withOpacity(0.0), // fade to transparent
                    ],
                  ),
                ),
              ),
            ),

            // main scrollable content on top of gradient
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // Focused larger logo (replaced previous Row)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0A8FDC).withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/CureOne.png',
                          height: 140,
                          width: 140,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),

                  const Text(
                    "Welcome!",
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    "Access doctors, medicines & tests in one place.\nEnter your details to continue.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),

                  const SizedBox(height: 35),

                  // Phone label
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Phone Number",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Phone Number Input with validation border
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FA),
                      borderRadius: BorderRadius.circular(14),
                      border: _phoneError != null
                          ? Border.all(color: Colors.red, width: 1.6)
                          : null,
                    ),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Icon(Icons.phone, color: Colors.grey),
                        ),
                        // Country code
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          child: const Text(
                            "+91",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // vertical divider
                        Container(
                          height: 28,
                          width: 1,
                          color: Colors.grey.withOpacity(0.25),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _phoneError = _validatePhone(v);
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: "",
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 0,
                              ),
                              counterText: "",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error text under phone input
                  if (_phoneError != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _phoneError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Send OTP Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A8FDC),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _sending
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Send OTP",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 35),

                  // Footer Text
                  const Text.rich(
                    TextSpan(
                      text: "By continuing, you agree to our ",
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                      children: [
                        TextSpan(
                          text: "Terms of Service",
                          style: TextStyle(color: Color(0xFF0A8FDC)),
                        ),
                        TextSpan(text: " and "),
                        TextSpan(
                          text: "Privacy Policy",
                          style: TextStyle(color: Color(0xFF0A8FDC)),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
