import 'package:flutter/material.dart';
import 'package:houston/screens/main_screen.dart';
import '../utils/update_checker.dart';

class UpdateWrapper extends StatefulWidget {
  const UpdateWrapper({super.key});

  @override
  State<UpdateWrapper> createState() => _UpdateWrapperState();
}

class _UpdateWrapperState extends State<UpdateWrapper> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      checkForUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MainScreen();
  }
}
