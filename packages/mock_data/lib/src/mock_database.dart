import 'fixtures.dart';

/// Thrown for request errors; [fields] maps a field name to an error code
/// (for example `email: taken`) so clients can show it next to that field.
class MockError implements Exception {
  MockError(this.status, this.code, {this.fields = const {}});

  final int status;
  final String code;
  final Map<String, String> fields;

  Map<String, Object?> toJson() => {'error': code, if (fields.isNotEmpty) 'fields': fields};

  @override
  String toString() => 'MockError($status, $code, $fields)';
}

/// In-memory backend shared by the HTTP mock server and the app's offline fake,
/// so both behave the same.
class MockDatabase {
  MockDatabase({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    final now = _clock();
    _inspections = buildInspections(now);
    _notifications = buildNotifications(now);
    _users = [
      {...inspectorAnna, 'password': demoPassword},
    ];
  }

  final DateTime Function() _clock;
  late final List<Map<String, Object?>> _inspections;
  late final List<Map<String, Object?>> _notifications;
  late final List<Map<String, Object?>> _users;
  final Map<String, String> _tokens = {};
  int _nextId = 1046;

  static const statuses = {'scheduled', 'inProgress', 'draft', 'overdue', 'submitted'};
  static const sorts = {'dueAsc', 'dueDesc', 'siteAsc'};
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // ---- Auth ----

  Map<String, Object?> signIn(String email, String password) {
    final fields = <String, String>{};
    if (!_emailPattern.hasMatch(email)) fields['email'] = 'invalid';
    if (password.length < 8) fields['password'] = 'tooShort';
    if (fields.isNotEmpty) throw MockError(422, 'validation', fields: fields);
    final user = _users.where((u) => u['email'] == email.toLowerCase() && u['password'] == password).firstOrNull;
    if (user == null) throw MockError(401, 'invalidCredentials');
    return _session(user);
  }

  bool isEmailAvailable(String email) => !_users.any((u) => u['email'] == email.toLowerCase());

  Map<String, Object?> signUp({required String name, required String email, required String password}) {
    final fields = <String, String>{};
    if (name.trim().isEmpty) fields['name'] = 'required';
    if (!_emailPattern.hasMatch(email)) {
      fields['email'] = 'invalid';
    } else if (!isEmailAvailable(email)) {
      fields['email'] = 'taken';
    }
    if (password.length < 8 || !password.contains(RegExp(r'[A-Za-z]')) || !password.contains(RegExp(r'\d'))) {
      fields['password'] = 'weak';
    }
    if (fields.isNotEmpty) throw MockError(422, 'validation', fields: fields);
    final parts = name.trim().split(RegExp(r'\s+'));
    final user = {
      'id': 'u-${_users.length + 1}',
      'name': name.trim(),
      'email': email.toLowerCase(),
      'initials': parts.take(2).map((p) => p[0].toUpperCase()).join(),
      'role': 'Inspector',
      'password': password,
    };
    _users.add(user);
    return _session(user);
  }

  Map<String, Object?> _session(Map<String, Object?> user) {
    final token = 'mock-${user['id']}-${_clock().microsecondsSinceEpoch}';
    _tokens[token] = user['id']! as String;
    return {'token': token, 'user': Map.of(user)..remove('password')};
  }

  /// Returns the user for a bearer token, or throws 401.
  ///
  /// Tokens look like `mock-<userId>-<micros>`, so a session survives a mock
  /// server restart or an app restart in offline-fake mode.
  Map<String, Object?> authenticate(String? token) {
    final id = token == null ? null : _tokens[token] ?? RegExp(r'^mock-(u-[\w]+)-\d+$').firstMatch(token)?.group(1);
    final user = _users.where((u) => u['id'] == id).firstOrNull;
    if (user == null) throw MockError(401, 'unauthorized');
    return Map.of(user)..remove('password');
  }

  // ---- Inspections ----

  /// [due] is any|today|week|custom; custom uses [from] and [to] (inclusive dates).
  Map<String, Object?> listInspections({
    Set<String>? status,
    String? q,
    String sort = 'dueAsc',
    String due = 'any',
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) {
    if (!sorts.contains(sort)) throw MockError(400, 'badSort');
    if (page < 1 || pageSize < 1 || pageSize > 100) throw MockError(400, 'badPage');
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final query = q?.trim().toLowerCase() ?? '';
    bool inDue(DateTime at) => switch (due) {
      'today' => !at.isBefore(today) && at.isBefore(today.add(const Duration(days: 1))),
      'week' => !at.isBefore(today) && at.isBefore(today.add(const Duration(days: 7))),
      'custom' => (from == null || !at.isBefore(from)) && (to == null || at.isBefore(to.add(const Duration(days: 1)))),
      _ => true,
    };
    final items = _inspections.where((i) {
      if (i['archived'] == true) return false;
      if (status != null && status.isNotEmpty && !status.contains(i['status'])) return false;
      if (query.isNotEmpty &&
          !(i['site']! as String).toLowerCase().contains(query) &&
          !(i['id']! as String).toLowerCase().contains(query)) {
        return false;
      }
      return inDue(DateTime.parse(i['scheduledAt']! as String));
    }).toList();
    int byDate(Map<String, Object?> a, Map<String, Object?> b) => (a['scheduledAt']! as String).compareTo(b['scheduledAt']! as String);
    switch (sort) {
      case 'dueDesc':
        items.sort((a, b) => byDate(b, a));
      case 'siteAsc':
        items.sort((a, b) => (a['site']! as String).compareTo(b['site']! as String));
      default:
        // Open work first (soonest due), then submitted history, newest first.
        items.sort((a, b) {
          final aDone = a['status'] == 'submitted', bDone = b['status'] == 'submitted';
          if (aDone != bDone) return aDone ? 1 : -1;
          return aDone ? byDate(b, a) : byDate(a, b);
        });
    }
    final start = (page - 1) * pageSize;
    final pageItems = start >= items.length ? <Map<String, Object?>>[] : items.sublist(start, (start + pageSize).clamp(0, items.length));
    return {
      'items': pageItems.map(_summary).toList(),
      'total': items.length,
      'page': page,
      'pageSize': pageSize,
      'hasMore': start + pageSize < items.length,
    };
  }

  Map<String, Object?> _summary(Map<String, Object?> i) => {
    for (final k in ['id', 'siteId', 'site', 'address', 'city', 'icon', 'status', 'scheduledAt', 'lat', 'lng', 'priority', 'type']) k: i[k],
  };

  Map<String, Object?> getInspection(String id) {
    final i = _find(id);
    final answers = i['answers']! as Map;
    final total = (fireSafetyTemplate['items']! as List).length;
    return {
      ...i,
      'checklistSummary': {'answered': answers.length, 'total': total, 'failed': answers.values.where((v) => v == 'fail').length},
      'history': buildHistory(id, _clock()),
    };
  }

  Map<String, Object?> _find(String id) => _inspections.where((i) => i['id'] == id).firstOrNull ?? (throw MockError(404, 'notFound'));

  /// Server-side validation mirrors the app's wizard validators, so a client
  /// that skips them still gets field errors back (HTTP 422).
  Map<String, String> validateInspection(Map<String, Object?> body, {required bool submitting, bool isNew = false}) {
    final f = <String, String>{};
    final siteId = body['siteId'];
    final siteName = (body['site'] as String?)?.trim() ?? '';
    if (siteId == null && siteName.length < 3) f['site'] = 'required';
    if (!inspectionTypes.contains(body['type'])) f['type'] = 'required';
    final at = DateTime.tryParse(body['scheduledAt'] as String? ?? '');
    if (at == null) {
      f['scheduledAt'] = 'required';
    } else if (isNew && at.isBefore(DateTime(_clock().year, _clock().month, _clock().day))) {
      f['scheduledAt'] = 'past';
    }
    final duration = body['durationMin'];
    if (duration is! int || duration < 15 || duration > 480) f['durationMin'] = 'range';
    if ((body['notes'] as String? ?? '').length > 500) f['notes'] = 'tooLong';
    if (!const {'low', 'normal', 'high'}.contains(body['priority'] ?? 'normal')) f['priority'] = 'invalid';
    if (submitting) {
      final answers = (body['answers'] as Map?) ?? const {};
      final items = (fireSafetyTemplate['items']! as List).cast<Map>();
      if (items.any((it) => !answers.containsKey(it['id']))) f['answers'] = 'incomplete';
      if (body['confirmed'] != true) f['confirmed'] = 'required';
    }
    return f;
  }

  Map<String, Object?> createInspection(Map<String, Object?> body, {bool submit = false}) {
    final errors = validateInspection(body, submitting: submit, isNew: true);
    if (errors.isNotEmpty) throw MockError(422, 'validation', fields: errors);
    final site = sites.where((s) => s['id'] == body['siteId']).firstOrNull;
    final now = _clock().toIso8601String();
    final created = <String, Object?>{
      'id': 'INS-${_nextId++}',
      'siteId': body['siteId'] ?? 's-new-$_nextId',
      'site': site?['name'] ?? body['site'],
      'address': site?['address'] ?? body['address'] ?? '',
      'postcode': site?['postcode'] ?? '',
      'city': site?['city'] ?? '',
      'icon': site?['icon'] ?? 'location_on',
      'lat': site?['lat'] ?? body['lat'],
      'lng': site?['lng'] ?? body['lng'],
      'status': submit ? 'submitted' : 'draft',
      'type': body['type'],
      'templateId': fireSafetyTemplate['id'],
      'scheduledAt': body['scheduledAt'],
      'durationMin': body['durationMin'],
      'priority': body['priority'] ?? 'normal',
      'inspector': inspectorAnna,
      'siteManager': siteManagerPiotr,
      'answers': body['answers'] ?? const <String, String>{},
      'photos': _storePhotos(body['photos'], const []),
      'files': body['files'] ?? const [],
      'notes': body['notes'] ?? '',
      'archived': false,
      'updatedAt': now,
    };
    _inspections.add(created);
    return getInspection(created['id']! as String);
  }

  Map<String, Object?> updateInspection(String id, Map<String, Object?> body, {bool submit = false}) {
    final existing = _find(id);
    final merged = {...existing, ...body};
    final errors = validateInspection(merged, submitting: submit);
    if (errors.isNotEmpty) throw MockError(422, 'validation', fields: errors);
    final photos = _storePhotos(body['photos'] ?? existing['photos'], (existing['photos'] as List?) ?? const []);
    existing
      ..addAll(body)
      ..['photos'] = photos
      ..['status'] = submit ? 'submitted' : existing['status']
      ..['updatedAt'] = _clock().toIso8601String();
    return getInspection(id);
  }

  /// Turns uploaded photo metadata (`{id, name, sizeBytes, forItem}` from the
  /// app's drafts) into stored photo records, like a real API would: known ids
  /// keep their record, new ones get a caption and a server timestamp.
  List<Map<String, Object?>> _storePhotos(Object? uploaded, List<Object?> current) {
    final known = {for (final p in current.cast<Map<String, Object?>>()) p['id']: p};
    final now = _clock().toIso8601String();
    return [
      for (final p in ((uploaded as List?) ?? const []).cast<Map<String, Object?>>())
        known[p['id']] ??
            (p.containsKey('takenAt')
                ? p
                : {
                    'id': p['id'],
                    'caption': p['caption'] ?? p['name'] ?? '',
                    'takenAt': now,
                    'sizeBytes': p['sizeBytes'] ?? 0,
                    if (p['forItem'] != null) 'forItem': p['forItem'],
                  }),
    ];
  }

  void setArchived(String id, bool archived) => _find(id)['archived'] = archived;

  // ---- Lookups ----

  List<Map<String, Object?>> searchSites(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final matches =
        sites
            .where((s) => (s['name']! as String).toLowerCase().contains(query) || (s['address']! as String).toLowerCase().contains(query))
            .toList()
          ..sort((a, b) {
            // Prefix matches first, like the P09 suggestions.
            final ap = (a['name']! as String).toLowerCase().startsWith(query) ? 0 : 1;
            final bp = (b['name']! as String).toLowerCase().startsWith(query) ? 0 : 1;
            return ap != bp ? ap - bp : (a['name']! as String).compareTo(b['name']! as String);
          });
    return matches.take(8).toList();
  }

  Map<String, Object?> checklistTemplate(String id) =>
      id == fireSafetyTemplate['id'] ? fireSafetyTemplate : (throw MockError(404, 'notFound'));

  List<Map<String, Object?>> notifications() => List.of(_notifications);

  void markNotificationsRead({String? id}) {
    for (final n in _notifications) {
      if (id == null || n['id'] == id) n['read'] = true;
    }
  }

  void deleteNotification(String id) => _notifications.removeWhere((n) => n['id'] == id);
}
