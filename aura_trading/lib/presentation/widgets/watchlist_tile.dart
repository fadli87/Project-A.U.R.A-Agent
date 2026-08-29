import 'package:flutter/material.dart';
import '../../data/models/price_ticker.dart';

class WatchlistTile extends StatelessWidget {
  final PriceTicker ticker;
  final bool isSelected;
  final VoidCallback onTap;

  const WatchlistTile({
    super.key,
    required this.ticker,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = ticker.isPositive;
    final changeColor = isPositive ? const Color(0xFF00E676) : const Color(0xFFFF5252);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.25)
              : const Color(0xFF1E1E2C).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6C63FF)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Row(
          children: [
            // Category Icon / Badge
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _getCategoryColor(ticker.category).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getCategoryColor(ticker.category).withValues(alpha: 0.4),
                ),
              ),
              child: Icon(
                _getCategoryIcon(ticker.category),
                color: _getCategoryColor(ticker.category),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Symbol & Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ticker.symbol,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ticker.category.name.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ticker.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Price & Change
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatPrice(ticker.price, ticker.category),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: changeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: changeColor,
                        size: 14,
                      ),
                      Text(
                        '${isPositive ? '+' : ''}${ticker.changePercent.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: changeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(AssetCategory category) {
    switch (category) {
      case AssetCategory.forex:
        return const Color(0xFF29B6F6);
      case AssetCategory.gold:
        return const Color(0xFFFFCA28);
      case AssetCategory.idxStock:
        return const Color(0xFFAB47BC);
    }
  }

  IconData _getCategoryIcon(AssetCategory category) {
    switch (category) {
      case AssetCategory.forex:
        return Icons.currency_exchange;
      case AssetCategory.gold:
        return Icons.workspace_premium;
      case AssetCategory.idxStock:
        return Icons.candlestick_chart;
    }
  }

  String _formatPrice(double price, AssetCategory category) {
    if (category == AssetCategory.idxStock) {
      return 'Rp ${price.toStringAsFixed(0)}';
    } else if (category == AssetCategory.gold) {
      return '\$${price.toStringAsFixed(2)}';
    } else {
      return price.toStringAsFixed( price >= 100 ? 2 : 4);
    }
  }
}
