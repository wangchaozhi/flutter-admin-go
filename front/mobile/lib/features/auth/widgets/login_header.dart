import 'package:flutter/material.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE85D75), Color(0xFFEF9A62)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33E85D75),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              '心遇',
              style: textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          '欢迎回来',
          style: textTheme.headlineMedium?.copyWith(
            color: const Color(0xFF111827),
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '用真实资料认识认真生活的人，互相喜欢后再开始聊天。',
          style: textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
