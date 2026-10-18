import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/agent_master.dart';
import 'package:admin_panel/services/commission_service.dart';

void main() {
  group('Commission Agent Master CRUD Operations', () {
    test('1. Create Agent: registers agent with complete personal & banking details', () async {
      final agent = await CommissionService.createAgent(
        name: 'Sachin Tendulkar',
        mobile: '9876543210',
        email: 'sachin@solarenergy.in',
        agencyName: 'Master Blaster Solar',
        address: 'Bandra, Mumbai',
        panNumber: 'ABCDE1234Z',
        bankName: 'HDFC Bank',
        accountNumber: '50100234567890',
        ifscCode: 'HDFC0001234',
        upiId: 'sachin@okhdfc',
        isActive: true,
      );

      expect(agent.id, isNotEmpty);
      expect(agent.name, equals('Sachin Tendulkar'));
      expect(agent.mobile, equals('9876543210'));
      expect(agent.email, equals('sachin@solarenergy.in'));
      expect(agent.agencyName, equals('Master Blaster Solar'));
      expect(agent.bankName, equals('HDFC Bank'));
      expect(agent.accountNumber, equals('50100234567890'));
      expect(agent.ifscCode, equals('HDFC0001234'));
      expect(agent.upiId, equals('sachin@okhdfc'));
      expect(agent.isActive, isTrue);
      expect(agent.deleted, isFalse);
    });

    test('2. Read Agents: fetches agents with live search and active filtering', () async {
      final allAgents = await CommissionService.fetchAgents();
      expect(allAgents, isNotEmpty);
      expect(allAgents.any((a) => a.name == 'Sachin Tendulkar'), isTrue);

      // Search by agency name
      final searchResults = await CommissionService.fetchAgents(searchQuery: 'Master Blaster');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.name, equals('Sachin Tendulkar'));

      // Search by mobile
      final mobileResults = await CommissionService.fetchAgents(searchQuery: '9876543210');
      expect(mobileResults.isNotEmpty, isTrue);
      expect(mobileResults.first.name, equals('Sachin Tendulkar'));

      // Get by ID
      final byId = await CommissionService.getAgentById(allAgents.first.id);
      expect(byId, isNotNull);
      expect(byId!.id, equals(allAgents.first.id));
    });

    test('3. Update Agent: modifies existing agent profile and bank accounts', () async {
      final agents = await CommissionService.fetchAgents(searchQuery: 'Sachin Tendulkar');
      expect(agents.isNotEmpty, isTrue);
      final original = agents.first;

      final updatedModel = original.copyWith(
        name: 'Sachin R. Tendulkar',
        agencyName: 'SRT Green Ventures',
        mobile: '9876599999',
        bankName: 'State Bank of India',
        accountNumber: '333344445555',
        ifscCode: 'SBIN0001234',
      );

      final success = await CommissionService.updateAgent(updatedModel);
      expect(success, isTrue);

      // Verify update persisted
      final reloaded = await CommissionService.getAgentById(original.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.name, equals('Sachin R. Tendulkar'));
      expect(reloaded.agencyName, equals('SRT Green Ventures'));
      expect(reloaded.mobile, equals('9876599999'));
      expect(reloaded.bankName, equals('State Bank of India'));
      expect(reloaded.accountNumber, equals('333344445555'));
    });

    test('4. Toggle Active Status: deactivates and reactivates agent', () async {
      final agents = await CommissionService.fetchAgents(searchQuery: 'Sachin R. Tendulkar');
      expect(agents.isNotEmpty, isTrue);
      final agentId = agents.first.id;

      // Deactivate
      await CommissionService.toggleAgentActiveStatus(agentId, false);
      var reloaded = await CommissionService.getAgentById(agentId);
      expect(reloaded!.isActive, isFalse);

      // Filter by active only should not include deactivated agent
      final activeOnly = await CommissionService.fetchAgents(activeOnly: true);
      expect(activeOnly.any((a) => a.id == agentId), isFalse);

      // Reactivate
      await CommissionService.toggleAgentActiveStatus(agentId, true);
      reloaded = await CommissionService.getAgentById(agentId);
      expect(reloaded!.isActive, isTrue);
    });

    test('5. Delete Agent: soft deletes agent from master list', () async {
      final agents = await CommissionService.fetchAgents(searchQuery: 'Sachin R. Tendulkar');
      expect(agents.isNotEmpty, isTrue);
      final agentId = agents.first.id;

      final deleteResult = await CommissionService.deleteAgent(agentId);
      expect(deleteResult, isTrue);

      // Agent is no longer in regular fetch list
      final remainingAgents = await CommissionService.fetchAgents();
      expect(remainingAgents.any((a) => a.id == agentId), isFalse);
    });
  });
}
