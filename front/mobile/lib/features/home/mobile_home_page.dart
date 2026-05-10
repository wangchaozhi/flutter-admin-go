import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/api_client.dart';
import '../auth/login_storage.dart';

class MobileHomePage extends StatefulWidget {
  const MobileHomePage({super.key});

  @override
  State<MobileHomePage> createState() => _MobileHomePageState();
}

class _MobileHomePageState extends State<MobileHomePage> {
  int _tabIndex = 0;
  bool _loading = true;
  bool _usingApi = true;
  String _token = '';
  String _loadError = '';
  DatingProfile _profile = DatingProfile.empty();
  final List<Candidate> _candidates = [];
  final Set<int> _likedIds = {};
  final Set<int> _skippedIds = {};
  final List<MatchChat> _matches = [];
  RecommendationFilter _filter = const RecommendationFilter();

  int get _totalUnreadCount =>
      _matches.fold(0, (total, match) => total + match.unreadCount);

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  List<Candidate> get _visibleCandidates {
    return _candidates.where((candidate) {
      if (_skippedIds.contains(candidate.id)) return false;
      if (_filter.city != '全部' && candidate.city != _filter.city) return false;
      if (_filter.verifiedOnly && !candidate.verified) return false;
      return candidate.matchScore >= _filter.minScore;
    }).toList();
  }

