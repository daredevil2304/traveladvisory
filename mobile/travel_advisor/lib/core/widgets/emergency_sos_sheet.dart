import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';

/// Floating SOS button that opens the Expressway Emergency & SOS Directory sheet.
class ExpresswaySosFloatingButton extends StatelessWidget {
  final String heroTag;

  const ExpresswaySosFloatingButton({
    super.key,
    this.heroTag = 'welcome_sos_fab',
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: () => showExpresswayEmergencySheet(context),
      backgroundColor: const Color(0xFFDC2626), // Emergency red
      foregroundColor: Colors.white,
      elevation: 6,
      icon: const Icon(Icons.emergency_rounded, color: Colors.white, size: 22),
      label: const Text(
        'SOS',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// AppBar SOS Icon Button that opens the Expressway Emergency Directory sheet.
class ExpresswaySosIconButton extends StatelessWidget {
  const ExpresswaySosIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Expressway Emergency SOS',
      icon: const Icon(
        Icons.emergency_outlined,
        color: Color(0xFFDC2626),
      ),
      onPressed: () => showExpresswayEmergencySheet(context),
    );
  }
}

/// Shows the Expressway Emergency & SOS Directory bottom sheet.
void showExpresswayEmergencySheet(BuildContext context, [dynamic emergencyDir]) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        height: MediaQuery.of(ctx).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Icon(
                      Icons.emergency_rounded,
                      color: Color(0xFFDC2626),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expressway Emergency & SOS Directory',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkNavy,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mumbai-Pune Expressway (NH-48) 24x7 Assistance',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                children: [
                  const Text(
                    '24x7 EMERGENCY DISPATCH HOTLINES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildEmergencyContactTile(
                    ctx,
                    title: 'IRB Expressway Control Room (24x7)',
                    phone: '9822498224',
                    displayPhone: '98224 98224',
                    desc: 'Ambulance, Heavy Towing Crane & Highway Patrol SOS',
                    isHighPriority: true,
                  ),
                  _buildEmergencyContactTile(
                    ctx,
                    title: 'National Highway Patrol (MSRDC)',
                    phone: '1033',
                    displayPhone: '1033',
                    desc: 'Toll-free Expressway Emergency Helpline',
                    isHighPriority: true,
                  ),
                  _buildEmergencyContactTile(
                    ctx,
                    title: 'Maharashtra Highway Police Control',
                    phone: '02025651515',
                    displayPhone: '020-25651515',
                    desc: 'State Highway Police HQ Control Room',
                    isHighPriority: false,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'NEAREST TRAUMA CARE HOSPITALS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTraumaTile(
                    ctx,
                    name: 'MGM Hospital & Medical College',
                    location: 'Kamothe / Panvel (km 34)',
                    phone: '02227437900',
                    displayPhone: '022-27437900',
                    badge: 'Level 1 Trauma',
                  ),
                  _buildTraumaTile(
                    ctx,
                    name: 'Jakhotia Trauma Care Hospital',
                    location: 'Khopoli Phata (km 70 - Ghat Base)',
                    phone: '02192263300',
                    displayPhone: '02192-263300',
                    badge: 'Ghat Entry Trauma',
                  ),
                  _buildTraumaTile(
                    ctx,
                    name: 'Sanjeevani Critical Care Hospital',
                    location: 'Lonavala (km 88 - Ghat Crest)',
                    phone: '02114273545',
                    displayPhone: '02114-273545',
                    badge: 'Mountain Crest Care',
                  ),
                  _buildTraumaTile(
                    ctx,
                    name: 'Lokmanya Hospital for Trauma',
                    location: 'Nigdi / Pune (km 138)',
                    phone: '02030717500',
                    displayPhone: '020-30717500',
                    badge: 'Neuro & Ortho Care',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'AUTHORIZED REST & FUEL PLAZAS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPlazaTile(
                    name: 'Khalapur Food Mall (Pune-bound, km 38)',
                    amenities: 'Fuel • EV Fast Chargers • Medical Kit • Food Court',
                  ),
                  _buildPlazaTile(
                    name: 'Ozarde Food Plaza (Mumbai-bound, km 78)',
                    amenities: 'Fuel • Tire Mechanics • Towing Assistance • Restrooms',
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildEmergencyContactTile(
  BuildContext ctx, {
  required String title,
  required String phone,
  required String displayPhone,
  required String desc,
  required bool isHighPriority,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isHighPriority ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isHighPriority ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isHighPriority ? const Color(0xFFDC2626) : AppTheme.darkNavy,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                displayPhone,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isHighPriority ? const Color(0xFFDC2626) : AppTheme.royalSapphire,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 20, color: AppTheme.darkNavy),
          tooltip: 'Copy Number',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: phone));
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('Copied $displayPhone to clipboard!')),
            );
          },
        ),
      ],
    ),
  );
}

Widget _buildTraumaTile(
  BuildContext ctx, {
  required String name,
  required String location,
  required String phone,
  required String displayPhone,
  required String badge,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkNavy,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.royalCobalt,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                location,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                displayPhone,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.royalCobalt,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.darkNavy),
          tooltip: 'Copy Number',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: phone));
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('Copied $name phone to clipboard!')),
            );
          },
        ),
      ],
    ),
  );
}

Widget _buildPlazaTile({required String name, required String amenities}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      children: [
        const Icon(Icons.local_gas_station_rounded, size: 20, color: AppTheme.royalCobalt),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                amenities,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
