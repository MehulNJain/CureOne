import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'create_user.dart';
import 'home_page.dart';

class VerifyOtpPage extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final VoidCallback? onVerified;

  const VerifyOtpPage({
    Key? key,
    required this.phoneNumber,
    required this.verificationId,
    this.onVerified,
  }) : super(key: key);

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  Timer? _resendTimer;
  int _secondsLeft = 30;
  bool _isResendAvailable = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    for (var i = 0; i < 6; i++) {
      _controllers[i].addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer({int seconds = 30}) {
    _resendTimer?.cancel();
    setState(() {
      _secondsLeft = seconds;
      _isResendAvailable = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() {
          _isResendAvailable = true;
          _secondsLeft = 0;
        });
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String get _currentOtp => _controllers.map((c) => c.text.trim()).join();

  bool get _isOtpComplete =>
      _controllers.every((c) => c.text.trim().isNotEmpty);

  void _onOtpChanged(int i, String value) {
    if (value.isEmpty) {
      // if user deleted go to previous
      if (i > 0) _focusNodes[i - 1].requestFocus();
      return;
    }
    // move to next if available
    if (i < _focusNodes.length - 1) {
      _focusNodes[i + 1].requestFocus();
    } else {
      _focusNodes[i].unfocus();
    }
  }

  void _onVerify() async {
    if (!_isOtpComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code')),
      );
      return;
    }

    // Attempt to sign in with the provided verificationId and OTP
    final smsCode = _currentOtp;
    final cred = PhoneAuthProvider.credential(
      verificationId: widget.verificationId,
      smsCode: smsCode,
    );

    // set verifying flag so the button shows a spinner until process completes
    setState(() => _isVerifying = true);

    try {
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      final uid = userCred.user?.uid;
      if (uid == null) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get user id after verification'),
          ),
        );
        return;
      }

      // check realtime database for existing user node using phone number as key
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://cureone-4e269-default-rtdb.asia-southeast1.firebasedatabase.app',
      );
      final phoneKey = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
      final ref = db.ref('users/$phoneKey');
      final snapshot = await ref.get();

      setState(() => _isVerifying = false);

      if (snapshot.exists) {
        // user exists -> navigate to main/home screen
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      } else {
        // new user -> open create user page (pass phone number so it becomes node key)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CreateUserPage(phoneNumber: widget.phoneNumber),
          ),
        );
      }
    } catch (e) {
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: ${e.toString()}')),
      );
    }
  }

  void _onResend() {
    // implement resend behavior (API call) then restart timer
    _startResendTimer();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('OTP resent')));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // top half gradient (darker bluish tint)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: height * 0.5,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFD0EAFF),
                      Color(0x00FFFFFF), // fade to transparent
                    ],
                  ),
                ),
              ),
            ),

            // content
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: height - media.padding.vertical,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // app logo (same as login page)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0A8FDC,
                                  ).withOpacity(0.15),
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

                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),

                              // Title
                              const Text(
                                'Verify OTP',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0B2743),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Subtitle
                              const Text(
                                'Enter the 6-digit code sent to your phone number',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6C7A89),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // phone number with small edit icon
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.phoneNumber,
                                    style: const TextStyle(
                                      color: Color(0xFF0A8FDC),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: Color(0xFF6C7A89),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              // "Enter OTP Code" label
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Enter OTP Code',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // OTP boxes
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (i) {
                                  return SizedBox(
                                    width: 48,
                                    height: 56,
                                    child: TextField(
                                      controller: _controllers[i],
                                      focusNode: _focusNodes[i],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(1),
                                      ],
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFF7FBFE),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.withOpacity(0.2),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF0A8FDC),
                                            width: 1.6,
                                          ),
                                        ),
                                        counterText: '',
                                      ),
                                      onChanged: (v) => _onOtpChanged(i, v),
                                    ),
                                  );
                                }),
                              ),

                              const SizedBox(height: 18),

                              // Resend timer / link
                              Column(
                                children: [
                                  const Text(
                                    "Didn't receive the code?",
                                    style: TextStyle(color: Color(0xFF6C7A89)),
                                  ),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: _isResendAvailable
                                        ? _onResend
                                        : null,
                                    child: Text(
                                      _isResendAvailable
                                          ? 'Resend OTP'
                                          : 'Resend OTP in ${_secondsLeft}s',
                                      style: TextStyle(
                                        color: _isResendAvailable
                                            ? const Color(0xFF0A8FDC)
                                            : Colors.grey,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 22),

                              // Verify button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: (_isOtpComplete && !_isVerifying)
                                      ? _onVerify
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0A8FDC),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isVerifying
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Text(
                                              'Verify & Continue',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.check,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 18),
                            ],
                          ),
                        ),

                        // secure info box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F9FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              CircleAvatar(
                                backgroundColor: Color(0xFF0A8FDC),
                                child: Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                radius: 16,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your information is secure and encrypted.\nWe never share your personal data with third parties.',
                                  style: TextStyle(color: Color(0xFF6C7A89)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