  Future<void> _loadState() async {
    _token = await LoginStorage().loadToken();
    if (_token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '请先登录账号，再查看推荐与消息';
      });
      return;
    }
    try {
      await _loadRemoteState();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '暂时无法连接服务：$err';
      });
    }
  }

  Future<void> _loadRemoteState() async {
    final api = ApiClient();
    final filterQuery =
        '?city=${Uri.encodeQueryComponent(_filter.city)}&minScore=${_filter.minScore}&verifiedOnly=${_filter.verifiedOnly}';
    final responses = await Future.wait([
      api.get('/api/mobile/profile', token: _token),
      api.get('/api/mobile/recommendations$filterQuery', token: _token),
      api.get('/api/mobile/matches', token: _token),
    ]);

    final profileData = responses[0]['data'] as Map<String, dynamic>? ?? {};
    final recommendationData = responses[1]['data'] as List<dynamic>? ?? [];
    final matchData = responses[2]['data'] as List<dynamic>? ?? [];

    if (!mounted) return;
    setState(() {
      _profile = DatingProfile.fromJson(profileData);
      _candidates
        ..clear()
        ..addAll(
          recommendationData.whereType<Map<String, dynamic>>().map(
            Candidate.fromJson,
          ),
        );
      _matches
        ..clear()
        ..addAll(
          matchData
              .whereType<Map<String, dynamic>>()
              .map((item) => MatchChat.fromJson(item, _candidates))
              .whereType<MatchChat>(),
        );
      _usingApi = true;
      _loading = false;
      _loadError = '';
    });
  }

  void _like(Candidate candidate) async {
    if (_likedIds.contains(candidate.id)) return;
    final resp = await ApiClient().post('/api/mobile/likes', {
      'targetUserId': candidate.id,
    }, token: _token);
    final data = resp['data'] as Map<String, dynamic>? ?? {};
    final matchData = data['match'] as Map<String, dynamic>?;
    if (matchData != null) {
      final match = MatchChat.fromJson(matchData, _candidates);
      if (match != null && !_matches.any((item) => item.id == match.id)) {
        setState(() => _matches.add(match));
      }
    }
    setState(() {
      _likedIds.add(candidate.id);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          candidate.likesMe ? '你们已互相喜欢，可以开始聊天了' : '已向 ${candidate.name} 表达喜欢',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _skip(Candidate candidate) async {
    await ApiClient().post('/api/mobile/passes', {
      'targetUserId': candidate.id,
    }, token: _token);
    setState(() => _skippedIds.add(candidate.id));
  }

  void _saveProfile(DatingProfile profile) async {
    final resp = await ApiClient().put(
      '/api/mobile/profile',
      profile.toJson()..remove('photos'),
      token: _token,
    );
    final data = resp['data'] as Map<String, dynamic>? ?? {};
    profile = DatingProfile.fromJson(data);
    if (!mounted) return;
    setState(() => _profile = profile);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('资料已保存，推荐会随资料更新'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openChat(MatchChat match) async {
    setState(() => match.unreadCount = 0);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatPage(match: match, token: _token, usingApi: _usingApi),
      ),
    );
    setState(() {});
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('个人资料')),
          body: SafeArea(
            child: ProfilePage(
              profile: _profile,
              token: _token,
              onSave: _saveProfile,
            ),
          ),
        ),
      ),
    );
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        var draft = _filter;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '筛选推荐',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: draft.city,
                    decoration: const InputDecoration(labelText: '所在城市'),
                    items: const ['全部', '上海', '杭州', '苏州', '南京']
                        .map(
                          (city) =>
                              DropdownMenuItem(value: city, child: Text(city)),
                        )
                        .toList(),
                    onChanged: (value) => setSheetState(
                      () => draft = draft.copyWith(city: value ?? '全部'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('最低匹配度 ${draft.minScore}%'),
                  Slider(
                    value: draft.minScore.toDouble(),
                    min: 0,
                    max: 95,
                    divisions: 19,
                    label: '${draft.minScore}%',
                    onChanged: (value) => setSheetState(
                      () => draft = draft.copyWith(minScore: value.round()),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    value: draft.verifiedOnly,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('只看已认证用户'),
                    onChanged: (value) => setSheetState(
                      () => draft = draft.copyWith(verifiedOnly: value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _filter = draft);
                      _loadRemoteState();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('查看结果'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    await LoginStorage().clearToken();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('心遇')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 42,
                  color: Color(0xFFE85D75),
                ),
                const SizedBox(height: 12),
                Text(_loadError, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _loadError = '';
                    });
                    _loadState();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重新加载'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = [
      RecommendPage(
        candidates: _visibleCandidates,
        likedIds: _likedIds,
        activeFilter: _filter,
        onLike: _like,
        onSkip: _skip,
        onOpenFilters: _openFilters,
        onRefresh: _loadRemoteState,
      ),
      MatchPage(matches: _matches, onOpenChat: _openChat),
      ChatListPage(matches: _matches, onOpenChat: _openChat),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('心遇'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '我的',
            onSelected: (value) {
              if (value == 'profile') {
                _openProfile();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.badge_rounded),
                  title: Text('个人资料'),
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_rounded),
                  title: Text('退出登录'),
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE85D75),
                child: Text(
                  _profile.name.isNotEmpty
                      ? _profile.name.characters.first
                      : '我',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: pages[_tabIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: '推荐',
          ),
          const NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group_rounded),
            label: '匹配',
          ),
          NavigationDestination(
            icon: _NavBadge(
              count: _totalUnreadCount,
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            selectedIcon: _NavBadge(
              count: _totalUnreadCount,
              child: const Icon(Icons.chat_bubble_rounded),
            ),
            label: '消息',
          ),
        ],
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Badge(label: Text(count > 99 ? '99+' : '$count'), child: child);
  }
}

enum PhotoStatus {
  pending('审核中', Color(0xFFF59E0B)),
  approved('已认证', Color(0xFF059669)),
  rejected('需重传', Color(0xFFDC2626));

  const PhotoStatus(this.label, this.color);

  final String label;
  final Color color;

  static PhotoStatus parse(String? value) {
    if (value == 'approved') return PhotoStatus.approved;
    if (value == 'rejected') return PhotoStatus.rejected;
    if (value == 'pending') return PhotoStatus.pending;
    return PhotoStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PhotoStatus.pending,
    );
  }
}

class ProfilePhoto {
  const ProfilePhoto({
    required this.id,
    required this.label,
    required this.status,
  });

  final String id;
  final String label;
  final PhotoStatus status;

  ProfilePhoto copyWith({String? id, String? label, PhotoStatus? status}) {
    return ProfilePhoto(
      id: id ?? this.id,
      label: label ?? this.label,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'status': status.name,
  };

  factory ProfilePhoto.fromJson(Map<String, dynamic> json) {
    return ProfilePhoto(
      id: json['id']?.toString() ?? 'photo',
      label: json['label']?.toString() ?? '个人照片',
      status: PhotoStatus.parse(json['status']?.toString()),
    );
  }
}

class DatingProfile {
  const DatingProfile({
    required this.name,
    required this.gender,
    required this.city,
    required this.age,
    required this.height,
    required this.education,
    required this.job,
    required this.income,
    required this.marriage,
    required this.intention,
    required this.bio,
    required this.photos,
  });

