import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
      ),
      titlePadding: EdgeInsets.zero,
      actionsPadding: EdgeInsets.zero,
      title: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: appColors[0],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(borderRadius),
            topRight: Radius.circular(borderRadius),
          )
        ),
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

class CustomDropdownButtonFormField<T> extends StatelessWidget {
  final dynamic value;
  final List<T> items;
  final String label;
  final String? Function(dynamic)? validator;
  final void Function(dynamic)? onChanged;
  final String Function(T) itemAsString;
  final dynamic Function(T) itemValue;

  const CustomDropdownButtonFormField({
    super.key,
    required this.items,
    required this.label,
    required this.itemAsString,
    required this.itemValue,
    this.value,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      child: DropdownButtonFormField<dynamic>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 10, color: Colors.black),
          contentPadding: const EdgeInsets.all(10),
          border: InputBorder.none,
        ),
        icon: const SizedBox.shrink(),
        items: items.map((T item) {
          return DropdownMenuItem<dynamic>(
            value: itemValue(item),
            child: Text(
              itemAsString(item),
              style: const TextStyle(fontSize: 10, color: Colors.black),
            ),
          );
        }).toList(),
        iconSize: 0.0,
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final String? label;
  final TextEditingController? controller;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? child;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool isDate;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;

  const CustomTextField({
    super.key,
    this.label,
    this.controller,
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
    this.child,
    this.firstDate,
    this.lastDate,
    this.isDate = false,
    this.onChanged,
    this.prefixIcon
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              /*boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],*/
            ),
            child: child ?? TextField(
              style: const TextStyle(fontSize: 10, color: Colors.black),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(fontSize: 10, color: Colors.black),
                prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: appColors[0], size: 20,) : null,
                contentPadding: prefixIcon == null ? const EdgeInsets.all(10) : null,
                border: InputBorder.none,
              ),
              controller: controller,
              onChanged: onChanged,
              enabled: enabled,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              readOnly: readOnly,
              onTap: isDate ? () => _pickDate(context) : onTap,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    if (controller == null) return;

    final now = DateTime.now();

    final DateTime initialDate =
    controller!.text.isNotEmpty
        ? DateTime.parse(controller!.text)
        : (firstDate ?? DateTime(now.year, 1, 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: lastDate ?? DateTime(now.year + 5),
    );

    if (pickedDate != null) {
      controller!.text =
      "${pickedDate.year.toString().padLeft(4, '0')}-"
          "${pickedDate.month.toString().padLeft(2, '0')}-"
          "${pickedDate.day.toString().padLeft(2, '0')}";
    }
  }
}

