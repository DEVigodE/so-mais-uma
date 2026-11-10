import 'package:equatable/equatable.dart';

import '../enums.dart';

/// Endereço devolvido por `GET /cep/{cep}` (`CepResponse`).
class EnderecoCep extends Equatable {
  const EnderecoCep({
    required this.cep,
    this.logradouro,
    this.bairro,
    this.cidade,
    this.uf,
    this.latitude,
    this.longitude,
    this.fonte,
  });

  final String cep;
  final String? logradouro;
  final String? bairro;
  final String? cidade;
  final String? uf;
  final double? latitude;
  final double? longitude;
  final FonteCep? fonte;

  @override
  List<Object?> get props =>
      [cep, logradouro, bairro, cidade, uf, latitude, longitude, fonte];
}
