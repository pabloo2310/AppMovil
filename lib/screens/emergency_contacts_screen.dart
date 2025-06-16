import 'package:flutter/material.dart';
import 'package:app_bullying/widgets/card_container.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_bullying/services/audit_logger.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, String>> contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContactsFromFirebase();
  }

  Future<void> _loadContactsFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('info_usuario')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            contacts.clear(); // Clear existing contacts

            // Cargar todos los contactos de emergencia (hasta 10)
            for (int i = 1; i <= 10; i++) {
              final contactName = data['EmergencyContact${i}Name'];
              final contactPhone = data['EmergencyContact${i}Phone'];
              
              if (contactName != null && contactPhone != null && 
                  contactName.toString().isNotEmpty && contactPhone.toString().isNotEmpty &&
                  contactPhone != 'No configurado') {
                contacts.add({
                  'name': contactName.toString(),
                  'number': contactPhone.toString(),
                });
              }
            }

            // Si no hay contactos, agregar uno por defecto para empezar
            if (contacts.isEmpty) {
              contacts.add({
                'name': 'Contacto de Emergencia',
                'number': 'No configurado',
              });
            }

            _isLoading = false;
          });
        } else {
          setState(() {
            // Si no existe el documento, crear un contacto por defecto
            contacts.clear();
            contacts.add({
              'name': 'Contacto de Emergencia',
              'number': 'No configurado',
            });
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading emergency contacts: $e');
        setState(() {
          contacts.clear();
          contacts.add({
            'name': 'Contacto de Emergencia',
            'number': 'No configurado',
          });
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar contactos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      setState(() {
        contacts.clear();
        contacts.add({
          'name': 'Contacto de Emergencia',
          'number': 'No configurado',
        });
        _isLoading = false;
      });
    }
  }

  Future<void> _saveContactsToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario no autenticado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Preparar datos para guardar
      Map<String, dynamic> contactsData = {};
      
      for (int i = 0; i < contacts.length; i++) {
        final contact = contacts[i];
        final index = i + 1;
        
        contactsData['EmergencyContact${index}Name'] = contact['name'];
        contactsData['EmergencyContact${index}Phone'] = contact['number'];
      }

      // Limpiar contactos que ya no existen (hasta 10)
      for (int i = contacts.length + 1; i <= 10; i++) {
        contactsData['EmergencyContact${i}Name'] = FieldValue.delete();
        contactsData['EmergencyContact${i}Phone'] = FieldValue.delete();
      }

      // Agregar timestamp
      contactsData['EmergencyContactsTimestamp'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection('info_usuario')
          .doc(user.uid)
          .set(contactsData, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📞 Contactos de emergencia guardados exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      AuditLogger.log('Contactos de emergencia guardados exitosamente');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar contactos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _pickContact(int index) async {
    if (!await FlutterContacts.requestPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de contactos denegado')),
      );
      return;
    }

    // Obtener contactos
    final contactsList = await FlutterContacts.getContacts(
      withProperties: true,
    );

    // Mostrar un selector simple
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView.builder(
          itemCount: contactsList.length,
          itemBuilder: (context, i) {
            final c = contactsList[i];
            return ListTile(
              title: Text(c.displayName),
              subtitle: Text(
                c.phones.isNotEmpty ? c.phones.first.number : 'Sin número',
              ),
              onTap: () {
                if (c.phones.isNotEmpty) {
                  setState(() {
                    contacts[index] = {
                      'name': c.displayName,
                      'number': c.phones.first.number,
                    };
                  });
                }
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Contactos de Emergencia',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFF5A623),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contactos de Emergencia',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF5A623),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5A623), // Naranja
              Color(0xFFA03E99), // Morado
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: CardContainer(
                  child: Column(
                    children: [
                      const Text(
                        'Contactos de Emergencia',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA03E99),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Configura los contactos que serán notificados en caso de emergencia',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      Expanded(
                        child: ListView(
                          children: [
                            _buildAdminContact(),
                            const Divider(),
                            ...contacts.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final contact = entry.value;
                              return Column(
                                children: [
                                  _buildContactItem(
                                    contact['name']!,
                                    contact['number']!,
                                    idx,
                                  ),
                                  const Divider(),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Botones para guardar contactos y agregar nuevo contacto
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isSaving ? null : _saveContactsToFirebase,
                                icon:
                                    _isSaving
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(Icons.save),
                                label: Text(
                                  _isSaving
                                      ? 'Guardando...'
                                      : 'Guardar Contactos',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFA03E99),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    contacts.add({
                                      'name': 'Nuevo Contacto',
                                      'number': 'No configurado',
                                    });
                                  });
                                },
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Agregar Contacto',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFA03E99),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Información adicional
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.yellow.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info,
                              color: Colors.orange.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Los contactos se guardan de forma segura y solo tú puedes acceder a ellos.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminContact() {
    return ListTile(
      leading: const Icon(Icons.admin_panel_settings, color: Color(0xFFA03E99)),
      title: const Text('Admin', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('admin@emergencia.com'),
      trailing: const Icon(Icons.lock, color: Colors.grey),
    );
  }

  Widget _buildContactItem(String name, String number, int index) {
    return ListTile(
      leading: const Icon(Icons.contact_phone, color: Color(0xFFA03E99)),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(number),
      trailing: IconButton(
        icon: const Icon(Icons.edit, color: Color(0xFFF5A623)),
        onPressed: () => _pickContact(index),
      ),
    );
  }
}
