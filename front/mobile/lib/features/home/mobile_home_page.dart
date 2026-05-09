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

  void _addPhoto() async {
    final nextIndex = _profile.photos.length + 1;
    final resp = await ApiClient().post('/api/mobile/photos', {
      'label': '个人照片 $nextIndex',
    }, token: _token);
    final data = resp['data'] as Map<String, dynamic>? ?? {};
    setState(() {
      _profile = _profile.copyWith(
        photos: [..._profile.photos, ProfilePhoto.fromJson(data)],
      );
    });
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
              onSave: _saveProfile,
              onAddPhoto: _addPhoto,
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

  void _logout() {
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
        fields.where((field) => field.trim().isNotEmpty).length +
        (photos.isNotEmpty ? 1 : 0);
    return ((filled / 11) * 100).round();
  }

  DatingProfile copyWith({
    String? name,
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
  });

  final List<Candidate> candidates;
  final Set<int> likedIds;
  final RecommendationFilter activeFilter;
  final ValueChanged<Candidate> onLike;
  final ValueChanged<Candidate> onSkip;
  final VoidCallback onOpenFilters;

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
          const SliverToBoxAdapter(
            child: EmptyState(text: '暂时没有符合条件的推荐，可以调整筛选条件后再看看。'),
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
          Container(
            height: 260,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: candidate.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
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
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (candidate.verified)
                            const Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${candidate.city} · ${candidate.height}cm · ${candidate.education} · ${candidate.job}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Chip(
                    label: Text('${candidate.matchScore}% 适配'),
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.onSave,
    required this.onAddPhoto,
  });

  final DatingProfile profile;
  final ValueChanged<DatingProfile> onSave;
  final VoidCallback onAddPhoto;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.name,
  );
  late final TextEditingController _city = TextEditingController(
    text: widget.profile.city,
  );
  late final TextEditingController _age = TextEditingController(
    text: widget.profile.age.toString(),
  );
  late final TextEditingController _height = TextEditingController(
    text: widget.profile.height.toString(),
  );
  late final TextEditingController _education = TextEditingController(
    text: widget.profile.education,
  );
  late final TextEditingController _job = TextEditingController(
    text: widget.profile.job,
  );
  late final TextEditingController _income = TextEditingController(
    text: widget.profile.income,
  );
  late final TextEditingController _marriage = TextEditingController(
    text: widget.profile.marriage,
  );
  late final TextEditingController _intention = TextEditingController(
    text: widget.profile.intention,
  );
  late final TextEditingController _bio = TextEditingController(
    text: widget.profile.bio,
  );

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _name.text = widget.profile.name;
      _city.text = widget.profile.city;
      _age.text = widget.profile.age.toString();
      _height.text = widget.profile.height.toString();
      _education.text = widget.profile.education;
      _job.text = widget.profile.job;
      _income.text = widget.profile.income;
      _marriage.text = widget.profile.marriage;
      _intention.text = widget.profile.intention;
      _bio.text = widget.profile.bio;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _age.dispose();
    _height.dispose();
    _education.dispose();
    _job.dispose();
    _income.dispose();
    _marriage.dispose();
    _intention.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(
      widget.profile.copyWith(
        name: _name.text.trim(),
        city: _city.text.trim(),
        age: int.tryParse(_age.text.trim()) ?? widget.profile.age,
        height: int.tryParse(_height.text.trim()) ?? widget.profile.height,
        education: _education.text.trim(),
        job: _job.text.trim(),
        income: _income.text.trim(),
        marriage: _marriage.text.trim(),
        intention: _intention.text.trim(),
        bio: _bio.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const PageHeader(
          title: '个人资料',
          subtitle: '完善真实资料和照片认证，让推荐更准确，也让对方更放心。',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              ProfileCompletionCard(profile: widget.profile),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: panelDecoration(),
                child: Column(
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: '昵称'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _city,
                      decoration: const InputDecoration(labelText: '常住城市'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _age,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '年龄'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _height,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '身高 cm',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _education,
                      decoration: const InputDecoration(labelText: '最高学历'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _job,
                      decoration: const InputDecoration(labelText: '职业'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _income,
                      decoration: const InputDecoration(labelText: '收入区间'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _marriage,
                      decoration: const InputDecoration(labelText: '婚姻状态'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _intention,
                      decoration: const InputDecoration(labelText: '期待关系'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bio,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: '自我介绍'),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text(
                          '照片认证',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          onPressed: widget.onAddPhoto,
                          icon: const Icon(Icons.add_photo_alternate_rounded),
                          tooltip: '上传照片',
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: widget.profile.photos
                            .map((photo) => PhotoTile(photo: photo))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('保存并更新推荐'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileCompletionCard extends StatelessWidget {
  const ProfileCompletionCard({super.key, required this.profile});

  final DatingProfile profile;

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
              const Icon(
                Icons.assignment_turned_in_rounded,
                color: Color(0xFFE85D75),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '资料完整度',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text('${profile.completion}%'),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: profile.completion / 100),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoPill(label: profile.city),
              InfoPill(label: '${profile.age}岁'),
              InfoPill(label: '${profile.height}cm'),
              InfoPill(label: profile.intention),
            ],
          ),
        ],
      ),
    );
  }
}

class PhotoTile extends StatelessWidget {
  const PhotoTile({super.key, required this.photo});

  final ProfilePhoto photo;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  CircleAvatar(
                    backgroundColor: candidate.colors.last,
                    child: Text(
                      candidate.name.characters.first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF6B7280), height: 1.5),
                ),
              ],
            ),
          ),
          ?action,
        ],
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
            const Icon(Icons.info_outline_rounded, color: Color(0xFFE85D75)),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
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
    border: Border.all(color: const Color(0xFFE7E2DE)),
    boxShadow: const [
      BoxShadow(color: Color(0x0F111827), blurRadius: 16, offset: Offset(0, 8)),
    ],
  );
}
