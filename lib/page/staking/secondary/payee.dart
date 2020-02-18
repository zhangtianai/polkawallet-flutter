import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:polka_wallet/store/app.dart';
import 'package:polka_wallet/utils/i18n/index.dart';

class SetPayee extends StatefulWidget {
  SetPayee(this.store);
  final AppStore store;
  @override
  _SetPayeeState createState() => _SetPayeeState(store);
}

class _SetPayeeState extends State<SetPayee> {
  _SetPayeeState(this.store);
  final AppStore store;

  int _rewardTo = 0;

  @override
  void initState() {
    super.initState();
    if (store.staking.ledger['rewardDestination'] != 'Staked') {
      setState(() {
        _rewardTo = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var dic = I18n.of(context).staking;
    String address = store.account.currentAccount.address;

    var rewardToOptions = [dic['reward.bond'], dic['reward.stash']];

//    print(store.staking.overview['account'].keys.join(','));
    return Scaffold(
      appBar: AppBar(
        title: Text(dic['action.setting']),
        centerTitle: true,
      ),
      body: Builder(builder: (BuildContext context) {
        return Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: TextFormField(
                      decoration: InputDecoration(
                        hintText: dic['stash'],
                        labelText: dic['stash'],
                      ),
                      initialValue: address,
                      readOnly: true,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: TextFormField(
                      decoration: InputDecoration(
                        hintText: dic['controller'],
                        labelText: dic['controller'],
                      ),
                      initialValue: address,
                      readOnly: true,
                    ),
                  ),
                  ListTile(
                    title: Text(dic['bond.reward']),
                    subtitle: Text(rewardToOptions[_rewardTo]),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (_) => Container(
                          height:
                              MediaQuery.of(context).copyWith().size.height / 3,
                          child: CupertinoPicker(
                            backgroundColor: Colors.white,
                            itemExtent: 56,
                            scrollController: FixedExtentScrollController(
                                initialItem: _rewardTo),
                            children: rewardToOptions
                                .map((i) => Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(i)))
                                .toList(),
                            onSelectedItemChanged: (v) {
                              setState(() {
                                _rewardTo = v;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  )
                ],
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: RaisedButton(
                      color: Colors.pink,
                      padding: EdgeInsets.all(16),
                      child: Text(
                        I18n.of(context).home['submit.tx'],
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () {
                        var args = {
                          "title": dic['action.setting'],
                          "detail": jsonEncode({
                            "reward_destination": rewardToOptions[_rewardTo],
                          }),
                          "params": {
                            "module": 'staking',
                            "call": 'setPayee',
                            "to": _rewardTo,
                          },
                          'redirect': '/'
                        };
                        Navigator.of(context)
                            .pushNamed('/staking/confirm', arguments: args);
                      },
                    ),
                  ),
                ),
              ],
            )
          ],
        );
      }),
    );
  }
}
