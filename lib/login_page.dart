import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final username = _usernameCtrl.text.trim();
      final inputPassword =
          _passwordCtrl.text; // For demo only (prefer hashing!)

      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _error = 'User not found');
        return;
      }

      final data = query.docs.first.data();
      final storedPassword = data['password']; // Expect plain or hashed

      if (storedPassword == null) {
        setState(() => _error = 'User data invalid');
        return;
      }

      // Simple comparison (if you store hash, compare hash of inputPassword)
      if (storedPassword != inputPassword) {
        setState(() => _error = 'Incorrect password');
        return;
      }

      // Get user type and redirect accordingly
      final userType = data['userType']?.toString() ?? 'admin';

      if (!mounted) return;

      // Navigate all user types to HomeScreen - it will handle the specific UI based on userType
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(username: username, userType: userType),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Login failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade800,
                  Colors.blue.shade500,
                  Colors.white,
                ],
                stops: const [0.0, 0.55, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Light overlay shapes
          Positioned(
            top: -120,
            right: -60,
            child: _CircleBlur(
              radius: 220,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -40,
            child: _CircleBlur(
              radius: 180,
              color: Colors.blue.shade200.withValues(alpha: 0.25),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 40,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payments_rounded,
                                size: 44,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pay Flow',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.blue.shade800,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Secure sign in',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _usernameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter username'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _passwordCtrl,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                            obscureText: _obscure,
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter password'
                                : null,
                            onFieldSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading ? null : () {},
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.errorContainer.withValues(
                                  alpha: 0.35,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: cs.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: cs.error,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          _GradientButton(
                            onTap: _loading ? null : _login,
                            label: 'Sign In',
                            icon: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                  ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Text(
                              'Version 1.0.3',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Removed previous _LoggedInScreen that depended on FirebaseAuth.

// Decorative blurred circle
class _CircleBlur extends StatelessWidget {
  final double radius;
  final Color color;
  const _CircleBlur({required this.radius, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius,
      height: radius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        // Could add blur using BackdropFilter in more complex scenario
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final Widget? icon;
  const _GradientButton({required this.onTap, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final gradient = LinearGradient(
      colors: enabled
          ? [Colors.blue.shade700, Colors.blue.shade500, Colors.blue.shade400]
          : [Colors.blueGrey.shade300, Colors.blueGrey.shade200],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: enabled ? 1 : .6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade800.withValues(alpha: .35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 10)],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
