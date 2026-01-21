// lib/services/in_app_purchase_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'supabase_service.dart';
import '../utils/logger.dart';

class InAppPurchaseService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final SupabaseService _supabaseService;
  
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isAvailable = false;
  Set<String> _availableProducts = {};
  final Map<String, ProductDetails> _products = {};

  /// Callback opcional para notificar a UI quando uma compra for validada com sucesso
  VoidCallback? onPurchaseValidated;
  /// Callback opcional para notificar erro de validação para a UI
  void Function(String message)? onPurchaseValidationError;

  InAppPurchaseService(this._supabaseService);

  /// Inicializa o serviço de In-App Purchase
  Future<void> initialize() async {
    try {
      Logger.info('Inicializando In-App Purchase...');
      Logger.debug('Plataforma: ${Platform.isIOS ? "iOS" : Platform.isAndroid ? "Android" : "Outra"}');
      
      _isAvailable = await _inAppPurchase.isAvailable();
      Logger.info('In-App Purchase disponível: $_isAvailable');
      
      if (!_isAvailable) {
        Logger.warning('In-App Purchase não está disponível nesta plataforma');
        Logger.debug('Isso é normal em simuladores ou dispositivos sem conta configurada');
        return;
      }

      // Configurar listener para atualizações de compra
      Logger.debug('Configurando listener para atualizações de compra...');
      _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () {
          Logger.info('Stream de compras finalizado');
          _purchaseSubscription?.cancel();
        },
        onError: (error) => Logger.error('Erro no stream de compras', error, StackTrace.current),
      );

      Logger.info('In-App Purchase Service inicializado com sucesso');
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar In-App Purchase Service', e, stackTrace);
      _isAvailable = false;
    }
  }

  /// Busca produtos disponíveis
  Future<Map<String, ProductDetails>> getAvailableProducts(List<String> productIds) async {
    if (!_isAvailable || productIds.isEmpty) {
      return {};
    }

    try {
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds.toSet());
      
      if (response.error != null) {
        Logger.error('Erro ao buscar produtos', response.error, StackTrace.current);
        return {};
      }

      // Armazenar produtos encontrados
      for (final product in response.productDetails) {
        _products[product.id] = product;
        _availableProducts.add(product.id);
      }

      // Log de produtos não encontrados
      final notFoundIds = productIds.where((id) => !_availableProducts.contains(id)).toList();
      if (notFoundIds.isNotEmpty) {
        Logger.warning('Produtos não encontrados: $notFoundIds');
      }

      return _products;
    } catch (e, stackTrace) {
      Logger.error('Erro ao buscar produtos disponíveis', e, stackTrace);
      return {};
    }
  }

  /// Obtém detalhes de um produto específico
  ProductDetails? getProductDetails(String productId) {
    return _products[productId];
  }

  /// Comprar uma assinatura
  Future<bool> buySubscription(String productId) async {
    if (!_isAvailable) {
      Logger.warning('In-App Purchase não está disponível');
      return false;
    }

    Logger.debug('Tentando comprar produto: $productId');
    Logger.debug('Produtos disponíveis no map: ${_products.keys.toList()}');
    
    final product = _products[productId];
    if (product == null) {
      Logger.error('Produto não encontrado no map: $productId', null, StackTrace.current);
      Logger.warning('Tentando buscar produto do store...');
      
      // Tentar buscar o produto do store se não estiver no map
      try {
        final products = await getAvailableProducts([productId]);
        if (products.isEmpty || !products.containsKey(productId)) {
          Logger.error('Produto não encontrado no store: $productId', null, StackTrace.current);
          return false;
        }
        final fetchedProduct = products[productId]!;
        Logger.info('Produto encontrado no store, iniciando compra...');
        
        final PurchaseParam purchaseParam = PurchaseParam(productDetails: fetchedProduct);
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
        Logger.info('Compra iniciada para produto: $productId');
        return true;
      } catch (e, stackTrace) {
        Logger.error('Erro ao buscar produto do store', e, stackTrace);
        return false;
      }
    }

    try {
      Logger.debug('Produto encontrado no map, criando PurchaseParam...');
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      
      Logger.debug('Chamando buyNonConsumable...');
      // Para assinaturas, usar buyNonConsumable que funciona para ambas as plataformas
      final result = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      
      Logger.info('buyNonConsumable retornou: $result');
      Logger.info('Compra iniciada para produto: $productId');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Erro ao iniciar compra', e, stackTrace);
      Logger.error('Tipo do erro: ${e.runtimeType}', e, stackTrace);
      return false;
    }
  }

  /// Restaurar compras anteriores
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      Logger.warning('In-App Purchase não está disponível');
      return;
    }

    try {
      await _inAppPurchase.restorePurchases();
      Logger.info('Compras restauradas com sucesso');
    } catch (e, stackTrace) {
      Logger.error('Erro ao restaurar compras', e, stackTrace);
      rethrow;
    }
  }

  /// Manipula atualizações de compra
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      try {
        if (purchase.status == PurchaseStatus.pending) {
          Logger.info('Compra pendente: ${purchase.productID}');
        } else if (purchase.status == PurchaseStatus.purchased || 
                   purchase.status == PurchaseStatus.restored) {
          Logger.info('Compra realizada/restaurada: ${purchase.productID}');
          
          // Validar compra no backend
          await _validatePurchase(purchase);
          
          // Marcar como completa
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
        } else if (purchase.status == PurchaseStatus.error) {
          Logger.error('Erro na compra: ${purchase.productID}', purchase.error, StackTrace.current);
          
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
        } else if (purchase.status == PurchaseStatus.canceled) {
          Logger.info('Compra cancelada: ${purchase.productID}');
          
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
        }
      } catch (e, stackTrace) {
        Logger.error('Erro ao processar compra: ${purchase.productID}', e, stackTrace);
      }
    }
  }

  /// Valida a compra no backend
  Future<void> _validatePurchase(PurchaseDetails purchase) async {
    try {
      final client = _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;

      if (userId == null) {
        Logger.warning('Usuário não autenticado, não é possível validar compra');
        return;
      }

      // Preparar dados da compra baseado na plataforma
      Map<String, dynamic> receiptData;
      String platform;

      if (Platform.isIOS) {
        platform = 'apple';
        final AppStorePurchaseDetails iosDetails = purchase as AppStorePurchaseDetails;
        receiptData = {
          'transaction_id': purchase.purchaseID ?? '',
          'product_id': purchase.productID,
          'receipt_data': purchase.verificationData.serverVerificationData,
          'local_verification_data': purchase.verificationData.localVerificationData,
          'source': purchase.verificationData.source,
        };
      } else if (Platform.isAndroid) {
        platform = 'google';
        final GooglePlayPurchaseDetails androidDetails = purchase as GooglePlayPurchaseDetails;
        // O purchaseToken está em serverVerificationData para Android
        receiptData = {
          'purchase_token': purchase.verificationData.serverVerificationData,
          'transaction_id': purchase.purchaseID ?? '',
          'product_id': purchase.productID,
          'package_name': androidDetails.billingClientPurchase?.packageName ?? '',
          'verification_data': purchase.verificationData.serverVerificationData,
          'local_verification_data': purchase.verificationData.localVerificationData,
        };
      } else {
        Logger.warning('Plataforma não suportada para validação');
        return;
      }

      // Chamar Edge Function para validar
      Logger.info('Enviando receipt para validate-receipt: platform=$platform, product_id=${purchase.productID}');

      final response = await client.functions.invoke(
        'validate-receipt',
        body: {
          'user_id': userId,
          'platform': platform,
          'receipt_data': receiptData,
          'product_id': purchase.productID,
        },
      );

      if (response.status != 200) {
        final errorMessage = 'Falha na validação do receipt (status ${response.status}): ${response.data}';
        Logger.error(errorMessage, null, StackTrace.current);
        // Notificar UI, se configurado
        onPurchaseValidationError?.call(errorMessage);
        throw Exception(errorMessage);
      }

      Logger.info('Compra validada com sucesso no backend: ${purchase.productID}');
      // Notificar UI de sucesso, se configurado
      onPurchaseValidated?.call();
    } catch (e, stackTrace) {
      Logger.error('Erro ao validar compra no backend', e, stackTrace);
      rethrow;
    }
  }

  /// Limpa recursos
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
  }

  /// Verifica se o serviço está disponível
  bool get isAvailable => _isAvailable;

  /// Obtém produtos disponíveis
  Set<String> get availableProducts => _availableProducts;
}

