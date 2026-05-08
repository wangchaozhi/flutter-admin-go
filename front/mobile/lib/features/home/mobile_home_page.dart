import 'package:flutter/material.dart';

class MobileHomePage extends StatelessWidget {
  const MobileHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: _HomeHeader(onLogout: () => Navigator.pushReplacementNamed(context, '/login')),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(child: _StatusPanel()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.28,
                children: [
                  _MetricCard(label: '今日访问', value: '1,284', icon: Icons.trending_up_rounded),
                  _MetricCard(label: '待处理', value: '18', icon: Icons.task_alt_rounded),
                  _MetricCard(label: '在线用户', value: '326', icon: Icons.people_alt_rounded),
                  _MetricCard(label: '系统状态', value: '稳定', icon: Icons.verified_rounded),
                ],
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 24),
              sliver: SliverToBoxAdapter(child: _QuickActions()),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '移动工作台',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '欢迎回来，今天也稳稳推进',
                style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          tooltip: '退出登录',
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1D4ED8), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
          SizedBox(height: 18),
          Text(
            '系统运行良好',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            '关键服务在线，数据同步正常，可以继续处理今日任务。',
            style: TextStyle(color: Color(0xFFDDEBFF), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '快捷入口',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.person_add_alt_1_rounded,
          title: '用户审核',
          subtitle: '查看新用户资料与状态',
          color: const Color(0xFF2563EB),
        ),
        _ActionTile(
          icon: Icons.notifications_active_rounded,
          title: '消息中心',
          subtitle: '处理待确认通知',
          color: const Color(0xFF0F766E),
        ),
        _ActionTile(
          icon: Icons.analytics_rounded,
          title: '运营数据',
          subtitle: '查看访问与活跃趋势',
          color: const Color(0xFF7C3AED),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
        ],
      ),
    );
  }
}
