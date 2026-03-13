# Fruit Sprite Mapping (8x8, Index 0-63)

File sumber sprite sheet:

- `assets/images/sprite/fruits.png`

Spesifikasi mapping:

- Grid: `8 x 8`
- Total item: `64`
- Rentang index valid: `0..63`
- Urutan index: row-major
- Rumus index: `index = row * 8 + column`

## API yang tersedia

Kelas: `FruitSpriteSheet` di `lib/game/fruit_sprite_sheet.dart`

- `FruitSpriteSheet.load(images: images)`  
  Memuat sprite sheet dari cache Flame Images.

- `spriteByIndex(int index)`  
  Ambil sprite berdasarkan index 0..63.

- `spriteByRowColumn(row: r, column: c)`  
  Ambil sprite berdasarkan row/column.

- `indexFromRowColumn(row: r, column: c)`  
  Konversi row/column ke index dengan format umum game.

- `rowColumnFromIndex(index)`  
  Konversi index ke `(row, column)`.

## Contoh penggunaan

```dart
final sheet = await FruitSpriteSheet.load(images: game.images);

final sprite0 = sheet.spriteByIndex(0);    // kiri atas
final sprite63 = sheet.spriteByIndex(63);  // kanan bawah

final index = sheet.indexFromRowColumn(row: 2, column: 5); // 21
final rc = sheet.rowColumnFromIndex(21); // (row: 2, column: 5)
final sprite = sheet.spriteByRowColumn(row: 2, column: 5);
```

## Error handling

- Jika `index` di luar `0..63`, method akan throw `RangeError`.
- Jika `row` atau `column` di luar batas grid (`0..7`), method akan throw `RangeError`.
