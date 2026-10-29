import 'dart:math';

import 'package:characters/characters.dart';

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
    _fixtureUserIds = {for (final u in _users) u['id']! as String};
  }

  static final _random = Random();

  final DateTime Function() _clock;
  late final List<Map<String, Object?>> _inspections;
  late final List<Map<String, Object?>> _notifications;
  late final List<Map<String, Object?>> _users;

  /// Users that exist on every start (the demo account). Only their tokens
  /// outlive the database; see [authenticate].
  late final Set<String> _fixtureUserIds;
  final Map<String, String> _tokens = {};

  /// Inspections created per `Idempotency-Key`, so a create retried after a
  /// lost response returns the first one instead of making a second.
  final Map<String, String> _createdByKey = {};
  int _nextId = 1046;

  static const statuses = {'scheduled', 'inProgress', 'draft', 'overdue', 'submitted'};
  static const sorts = {'dueAsc', 'dueDesc', 'siteAsc'};
  static const dueWindows = {'any', 'today', 'week', 'custom'};

  /// Highest page number accepted; far beyond the data, small enough that
  /// `(page - 1) * pageSize` can't overflow.
  static const maxPage = 100000;
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
      // Random, so a token from before a reset can't match the next sign-up.
      'id': 'u-${_random.nextInt(0x3FFFFFFF).toRadixString(36)}${_users.length}',
      'name': name.trim(),
      'email': email.toLowerCase(),
      'initials': parts.take(2).map((p) => p[0].toUpperCase()).join(),
      'role': 'Inspector',
      'password': password,
    };
    _users.add(user);
    return _session(user);
  }

  String? _fixtureToken(String token) {
    final id = RegExp(r'^mock-(u-[\w]+)-\d+$').firstMatch(token)?.group(1);
    return _fixtureUserIds.contains(id) ? id : null;
  }

  Map<String, Object?> _session(Map<String, Object?> user) {
    final token = 'mock-${user['id']}-${_clock().microsecondsSinceEpoch}';
    _tokens[token] = user['id']! as String;
    return {'token': token, 'user': Map.of(user)..remove('password')};
  }

  /// Returns the user for a bearer token, or throws 401.
  ///
  /// Tokens look like `mock-<userId>-<micros>`. Tokens this database issued
  /// are checked against the ones it handed out. The demo account's tokens
  /// are also accepted by shape, so its session survives a mock server
  /// restart or an app restart in offline-fake mode (its password is public
  /// anyway); a signed-up user's token ends with the database.
  Map<String, Object?> authenticate(String? token) {
    final id = token == null ? null : _tokens[token] ?? _fixtureToken(token);
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
    if (!dueWindows.contains(due)) throw MockError(400, 'badDue');
    if (status != null && !statuses.containsAll(status)) throw MockError(400, 'badStatus');
    if (page < 1 || page > maxPage || pageSize < 1 || pageSize > 100) throw MockError(400, 'badPage');
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final query = q?.trim().toLowerCase() ?? '';
    // Next local midnights by calendar day: adding a Duration of days would be
    // an hour off across a daylight-saving change (decision 104).
    DateTime dayAfter(DateTime d, [int days = 1]) => DateTime(d.year, d.month, d.day + days);
    bool inDue(DateTime at) => switch (due) {
      'today' => !at.isBefore(today) && at.isBefore(dayAfter(today)),
      'week' => !at.isBefore(today) && at.isBefore(dayAfter(today, 7)),
      'custom' => (from == null || !at.isBefore(from)) && (to == null || at.isBefore(dayAfter(to))),
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
    final answers = (i['answers'] as Map?) ?? const {};
    final total = _itemIds.length;
    return {
      ...i,
      'checklistSummary': {'answered': answers.length, 'total': total, 'failed': answers.values.where((v) => v == 'fail').length},
      'history': buildHistory(id, _clock()),
    };
  }

  Map<String, Object?> _find(String id) => _inspections.where((i) => i['id'] == id).firstOrNull ?? (throw MockError(404, 'notFound'));

  // ---- Inspection writes ----

  /// The keys `POST` / `PUT /inspections` read. Anything else in a body (id,
  /// status, archived, inspector, history, …) is ignored: those belong to the
  /// server, so a client can't rewrite them.
  static const writableKeys = {
    'siteId',
    'site',
    'address',
    'lat',
    'lng',
    'checkedInAt',
    'type',
    'scheduledAt',
    'durationMin',
    'priority',
    'notes',
    'answers',
    'failures',
    'photos',
    'files',
    'confirmed',
  };

  static const _priorities = {'low', 'normal', 'high'};
  static const _answerValues = {'pass', 'fail', 'na'};
  static final _itemIds = {for (final i in fireSafetyTemplate['items']! as List) (i as Map)['id']! as String};

  /// Server-side validation mirrors the app's wizard validators, so a client
  /// that skips them still gets field errors back (HTTP 422). [record] is the
  /// inspection as it would be stored, plus `confirmed` from the request.
  /// A past date isn't refused: a report written offline for today may only
  /// arrive after midnight (decision 118); the wizard keeps new ones from
  /// being scheduled in the past.
  Map<String, String> validateInspection(Map<String, Object?> record, {required bool submitting}) {
    final f = <String, String>{};
    final site = record['site'];
    if (site is! String || site.trim().length < 3) f['site'] = 'required';
    if (!inspectionTypes.contains(record['type'])) f['type'] = 'required';
    final at = switch (record['scheduledAt']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    };
    if (at == null) f['scheduledAt'] = 'required';
    final duration = record['durationMin'];
    if (duration is! int || duration < 15 || duration > 480) f['durationMin'] = 'range';
    // Characters as the app's notes field counts them (an emoji is one).
    if (record['notes'] case final String notes when notes.characters.length > 500) f['notes'] = 'tooLong';
    if (!_priorities.contains(record['priority'] ?? 'normal')) f['priority'] = 'invalid';
    if (submitting) {
      final answers = record['answers'];
      if (answers is! Map || _itemIds.any((id) => !answers.containsKey(id))) f['answers'] = 'incomplete';
      if (record['confirmed'] != true) f['confirmed'] = 'required';
    }
    return f;
  }

  ///
  /// [requestKey]: the client's idempotency key. A create with a key seen
  /// before returns the inspection that key created and changes nothing.
  /// [inspector]: the signed-in user making it (Anna when not given).
  Map<String, Object?> createInspection(
    Map<String, Object?> body, {
    bool submit = false,
    String? requestKey,
    Map<String, Object?>? inspector,
  }) {
    if (_createdByKey[requestKey] case final existing?) return getInspection(existing);
    final id = 'INS-$_nextId';
    final record = _prepare(body, id: id, submit: submit);
    _nextId++;
    _inspections.add({
      'id': id,
      ...record,
      'status': submit ? 'submitted' : 'draft',
      'templateId': fireSafetyTemplate['id'],
      'inspector': inspector == null
          ? inspectorAnna
          : {
              for (final k in ['id', 'name', 'email', 'initials']) k: inspector[k],
              'role': inspector['role'] ?? 'Inspector',
            },
      'siteManager': siteManagerPiotr,
      'archived': false,
      'updatedAt': _clock().toIso8601String(),
    });
    if (requestKey != null) _createdByKey[requestKey] = id;
    return getInspection(id);
  }

  /// Merges [body] into the stored inspection. Only [writableKeys] change; the
  /// whole body is checked before anything is stored.
  Map<String, Object?> updateInspection(String id, Map<String, Object?> body, {bool submit = false}) {
    final existing = _find(id);
    final record = _prepare(body, id: id, existing: existing, submit: submit);
    existing
      ..addAll(record)
      ..['status'] = submit ? 'submitted' : existing['status']
      ..['updatedAt'] = _clock().toIso8601String();
    return getInspection(id);
  }

  /// The client-writable fields of the inspection [id] after applying [body]
  /// to [existing] (null for a create). Throws 422 with field errors, before
  /// anything is stored, for values of the wrong type, an unknown site or a
  /// failed validation rule.
  Map<String, Object?> _prepare(Map<String, Object?> body, {required String id, Map<String, Object?>? existing, required bool submit}) {
    final b = {
      for (final e in body.entries)
        if (writableKeys.contains(e.key)) e.key: e.value,
    };
    final errors = _shapeErrors(b);
    final record = <String, Object?>{
      if (existing == null) ...{
        'priority': 'normal',
        'notes': '',
        'answers': <String, Object?>{},
        'failures': <String, Object?>{},
        'photos': <Object?>[],
        'files': <Object?>[],
      },
      for (final k in const ['type', 'scheduledAt', 'durationMin', 'priority', 'notes', 'answers', 'failures', 'files', 'checkedInAt'])
        if (b.containsKey(k) && !errors.containsKey(k)) k: _copy(b[k]),
    };

    // Site: a known id copies that site's details; a name alone is a new site.
    if (b['siteId'] case final String siteId) {
      final site = _siteById(siteId);
      if (site == null) {
        errors['site'] ??= 'unknown';
      } else {
        record.addAll(site);
      }
    } else if (b['site'] is String || existing == null) {
      record.addAll({
        'siteId': 's-new-$id',
        'site': switch (b['site']) {
          final String s => s.trim(),
          _ => '',
        },
        'address': b['address'] is String ? b['address'] : '',
        'postcode': '',
        'city': '',
        'icon': 'location_on',
        'lat': errors.containsKey('lat') ? null : b['lat'],
        'lng': errors.containsKey('lng') ? null : b['lng'],
      });
    }

    if (b['photos'] case final List<Object?> photos when !errors.containsKey('photos')) {
      record['photos'] = _storePhotos(photos, (existing?['photos'] as List?) ?? const []);
    }

    final rules = validateInspection({...?existing, ...record, 'confirmed': b['confirmed']}, submitting: submit);
    final all = {...rules, ...errors};
    if (all.isNotEmpty) throw MockError(422, 'validation', fields: all);
    return record;
  }

  /// Field errors for values of the wrong JSON type or shape. A wrong `siteId`
  /// is reported on `site`, the field the app shows.
  static Map<String, String> _shapeErrors(Map<String, Object?> b) {
    final f = <String, String>{};
    bool isNum(Object? v) => v is num && v.isFinite;
    for (final k in const ['siteId', 'site', 'address', 'type', 'scheduledAt', 'priority', 'notes']) {
      if (b[k] != null && b[k] is! String) f[k == 'siteId' ? 'site' : k] = 'invalid';
    }
    for (final k in const ['lat', 'lng']) {
      if (b[k] != null && !isNum(b[k])) f[k] = 'invalid';
    }
    if (b['confirmed'] is! bool?) f['confirmed'] = 'invalid';
    if (b['checkedInAt'] case final Object c) {
      final ok = c is Map && isNum(c['lat']) && isNum(c['lng']) && (c['accuracy'] == null || isNum(c['accuracy']));
      if (!ok) f['checkedInAt'] = 'invalid';
    }
    if (b.containsKey('answers')) {
      final a = b['answers'];
      if (a is! Map || a.entries.any((e) => !_itemIds.contains(e.key) || !_answerValues.contains(e.value))) f['answers'] = 'invalid';
    }
    if (b.containsKey('failures')) {
      final m = b['failures'];
      if (m is! Map || m.entries.any((e) => !_itemIds.contains(e.key) || !_isFailure(e.value))) f['failures'] = 'invalid';
    }
    for (final k in const ['photos', 'files']) {
      if (b.containsKey(k) && !_isAttachmentList(b[k])) f[k] = 'invalid';
    }
    return f;
  }

  /// `{severity: 1–5, followUp: bool, note: String}`, each optional.
  static bool _isFailure(Object? v) =>
      v is Map &&
      switch (v['severity']) {
        null => true,
        final int s => s >= 1 && s <= 5,
        _ => false,
      } &&
      v['followUp'] is bool? &&
      v['note'] is String?;

  /// A list of `{id, name?, caption?, sizeBytes?, forItem?, isPhoto?, takenAt?,
  /// lat?, lng?}` with unique, non-empty string ids.
  static bool _isAttachmentList(Object? v) {
    if (v is! List) return false;
    final ids = <String>{};
    for (final a in v) {
      if (a is! Map) return false;
      final id = a['id'];
      if (id is! String || id.isEmpty || !ids.add(id)) return false;
      if (a['name'] is! String? || a['caption'] is! String? || a['forItem'] is! String? || a['isPhoto'] is! bool?) return false;
      final size = a['sizeBytes'];
      if (size != null && (size is! int || size < 0)) return false;
      final takenAt = a['takenAt'];
      if (takenAt != null && (takenAt is! String || DateTime.tryParse(takenAt) == null)) return false;
      for (final k in const ['lat', 'lng']) {
        final n = a[k];
        if (n != null && (n is! num || !n.isFinite)) return false;
      }
    }
    return true;
  }

  /// Site details for [siteId]: a fixture site, or a free-text site that an
  /// earlier inspection created. Null when there is no such site.
  Map<String, Object?>? _siteById(String siteId) {
    final fixture = sites.where((s) => s['id'] == siteId).firstOrNull;
    final source = fixture ?? _inspections.where((i) => i['siteId'] == siteId).firstOrNull;
    if (source == null) return null;
    return {
      'siteId': siteId,
      'site': fixture != null ? fixture['name'] : source['site'],
      for (final k in const ['address', 'postcode', 'city', 'icon', 'lat', 'lng']) k: source[k],
    };
  }

  /// Turns uploaded photo metadata (`{id, name, sizeBytes, forItem}` from the
  /// app's drafts) into stored photo records, like a real API would: known ids
  /// keep their stored record, new ones get a caption and a server timestamp.
  /// The list replaces the stored one, so a photo left out is removed.
  List<Map<String, Object?>> _storePhotos(List<Object?> uploaded, List<Object?> current) {
    final known = {
      for (final p in current)
        if (p is Map) p['id']: p.cast<String, Object?>(),
    };
    final now = _clock().toIso8601String();
    return [
      for (final p in uploaded)
        if (p is Map)
          known[p['id']] ??
              {
                'id': p['id'],
                'caption': p['caption'] ?? p['name'] ?? '',
                'takenAt': p['takenAt'] ?? now,
                'sizeBytes': p['sizeBytes'] ?? 0,
                if (p['lat'] != null) 'lat': p['lat'],
                if (p['lng'] != null) 'lng': p['lng'],
                if (p['forItem'] != null) 'forItem': p['forItem'],
              },
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

/// A deep copy of a JSON-like value, so stored records never share maps or
/// lists with the caller (the app's offline fake passes its own objects).
Object? _copy(Object? v) => switch (v) {
  final Map m => {for (final e in m.entries) '${e.key}': _copy(e.value)},
  final List l => [for (final x in l) _copy(x)],
  _ => v,
};
