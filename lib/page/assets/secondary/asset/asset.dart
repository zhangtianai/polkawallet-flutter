import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:polka_wallet/page/assets/secondary/asset/assetChart.dart';
import 'package:polka_wallet/service/polkascan.dart';
import 'package:polka_wallet/store/app.dart';
import 'package:polka_wallet/store/assets.dart';
import 'package:polka_wallet/utils/format.dart';
import 'package:polka_wallet/utils/i18n/index.dart';

class AssetPage extends StatefulWidget {
  AssetPage(this.store);

  final AppStore store;

  @override
  _AssetPageState createState() => _AssetPageState(store);
}

class _AssetPageState extends State<AssetPage>
    with SingleTickerProviderStateMixin {
  _AssetPageState(this.store);

  final AppStore store;

  TabController _tabController;
  int _txsPage = 1;
  bool _isLastPage = false;
  ScrollController _scrollController;

  Future<void> _updateTxs() async {
    List res = await store.api.updateTxs(_txsPage);
    if (res.length < list_page_size) {
      setState(() {
        _isLastPage = true;
      });
    }
  }

  Future<void> _refreshTxs() async {
    setState(() {
      _txsPage = 1;
      _isLastPage = false;
    });
    await _updateTxs();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 3);
    _updateTxs();
    store.api.fetchBalance();

    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent) {
        setState(() {
          if (_tabController.index == 0 && !_isLastPage) {
            _txsPage += 1;
            _updateTxs();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Widget> _buildTxList() {
    if (!store.assets.loading && store.assets.txsView.length == 0) {
      return [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No Data',
                style: TextStyle(fontSize: 18, color: Colors.black38),
              ),
            )
          ],
        )
      ];
    }
    int decimals = store.settings.networkState.tokenDecimals;
    String symbol = store.settings.networkState.tokenSymbol;
    Map<int, BlockData> blockMap = store.assets.blockMap;
    return store.assets.txsView.map((i) {
      BlockData block = blockMap[i.block];
      String time = 'time';
      if (block != null) {
        time = block.time.toString().split('.')[0];
      }
      return Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(width: 0.5, color: Colors.black12)),
        ),
        child: ListTile(
            title: Text(i.id),
            subtitle: Text(time),
            trailing: Container(
              width: 110,
              child: Row(
                children: <Widget>[
                  Expanded(
                      child: Text(
                    '${Fmt.token(i.value, decimals: decimals)} $symbol',
                    style: Theme.of(context).textTheme.display4,
                  )),
                  i.sender == store.account.currentAccount.address
                      ? Image.asset('assets/images/assets/assets_up.png')
                      : Image.asset('assets/images/assets/assets_down.png')
                ],
              ),
            ),
            onTap: () {
              store.assets.setTxDetail(i);
              Navigator.pushNamed(context, '/assets/tx');
            }),
      );
    }).toList();
  }

  List<Widget> _buildListView() {
    final dic = I18n.of(context).assets;

    int balance = Fmt.balanceInt(store.assets.balance);
    int bonded = 0;
    int unlocking = 0;
    bool hasData = store.staking.ledger['stakingLedger'] != null;
    if (hasData) {
      List unlockingList = store.staking.ledger['stakingLedger']['unlocking'];
      unlockingList.forEach((i) => unlocking += i['value']);
      bonded = store.staking.ledger['stakingLedger']['active'];
    }

    int locked = bonded + unlocking;
    int available = balance - locked;

    final List<Tab> _myTabs = <Tab>[
      Tab(text: dic['all']),
      Tab(text: dic['in']),
      Tab(text: dic['out']),
    ];

    // TODO: chart data is generated from transfer history
    // need to use other data source
    List<Map<String, dynamic>> balanceHistory = store.assets.balanceHistory;

    List<Widget> list = <Widget>[
      Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${dic['balance']}: ${Fmt.token(balance)}'),
            Text('${dic['locked']}: ${Fmt.token(locked)}'),
            Text('${dic['available']}: ${Fmt.token(available)}'),
          ],
        ),
      ),
      Container(
        height: 240,
        child: AssetChart.withData(balanceHistory),
      ),
      TabBar(
        labelColor: Colors.black87,
        labelStyle: TextStyle(fontSize: 18),
        controller: _tabController,
        tabs: _myTabs,
        onTap: (i) {
          store.assets.setTxsFilter(i);
        },
      ),
    ];
    list.addAll(_buildTxList());
    if (store.assets.loading) {
      list.add(
        Padding(
            padding: EdgeInsets.all(8), child: CupertinoActivityIndicator()),
      );
    }
    if (_isLastPage) {
      list.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                dic['end'],
                style: TextStyle(fontSize: 18, color: Colors.black38),
              ),
            )
          ],
        ),
      );
    }
    return list;
  }

  @override
  Widget build(BuildContext context) => Observer(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(
              title: Text(store.settings.networkState.tokenSymbol),
              centerTitle: true,
            ),
            body: Column(
              children: <Widget>[
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: RefreshIndicator(
                      onRefresh: _refreshTxs,
                      child: ListView(
                        controller: _scrollController,
                        children: _buildListView(),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        color: Colors.lightBlue,
                        child: FlatButton(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.only(right: 16),
                                child: Image.asset(
                                    'assets/images/assets/assets_send.png'),
                              ),
                              Text(
                                I18n.of(context).assets['transfer'],
                                style: TextStyle(color: Colors.white),
                              )
                            ],
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, '/assets/transfer');
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.lightGreen,
                        child: FlatButton(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.only(right: 16),
                                child: Image.asset(
                                    'assets/images/assets/assets_receive.png'),
                              ),
                              Text(
                                I18n.of(context).assets['receive'],
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, '/assets/receive');
                          },
                        ),
                      ),
                    )
                  ],
                )
              ],
            ),
          );
        },
      );
}
