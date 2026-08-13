import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/hostel_models.dart';

class HostelInventoryScreen extends StatefulWidget {
  const HostelInventoryScreen({
    super.key,
    required this.buildings,
    this.onBack,
  });

  final List<HostelBuilding> buildings;
  final VoidCallback? onBack;

  @override
  State<HostelInventoryScreen> createState() => _HostelInventoryScreenState();
}

class _HostelInventoryScreenState extends State<HostelInventoryScreen> {
  late HostelBuilding _selectedBuilding;

  @override
  void initState() {
    super.initState();
    _selectedBuilding = widget.buildings.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null ? BackButton(onPressed: widget.onBack) : null,
        title: const Text('Hostel Inventory & Beds'),
      ),
      body: Column(
        children: [
          // Hostel Selector Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text(
                  'Select Building: ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<HostelBuilding>(
                        value: _selectedBuilding,
                        isExpanded: true,
                        items: widget.buildings.map((b) {
                          return DropdownMenuItem(
                            value: b,
                            child: Text(
                              '${b.name} (${b.occupiedBeds}/${b.totalBeds} Beds)',
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedBuilding = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Inventory Hierarchy View
          Expanded(
            child: _selectedBuilding.blocks.isEmpty
                ? const Center(child: Text('No blocks configured for this hostel.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _selectedBuilding.blocks.length,
                    itemBuilder: (context, bIndex) {
                      final block = _selectedBuilding.blocks[bIndex];
                      return _buildBlockCard(context, block);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockCard(BuildContext context, HostelBlock block) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.location_city, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  block.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Floors & Rooms
            ...block.floors.map((floor) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Floor ${floor.floorNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: floor.rooms.map((room) {
                      return _buildRoomTile(context, room);
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTile(BuildContext context, HostelRoom room) {
    final statusColor = switch (room.status) {
      RoomStatus.available => Colors.green,
      RoomStatus.partiallyOccupied => Colors.orange,
      RoomStatus.full => Colors.red,
      RoomStatus.maintenance => Colors.grey,
      RoomStatus.blocked => Colors.purple,
    };

    return Container(
      width: 155,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Room ${room.roomNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          Text(
            '${room.type} · ${room.status.label}',
            style: TextStyle(
              fontSize: 10,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Bed level details
          Column(
            children: room.beds.map((bed) {
              final isOcc = bed.status == BedStatus.occupied;
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: isOcc ? Colors.grey.shade200 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bed_outlined,
                      size: 12,
                      color: isOcc ? Colors.grey.shade700 : Colors.green.shade800,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${bed.code}: ${isOcc ? (bed.occupantName ?? "Occupied") : "VACANT"}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isOcc ? FontWeight.normal : FontWeight.bold,
                          color: isOcc ? Colors.grey.shade800 : Colors.green.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