  factory DatingProfile.empty() => const DatingProfile(
    name: '',
    gender: '',
    city: '',
    age: 0,
    height: 0,
    education: '',
    job: '',
    income: '',
    marriage: '',
    intention: '',
    bio: '',
    photos: [],
  );

  final String name;
  final String gender;
  final String city;
  final int age;
  final int height;
  final String education;
  final String job;
  final String income;
  final String marriage;
  final String intention;
  final String bio;
  final List<ProfilePhoto> photos;

  int get completion {
    final fields = [
      name,
      gender,
      city,
      age.toString(),
      height.toString(),
      education,
      job,
      income,
      marriage,
      intention,
      bio,
    ];
    final filled =
        fields.where((f) => f.trim().isNotEmpty && f != '0').length +
        (photos.isNotEmpty ? 1 : 0);
    return ((filled / 12) * 100).round();
  }

  DatingProfile copyWith({
    String? name,
    String? gender,
    String? city,
    int? age,
    int? height,
    String? education,
    String? job,
    String? income,
    String? marriage,
    String? intention,
    String? bio,
    List<ProfilePhoto>? photos,
  }) {
    return DatingProfile(
      name: name ?? this.name,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      age: age ?? this.age,
      height: height ?? this.height,
      education: education ?? this.education,
      job: job ?? this.job,
      income: income ?? this.income,
      marriage: marriage ?? this.marriage,
      intention: intention ?? this.intention,
      bio: bio ?? this.bio,
      photos: photos ?? this.photos,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender,
    'city': city,
    'age': age,
    'height': height,
    'education': education,
    'job': job,
    'income': income,
    'marriage': marriage,
    'intention': intention,
    'bio': bio,
    'photos': photos.map((photo) => photo.toJson()).toList(),
  };

  factory DatingProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DatingProfile.empty();
    return DatingProfile(
      name: json['name']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      age: int.tryParse(json['age']?.toString() ?? '') ?? 0,
      height: int.tryParse(json['height']?.toString() ?? '') ?? 0,
      education: json['education']?.toString() ?? '',
      job: json['job']?.toString() ?? '',
      income: json['income']?.toString() ?? '',
      marriage: json['marriage']?.toString() ?? '',
      intention: json['intention']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      photos: (json['photos'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ProfilePhoto.fromJson)
          .toList(),
    );
  }
}

class Candidate {
  const Candidate({
    required this.id,
    required this.name,
    required this.age,
    required this.city,
    required this.height,
    required this.education,
    required this.job,
    required this.intention,
    required this.bio,
    required this.matchScore,
    required this.likesMe,
    required this.verified,
    required this.tags,
    required this.colors,
  });

  final int id;
  final String name;
  final int age;
  final String city;
  final int height;
  final String education;
  final String job;
  final String intention;
  final String bio;
  final int matchScore;
  final bool likesMe;
  final bool verified;
  final List<String> tags;
  final List<Color> colors;

  factory Candidate.fromJson(Map<String, dynamic> json) {
    final id =
        int.tryParse(
          json['userId']?.toString() ?? json['id']?.toString() ?? '',
        ) ??
        0;
    return Candidate(
      id: id,
      name: json['name']?.toString() ?? '用户$id',
      age: int.tryParse(json['age']?.toString() ?? '') ?? 0,
      city: json['city']?.toString() ?? '',
      height: int.tryParse(json['height']?.toString() ?? '') ?? 0,
      education: json['education']?.toString() ?? '',
      job: json['job']?.toString() ?? '',
      intention: json['intention']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      matchScore: int.tryParse(json['matchScore']?.toString() ?? '') ?? 80,
      likesMe: json['likesMe'] == true,
      verified: json['verified'] == true,
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((tag) => tag.toString())
          .toList(),
      colors: candidateColors(id),
    );
  }
}

class RecommendationFilter {
  const RecommendationFilter({
    this.city = '全部',
    this.minScore = 0,
    this.verifiedOnly = false,
  });

  final String city;
  final int minScore;
  final bool verifiedOnly;

  RecommendationFilter copyWith({
    String? city,
    int? minScore,
    bool? verifiedOnly,
  }) {
    return RecommendationFilter(
      city: city ?? this.city,
      minScore: minScore ?? this.minScore,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    );
  }

  Map<String, dynamic> toJson() => {
    'city': city,
    'minScore': minScore,
    'verifiedOnly': verifiedOnly,
  };

