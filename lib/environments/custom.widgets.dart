import 'package:flutter/material.dart';
import 'package:innova/environments/environments.dart';

class CustomAlertDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool barrierDismissible;
  final double borderRadius;

  const CustomAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.barrierDismissible = false,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(0),
          topRight: const Radius.circular(0),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
      ),
      titlePadding: EdgeInsets.zero,
      actionsPadding: EdgeInsets.zero,
      title: Container(
        width: double.infinity,
        color: appColors[0],
        padding: const EdgeInsets.all(10),
        child: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 12,),
        ),
      ),
      content: content,
      actions: actions,
    );
  }
}

class CustomElevatedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const CustomElevatedButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: appColors[0],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10),),
    );
  }
}

class CustomNotification {
  static void showNotification(
      BuildContext context, String mensaje,
      {
        Color color = Colors.black,
        Duration duracion = const Duration(seconds: 2)
      }
      ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: duracion,
      ),
    );
  }
}

class CustomShowDialog extends StatelessWidget{
  final Widget child;
  final double screenWidth;
  final double maxWidthDesktop;

  const CustomShowDialog({
    super.key,
    required this.child,
    required this.screenWidth,
    required this.maxWidthDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Dialog(
          shape: const  RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(0),
              topRight: Radius.circular(0),
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
          ),
          insetPadding: const EdgeInsets.all(15),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth > 600 ? maxWidthDesktop : screenWidth * 0.95,
              minHeight: 500,
            ),
            child: child,
          ),
        );
      },
    );
  }
}