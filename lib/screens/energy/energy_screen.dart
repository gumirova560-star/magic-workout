import 'package:flutter/material.dart';
import '../../services/energy_service.dart';
import '../../services/energy_refresh_notifier.dart';

class EnergyScreen extends StatefulWidget {
  final int profileId;

  const EnergyScreen({super.key, required this.profileId});

  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen> {
  int _balance = 0;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    EnergyRefreshNotifier.ticker.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    EnergyRefreshNotifier.ticker.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final b = await EnergyService.getBalance(widget.profileId);
      final h = await EnergyService.getHistory(widget.profileId, limit: 100);
      if (!mounted) return;
      setState(() {
        _balance = b;
        _history = h;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки энергии: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Жизненная энергия')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 24),
            if (_history.isEmpty)
              _buildEmpty()
            else ...[
              const Text(
                'История',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ..._history.map(_buildTransaction),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade400, Colors.amber.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Жизненная энергия',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white, size: 48),
              const SizedBox(width: 8),
              Text(
                '$_balance',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Зарабатывай энергию, выполняя челленджи\nи тренировки',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.bolt_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('Пока пусто', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Выполни первый челлендж дня,\nчтобы получить энергию',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTransaction(Map<String, dynamic> tx) {
    final delta = (tx['delta'] as int?) ?? 0;
    final reason = (tx['reason'] as String?) ?? '';
    final createdAt = (tx['createdAt'] as String?) ?? '';
    final isPositive = delta >= 0;

    final meta = _reasonMeta(reason);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(meta['icon'] as IconData,
                color: isPositive ? Colors.green : Colors.red, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta['label'] as String,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}$delta ⚡️',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _reasonMeta(String reason) {
    switch (reason) {
      case 'challenge_completed':
        return {'icon': Icons.local_fire_department_rounded, 'label': 'Челлендж выполнен'};
      case 'workout_completed':
        return {'icon': Icons.fitness_center_rounded, 'label': 'Тренировка завершена'};
      case 'daily_login':
        return {'icon': Icons.login_rounded, 'label': 'Ежедневный вход'};
      case 'yoga_completed':
        return {'icon': Icons.self_improvement_rounded, 'label': 'Йога'};
      default:
        return {'icon': Icons.bolt_rounded, 'label': 'Начисление'};
    }
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${months[d.month - 1]}, $hh:$mm';
    } catch (_) {
      return iso;
    }
  }
}