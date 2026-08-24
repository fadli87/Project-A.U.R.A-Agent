import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:aura/src/storage/chat_database.dart';
import 'package:aura/src/agent/agent_tools.dart';

part 'persona_provider.g.dart';

class Persona {
  final int? id;
  final String name;
  final String content;
  final bool isActive;
  final bool isBuiltin;
  final DateTime createdAt;

  Persona({
    this.id,
    required this.name,
    required this.content,
    this.isActive = false,
    this.isBuiltin = false,
    required this.createdAt,
  });

  factory Persona.fromMap(Map<String, dynamic> map) {
    return Persona(
      id: map['id'] as int?,
      name: map['name'] as String,
      content: map['content'] as String,
      isActive: (map['is_active'] as int) == 1,
      isBuiltin: (map['is_builtin'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'content': content,
      'is_active': isActive ? 1 : 0,
      'is_builtin': isBuiltin ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  Persona copyWith({
    int? id,
    String? name,
    String? content,
    bool? isActive,
    bool? isBuiltin,
    DateTime? createdAt,
  }) {
    return Persona(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      isActive: isActive ?? this.isActive,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Skill {
  final int? id;
  final String name;
  final String description;
  final String body;
  final bool enabled;
  final String? keywords;
  final DateTime createdAt;

  Skill({
    this.id,
    required this.name,
    required this.description,
    required this.body,
    this.enabled = true,
    this.keywords,
    required this.createdAt,
  });

  factory Skill.fromMap(Map<String, dynamic> map) {
    return Skill(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String,
      body: map['body'] as String,
      enabled: (map['enabled'] as int) == 1,
      keywords: map['keywords'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'body': body,
      'enabled': enabled ? 1 : 0,
      'keywords': keywords,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}

class PersonaState {
  final List<Persona> personas;
  final Persona? activePersona;
  final List<Skill> skills;

  const PersonaState({
    this.personas = const [],
    this.activePersona,
    this.skills = const [],
  });

  PersonaState copyWith({
    List<Persona>? personas,
    Persona? activePersona,
    List<Skill>? skills,
  }) {
    return PersonaState(
      personas: personas ?? this.personas,
      activePersona: activePersona ?? this.activePersona,
      skills: skills ?? this.skills,
    );
  }
}

@riverpod
class PersonaNotifier extends _$PersonaNotifier {
  @override
  PersonaState build() {
    loadData();
    return const PersonaState();
  }

  Future<void> loadData() async {
    final db = await ChatDatabase.instance.database;
    final personaMaps = await db.query('Persona', orderBy: 'id ASC');
    final skillMaps = await db.query('Skills', orderBy: 'name ASC');

    final personas = personaMaps.map(Persona.fromMap).toList();
    final skills = skillMaps.map(Skill.fromMap).toList();

    Persona? active;
    for (final p in personas) {
      if (p.isActive) {
        active = p;
        break;
      }
    }
    active ??= personas.isNotEmpty ? personas.first : null;

    state = PersonaState(
      personas: personas,
      activePersona: active,
      skills: skills,
    );
  }

  Future<void> setActivePersona(int personaId) async {
    final db = await ChatDatabase.instance.database;
    await db.update('Persona', {'is_active': 0});
    await db.update('Persona', {'is_active': 1}, where: 'id = ?', whereArgs: [personaId]);
    await loadData();
  }

  Future<void> savePersona(String name, String content) async {
    final db = await ChatDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('Persona', {
      'name': name,
      'content': content,
      'is_active': 0,
      'is_builtin': 0,
      'created_at': now,
    });
    await loadData();
  }

  Future<void> toggleSkill(int skillId, bool enabled) async {
    final db = await ChatDatabase.instance.database;
    await db.update('Skills', {'enabled': enabled ? 1 : 0}, where: 'id = ?', whereArgs: [skillId]);
    await loadData();
  }

  Future<void> addSkill({
    required String name,
    required String description,
    required String body,
    String? keywords,
  }) async {
    final db = await ChatDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('Skills', {
      'name': name,
      'description': description,
      'body': body,
      'enabled': 1,
      'keywords': keywords,
      'created_at': now,
    });
    await loadData();
  }

  String assembleSystemPrompt(String userQuery, {List<String>? userFacts, String? memorySnapshot}) {
    final buffer = StringBuffer();

    // System time context injection for exact alarm/reminder calculations
    final nowTime = DateTime.now();
    buffer.writeln('=== INFORMASI WAKTU SISTEM ===');
    buffer.writeln('Tanggal & Waktu Sekarang: ${nowTime.toLocal().toIso8601String()}');
    buffer.writeln('Hari: ${_getDayName(nowTime.weekday)}\n');

    // Default style instruction for interactive responses with emojis and symbols
    buffer.writeln('=== PETUNJUK GAYA BAHASA & EKSPRESI ===');
    buffer.writeln('• Selalu gunakan emotikon/emoji yang relevan (misal: 🚀, ✨, ⚡, 💡, 🎯, 📊, 🛡️, 📌, ➔).');
    buffer.writeln('• Buat jawaban yang ramah, ekspresif, terstruktur dengan poin-poin menarik, dan format Markdown yang rapi.\n');

    // [1a] Persona aktif
    if (state.activePersona != null) {
      buffer.writeln('=== PERSONA & INSTRUKSI UTAMA ===');
      buffer.writeln(state.activePersona!.content);
      buffer.writeln();
    }

    // [1b] Tool-calling schema (Rule 05-persona-skills.md: urutan wajib)
    final toolRegistry = AgentToolRegistry();
    buffer.writeln(toolRegistry.buildToolsPrompt());

    // [1c] Skills index
    final enabledSkills = state.skills.where((s) => s.enabled).toList();
    if (enabledSkills.isNotEmpty) {
      buffer.writeln('=== SKILLS INDEX ===');
      for (final skill in enabledSkills) {
        buffer.writeln('- ${skill.name}: ${skill.description}');
      }
      buffer.writeln();
    }

    final queryLower = userQuery.toLowerCase();
    int injectedCount = 0;
    for (final skill in enabledSkills) {
      if (injectedCount >= 2) break;
      final kw = skill.keywords?.toLowerCase() ?? '';
      final nameLower = skill.name.toLowerCase();
      if ((kw.isNotEmpty && queryLower.contains(kw)) || queryLower.contains(nameLower)) {
        if (injectedCount == 0) buffer.writeln('=== SKILL DEEP-GUIDE ===');
        buffer.writeln('[Skill: ${skill.name}]');
        buffer.writeln(skill.body);
        buffer.writeln();
        injectedCount++;
      }
    }

    if (userFacts != null && userFacts.isNotEmpty) {
      buffer.writeln('=== USER PROFILE FACTS ===');
      for (final fact in userFacts) {
        buffer.writeln('- $fact');
      }
      buffer.writeln();
    }

    if (memorySnapshot != null && memorySnapshot.isNotEmpty) {
      buffer.writeln('=== MEMORY SNAPSHOT ===');
      buffer.writeln(memorySnapshot);
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Senin';
      case 2: return 'Selasa';
      case 3: return 'Rabu';
      case 4: return 'Kamis';
      case 5: return 'Jumat';
      case 6: return 'Sabtu';
      case 7: return 'Minggu';
      default: return 'Tidak Diketahui';
    }
  }
}
