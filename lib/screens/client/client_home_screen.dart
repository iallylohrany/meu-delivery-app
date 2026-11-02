import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/placeholder_content.dart';
import '../profile_select_screen.dart';
import 'lojas_screen.dart';
import 'enderecos_screen.dart';
import 'pedidos_screen.dart';


class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  int _indiceAtual = 0;

  static const _titulos = ['Lojas', 'Meus pedidos', 'Endereços', 'Minha conta'];
  static const _icones = [
    Icons.storefront_outlined,
    Icons.receipt_long_outlined,
    Icons.location_on_outlined,
    Icons.person_outline,
  ];


  Future<void> _sessaoExpirada() async {
    await AuthService.sair();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sua sessão expirou. Entre novamente.')),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ProfileSelectScreen()),
      (route) => false,
    );
  }

  Widget _corpoDaAba() {
    switch (_indiceAtual) {
      case 0:
        return LojasScreen(onSessaoExpirada: _sessaoExpirada);
      case 1:
        return PedidosScreen(
          onSessaoExpirada: _sessaoExpirada,
          onVerLojas: () => setState(() => _indiceAtual = 0),
        );
      case 2:
        return EnderecosScreen(onSessaoExpirada: _sessaoExpirada);
      case 3:
        return const _MinhaContaTab();
      default:
        return PlaceholderContent(
          titulo: _titulos[_indiceAtual],
          icone: _icones[_indiceAtual],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titulos[_indiceAtual])),
      body: _corpoDaAba(),
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


class _MinhaContaTab extends StatelessWidget {
  const _MinhaContaTab();

  Future<void> _sair(BuildContext context) async {
    await AuthService.sair();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ProfileSelectScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Minha conta',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              '(dados do perfil virão em outra tarefa)',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _sair(context),
              icon: const Icon(Icons.logout),
              label: const Text('Sair'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
