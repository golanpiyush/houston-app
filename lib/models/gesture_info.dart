/// Gesture direction enum
enum GestureDirection { up, down, left, right }

/// Gesture information class
class GestureInfo {
  final GestureDirection direction;
  final double strength;
  final bool isValid;
  final bool isStrong;
  final String? reason;

  GestureInfo({
    required this.direction,
    required this.strength,
    required this.isValid,
    this.isStrong = false,
    this.reason,
  });

  factory GestureInfo.invalid(String reason) {
    return GestureInfo(
      direction: GestureDirection.up,
      strength: 0,
      isValid: false,
      reason: reason,
    );
  }
}
