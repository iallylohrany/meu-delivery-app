import 'package:flutter/material.dart';
import '../../widgets/placeholder_content.dart';
import 'entregas_screen.dart';
import 'ganhos_screen.dart';


class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  int _indiceAtual = 0;

  static const _titulos = ['Entregas', 'Ganhos', 'Minha conta'];
  static const _icones = [
    Icons.two_wheeler_outlined,
    Icons.payments_outlined,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titulos[_indiceAtual])),
      body: _indiceAtual == 0
          ? const EntregasScreen()
          : _indiceAtual == 1
              ? const GanhosScreen()
              : PlaceholderContent(
                  titulo: _titulos[_indiceAtual],
                  icone: _icones[_indiceAtual],
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceAtual,
        onDestinationSelected: (i) => setState(() => _indiceAtual = i),
        destinations: List.generate(
          _titulos.length,
          (i) => NavigationDestination(
            icon: Icon(_icones[i]),
            label: _titulos[i],
          ),
        ),
      ),
    );
  }
}
