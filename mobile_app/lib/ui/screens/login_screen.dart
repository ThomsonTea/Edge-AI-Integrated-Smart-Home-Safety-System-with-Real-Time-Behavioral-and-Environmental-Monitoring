import 'package:flutter/material.dart';
import '../../viewmodels/login_viewmodel.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _viewModel = LoginViewModel();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _passwordController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final success = await _viewModel.login(
        username: _fullNameController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${_viewModel.errorMessage}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Home Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter your username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter your password';
                  }
                  if (value!.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: AnimatedBuilder(
                  animation: _viewModel,
                  builder: (context, child) {
                    return ElevatedButton(
                      onPressed: _viewModel.isLoading ? null : _handleLogin,
                      child: _viewModel.isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Login'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Navigate to signup screen
                },
                child: const Text('Don\'t have an account? Sign up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
