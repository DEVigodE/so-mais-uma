import 'package:so_mais_uma/src/shared/domain/entities/app_user.dart';
import 'package:so_mais_uma/src/shared/domain/enums.dart';

/// Data-layer user DTO (`UsuarioResponse`). Maps to/from the domain [AppUser].
class UserModel {
  const UserModel({
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
  final String? telefone;
  final DateTime? criadoEm;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final source = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;

    return switch (source) {
      {
        'id': final Object? id,
        'email': final Object? email,
      } =>
        UserModel(
          id: id?.toString() ?? '',
          email: email?.toString() ?? '',
          name: source['nome']?.toString(),
          photoUrl: source['photoUrl']?.toString(),
          perfil: PerfilUsuario.fromApi(source['perfil']),
          telefone: source['telefone']?.toString(),
          criadoEm: DateTime.tryParse(source['criadoEm']?.toString() ?? ''),
        ),
      _ => const UserModel(id: '', email: ''),
    };
  }

  factory UserModel.fromEntity(AppUser user) => UserModel(
        id: user.id,
        email: user.email,
        name: user.name,
        photoUrl: user.photoUrl,
        perfil: user.perfil,
        telefone: user.telefone,
        criadoEm: user.criadoEm,
      );

  AppUser toEntity() => AppUser(
        id: id,
        email: email,
        name: name,
        photoUrl: photoUrl,
        perfil: perfil,
        telefone: telefone,
        criadoEm: criadoEm,
      );

  /// Mesmo formato do `UsuarioResponse`, para persistir e restaurar a sessão.
  Map<String, Object?> toJson() => {
        'id': id,
        'email': email,
        'nome': name,
        'perfil': perfil.api,
        'telefone': telefone,
        'criadoEm': criadoEm?.toIso8601String(),
      };
}
