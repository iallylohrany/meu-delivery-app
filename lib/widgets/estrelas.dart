import 'package:flutter/material.dart';


class Estrelas extends StatelessWidget {
  final int nota;
  final ValueChanged<int>? aoMudar;
  final double tamanho;

  const Estrelas({
    super.key,
    required this.nota,
    this.aoMudar,
    this.tamanho = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          aoMudar == null
              ? Icon(
                  i <= nota ? Icons.star : Icons.star_border,
                  size: tamanho,
                  color: Colors.amber.shade700,
                )
              : IconButton(
                  tooltip: '$i ${i == 1 ? 'estrela' : 'estrelas'}',
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: tamanho + 8, minHeight: tamanho + 8),
                  onPressed: () => aoMudar!(i),
                  icon: Icon(
                    i <= nota ? Icons.star : Icons.star_border,
                    size: tamanho,
                    color: Colors.amber.shade700,
                  ),
                ),
      ],
    );
  }
}
