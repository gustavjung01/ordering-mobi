import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

class CustomerSignInScreen extends StatelessWidget {
  const CustomerSignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 480),
              child: ClerkAuthentication(),
            ),
          ),
        ),
      ),
    );
  }
}
