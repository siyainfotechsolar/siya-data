import 'package:flutter/material.dart';
import 'package:siya_shared/siya_shared.dart';
import '../services/sub_vendor_material_outward_service.dart';

/// Shared Searchable Material Master Picker Dialog connected to the central
/// `solar_cost_material_master` database table across the entire application.
/// Supports searching existing materials and adding new custom materials.
Future<MaterialMasterItem?> showCentralMaterialPickerDialog(
  BuildContext context, {
  List<MaterialMasterItem>? initialMaterials,
  MaterialMasterItem? currentSelection,
  String defaultUnit = 'NOS',
  double defaultRate = 0.0,
}) async {
  final materials = List<MaterialMasterItem>.from(
    initialMaterials ?? await SubVendorMaterialOutwardService.fetchMaterialMaster(),
  );

  if (!context.mounted) return null;

  final searchCtrl = TextEditingController();
  String query = '';
  MaterialMasterItem? result;

  const Color navyColor = Color(0xFF0D2B6F);
  const Color greenColor = Color(0xFF059669);

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDlgState) {
          final filtered = materials.where((m) {
            if (query.isEmpty) return true;
            final q = query.toLowerCase();
            return m.itemName.toLowerCase().contains(q) || m.category.toLowerCase().contains(q);
          }).toList();

          final exactExists = query.trim().isNotEmpty &&
              materials.any((m) => m.itemName.toLowerCase() == query.trim().toLowerCase());

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.search, color: navyColor),
                SizedBox(width: 8),
                Text('Select or Add Central Material'),
              ],
            ),
            content: SizedBox(
              width: 480,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Type material name to search or add...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                setDlgState(() => query = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => setDlgState(() => query = val),
                  ),
                  const SizedBox(height: 12),
                  if (query.trim().isNotEmpty && !exactExists)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: Text('Add "${query.trim()}" to Central Material Master'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: greenColor,
                            side: const BorderSide(color: greenColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            final newMat = await SubVendorMaterialOutwardService.addMaterialToMaster(
                              itemName: query.trim(),
                              unit: defaultUnit,
                              defaultRate: defaultRate,
                            );
                            if (initialMaterials != null && !initialMaterials.any((m) => m.id == newMat.id)) {
                              initialMaterials.add(newMat);
                            }
                            result = newMat;
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching material found. Type a name above to add it.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final m = filtered[index];
                              final isSelected = currentSelection?.id == m.id;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: navyColor.withValues(alpha: 0.06),
                                title: Text(m.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: m.category.isNotEmpty
                                    ? Text('${m.category} • Unit: ${m.unit}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))
                                    : null,
                                trailing: isSelected ? const Icon(Icons.check_circle, color: greenColor, size: 18) : null,
                                onTap: () {
                                  result = m;
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      );
    },
  );

  searchCtrl.dispose();
  return result;
}
