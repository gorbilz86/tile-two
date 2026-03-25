import 'package:tile_two/game/save_game_repository.dart';

class ShopCatalogItem {
  final String id;
  final String title;
  final String description;
  final int priceCoins;
  final int undo;
  final int shuffle;
  final int hint;

  const ShopCatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.priceCoins,
    required this.undo,
    required this.shuffle,
    required this.hint,
  });
}

class ShopPurchaseResult {
  final bool success;
  final ShopPurchaseStatus status;
  final String? purchasedItemId;
  final SaveGameData updatedData;

  const ShopPurchaseResult({
    required this.success,
    required this.status,
    required this.purchasedItemId,
    required this.updatedData,
  });
}

enum ShopPurchaseStatus {
  itemNotFound,
  coinsNotEnough,
  success,
}

class ShopService {
  ShopService._();

  static final ShopService instance = ShopService._();

  static const List<ShopCatalogItem> _catalog = [
    ShopCatalogItem(
      id: 'hint_single',
      title: 'Hint x1',
      description: 'Tambahan 1 Hint untuk bantu cari match.',
      priceCoins: 35,
      undo: 0,
      shuffle: 0,
      hint: 1,
    ),
    ShopCatalogItem(
      id: 'undo_single',
      title: 'Undo x1',
      description: 'Batalkan 1 langkah terakhir.',
      priceCoins: 45,
      undo: 1,
      shuffle: 0,
      hint: 0,
    ),
    ShopCatalogItem(
      id: 'shuffle_single',
      title: 'Shuffle x1',
      description: 'Acak ulang posisi ubin tersisa.',
      priceCoins: 55,
      undo: 0,
      shuffle: 1,
      hint: 0,
    ),
    ShopCatalogItem(
      id: 'starter_pack',
      title: 'Starter Pack',
      description: 'Paket hemat awal permainan.',
      priceCoins: 120,
      undo: 1,
      shuffle: 1,
      hint: 2,
    ),
    ShopCatalogItem(
      id: 'strategy_pack',
      title: 'Strategy Pack',
      description: 'Fokus boost untuk puzzle sulit.',
      priceCoins: 210,
      undo: 3,
      shuffle: 2,
      hint: 3,
    ),
    ShopCatalogItem(
      id: 'mega_pack',
      title: 'Mega Pack',
      description: 'Booster bundle lengkap.',
      priceCoins: 360,
      undo: 5,
      shuffle: 4,
      hint: 6,
    ),
  ];

  List<ShopCatalogItem> catalog() {
    return _catalog;
  }

  ShopPurchaseResult purchase({
    required SaveGameData saveData,
    required String itemId,
  }) {
    ShopCatalogItem? selected;
    for (final item in _catalog) {
      if (item.id == itemId) {
        selected = item;
        break;
      }
    }
    if (selected == null) {
      return ShopPurchaseResult(
        success: false,
        status: ShopPurchaseStatus.itemNotFound,
        purchasedItemId: null,
        updatedData: saveData,
      );
    }
    if (saveData.coins < selected.priceCoins) {
      return ShopPurchaseResult(
        success: false,
        status: ShopPurchaseStatus.coinsNotEnough,
        purchasedItemId: null,
        updatedData: saveData,
      );
    }
    final nextData = saveData.copyWith(
      coins: saveData.coins - selected.priceCoins,
      inventory: saveData.inventory.copyWith(
        undo: saveData.inventory.undo + selected.undo,
        shuffle: saveData.inventory.shuffle + selected.shuffle,
        hint: saveData.inventory.hint + selected.hint,
      ),
    );
    return ShopPurchaseResult(
      success: true,
      status: ShopPurchaseStatus.success,
      purchasedItemId: selected.id,
      updatedData: nextData,
    );
  }
}
