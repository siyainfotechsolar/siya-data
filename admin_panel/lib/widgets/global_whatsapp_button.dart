import 'package:flutter/material.dart';
import '../services/whatsapp_service.dart';

enum WhatsAppButtonVariant {
  floating,
  icon,
  filled,
  outlined,
}

class GlobalWhatsAppButton extends StatelessWidget {
  final String? phoneNumber;
  final String? customerName;
  final String? consumerNo;
  final String? currentStage;
  final String? defaultMessage;
  final WhatsAppButtonVariant variant;
  final String label;
  final double iconSize;

  const GlobalWhatsAppButton({
    super.key,
    this.phoneNumber,
    this.customerName,
    this.consumerNo,
    this.currentStage,
    this.defaultMessage,
    this.variant = WhatsAppButtonVariant.icon,
    this.label = 'WhatsApp',
    this.iconSize = 20,
  });

  /// Factory for Floating Action Button
  const GlobalWhatsAppButton.floating({
    super.key,
    this.phoneNumber,
    this.customerName,
    this.consumerNo,
    this.currentStage,
    this.defaultMessage,
    this.label = 'WhatsApp',
    this.iconSize = 24,
  }) : variant = WhatsAppButtonVariant.floating;

  /// Factory for Form/Header Filled Button
  const GlobalWhatsAppButton.filled({
    super.key,
    this.phoneNumber,
    this.customerName,
    this.consumerNo,
    this.currentStage,
    this.defaultMessage,
    this.label = 'Chat on WhatsApp',
    this.iconSize = 18,
  }) : variant = WhatsAppButtonVariant.filled;

  /// Factory for Outlined Button
  const GlobalWhatsAppButton.outlined({
    super.key,
    this.phoneNumber,
    this.customerName,
    this.consumerNo,
    this.currentStage,
    this.defaultMessage,
    this.label = 'WhatsApp',
    this.iconSize = 16,
  }) : variant = WhatsAppButtonVariant.outlined;

  static void openChat(
    BuildContext context, {
    String? phoneNumber,
    String? customerName,
    String? consumerNo,
    String? currentStage,
    String? defaultMessage,
  }) {
    final btn = GlobalWhatsAppButton(
      phoneNumber: phoneNumber,
      customerName: customerName,
      consumerNo: consumerNo,
      currentStage: currentStage,
      defaultMessage: defaultMessage,
    );
    btn._onPressed(context);
  }

  void _onPressed(BuildContext context) {
    if (phoneNumber != null && phoneNumber!.trim().isNotEmpty) {
      _showQuickMessageDialog(context, phoneNumber!);
    } else {
      _showManualPhoneDialog(context);
    }
  }

  void _showQuickMessageDialog(BuildContext context, String phone) {
    final templates = WhatsAppService.getStandardTemplates(
      customerName: customerName,
      consumerNo: consumerNo,
      currentStage: currentStage,
    );

    final msgController = TextEditingController(text: defaultMessage ?? templates.first.message);
    String selectedTemplateTitle = defaultMessage != null ? 'Custom' : templates.first.title;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Send WhatsApp Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      'To: ${customerName ?? "Customer"} ($phone)',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose Message Template:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedTemplateTitle,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: [
                    if (defaultMessage != null) const DropdownMenuItem(value: 'Custom', child: Text('Default / Custom Note')),
                    ...templates.map((t) => DropdownMenuItem(value: t.title, child: Text(t.title))),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setDialogState(() {
                      selectedTemplateTitle = val;
                      final found = templates.where((t) => t.title == val).toList();
                      if (found.isNotEmpty) {
                        msgController.text = found.first.message;
                      } else if (val == 'Custom' && defaultMessage != null) {
                        msgController.text = defaultMessage!;
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),
                const Text('Message Preview / Edit:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: msgController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Type your WhatsApp message here...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Open WhatsApp'),
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await WhatsAppService.launchWhatsApp(
                  phoneNumber: phone,
                  message: msgController.text,
                );
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not launch WhatsApp. Please verify the mobile number.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManualPhoneDialog(BuildContext context) {
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Text('Enter WhatsApp Number'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No mobile number recorded for ${customerName ?? "this contact"}. Please enter a 10-digit WhatsApp number to continue:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  hintText: 'e.g. 9876543210',
                  prefixText: '+91 ',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  final clean = val?.replaceAll(RegExp(r'\D'), '') ?? '';
                  if (clean.length < 10) return 'Please enter a valid 10-digit number';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final entered = phoneCtrl.text.trim();
                Navigator.pop(ctx);
                _showQuickMessageDialog(context, entered);
              }
            },
            child: const Text('Continue to WhatsApp'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case WhatsAppButtonVariant.floating:
        return FloatingActionButton.extended(
          heroTag: 'global_whatsapp_fab_${customerName ?? ""}_${phoneNumber ?? ""}',
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          elevation: 4,
          icon: Icon(Icons.chat_rounded, size: iconSize),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _onPressed(context),
        );

      case WhatsAppButtonVariant.filled:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          icon: Icon(Icons.chat_rounded, size: iconSize),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _onPressed(context),
        );

      case WhatsAppButtonVariant.outlined:
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF16A34A),
            side: const BorderSide(color: Color(0xFF25D366)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            visualDensity: VisualDensity.compact,
          ),
          icon: Icon(Icons.chat_rounded, size: iconSize, color: const Color(0xFF25D366)),
          label: Text(label),
          onPressed: () => _onPressed(context),
        );

      case WhatsAppButtonVariant.icon:
        return IconButton(
          icon: Icon(Icons.chat_rounded, size: iconSize, color: const Color(0xFF25D366)),
          tooltip: phoneNumber != null && phoneNumber!.isNotEmpty
              ? 'Chat with ${customerName ?? "Customer"} on WhatsApp'
              : 'Open WhatsApp Chat',
          onPressed: () => _onPressed(context),
        );
    }
  }
}
