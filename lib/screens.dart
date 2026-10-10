import 'package:flutter/material.dart';

import 'models.dart';
import 'repository.dart';

String suitSymbol(String suit) => switch (suit) {
  'Hearts' => '♥',
  'Diamonds' => '♦',
  'Clubs' => '♣',
  'Spades' => '♠',
  _ => '♠',
};

Future<bool> confirmRemoval(BuildContext context, String item) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $item?'),
        content: Text(
          'Are you sure you want to delete $item? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

void showFailure(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Operation failed: $error')));
}

class FoldersPage extends StatefulWidget {
  final CardRepository repository;
  const FoldersPage({super.key, required this.repository});
  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  List<CardFolder> folders = [];
  bool loading = true;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final result = await widget.repository.getFoldersWithCounts();
      if (mounted)
        setState(() {
          folders = result;
          loading = false;
          error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          loading = false;
          error = '$e';
        });
    }
  }

  Future<void> editFolder([CardFolder? folder]) async {
    if (busy) return;

    final controller = TextEditingController(text: folder?.name ?? '');

    String? name;

    try {
      name = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              folder == null ? 'Add folder' : 'Rename ${folder.name}',
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Folder name'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();

                  if (value.isEmpty) return;

                  Navigator.of(dialogContext).pop(value);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    } finally {
      // Allow the dialog's exit animation to finish before
      // disposing the controller.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      controller.dispose();
    }

    if (!mounted || name == null) return;

    setState(() {
      busy = true;
    });

    try {
      final affected = folder == null
          ? await widget.repository.insertFolder(name)
          : await widget.repository.updateFolder(folder.id!, name);

      if (affected == 0) {
        throw StateError('No folder was updated');
      }

      await refresh();
    } catch (e) {
      if (mounted) {
        showFailure(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> removeFolder(CardFolder folder) async {
    if (busy ||
        !await confirmRemoval(
          context,
          'folder "${folder.name}" and its ${folder.cardCount} card(s)',
        ))
      return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final affected = await widget.repository.deleteFolder(folder.id!);
      if (affected == 0) throw StateError('Folder no longer exists');
      await refresh();
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Card folders')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: busy ? null : () => editFolder(),
      icon: const Icon(Icons.create_new_folder_outlined),
      label: const Text('Add folder'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(child: Text('Could not load folders: $error'))
        : folders.isEmpty
        ? const Center(child: Text('No folders yet. Add one to begin.'))
        : RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return ListTile(
                  title: Text(folder.name),
                  subtitle: Text('${folder.cardCount} card(s)'),
                  leading: const Icon(Icons.folder_outlined),
                  onTap: busy
                      ? null
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CardsPage(
                                repository: widget.repository,
                                folder: folder,
                              ),
                            ),
                          );
                          if (mounted) await refresh();
                        },
                  trailing: PopupMenuButton<String>(
                    enabled: !busy,
                    onSelected: (action) {
                      if (action == 'edit')
                        editFolder(folder);
                      else
                        removeFolder(folder);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                );
              },
            ),
          ),
  );
}

