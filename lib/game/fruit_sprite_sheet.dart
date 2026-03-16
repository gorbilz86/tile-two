import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

class FruitSpriteSheet {
  static const int columns = 8;
  static const int rows = 8;
  static const int tileCount = columns * rows;

  final SpriteSheet _spriteSheet;
  final List<Sprite> _sprites;

  FruitSpriteSheet._({
    required SpriteSheet spriteSheet,
    required List<Sprite> sprites,
  })  : _spriteSheet = spriteSheet,
        _sprites = sprites;

  static Future<FruitSpriteSheet> load({
    required Images images,
    String assetPath = 'fruits.png',
  }) async {
    final candidates = [
      assetPath,
      'sprite/fruits.png',
      'sprite_sheet_fruits.png',
    ];
    String? loadedPath;
    for (final candidate in candidates) {
      try {
        await images.load(candidate);
        loadedPath = candidate;
        break;
      } catch (_) {}
    }
    if (loadedPath == null) {
      throw StateError('Unable to load fruit sprite sheet from ${candidates.join(', ')}');
    }
    final image = images.fromCache(loadedPath);

    final cellWidth = image.width / columns;
    final cellHeight = image.height / rows;
    if (cellWidth <= 0 || cellHeight <= 0) {
      throw StateError('Invalid sprite sheet size for $loadedPath');
    }

    final spriteSheet = SpriteSheet(
      image: image,
      srcSize: Vector2(cellWidth, cellHeight),
    );

    final sprites = <Sprite>[];
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        sprites.add(spriteSheet.getSprite(row, column));
      }
    }

    return FruitSpriteSheet._(
      spriteSheet: spriteSheet,
      sprites: sprites,
    );
  }

  int indexFromRowColumn({
    required int row,
    required int column,
  }) {
    _validateRowColumn(row: row, column: column);
    return (row * columns) + column;
  }

  ({int row, int column}) rowColumnFromIndex(int index) {
    _validateIndex(index);
    return (
      row: index ~/ columns,
      column: index % columns,
    );
  }

  Sprite spriteByIndex(int index) {
    _validateIndex(index);
    return _sprites[index];
  }

  Sprite spriteByRowColumn({
    required int row,
    required int column,
  }) {
    return spriteByIndex(indexFromRowColumn(row: row, column: column));
  }

  Rect srcRectByIndex(int index) {
    final rc = rowColumnFromIndex(index);
    final sprite = _spriteSheet.getSprite(rc.row, rc.column);
    return Rect.fromLTWH(
      sprite.srcPosition.x,
      sprite.srcPosition.y,
      _spriteSheet.srcSize.x,
      _spriteSheet.srcSize.y,
    );
  }

  void _validateIndex(int index) {
    if (index < 0 || index >= tileCount) {
      throw RangeError.range(index, 0, tileCount - 1, 'index');
    }
  }

  void _validateRowColumn({
    required int row,
    required int column,
  }) {
    if (row < 0 || row >= rows) {
      throw RangeError.range(row, 0, rows - 1, 'row');
    }
    if (column < 0 || column >= columns) {
      throw RangeError.range(column, 0, columns - 1, 'column');
    }
  }
}
