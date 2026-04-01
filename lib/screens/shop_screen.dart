import 'package:flutter/material.dart';
import 'package:tile_two/game/save_game_repository.dart';
import 'package:tile_two/game/shop_service.dart';
import 'package:tile_two/l10n/app_i18n.dart';
import 'package:tile_two/ui/google_fonts_proxy.dart';
import 'package:tile_two/ui/booster_3d_icon.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final SaveGameRepository _saveRepository = SaveGameRepository();
  final ShopService _shopService = ShopService.instance;
  SaveGameData? _saveData;
  bool _isLoading = true;
  String _notice = '';
  String? _pendingItemId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final save = await _saveRepository.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _saveData = save;
      _isLoading = false;
    });
  }

  Future<void> _buyItem(ShopCatalogItem item) async {
    final t = AppI18n.of(context);
    final save = _saveData;
    if (save == null || _pendingItemId != null) {
      return;
    }
    setState(() {
      _pendingItemId = item.id;
      _notice = '';
    });
    final result = _shopService.purchase(
      saveData: save,
      itemId: item.id,
    );
    if (result.success) {
      await _saveRepository.save(result.updatedData);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _saveData = result.updatedData;
      _notice = _shopNoticeText(t, result);
      _pendingItemId = null;
    });
  }

  String _shopNoticeText(AppI18n t, ShopPurchaseResult result) {
    return switch (result.status) {
      ShopPurchaseStatus.itemNotFound => t.tr('shop.notice.item_not_found'),
      ShopPurchaseStatus.coinsNotEnough => t.tr('shop.notice.coin_not_enough'),
      ShopPurchaseStatus.success => t.tr(
          'shop.notice.purchase_success',
          params: {'item': _shopItemTitle(t, result.purchasedItemId ?? '')},
        ),
    };
  }

  String _shopItemTitle(AppI18n t, String itemId) {
    return t.tr('shop.item.$itemId.title');
  }

  String _shopItemDescription(AppI18n t, String itemId) {
    return t.tr('shop.item.$itemId.desc');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final save = _saveData;
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(18),
                        Colors.black.withAlpha(72),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(85),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.white.withAlpha(130)),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.tr('shop.title'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(95),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withAlpha(120)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/coin_icon.png',
                              width: 18,
                              height: 18,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${save?.coins ?? 0}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_notice.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF112C49).withAlpha(238),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha(70)),
                      ),
                      child: Text(
                        _notice,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFBFE6FF),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _shopService.catalog().length,
                            itemBuilder: (context, index) {
                              final item = _shopService.catalog()[index];
                              final pending = _pendingItemId == item.id;
                              final canBuy =
                                  (save?.coins ?? 0) >= item.priceCoins;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF102744).withAlpha(240),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.white.withAlpha(95),
                                      width: 1.2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _shopItemTitle(t, item.id),
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Image.asset(
                                              'assets/images/coin_icon.png',
                                              width: 16,
                                              height: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${item.priceCoins}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFFFFE08A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _shopItemDescription(t, item.id),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white.withAlpha(215),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (item.hint > 0)
                                          _buildRewardItem(
                                            type: BoosterType.hint,
                                            count: item.hint,
                                          ),
                                        if (item.undo > 0)
                                          _buildRewardItem(
                                            type: BoosterType.undo,
                                            count: item.undo,
                                          ),
                                        if (item.shuffle > 0)
                                          _buildRewardItem(
                                            type: BoosterType.shuffle,
                                            count: item.shuffle,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onTap: (!pending && canBuy)
                                          ? () => _buyItem(item)
                                          : null,
                                      child: Opacity(
                                        opacity: (!pending && canBuy) ? 1 : 0.5,
                                        child: Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Color(0xFF00C896),
                                                Color(0xFF00A27C),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color:
                                                  Colors.white.withAlpha(170),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              pending
                                                  ? t.tr('common.processing')
                                                  : (canBuy
                                                      ? t.tr('shop.buy_now')
                                                      : t.tr(
                                                          'shop.coin_insufficient',
                                                        )),
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardItem({
    required BoosterType type,
    required int count,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Booster3DIcon(
          type: type,
          size: 24,
        ),
        const SizedBox(width: 6),
        Text(
          '+$count',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFBEE0FF),
          ),
        ),
      ],
    );
  }
}