class CardsPage extends StatefulWidget {
  final CardRepository repository;
  final CardFolder folder;
  const CardsPage({super.key, required this.repository, required this.folder});
  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  List<PlayingCard> cards = [];
  bool loading = true;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final result = await widget.repository.getCards(widget.folder.id!);
      if (mounted)
        setState(() {
          cards = result;
          loading = false;
          error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          loading = false;
          error = '$e';
        });
    }
  }

  Future<void> editCard([PlayingCard? card]) async {
    if (busy) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CardEditorPage(
          repository: widget.repository,
          initialFolderId: widget.folder.id!,
          existing: card,
        ),
      ),
    );
    if (saved == true && mounted) await refresh();
  }

  Future<void> removeCard(PlayingCard card) async {
    if (busy || !await confirmRemoval(context, 'card "${card.title}"')) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final affected = await widget.repository.deleteCard(card.id!);
      if (affected == 0) throw StateError('Card no longer exists');
      await refresh();
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget cardImage(PlayingCard card) {
    final ref = card.imageRef;
    final fallback = Center(
      child: Text(suitSymbol(card.suit), style: const TextStyle(fontSize: 32)),
    );
    if (ref == null || ref.trim().isEmpty) return fallback;
    final uri = Uri.tryParse(ref);
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty)
      return fallback;
    return Image.network(
      ref,
      height: 54,
      width: 54,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : fallback,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.folder.name)),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: busy ? null : () => editCard(),
      icon: const Icon(Icons.add),
      label: const Text('Add card'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(child: Text('Could not load cards: $error'))
        : cards.isEmpty
        ? const Center(child: Text('This folder has no cards yet.'))
        : RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return ListTile(
                  leading: SizedBox(
                    width: 54,
                    height: 54,
                    child: cardImage(card),
                  ),
                  title: Text(card.title),
                  subtitle: Text('${card.suit} · ${card.notes}'),
                  onTap: busy ? null : () => editCard(card),
                  trailing: IconButton(
                    tooltip: 'Delete ${card.title}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: busy ? null : () => removeCard(card),
                  ),
                );
              },
            ),
          ),
  );
}

class CardEditorPage extends StatefulWidget {
  final CardRepository repository;
  final int initialFolderId;
  final PlayingCard? existing;
  const CardEditorPage({
    super.key,
    required this.repository,
    required this.initialFolderId,
    this.existing,
  });
  @override
  State<CardEditorPage> createState() => _CardEditorPageState();
}

class _CardEditorPageState extends State<CardEditorPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController notes;
  late final TextEditingController imageRef;
  late String suit;
  late int folderId;
  List<CardFolder> folders = [];
  bool loading = true;
  bool saving = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.existing?.title ?? '');
    notes = TextEditingController(text: widget.existing?.notes ?? '');
    imageRef = TextEditingController(text: widget.existing?.imageRef ?? '');
    suit = widget.existing?.suit ?? PlayingCard.suits.first;
    folderId = widget.existing?.folderId ?? widget.initialFolderId;
    loadFolders();
  }

  Future<void> loadFolders() async {
    try {
      final result = await widget.repository.getFoldersWithCounts();
      if (mounted)
        setState(() {
          folders = result;
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          loadError = '$e';
          loading = false;
        });
    }
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    imageRef.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
    });

    bool savedSuccessfully = false;

    try {
      final card = PlayingCard(
        title: title.text.trim(),
        suit: suit,
        notes: notes.text,
        imageRef: imageRef.text,
        folderId: folderId,
      );

      final affected = widget.existing == null
          ? await widget.repository.insertCard(card)
          : await widget.repository.updateCard(widget.existing!.id!, card);

      if (affected == 0) {
        throw StateError('No card was changed');
      }

      savedSuccessfully = true;
    } catch (e) {
      if (mounted) {
        showFailure(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }

    if (!mounted) return;

    if (savedSuccessfully) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.existing == null ? 'Add card' : 'Edit card'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : loadError != null
        ? Center(child: Text('Unable to load folders: $loadError'))
        : Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: title,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Title is required'
                      : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: suit,
                  decoration: const InputDecoration(labelText: 'Suit *'),
                  items: PlayingCard.suits
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text('${suitSymbol(s)} $s'),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => suit = value);
                        },
                  validator: (value) => !PlayingCard.suits.contains(value)
                      ? 'Choose a supported suit'
                      : null,
                ),
                DropdownButtonFormField<int>(
                  initialValue: folders.any((f) => f.id == folderId)
                      ? folderId
                      : null,
                  decoration: const InputDecoration(labelText: 'Folder *'),
                  items: folders
                      .map(
                        (f) =>
                            DropdownMenuItem(value: f.id, child: Text(f.name)),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => folderId = value);
                        },
                  validator: (value) =>
                      value == null ? 'Choose an existing folder' : null,
                ),
                TextFormField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                TextFormField(
                  controller: imageRef,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                    helperText: 'Empty or invalid URLs show a suit symbol',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: saving || folders.isEmpty ? null : save,
                  child: Text(saving ? 'Saving…' : 'Save card'),
                ),
              ],
            ),
          ),
  );
}
