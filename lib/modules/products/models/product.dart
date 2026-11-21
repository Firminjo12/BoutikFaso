enum ProductStockStatus { available, low, outOfStock }

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.purchasePrice,
    required this.salePrice,
    required this.quantity,
    required this.alertThreshold,
    this.sku = '',
    this.description = '',
    this.imagePath,
  });

  final String id;
  final String name;
  final String category;
  final int purchasePrice;
  final int salePrice;
  final int quantity;
  final int alertThreshold;
  final String sku;
  final String description;
  final String? imagePath;

  ProductStockStatus get stockStatus {
    if (quantity == 0) return ProductStockStatus.outOfStock;
    if (quantity <= alertThreshold) return ProductStockStatus.low;
    return ProductStockStatus.available;
  }

  Product copyWith({
    String? id,
    String? name,
    String? category,
    int? purchasePrice,
    int? salePrice,
    int? quantity,
    int? alertThreshold,
    String? sku,
    String? description,
    String? imagePath,
    bool clearImage = false,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    salePrice: salePrice ?? this.salePrice,
    quantity: quantity ?? this.quantity,
    alertThreshold: alertThreshold ?? this.alertThreshold,
    sku: sku ?? this.sku,
    description: description ?? this.description,
    imagePath: clearImage ? null : imagePath ?? this.imagePath,
  );
}
