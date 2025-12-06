import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String? _name;

  @override
  void initState() {
    super.initState();
    _loadUserName();

    // Precache logo to avoid image decode jank during animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/CureOne.png'), context);
    });

    // setup simple staggered animations for feature cards
    _animController = AnimationController(
      vsync: this,
      // longer duration to make the motion more noticeable and smooth
      duration: const Duration(milliseconds: 1800),
    );

    // header animations (greeting + name)
    _headerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.02, 0.28, curve: Curves.easeOutQuart),
      ),
    );
    _headerOffset =
        Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.02, 0.28, curve: Curves.easeOutQuart),
          ),
        );

    // three cards with explicit tweens for clearer opacity animation
    _cardOpacities = List.generate(3, (i) {
      final start = 0.18 * i + 0.08; // stagger a bit more
      final end = 0.68 + 0.04 * i;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(start, end, curve: Curves.easeOutQuart),
        ),
      );
    });
    _cardOffsets = List.generate(3, (i) {
      final start = 0.18 * i + 0.08;
      final end = 0.68 + 0.04 * i;
      return Tween<Offset>(
        begin: const Offset(0, 0.18),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(start, end, curve: Curves.easeOutQuart),
        ),
      );
    });
  }

  late final AnimationController _animController;
  // initialize as empty lists so hot-reload or unexpected ordering won't crash
  List<Animation<double>> _cardOpacities = <Animation<double>>[];
  List<Animation<Offset>> _cardOffsets = <Animation<Offset>>[];
  // header animations
  // ignore: unused_field
  late Animation<double> _headerOpacity;
  // ignore: unused_field
  late Animation<Offset> _headerOffset;

  Future<void> _loadUserName() async {
    try {
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber;
      if (phone == null) return;
      final phoneKey = phone.replaceAll(RegExp(r'\D'), '');
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://cureone-4e269-default-rtdb.asia-southeast1.firebasedatabase.app',
      );
      final snap = await db.ref('users/$phoneKey/name').get();
      if (snap.exists) {
        setState(() => _name = snap.value?.toString());
      }
    } catch (_) {
      // ignore errors; leave name null
    }
  }

  // Return a greeting based on local device time
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  Widget _featureCard(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return RepaintBoundary(
      // <- added
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            // reduced blur and opacity to lower GPU cost while keeping depth
            BoxShadow(
              color: color.withOpacity(0.16), // slightly reduced
              blurRadius: 14, // reduced from 22
              offset: const Offset(0, 8), // slightly smaller offset
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.28), // reduced
                      blurRadius: 8, // reduced
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF6C7A89)),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF9FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Color(0xFF0A8FDC),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // start (or restart) the animation when this widget becomes active in the tree
    // using forward(from: 0) ensures it plays each time the page is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animController.forward(from: 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (_name != null && _name!.trim().isNotEmpty)
        ? _name!.trim().split(RegExp(r'\s+'))[0]
        : 'Sarah';
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFE),
      body: SafeArea(
        child: Stack(
          children: [
            // top half gradient (matches other pages)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.45,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFD0EAFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),

            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // restore login-style centered circular logo
                  const SizedBox(height: 16),
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
                          errorBuilder: (ctx, err, stack) => const CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.medical_services,
                              color: Color(0xFF0A8FDC),
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // centered greeting and prompt
                  Text(
                    _greeting(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'What do you want to do today?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6C7A89)),
                  ),

                  const SizedBox(height: 22),

                  // animated/staggered feature cards
                  _animatedFeatureCard(
                    0,
                    context,
                    color: const Color(0xFF0A8FDC),
                    icon: Icons.person_search,
                    title: 'Book Doctor\nAppointment',
                    subtitle:
                        'Find and book appointments with\nverified doctors',
                  ),

                  _animatedFeatureCard(
                    1,
                    context,
                    color: const Color(0xFF2EC04F),
                    icon: Icons.local_pharmacy,
                    title: 'Buy Medicines',
                    subtitle:
                        'Order prescription and over-the-\ncounter medicines online',
                  ),

                  _animatedFeatureCard(
                    2,
                    context,
                    color: const Color(0xFFE94B4B),
                    icon: Icons.science,
                    title: 'Book Blood\nTest',
                    subtitle: 'Schedule lab tests and health checkups',
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedFeatureCard(
    int index,
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    // if animations aren't ready (hot-reload or init ordering), show static card
    if (index >= _cardOpacities.length || index >= _cardOffsets.length) {
      return _featureCard(
        context,
        color: color,
        icon: icon,
        title: title,
        subtitle: subtitle,
      );
    }

    // wrap the static card with Fade + Slide transitions
    return FadeTransition(
      opacity: _cardOpacities[index],
      child: SlideTransition(
        position: _cardOffsets[index],
        child: _featureCard(
          context,
          color: color,
          icon: icon,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }
}
