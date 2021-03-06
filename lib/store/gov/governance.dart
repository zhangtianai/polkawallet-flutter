import 'package:mobx/mobx.dart';
import 'package:polka_wallet/store/account.dart';
import 'package:polka_wallet/store/gov/types/referendumInfoData.dart';
import 'package:polka_wallet/store/gov/types/councilInfoData.dart';
import 'package:polka_wallet/utils/localStorage.dart';

part 'governance.g.dart';

class GovernanceStore extends _GovernanceStore with _$GovernanceStore {
  GovernanceStore(AccountStore store) : super(store);
}

abstract class _GovernanceStore with Store {
  _GovernanceStore(this.account);

  final AccountStore account;

  final String cacheCouncilKey = 'council';

  @observable
  int cacheCouncilTimestamp = 0;

  @observable
  int bestNumber = 0;

  @observable
  CouncilInfoData council;

  @observable
  Map<String, Map<String, dynamic>> councilVotes;

  @observable
  Map<String, dynamic> userCouncilVotes;

  @observable
  ObservableList<ReferendumInfo> referendums;

  @action
  void setCouncilInfo(Map info, {bool shouldCache = true}) {
    council = CouncilInfoData.fromJson(info);

    if (shouldCache) {
      cacheCouncilTimestamp = DateTime.now().millisecondsSinceEpoch;
      LocalStorage.setKV(
          cacheCouncilKey, {'data': info, 'cacheTime': cacheCouncilTimestamp});
    }
  }

  @action
  void setCouncilVotes(Map votes) {
    councilVotes = Map<String, Map<String, dynamic>>.from(votes);
  }

  @action
  void setUserCouncilVotes(Map votes) {
    userCouncilVotes = Map<String, dynamic>.from(votes);
  }

  @action
  void setBestNumber(int number) {
    bestNumber = number;
  }

  @action
  void setReferendums(List ls) {
    referendums = ObservableList.of(ls.map((i) => ReferendumInfo.fromJson(
        i as Map<String, dynamic>, account.currentAddress)));
  }

  @action
  Future<void> loadCache() async {
    Map data = await LocalStorage.getKV(cacheCouncilKey);
    if (data != null) {
      setCouncilInfo(data['data'], shouldCache: false);
      cacheCouncilTimestamp = data['cacheTime'];
    }
  }
}
