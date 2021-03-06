import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:polka_wallet/store/app.dart';
import 'package:polka_wallet/store/assets/types/balancesInfo.dart';
import 'package:polka_wallet/store/assets/types/transferData.dart';
import 'package:polka_wallet/utils/localStorage.dart';

part 'assets.g.dart';

class AssetsStore extends _AssetsStore with _$AssetsStore {
  AssetsStore(AppStore store) : super(store);
}

abstract class _AssetsStore with Store {
  _AssetsStore(this.rootStore);

  final AppStore rootStore;

  final String localStorageBlocksKey = 'blocks';

  final String cacheBalanceKey = 'balance';
  final String cacheTxsKey = 'txs';
  final String cacheTimeKey = 'assets_cache_time';
  @observable
  int cacheTxsTimestamp = 0;

  @observable
  bool isTxsLoading = true;

  @observable
  bool submitting = false;

  @observable
  ObservableMap<String, BalancesInfo> balances =
      ObservableMap<String, BalancesInfo>();

  @observable
  Map<String, String> tokenBalances = Map<String, String>();

  @observable
  int txsCount = 0;

  @observable
  ObservableList<TransferData> txs = ObservableList<TransferData>();

  @observable
  int txsFilter = 0;

  @observable
  ObservableMap<int, BlockData> blockMap = ObservableMap<int, BlockData>();

  @computed
  ObservableList<TransferData> get txsView {
    return ObservableList.of(txs.where((i) {
      switch (txsFilter) {
        case 1:
          return i.to == rootStore.account.currentAddress;
        case 2:
          return i.from == rootStore.account.currentAddress;
        default:
          return true;
      }
    }));
  }

//  @computed
//  ObservableList<Map<String, dynamic>> get balanceHistory {
//    List<Map<String, dynamic>> res = List<Map<String, dynamic>>();
//    double total = Fmt.balanceDouble(
//        balances[rootStore.settings.networkState.tokenSymbol]);
//    txs.asMap().forEach((index, i) {
//      if (index != 0) {
//        TransferData prev = txs[index - 1];
//        if (i.from == rootStore.account.currentAddress) {
//          total -= double.parse(prev.amount);
//          // add transfer fee: 0.02KSM
//          total += 0.02;
//        } else {
//          total += double.parse(prev.amount);
//        }
//      }
//      res.add({
//        "time": DateTime.fromMillisecondsSinceEpoch(i.blockTimestamp * 1000),
//        "value": total
//      });
//    });
//    return ObservableList.of(res.reversed);
//  }

  @action
  Future<void> setAccountBalances(String pubKey, Map amt,
      {bool needCache = true}) async {
    if (rootStore.account.currentAccount.pubKey != pubKey) return;

    amt.forEach((k, v) {
      balances[k] = BalancesInfo.fromJson(v);
    });

    if (!needCache) return;
    Map cache = await LocalStorage.getAccountCache(
      rootStore.account.currentAccount.pubKey,
      cacheBalanceKey,
    );
    if (cache == null) {
      cache = amt;
    } else {
      amt.forEach((k, v) {
        cache[k] = v;
      });
    }
    LocalStorage.setAccountCache(
      rootStore.account.currentAccount.pubKey,
      cacheBalanceKey,
      cache,
    );
  }

  @action
  Future<void> setAccountTokenBalances(String pubKey, Map amt) async {
    if (rootStore.account.currentAccount.pubKey != pubKey) return;

    tokenBalances = Map<String, String>.from(amt);
  }

  @action
  void setTxsLoading(bool isLoading) {
    isTxsLoading = isLoading;
  }

  @action
  Future<void> clearTxs() async {
    txs.clear();
  }

  @action
  Future<void> addTxs(Map res, String address,
      {bool shouldCache = false}) async {
    if (rootStore.account.currentAddress != address) return;

    txsCount = res['count'];

    List ls = res['transfers'];
    if (ls == null) return;
    print(ls.length);

    ls.forEach((i) {
      TransferData tx = TransferData.fromJson(i);
      txs.add(tx);
    });

    if (shouldCache) {
      LocalStorage.setAccountCache(
          rootStore.account.currentAccount.pubKey, cacheTxsKey, ls);

      cacheTxsTimestamp = DateTime.now().millisecondsSinceEpoch;
      LocalStorage.setAccountCache(rootStore.account.currentAccount.pubKey,
          cacheTimeKey, cacheTxsTimestamp);
    }
  }

  @action
  void setTxsFilter(int filter) {
    txsFilter = filter;
  }

  @action
  Future<void> setBlockMap(String data) async {
    var ls = await compute(jsonDecode, data);
    List.of(ls).forEach((i) {
      if (blockMap[i['id']] == null) {
        blockMap[i['id']] = BlockData.fromJson(i);
      }
    });

    if (List.of(ls).length > 0) {
      LocalStorage.setKV(localStorageBlocksKey,
          blockMap.values.map((i) => BlockData.toJson(i)).toList());
    }
  }

  @action
  void setSubmitting(bool isSubmitting) {
    submitting = isSubmitting;
  }

  @action
  Future<void> loadAccountCache() async {
    // loadCache if currentAccount exist
    String pubKey = rootStore.account.currentAccount.pubKey;
    if (pubKey == null) {
      return;
    }

    List cache = await Future.wait([
      LocalStorage.getAccountCache(pubKey, cacheBalanceKey),
      LocalStorage.getAccountCache(pubKey, cacheTxsKey),
      LocalStorage.getAccountCache(pubKey, cacheTimeKey),
    ]);
    if (cache[0] != null) {
      setAccountBalances(pubKey, cache[0], needCache: false);
    }
    if (cache[1] != null) {
      txs = ObservableList.of(
          List.of(cache[1]).map((i) => TransferData.fromJson(i)).toList());
    }
    if (cache[2] != null) {
      cacheTxsTimestamp = cache[2];
    }
  }

  @action
  Future<void> loadCache() async {
    List ls = await LocalStorage.getKV(localStorageBlocksKey);
    if (ls != null) {
      ls.forEach((i) {
        if (blockMap[i['id']] == null) {
          blockMap[i['id']] = BlockData.fromJson(i);
        }
      });
    }

    loadAccountCache();
  }
}

class BlockData extends _BlockData {
  static BlockData fromJson(Map<String, dynamic> json) {
    BlockData block = BlockData();
    block.id = json['id'];
    block.hash = json['hash'];
    block.time = DateTime.fromMillisecondsSinceEpoch(json['timestamp']);
    return block;
  }

  static Map<String, dynamic> toJson(BlockData block) {
    return {
      'id': block.id,
      'hash': block.hash,
      'timestamp': block.time.millisecondsSinceEpoch,
    };
  }
}

abstract class _BlockData {
  int id = 0;

  String hash = '';

  DateTime time = DateTime.now();
}
