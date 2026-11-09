import 'package:equatable/equatable.dart';

import '../enums.dart';

/// Usuário autenticado (`UsuarioResponse`). Parsing fica em `UserModel`.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    this.name,
    this.photoUrl,
    this.perfil = PerfilUsuario.cliente,
    this.telefone,
    this.criadoEm,
  });

  final String id;
  final String email;
  final String? name;
  final String? photoUrl;
  final PerfilUsuario perfil;

  /// Só dígitos (10 ou 11), quando informado.
  final String? telefone;
  final DateTime? criadoEm;

  factory AppUser.empty() => const AppUser(id: '', email: '');

  bool get isEmpty => id.isEmpty;
  bool get isNotEmpty => id.isNotEmpty;
  bool get isDono => perfil == PerfilUsuario.dono;

  /// Iniciais do avatar: primeira letra do primeiro e do último nome.
  String get iniciais {
    final partes = (name ?? email)
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    final primeira = partes.first.substring(0, 1);
    if (partes.length == 1) return primeira.toUpperCase();
    return '$primeira${partes.last.substring(0, 1)}'.toUpperCase();
  }

  AppUser copyWith({String? name, String? telefone}) => AppUser(
        id: id,
        email: email,
        name: name ?? this.name,
        photoUrl: photoUrl,
        perfil: perfil,
        telefone: telefone ?? this.telefone,
        criadoEm: criadoEm,
      );

  @override
  List<Object?> get props =>
      [id, email, name, photoUrl, perfil, telefone, criadoEm];
}
