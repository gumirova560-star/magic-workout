import 'package:flutter/material.dart';
import '../services/energy_service.dart';
import '../services/energy_refresh_notifier.dart';
import '../screens/energy/energy_screen.dart';

class EnergyBadge extends StatefulWidget {
  final int profileId;

  const EnergyBadge({super.key, required this.profileId});

  @override
  State<EnergyBadge> createState() => _EnergyBadgeState();
}

class _EnergyBadgeState extends State<EnergyBadge> {
  int _balance = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    EnergyRefreshNotifier.ticker.addListener(_loadBalance);
    _loadBalance();
  }

  @override
  void dispose() {
    EnergyRefreshNotifier.ticker.removeListener(_loadBalance);
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final b = await EnergyService.getBalance(widget.profileId);
    if (!mounted) return;
    setState(() {
      _balance = b;
      _loading = false;
    });
  }

  Future<void> _openScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnergyScreen(profileId: widget.profileId),
      ),
    );
    _loadBalance();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: InkWell(
        onTap: _openScreen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 4),
              _loading
                  ? SizedBox(
                width: 20,
                height: 14,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: Colors.amber.shade400,
                ),
              )
                  : Text(
                '$_balance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}