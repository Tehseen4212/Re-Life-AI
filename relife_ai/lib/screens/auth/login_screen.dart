import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      await context.read<AuthProvider>().signIn(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );
      if (mounted) {
        context.go('/');
      }
    } on AuthException catch (e) {
      if (mounted) {
        String errorMsg = e.message;
        if (errorMsg.toLowerCase().contains('invalid login credentials') || errorMsg.toLowerCase().contains('user_not_found')) {
           errorMsg = 'Incorrect email or password.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.white,
            content: Row(
              children: [
                Container(width: 4, height: 40, color: AppTheme.errorColor, margin: const EdgeInsets.only(right: 12)),
                Expanded(child: Text(errorMsg, style: const TextStyle(color: AppTheme.textMainColor))),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'An unexpected error occurred. Please try again.';
        if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
            errorMsg = 'No internet connection. Please check your network.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.white,
            content: Row(
              children: [
                Container(width: 4, height: 40, color: AppTheme.errorColor, margin: const EdgeInsets.only(right: 12)),
                Expanded(child: Text(errorMsg, style: const TextStyle(color: AppTheme.textMainColor))),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_emailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your email address first', style: TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        )
      );
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().supabase.auth.resetPasswordForEmail(_emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password reset link sent to your email!', style: TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message, style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'An unexpected error occurred. Please try again.';
        if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
            errorMsg = 'No internet connection. Please try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg, style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Gradient Section
            Container(
              height: MediaQuery.of(context).size.height * 0.40,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.eco, color: AppTheme.primaryColor, size: 32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ReLife AI',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reduce waste. Feed communities.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFFC4B5FD),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // White Body Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Welcome back',
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textMainColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to continue',
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondaryColor),
                  ),
                  const SizedBox(height: 32),
                  
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textSecondaryColor),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passCtrl,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondaryColor),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF9CA3AF)),
                        onPressed: () => setState(() => _obscureText = !_obscureText),
                      ),
                    ),
                    obscureText: _obscureText,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      child: Text('Forgot Password?', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Primary CTA
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFF3F4F6))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('or continue with', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor)),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFF3F4F6))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?", style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondaryColor)),
                      TextButton(
                        onPressed: () => context.push('/signup'),
                        child: Text('Sign Up', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
