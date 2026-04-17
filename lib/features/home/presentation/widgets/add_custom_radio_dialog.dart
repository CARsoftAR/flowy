import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../../../../domain/entities/radio_station.dart';
import '../../../../domain/entities/entities.dart';
import '../../../player/presentation/providers/player_provider.dart';
import 'package:provider/provider.dart';

class AddCustomRadioDialog extends StatefulWidget {
  final RadioStation? editingStation;
  const AddCustomRadioDialog({super.key, this.editingStation});

  @override
  State<AddCustomRadioDialog> createState() => _AddCustomRadioDialogState();
}

class _AddCustomRadioDialogState extends State<AddCustomRadioDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _genreController;
  late final TextEditingController _urlController;
  
  final List<List<Color>> _colorPresets = [
    [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
    [const Color(0xFFD97706), const Color(0xFFDC2626)],
    [const Color(0xFF059669), const Color(0xFF0D9488)],
    [const Color(0xFFEC4899), const Color(0xFF8B5CF6)],
    [const Color(0xFFF43F5E), const Color(0xFFE11D48)],
    [const Color(0xFF2563EB), const Color(0xFF7C3AED)],
    [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
    [const Color(0xFF84CC16), const Color(0xFF22C55E)],
  ];
  
  int _selectedColorIndex = 0;
  bool _isSearching = false;

  Future<void> _autoFetchUrl() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa el nombre de la radio primero')),
      );
      return;
    }

    setState(() => _isSearching = true);
    try {
      // Usando el balanceador de Radio Browser API
      final response = await http.get(
        Uri.parse('https://all.api.radio-browser.info/json/stations/byname/${Uri.encodeComponent(name)}'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List results = jsonDecode(response.body);
        if (results.isNotEmpty) {
          final bestMatch = results.first;
          setState(() {
            _urlController.text = bestMatch['url_resolved'] ?? bestMatch['url'] ?? '';
            if (_genreController.text.isEmpty && bestMatch['tags'] != null) {
              final tags = bestMatch['tags'].toString().split(',');
              if (tags.isNotEmpty) _genreController.text = tags.first.trim();
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Se encontró la URL para "${bestMatch['name']}"')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontró ninguna radio con ese nombre automáticamente')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al buscar la radio. Intenta ingresar la URL manualmente.')),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editingStation?.name);
    _genreController = TextEditingController(text: widget.editingStation?.genre);
    _urlController = TextEditingController(text: widget.editingStation?.streamUrl);
    
    if (widget.editingStation != null) {
      final stationColors = widget.editingStation!.gradientColors;
      for (int i = 0; i < _colorPresets.length; i++) {
        if (_colorPresets[i].first.value == stationColors.first.value) {
          _selectedColorIndex = i;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genreController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingStation != null;
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isEditing ? Icons.edit_rounded : Icons.radio, color: const Color(0xFF6366F1)),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Editar Radio' : 'Agregar Radio Personalizada',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre de la radio',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.label, color: Colors.white54),
                  suffixIcon: IconButton(
                    icon: _isSearching 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)))
                        : const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF6366F1)),
                    tooltip: 'Buscar URL automáticamente',
                    onPressed: _isSearching ? null : _autoFetchUrl,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa un nombre';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _autoFetchUrl(),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _genreController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Género (opcional)',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.music_note, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'URL del stream',
                  hintText: 'https://stream.radio.com/live',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.link, color: Colors.white54),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa la URL del stream';
                  }
                  if (!value.startsWith('http://') && !value.startsWith('https://')) {
                    return 'La URL debe comenzar con http:// o https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              Text(
                'Color',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_colorPresets.length, (index) {
                  final isSelected = index == _selectedColorIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorIndex = index),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: _colorPresets[index]),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _addRadio,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isEditing ? 'Guardar Cambios' : 'Agregar Radio'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addRadio() {
    if (_formKey.currentState!.validate()) {
      final radio = RadioStation(
        id: widget.editingStation?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        genre: _genreController.text.trim().isEmpty 
            ? 'Personalizado' 
            : _genreController.text.trim(),
        streamUrl: _urlController.text.trim(),
        gradientColors: _colorPresets[_selectedColorIndex],
        icon: Icons.radio,
      );
      
      Navigator.pop(context, radio);
    }
  }
}

Future<RadioStation?> showAddCustomRadioDialog(BuildContext context, {RadioStation? editingStation}) {
  return showDialog<RadioStation>(
    context: context,
    builder: (context) => AddCustomRadioDialog(editingStation: editingStation),
  );
}