  factory RecommendationFilter.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RecommendationFilter();
    return RecommendationFilter(
      city: json['city']?.toString() ?? '全部',
      minScore: int.tryParse(json['minScore']?.toString() ?? '') ?? 0,
      verifiedOnly: json['verifiedOnly'] == true,
    );
  }
}

class MatchChat {
  MatchChat({
    required this.id,
    required this.candidate,
    this.unreadCount = 0,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  final int id;
  final Candidate candidate;
  int unreadCount;
  final List<ChatMessage> messages;

  Map<String, dynamic> toJson() => {
    'id': id,
    'candidateId': candidate.id,
    'unreadCount': unreadCount,
    'messages': messages.map((message) => message.toJson()).toList(),
  };

  static MatchChat? fromJson(
    Map<String, dynamic> json,
    List<Candidate> candidates,
  ) {
    final candidateJson = json['candidate'] as Map<String, dynamic>?;
    final candidateId = int.tryParse(
      json['candidateId']?.toString() ??
          candidateJson?['userId']?.toString() ??
          '',
    );
    final candidate = candidateJson != null
        ? Candidate.fromJson(candidateJson)
        : candidates.where((item) => item.id == candidateId).firstOrNull;
    if (candidate == null) return null;
    return MatchChat(
      id: int.tryParse(json['id']?.toString() ?? '') ?? candidate.id,
      candidate: candidate,
      unreadCount: int.tryParse(json['unreadCount']?.toString() ?? '') ?? 0,
      messages: (json['messages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    this.id = 0,
    required this.text,
    required this.mine,
    required this.time,
  });

  final int id;
  final String text;
  final bool mine;
  final DateTime time;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'mine': mine,
    'time': time.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      text: json['text']?.toString() ?? json['content']?.toString() ?? '',
      mine: json['mine'] == true,
      time:
          DateTime.tryParse(
            json['time']?.toString() ?? json['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

String formatMessageTime(DateTime time) {
  final local = time.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String formatConversationTime(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) {
    return formatMessageTime(local);
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return '昨天';
  }
  return '${local.month}/${local.day}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

List<Color> candidateColors(int id) {
  const palettes = [
    [Color(0xFF2F3A56), Color(0xFFDF8E73)],
    [Color(0xFF1E6F78), Color(0xFFF2B36D)],
    [Color(0xFF5C5470), Color(0xFFB9A7D1)],
    [Color(0xFF284B63), Color(0xFFDB504A)],
  ];
  return palettes[id.abs() % palettes.length];
}

class RecommendPage extends StatelessWidget {
  const RecommendPage({
    super.key,
    required this.candidates,
    required this.likedIds,
    required this.activeFilter,
    required this.onLike,
    required this.onSkip,
    required this.onOpenFilters,
    required this.onRefresh,
  });

  final List<Candidate> candidates;
  final Set<int> likedIds;
  final RecommendationFilter activeFilter;
  final ValueChanged<Candidate> onLike;
  final ValueChanged<Candidate> onSkip;
  final VoidCallback onOpenFilters;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: PageHeader(
            title: '为你推荐',
            subtitle: '根据资料完整度、认证状态和择偶意向，为你筛选更合适的人。',
            action: IconButton.filledTonal(
              onPressed: onOpenFilters,
              icon: const Icon(Icons.tune_rounded),
              tooltip: '筛选条件',
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text('城市 ${activeFilter.city}'),
                  selected: activeFilter.city != '全部',
                  onSelected: (_) => onOpenFilters(),
                ),
                FilterChip(
                  label: Text('${activeFilter.minScore}%+'),
                  selected: activeFilter.minScore > 0,
                  onSelected: (_) => onOpenFilters(),
                ),
                FilterChip(
                  label: const Text('认证用户'),
                  selected: activeFilter.verifiedOnly,
                  onSelected: (_) => onOpenFilters(),
                ),
              ],
            ),
          ),
        ),
        if (candidates.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: panelDecoration(),
                child: Column(
                  children: [
                    const Icon(
                      Icons.search_off_rounded,
                      size: 36,
                      color: Color(0xFFE85D75),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '暂时没有符合条件的推荐',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '可以调整筛选条件，或刷新后查看最新推荐。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onOpenFilters,
                            icon: const Icon(Icons.tune_rounded),
                            label: const Text('调整筛选'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onRefresh,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('刷新推荐'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            sliver: SliverList.separated(
              itemCount: candidates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                return CandidateCard(
                  candidate: candidate,
                  liked: likedIds.contains(candidate.id),
                  onLike: () => onLike(candidate),
                  onSkip: () => onSkip(candidate),
                );
              },
            ),
          ),
      ],
    );
  }
}

class CandidateCard extends StatelessWidget {
  const CandidateCard({
    super.key,
    required this.candidate,
    required this.liked,
    required this.onLike,
    required this.onSkip,
  });

  final Candidate candidate;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CandidateHero(candidate: candidate),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InfoPill(
                      icon: Icons.flag_rounded,
                      label: candidate.intention,
                    ),
                    ...candidate.tags.map((tag) => InfoPill(label: tag)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  candidate.bio,
                  style: const TextStyle(color: Color(0xFF374151), height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSkip,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('暂不考虑'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: liked ? null : onLike,
                        icon: Icon(
                          liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                        ),
                        label: Text(liked ? '已喜欢' : '喜欢'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateHero extends StatelessWidget {
  const _CandidateHero({required this.candidate});

  final Candidate candidate;

  @override
  Widget build(BuildContext context) {
    final initials = candidate.name.characters.take(1).toString();

    return SizedBox(
      height: 270,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: candidate.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          CustomPaint(painter: _CandidatePatternPainter(candidate.colors.last)),
          Positioned(
            top: 28,
            left: 24,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.36),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: _ScoreBadge(score: candidate.matchScore),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF130F18).withValues(alpha: 0.78),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${candidate.name}，${candidate.age}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    if (candidate.verified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '已认证',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${candidate.city} · ${candidate.height}cm · ${candidate.education} · ${candidate.job}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFE85D75),
            size: 16,
          ),
          const SizedBox(width: 5),
          Text(
            '$score% 适配',
            style: const TextStyle(
              color: Color(0xFF18151F),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidatePatternPainter extends CustomPainter {
  const _CandidatePatternPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width * (0.78 + i * 0.04), size.height * (0.12 + i * 0.08)),
        42 + i * 24,
        paint,
      );
    }
    final accent = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.62),
      84,
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant _CandidatePatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

const _cityOptions = [
  '上海',
  '杭州',
  '苏州',
  '南京',
  '北京',
  '广州',
  '深圳',
  '成都',
  '武汉',
  '其他',
];
const _educationOptions = ['高中及以下', '大专', '本科', '硕士', '博士'];
const _incomeOptions = ['5万以下', '5-10万', '10-20万', '20-30万', '30-50万', '50万以上'];
const _marriageOptions = ['未婚', '离异', '丧偶'];
const _intentionOptions = ['认真婚恋', '一年内结婚', '以结婚为前提', '稳定关系', '先交朋友', '随缘'];

String? _validOption(String value, List<String> options) =>
    options.contains(value) ? value : null;

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.token,
    required this.onSave,
  });

  final DatingProfile profile;
  final String token;
  final ValueChanged<DatingProfile> onSave;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.name,
  );
  late final TextEditingController _age = TextEditingController(
    text: widget.profile.age == 0 ? '' : widget.profile.age.toString(),
  );
  late final TextEditingController _height = TextEditingController(
    text: widget.profile.height == 0 ? '' : widget.profile.height.toString(),
  );
  late final TextEditingController _job = TextEditingController(
    text: widget.profile.job,
  );
  late final TextEditingController _bio = TextEditingController(
    text: widget.profile.bio,
  );

  late String? _gender = widget.profile.gender.isEmpty
      ? null
      : widget.profile.gender;
  late String? _city = _validOption(widget.profile.city, _cityOptions);
  late String? _education = _validOption(
    widget.profile.education,
    _educationOptions,
  );
  late String? _income = _validOption(widget.profile.income, _incomeOptions);
  late String? _marriage = _validOption(
    widget.profile.marriage,
    _marriageOptions,
  );
  late String? _intention = _validOption(
    widget.profile.intention,
    _intentionOptions,
  );

  late List<ProfilePhoto> _photos = List.from(widget.profile.photos);
  bool _addingPhoto = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _job.dispose();
    _bio.dispose();
    super.dispose();
  }

  DatingProfile _currentProfile() => widget.profile.copyWith(
    name: _name.text.trim(),
    gender: _gender ?? '',
    city: _city ?? '',
    age: int.tryParse(_age.text.trim()) ?? widget.profile.age,
    height: int.tryParse(_height.text.trim()) ?? widget.profile.height,
    education: _education ?? '',
    job: _job.text.trim(),
    income: _income ?? '',
    marriage: _marriage ?? '',
    intention: _intention ?? '',
    bio: _bio.text.trim(),
    photos: _photos,
  );

  Future<void> _addPhoto() async {
    setState(() => _addingPhoto = true);
    try {
      final nextIndex = _photos.length + 1;
      final resp = await ApiClient().post('/api/mobile/photos', {
        'label': '个人照片 $nextIndex',
      }, token: widget.token);
      final data = resp['data'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() => _photos = [..._photos, ProfilePhoto.fromJson(data)]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加照片失败：$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _addingPhoto = false);
    }
  }

  Future<void> _deletePhoto(ProfilePhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除照片'),
        content: Text('确定删除「${photo.label}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiClient().delete(
        '/api/mobile/photos/${photo.id}',
        token: widget.token,
      );
      if (!mounted) return;
      setState(() => _photos = _photos.where((p) => p.id != photo.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      widget.onSave(_currentProfile());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentProfile();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const PageHeader(
          title: '个人资料',
          subtitle: '完善真实资料和照片认证，让推荐更准确，也让对方更放心。',
        ),
        ProfileCompletionCard(profile: current),
        const SizedBox(height: 14),
        _ProfileSection(
          title: '基本信息',
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '昵称'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            const Text(
              '性别',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            _GenderSelector(
              value: _gender,
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 14),
            InputDecorator(
              decoration: const InputDecoration(labelText: '常住城市'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _city,
                  hint: const Text('请选择'),
                  isExpanded: true,
                  isDense: true,
                  items: _cityOptions
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _city = v),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '年龄'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _height,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '身高 cm'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileSection(
          title: '工作情况',
          children: [
            InputDecorator(
              decoration: const InputDecoration(labelText: '最高学历'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _education,
                  hint: const Text('请选择'),
                  isExpanded: true,
                  isDense: true,
                  items: _educationOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _education = v),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _job,
              decoration: const InputDecoration(labelText: '职业'),
            ),
            const SizedBox(height: 14),
            InputDecorator(
              decoration: const InputDecoration(labelText: '年收入区间'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _income,
                  hint: const Text('请选择'),
                  isExpanded: true,
                  isDense: true,
                  items: _incomeOptions
                      .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                      .toList(),
                  onChanged: (v) => setState(() => _income = v),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileSection(
          title: '婚恋信息',
          children: [
            InputDecorator(
              decoration: const InputDecoration(labelText: '婚姻状况'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _marriage,
                  hint: const Text('请选择'),
                  isExpanded: true,
                  isDense: true,
                  items: _marriageOptions
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => _marriage = v),
                ),
              ),
            ),
            const SizedBox(height: 14),
            InputDecorator(
              decoration: const InputDecoration(labelText: '期待关系'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _intention,
                  hint: const Text('请选择'),
                  isExpanded: true,
                  isDense: true,
                  items: _intentionOptions
                      .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                      .toList(),
                  onChanged: (v) => setState(() => _intention = v),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileSection(
          title: '自我介绍',
          children: [
            TextField(
              controller: _bio,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '介绍一下自己的生活状态、兴趣爱好或择偶期望……',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileSection(
          title: '照片认证',
          trailing: _addingPhoto
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton.filledTonal(
                  onPressed: _addPhoto,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  tooltip: '添加照片',
                ),
          children: [
            const Text(
              '上传照片后需等待管理员审核，通过后将显示认证标识。',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            if (_photos.isEmpty)
              const Text(
                '暂无照片，点击右上角添加',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _photos
                    .map(
                      (photo) => PhotoTile(
                        photo: photo,
                        onDelete: () => _deletePhoto(photo),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: const Text('保存并更新推荐'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
      ],
    );
  }
}

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = ['男', '女', '不透露'];
    return Row(
      children: options.map((opt) {
        final selected = value == opt;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => onChanged(selected ? null : opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFE85D75)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFE85D75)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Text(
                opt,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF374151),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class ProfileCompletionCard extends StatelessWidget {
  const ProfileCompletionCard({super.key, required this.profile});

  final DatingProfile profile;

  @override
  Widget build(BuildContext context) {
    final chips = [
      if (profile.city.isNotEmpty) InfoPill(label: profile.city),
      if (profile.age > 0) InfoPill(label: '${profile.age}岁'),
      if (profile.height > 0) InfoPill(label: '${profile.height}cm'),
      if (profile.intention.isNotEmpty) InfoPill(label: profile.intention),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFF2F3A56), Color(0xFFE85D75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22E85D75),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_turned_in_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '资料完整度',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${profile.completion}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: profile.completion / 100,
              minHeight: 8,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ],
      ),
    );
  }
}

class PhotoTile extends StatelessWidget {
  const PhotoTile({super.key, required this.photo, this.onDelete});

  final ProfilePhoto photo;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 104,
          height: 116,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEEF2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF2C4CD)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_rounded, color: Color(0xFFE85D75)),
              const SizedBox(height: 6),
              Text(
                photo.label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: photo.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  photo.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: photo.status.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (onDelete != null)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class MatchPage extends StatelessWidget {
  const MatchPage({super.key, required this.matches, required this.onOpenChat});

  final List<MatchChat> matches;
  final ValueChanged<MatchChat> onOpenChat;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const PageHeader(title: '互相喜欢', subtitle: '只有双方都表达喜欢后，才会开放聊天。'),
        if (matches.isEmpty) const EmptyState(text: '还没有互相喜欢的人，去推荐页看看新的推荐。'),
        ...matches.map(
          (match) => PersonTile(
            candidate: match.candidate,
            subtitle: match.candidate.intention,
            onTap: () => onOpenChat(match),
            trailing: IconButton.filledTonal(
              icon: const Icon(Icons.chat_bubble_rounded),
              tooltip: '发消息',
              onPressed: () => onOpenChat(match),
            ),
          ),
        ),
      ],
    );
  }
}

class ChatListPage extends StatelessWidget {
  const ChatListPage({
    super.key,
    required this.matches,
    required this.onOpenChat,
  });

  final List<MatchChat> matches;
  final ValueChanged<MatchChat> onOpenChat;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const PageHeader(title: '消息', subtitle: '互相喜欢后可以在这里开始沟通，消息会实时同步。'),
        if (matches.isEmpty) const EmptyState(text: '互相喜欢后，聊天入口会出现在这里。'),
        ...matches.map(
          (match) => PersonTile(
            candidate: match.candidate,
            subtitle: match.messages.isEmpty
                ? '还没有消息，主动打个招呼吧'
                : match.messages.last.text,
            meta: match.messages.isEmpty
                ? null
                : formatConversationTime(match.messages.last.time),
            badgeCount: match.unreadCount,
            onTap: () => onOpenChat(match),
            trailing: IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => onOpenChat(match),
            ),
          ),
        ),
      ],
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.match,
    required this.token,
    required this.usingApi,
  });

  final MatchChat match;
  final String token;
  final bool usingApi;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  Timer? _pollTimer;
  WebSocketChannel? _channel;
  bool _sending = false;
  bool _loadingMessages = false;
  bool _wsConnected = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.usingApi) {
      _loadMessages();
      _connectWebSocket();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _channel?.sink.close();
    _controller.dispose();
    super.dispose();
  }

  void _connectWebSocket() {
    _channel?.sink.close();
    final encodedToken = Uri.encodeComponent(widget.token);
    final uri = Uri.parse(
      '${ApiClient.wsBaseUrl}/api/mobile/ws/chats/${widget.match.id}?token=$encodedToken',
    );
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _pollTimer?.cancel();
      _pollTimer = null;
      setState(() {
        _wsConnected = true;
        _error = '';
      });
      channel.stream.listen(
        _handleWebSocketEvent,
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _wsConnected = false;
            _error = '当前网络不稳定，正在为你保持消息同步';
          });
          _startPollingFallback();
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _wsConnected = false);
          _startPollingFallback();
        },
      );
    } catch (_) {
      _startPollingFallback();
    }
  }

  void _handleWebSocketEvent(dynamic event) {
    try {
      final data = jsonDecode(event.toString()) as Map<String, dynamic>;
      if (data['error'] != null) {
        setState(() => _error = data['error'].toString());
        return;
      }
      final message = ChatMessage.fromJson(data);
      setState(() {
        final existingIndex = widget.match.messages.indexWhere(
          (item) => item.id != 0 && item.id == message.id,
        );
        if (existingIndex >= 0) {
          widget.match.messages[existingIndex] = message;
        } else {
          widget.match.messages.add(message);
        }
        widget.match.messages.sort((a, b) => a.time.compareTo(b.time));
        _error = '';
      });
    } catch (_) {
      // Ignore malformed socket frames; HTTP history remains the source of truth.
    }
  }

  void _startPollingFallback() {
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadMessages(quiet: true),
    );
  }

  Future<void> _loadMessages({bool quiet = false}) async {
    if (_loadingMessages) return;
    if (!quiet) {
      setState(() {
        _loadingMessages = true;
        _error = '';
      });
    } else {
      _loadingMessages = true;
    }

    try {
      final resp = await ApiClient().get(
        '/api/mobile/chats/${widget.match.id}/messages',
        token: widget.token,
      );
      final data = resp['data'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        widget.match.messages
          ..clear()
          ..addAll(
            data.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson),
          );
        _error = '';
      });
    } catch (err) {
      if (!mounted || quiet) return;
      setState(() => _error = err.toString());
    } finally {
      _loadingMessages = false;
      if (mounted && !quiet) {
        setState(() {});
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    if (widget.usingApi) {
      if (_wsConnected && _channel != null) {
        _channel!.sink.add(jsonEncode({'text': text}));
        setState(() {
          _controller.clear();
          _sending = false;
        });
        return;
      }
      try {
        final resp = await ApiClient().post(
          '/api/mobile/chats/${widget.match.id}/messages',
          {'text': text},
          token: widget.token,
        );
        final data = resp['data'] as List<dynamic>? ?? [];
        if (!mounted) return;
        setState(() {
          widget.match.messages
            ..clear()
            ..addAll(
              data.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson),
            );
          _controller.clear();
          _error = '';
        });
      } catch (err) {
        if (!mounted) return;
        setState(() => _error = err.toString());
      } finally {
        if (mounted) setState(() => _sending = false);
      }
      return;
    }
    setState(() {
      widget.match.messages.add(
        ChatMessage(text: text, mine: true, time: DateTime.now()),
      );
      _controller.clear();
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.match.candidate.name)),
      body: Column(
        children: [
          Material(
            color: _wsConnected
                ? const Color(0xFFEFFBF5)
                : const Color(0xFFFFFBEB),
            child: ListTile(
              dense: true,
              leading: Icon(
                _wsConnected ? Icons.bolt_rounded : Icons.sync_rounded,
                color: _wsConnected
                    ? const Color(0xFF059669)
                    : const Color(0xFFD97706),
              ),
              title: Text(_wsConnected ? '消息实时同步中' : '网络连接不稳定，正在保持同步'),
              trailing: _wsConnected
                  ? null
                  : IconButton(
                      onPressed: _connectWebSocket,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: '重新连接',
                    ),
            ),
          ),
          if (_loadingMessages)
            const LinearProgressIndicator(minHeight: 2)
          else if (_error.isNotEmpty)
            Material(
              color: const Color(0xFFFFF1F2),
              child: ListTile(
                dense: true,
                title: const Text('消息同步失败'),
                subtitle: Text(_error),
                trailing: IconButton(
                  onPressed: _loadMessages,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: '重试',
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.match.messages.length,
              itemBuilder: (context, index) {
                final message = widget.match.messages[index];
                return ChatBubble(message: message);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: '说点什么吧'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    tooltip: '发送',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: message.mine ? const Color(0xFFE85D75) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: message.mine
                  ? null
                  : Border.all(color: const Color(0xFFE7E2DE)),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.mine ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              formatMessageTime(message.time),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ),
        ],
      ),
    );
  }
}

class PersonTile extends StatelessWidget {
  const PersonTile({
    super.key,
    required this.candidate,
    this.subtitle,
    this.meta,
    this.badgeCount = 0,
    this.onTap,
    this.trailing,
  });

  final Candidate candidate;
  final String? subtitle;
  final String? meta;
  final int badgeCount;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: panelDecoration(),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: candidate.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A111827),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        candidate.name.characters.first,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${candidate.name} · ${candidate.city}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (candidate.verified)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFFE85D75),
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subtitle ??
                                    '${candidate.age}岁 · ${candidate.job}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            if (meta != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                meta!,
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (badgeCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE85D75),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F5),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: const Color(0xFFE85D75)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFFE85D75), width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: panelDecoration(),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE5EA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFE85D75),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0xFFEFE3DE)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x1018151F),
        blurRadius: 22,
        offset: Offset(0, 10),
      ),
    ],
  );
}
