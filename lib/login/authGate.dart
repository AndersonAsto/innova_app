import 'package:flutter/material.dart';

class SessionService {
  static Map<String, dynamic>? profile;
  static bool get isManager => profile?['role'] != null;
  static bool get isIntern => profile?['internship_start_date'] != null;
}