// =============================================================================
// search_field.dart  -  Campo de busqueda reutilizable
// =============================================================================
// ASPECTO EN PANTALLA:
//   TextField con fondo blanco, icono personalizable a la izquierda,
//   hint text configurable, borde gris (focused: azul). Diseno compacto
//   (isDense) con padding ajustado.
//
// USO:
//   Componente de busqueda generico usado en multiples pantallas
//   (obras, operarios, etc.). Estilizado con las constantes del tema.
//
// DATOS QUE NECESITA:
//   - controller: TextEditingController
//   - hint: texto placeholder
//   - icon: IconData a mostrar (ej: Icons.search, Icons.business)
//   - onSubmit: callback opcional al pulsar Enter
//
// INTERACCION DEL USUARIO:
//   - Escribir modifica el controller (gestionado externamente)
//   - Pulsar Enter ejecuta onSubmit si esta definido
// =============================================================================

/// Campo de búsqueda reutilizable con icono personalizable.
/// Se usa en varias pantallas para buscar obras, operarios, etc.
import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';

/// Campo de texto estilizado para busqueda. Reutilizable en toda la app.
///
/// [StatelessWidget]: no tiene estado interno; usa el controller externo.
class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<String>? onSubmit;

  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14, color: textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: textSecondary),
        filled: true,
        fillColor: bgCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        // Borde normal (gris).
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: cardBorder),
        ),
        // Borde cuando no esta enfocado.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: cardBorder),
        ),
        // Borde cuando esta enfocado (azul).
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: blue),
        ),
        isDense: true,
      ),
      onSubmitted: onSubmit,
    );
  }
}
