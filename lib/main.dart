import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'repository.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final helper = DatabaseHelper();

  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');

    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not open local storage. Restart the app and check the logs.',
            ),
          ),
        ),
      ),
    );

    return;
  }

  runApp(DirectoryApp(helper: helper));
}


class DirectoryApp extends StatefulWidget {
  final DatabaseHelper helper;

  const DirectoryApp({super.key, required this.helper});

  @override
  State<DirectoryApp> createState() => _DirectoryAppState();
}

class _DirectoryAppState extends State<DirectoryApp> {
  int selectedTab = 0;

  late final CardRepository repository =
      CardRepository(() async => widget.helper.database);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Festival Roster & Card Catalogue',
      home: Scaffold(
        body: IndexedStack(
          index: selectedTab,
          children: [
            DirectoryScreen(helper: widget.helper),
            FoldersPage(repository: repository),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedTab,
          onDestinationSelected: (index) {
            setState(() {
              selectedTab = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              label: 'Part I Roster',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              label: 'Card Folders',
            ),
          ],
        ),
      ),
    );
  }
}

class DirectoryScreen extends StatefulWidget {
  final DatabaseHelper helper;

  const DirectoryScreen({super.key, required this.helper});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<Map<String, dynamic>> _rows = [];
  int _count = 0;

  bool _isLoading = true;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  int? _selectedId;

  bool _isBusy = false;
  String? _feedbackMessage;

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  Future<void> _loadRows() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) return;

      setState(() {
        _rows = rows;
        _count = count;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load database: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Could not load the festival roster.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveGuest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final age = int.parse(_ageController.text.trim());

    setState(() {
      _isBusy = true;
      _feedbackMessage = null;
    });

    bool writeSucceeded = false;

    try {
      if (_selectedId == null) {
        final id = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        writeSucceeded = true;

        if (!mounted) return;

        setState(() {
          _feedbackMessage = 'Guest saved with ID $id';
        });
      } else {
        final updated = await widget.helper.update({
          DatabaseHelper.columnId: _selectedId,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        if (!mounted) return;

        if (updated == 1) {
          writeSucceeded = true;

          setState(() {
            _feedbackMessage = 'Guest updated successfully.';
          });
        } else {
          setState(() {
            _feedbackMessage = 'Guest was not found. Refreshing roster.';
          });
        }
      }

      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) return;

      setState(() {
        _rows = rows;
        _count = count;

        if (writeSucceeded) {
          _selectedId = null;
          _nameController.clear();
          _ageController.clear();
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to save guest: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _feedbackMessage = 'Could not save guest.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _deleteGuest(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete guest?'),
          content: Text('Delete $name (ID $id) from the roster?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isBusy = true;
      _feedbackMessage = null;
    });

    try {
      final deleted = await widget.helper.delete(id);

      if (!mounted) return;

      if (deleted == 1) {
        if (_selectedId == id) {
          _selectedId = null;
          _nameController.clear();
          _ageController.clear();
        }

        setState(() {
          _feedbackMessage = 'Guest deleted successfully.';
        });
      } else {
        setState(() {
          _feedbackMessage = 'Guest was not found. Refreshing roster.';
        });
      }

      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) return;

      setState(() {
        _rows = rows;
        _count = count;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to delete guest: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _feedbackMessage = 'Could not delete guest.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _startEdit(Map<String, dynamic> row) {
    setState(() {
      _selectedId = row[DatabaseHelper.columnId] as int;
      _nameController.text = row[DatabaseHelper.columnName].toString();
      _ageController.text = row[DatabaseHelper.columnAge].toString();

      _feedbackMessage = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _selectedId = null;
      _nameController.clear();
      _ageController.clear();
      _feedbackMessage = null;
    });
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadRows, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_isBusy,
                  decoration: const InputDecoration(
                    labelText: 'Guest name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';

                    if (name.isEmpty) {
                      return 'Please enter a name.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _ageController,
                  enabled: !_isBusy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    final age = int.tryParse(text);

                    if (age == null) {
                      return 'Enter a whole number.';
                    }

                    if (age < 0 || age > 130) {
                      return 'Age must be between 0 and 130.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isBusy ? null : _saveGuest,
                    child: Text(
                      _isBusy
                          ? 'Saving...'
                          : _selectedId == null
                          ? 'Add Guest'
                          : 'Save Changes',
                    ),
                  ),
                ),
                if (_selectedId != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isBusy ? null : _cancelEdit,
                      child: const Text('Cancel Edit'),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_feedbackMessage != null) Text(_feedbackMessage!),

          const SizedBox(height: 16),

          Text(
            'Record count: $_count',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: _rows.isEmpty
                ? const Center(child: Text('No festival guests yet'))
                : ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
                      final row = _rows[index];

                      return ListTile(
                        title: Text(row[DatabaseHelper.columnName].toString()),
                        subtitle: Text(
                          'ID: ${row[DatabaseHelper.columnId]} | '
                          'Age: ${row[DatabaseHelper.columnAge]}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _isBusy ? null : () => _startEdit(row),
                              icon: const Icon(Icons.edit),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              onPressed: _isBusy
                                  ? null
                                  : () => _deleteGuest(
                                      row[DatabaseHelper.columnId] as int,
                                      row[DatabaseHelper.columnName].toString(),
                                    ),
                              icon: const Icon(Icons.delete),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Festival Roster'),
        actions: [
          IconButton(
            onPressed: (_isLoading || _isBusy) ? null : _loadRows,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }
}
