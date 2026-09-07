import 'package:url_launcher/url_launcher.dart';

class WhatsAppTemplate {
  final String title;
  final String message;

  const WhatsAppTemplate({required this.title, required this.message});
}

class WhatsAppService {
  /// Clean and format Indian / international phone numbers for WhatsApp
  static String? cleanPhoneNumber(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    
    // Remove all non-digits
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    // Handle 10-digit Indian numbers without country code
    if (digits.length == 10) {
      return '91$digits';
    }

    // Handle numbers starting with 0
    if (digits.length == 11 && digits.startsWith('0')) {
      return '91${digits.substring(1)}';
    }

    // Handle numbers already having 91
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits;
    }

    return digits;
  }

  /// Launch WhatsApp with phone number and optional message
  static Future<bool> launchWhatsApp({
    required String? phoneNumber,
    String? message,
  }) async {
    final cleanedPhone = cleanPhoneNumber(phoneNumber);
    if (cleanedPhone == null || cleanedPhone.isEmpty) return false;

    final encodedMessage = message != null && message.trim().isNotEmpty
        ? Uri.encodeComponent(message.trim())
        : null;

    final urlString = encodedMessage != null
        ? 'https://wa.me/$cleanedPhone?text=$encodedMessage'
        : 'https://wa.me/$cleanedPhone';

    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(uri);
      }
    } catch (e) {
      // Fallback: try web.whatsapp.com for desktop browsers
      final webUri = Uri.parse(
        encodedMessage != null
            ? 'https://api.whatsapp.com/send?phone=$cleanedPhone&text=$encodedMessage'
            : 'https://api.whatsapp.com/send?phone=$cleanedPhone',
      );
      try {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }

  /// Predefined business message templates for solar consumers and leads
  static List<WhatsAppTemplate> getStandardTemplates({
    String? customerName,
    String? consumerNo,
    String? currentStage,
  }) {
    final name = customerName != null && customerName.isNotEmpty ? customerName : 'Customer';
    final cNo = consumerNo != null && consumerNo.isNotEmpty ? ' (Consumer No: $consumerNo)' : '';
    final stage = currentStage != null && currentStage.isNotEmpty ? currentStage : 'PM Surya Ghar Solar Application';

    return [
      WhatsAppTemplate(
        title: 'Greeting & Introduction',
        message: 'Namaste $name$cNo,\n\nGreetings from Siya Infotech & Solar Energy! How can we assist you with your rooftop solar project today?',
      ),
      WhatsAppTemplate(
        title: 'Stage Status Update',
        message: 'Hello $name$cNo,\n\nThis is an update regarding your solar application. Your current status is: "$stage". Our team is actively processing your file.\n\nPlease feel free to reach out if you have any questions.\n\nThank you,\nSiya Solar Team',
      ),
      WhatsAppTemplate(
        title: 'Document Request',
        message: 'Namaste $name$cNo,\n\nTo proceed with your solar application ($stage), we kindly request you to share the following pending documents:\n1. Latest Electricity Bill\n2. Aadhaar Card Copy\n3. Property / Tax Receipt\n\nThank you,\nSiya Solar Team',
      ),
      WhatsAppTemplate(
        title: 'Subsidy & RTS Update',
        message: 'Hello $name$cNo,\n\nGreat news! Your solar rooftop installation is progressing towards Net-Metering (RTS) and Government Subsidy approval.\n\nOur team is working with MSEDCL on your meter and portal approvals.\n\nBest regards,\nSiya Solar Team',
      ),
      WhatsAppTemplate(
        title: 'Payment Reminder / Receipt',
        message: 'Namaste $name$cNo,\n\nThis is a friendly reminder from Siya Solar regarding your project balance. Kindly let us know once the payment transaction is completed so we can update your official receipt.\n\nThank you,\nSiya Solar Team',
      ),
    ];
  }
}
