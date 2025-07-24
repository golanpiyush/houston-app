import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/screens/main_screen.dart';
import 'package:houston/utils/update_checker.dart';

class UpdateWrapper extends ConsumerStatefulWidget {
  const UpdateWrapper({super.key});

  @override
  ConsumerState<UpdateWrapper> createState() => _UpdateWrapperState();
}

class _UpdateWrapperState extends ConsumerState<UpdateWrapper> {
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdateSafely();
    });
  }

  Future<void> _checkForUpdateSafely() async {
    if (_isCheckingUpdate || !mounted) return;

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      await checkForUpdate(context, ref);
    } catch (e) {
      debugPrint('Update check error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MainScreen();
  }
}
