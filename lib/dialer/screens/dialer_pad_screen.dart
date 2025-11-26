import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/dialer_pad_controller.dart';

/// Dialer Pad Screen with Material 3, large circular gray buttons
class DialerPadScreen extends ConsumerWidget {
  const DialerPadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dialerState = ref.watch(dialerPadControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dial Pad')),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            dialerState.enteredNumber,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                String label;
                if (index < 9){ label = "${index + 1}";}
                else if (index == 9) {label = "*";}
                else if (index == 10){ label = "0";}
                else {label = "#";}

                return _DialButton(
                  label: label,
                  onTap: () => ref.read(dialerPadControllerProvider.notifier)
                      .addDigit(label),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.backspace),
                  iconSize: 32,
                  onPressed: () => ref
                      .read(dialerPadControllerProvider.notifier)
                      .deleteDigit(),
                ),
                const SizedBox(width: 40),
             FloatingActionButton(
                    backgroundColor: Colors.green,
                    onPressed: () {
                     ref.read(dialerPadControllerProvider.notifier)
                        .placeCall(context, number: dialerState.enteredNumber);

                    },
                    child: const Icon(Icons.call),
                  ),


              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual dial button (Material 3, light gray)
class _DialButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DialButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
