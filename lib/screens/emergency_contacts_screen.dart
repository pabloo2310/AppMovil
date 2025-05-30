import 'package:flutter/material.dart';
import 'package:app_bullying/widgets/card_container.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, String>> contacts = [
    {'name': 'Contacto 1', 'number': 'No configurado'},
    {'name': 'Contacto 2', 'number': 'No configurado'},
  ];

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
            // Cargar contacto 1
            if (data['EmergencyContact1Name'] != null && data['EmergencyContact1Phone'] != null) {
              contacts[0] = {
                'name': data['EmergencyContact1Name'],
                'number': data['EmergencyContact1Phone'],
              };
            }
            // Cargar contacto 2
            if (data['EmergencyContact2Name'] != null && data['EmergencyContact2Phone'] != null) {
              contacts[1] = {
                'name': data['EmergencyContact2Name'],
                'number': data['EmergencyContact2Phone'],
              };
            }
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading emergency contacts: $e');
        setState(() {
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
      await FirebaseFirestore.instance
          .collection('info_usuario')
          .doc(user.uid)
          .set({
        'EmergencyContact1Name': contacts[0]['name'],
        'EmergencyContact1Phone': contacts[0]['number'],
        'EmergencyContact2Name': contacts[1]['name'],
        'EmergencyContact2Phone': contacts[1]['number'],
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📞 Contactos de emergencia guardados exitosamente'),
          backgroundColor: Colors.green,
        ),
      );

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
    final contactsList = await FlutterContacts.getContacts(withProperties: true);

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
              subtitle: Text(c.phones.isNotEmpty ? c.phones.first.number : 'Sin número'),
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
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
                                  _buildContactItem(contact['name']!, contact['number']!, idx),
                                  const Divider(),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Botón para guardar contactos
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveContactsToFirebase,
                          icon: _isSaving 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                          label: Text(_isSaving ? 'Guardando...' : 'Guardar Contactos'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA03E99),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
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
                            Icon(Icons.info, color: Colors.orange.shade600, size: 20),
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
      title: const Text(
        'Admin',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('admin@emergencia.com'),
      trailing: const Icon(Icons.lock, color: Colors.grey),
    );
  }

  Widget _buildContactItem(String name, String number, int index) {
    return ListTile(
      leading: const Icon(Icons.contact_phone, color: Color(0xFFA03E99)),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(number),
      trailing: IconButton(
        icon: const Icon(Icons.edit, color: Color(0xFFF5A623)),
        onPressed: () => _pickContact(index),
      ),
    );
  }
}
