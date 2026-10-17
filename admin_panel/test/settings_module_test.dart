import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:siya_shared/siya_shared.dart';
import 'package:admin_panel/services/settings_service.dart';
import 'package:admin_panel/services/invoice_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompanySettings & CompanyMaster Unit Tests', () {
    test('Default CompanySettings provides accurate default company details', () {
      final settings = CompanySettings.defaultSettings();
      expect(settings.companyName, 'SIYA INFOTECH & DIGITAL SOLUTIONS');
      expect(settings.mobile, '7972143798');
      expect(settings.alternateMobile, '7588003220');
      expect(settings.email, 'siyainfodigital@gmail.com');
      expect(settings.gstin, '27CVTPK6358P1ZD');
      expect(settings.stateCode, '27');
      expect(settings.isSplitGstRuleEnabled, true);
    });

    test('CompanySettings converts accurately to CompanyMaster', () {
      const settings = CompanySettings(
        companyName: 'SIYA SOLAR EPC ENTERPRISE',
        address: 'Dhule Highway, Betawad, Maharashtra',
        mobile: '7972143798',
        alternateMobile: '7588003220',
        email: 'info@siyasolar.com',
        gstin: '27AABCS1429B1Z1',
      );

      final master = settings.toCompanyMaster(
        bankName: 'HDFC BANK',
        accountNo: '50200012345678',
        ifscCode: 'HDFC0001234',
        branch: 'Dhule Branch',
      );

      expect(master.companyName, 'SIYA SOLAR EPC ENTERPRISE');
      expect(master.address, 'Dhule Highway, Betawad, Maharashtra');
      expect(master.gstin, '27AABCS1429B1Z1');
      expect(master.bankName, 'HDFC BANK');
      expect(master.accountNo, '50200012345678');
      expect(master.displayPhones, '7972143798 / 7588003220');
    });

    test('CompanySettings JSON serialization and deserialization roundtrip', () {
      final original = CompanySettings.defaultSettings().copyWith(
        companyName: 'SIYA INFOTECH & SOLAR TECH',
        quotationPrefix: 'CUSTOM-Q-',
        invoicePrefix: 'CUSTOM-INV-',
        quotationValidityDays: 45,
        isSplitGstRuleEnabled: false,
      );

      final jsonMap = original.toJson();
      final reconstructed = CompanySettings.fromJson(jsonMap);

      expect(reconstructed.companyName, 'SIYA INFOTECH & SOLAR TECH');
      expect(reconstructed.quotationPrefix, 'CUSTOM-Q-');
      expect(reconstructed.invoicePrefix, 'CUSTOM-INV-');
      expect(reconstructed.quotationValidityDays, 45);
      expect(reconstructed.isSplitGstRuleEnabled, false);
    });

    test('CompanyBankAccount masking and JSON serialization', () {
      const acc = CompanyBankAccount(
        id: 'acc-1',
        bankName: 'STATE BANK OF INDIA',
        accountHolderName: 'SIYA INFOTECH & DIGITAL SOLUTIONS',
        accountNo: '40662252403',
        ifscCode: 'SBIN0004798',
        branch: 'Betawad',
        isDefault: true,
      );

      expect(acc.maskedAccountNo, '•••• •••• 2403');

      final json = acc.toJson();
      final reconstructed = CompanyBankAccount.fromJson(json);
      expect(reconstructed.accountNo, '40662252403');
      expect(reconstructed.isDefault, true);
    });

    test('MasterDataHub synchronization updates active master data', () {
      const customMaster = CompanyMaster(
        companyName: 'SIYA TEST SOLAR CORP',
        mobile: '7972143798',
        alternateMobile: '7588003220',
        gstin: '27AABCS9999P1Z9',
      );

      MasterDataHub.setCompanyMaster(customMaster);

      expect(MasterDataHub.company.companyName, 'SIYA TEST SOLAR CORP');
      expect(MasterDataHub.company.gstin, '27AABCS9999P1Z9');
      expect(MasterDataHub.company.displayPhones, '7972143798 / 7588003220');

      // Reset back to default
      MasterDataHub.setCompanyMaster(CompanyMaster.defaultMaster());
      expect(MasterDataHub.company.companyName, 'SIYA INFOTECH & DIGITAL SOLUTIONS');
    });

    test('SettingsService permission checks adhere to RBAC hierarchy', () {
      // Super Admin / Admin
      expect(SettingsService.canManageSettings({'role': 'admin'}, 'admin'), true);
      expect(SettingsService.canManageSettings({'role': 'super_admin'}, 'super_admin'), true);
      expect(SettingsService.canManageSettings({'role': 'owner'}, 'owner'), true);

      // Staff without explicit settings permission
      expect(SettingsService.canManageSettings({'role': 'staff'}, 'staff'), false);

      // Staff with granular settings permissions
      final staffWithPerms = {
        'role': 'staff',
        'permissions': {
          'settings': ['view', 'manage'],
        },
      };
      expect(SettingsService.canManageSettings(staffWithPerms, 'staff'), true);

      // Sensitive bank masking permission
      expect(SettingsService.canViewSensitiveBankDetails({'role': 'admin'}, 'admin'), true);
      expect(SettingsService.canViewSensitiveBankDetails({'role': 'accounts'}, 'accounts'), true);
      expect(SettingsService.canViewSensitiveBankDetails({'role': 'staff'}, 'staff'), false);
    });

    test('Base64 image processor converts and decodes bytes without data loss', () async {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final dataUri = await SettingsService.processImageForStorage(sampleBytes, 'image/png');
      expect(dataUri.startsWith('data:image/png;base64,'), true);

      final decoded = SettingsService.decodeImageFromDataUri(dataUri);
      expect(decoded, equals(sampleBytes));
    });

    test('Newly generated PDF uses current MasterDataHub company settings', () async {
      final testMaster = CompanyMaster(
        companyName: 'SIYA GREEN ENERGY PRIVATE LIMITED',
        address: 'Sector 5, Solar Tech Park, Maharashtra',
        mobile: '7972143798',
        alternateMobile: '7588003220',
        gstin: '27AABCS1234F1Z5',
        bankName: 'BANK OF MAHARASHTRA',
        accountNo: '60012345678',
        ifscCode: 'MAHB0000123',
        branch: 'Sindkheda',
      );
      MasterDataHub.setCompanyMaster(testMaster);

      final testInvoice = Invoice(
        id: 'test-inv-1',
        invoiceNumber: 'INV-2026-TEST',
        refInvoiceNo: 'QUOT-TEST-001',
        customerId: 'cust-1',
        consumerNo: '123456789012',
        customerName: 'Shri Manoj Patil',
        address: 'Betawad, Tal. Sindkheda',
        villageCity: 'Betawad',
        district: 'Dhule',
        mobileNo: '9876543210',
        invoiceDate: DateTime.now(),
        items: const [
          {
            'description': '3 kW Rooftop Solar PV System',
            'hsn': '8466',
            'qty': '1',
            'rate': '100000.00',
            'amount': '100000.00',
          }
        ],
        amountInWords: 'One Lakh Eight Thousand Nine Hundred Rupees Only',
        taxableAmount: 100000,
        gst5: 3500,
        gst18: 5400,
        totalGst: 8900,
        grandTotal: 108900,
      );

      final pdfBytes = await InvoicePdfService.generateInvoicePdfBytes(testInvoice);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, true);

      // Reset back to default
      MasterDataHub.setCompanyMaster(CompanyMaster.defaultMaster());
    });
  });
}
