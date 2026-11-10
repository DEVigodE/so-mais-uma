import 'package:equatable/equatable.dart';

import '../enums.dart';

/// Slot de 60 min da grade (`SlotResponse`), calculado pelo backend.
class Slot extends Equatable {
  const Slot({
    required this.inicio,
    required this.fim,
    required this.status,
    required this.valor,
  });

  final DateTime inicio;
  final DateTime fim;
  final StatusSlot status;
  final double valor;

  bool get livre => status == StatusSlot.livre;

  @override
  List<Object?> get props => [inicio, fim, status, valor];
}
