class CardFolder {
  final int? id;
  final String name;
  final String createdAt;
  final int cardCount;

  const CardFolder({this.id, required this.name, required this.createdAt, this.cardCount = 0});

  factory CardFolder.fromMap(Map<String, Object?> row) => CardFolder(
        id: row['id'] as int,
        name: row['name'] as String,
        createdAt: row['created_at'] as String,
        cardCount: (row['card_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toMap() => {
        'name': name,
        'created_at': createdAt,
      };
}

class PlayingCard {
  static const suits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];

  final int? id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;

  const PlayingCard({
    this.id,
    required this.title,
    required this.suit,
    this.notes = '',
    this.imageRef,
    required this.folderId,
  });

  factory PlayingCard.fromMap(Map<String, Object?> row) => PlayingCard(
        id: row['id'] as int,
        title: row['title'] as String,
        suit: row['suit'] as String,
        notes: row['notes'] as String? ?? '',
        imageRef: row['image_ref'] as String?,
        folderId: row['folder_id'] as int,
      );

  Map<String, Object?> toMap() => {
        'title': title.trim(),
        'suit': suit,
        'notes': notes,
        'image_ref': imageRef?.trim().isEmpty == true ? null : imageRef?.trim(),
        'folder_id': folderId,
      };
}
