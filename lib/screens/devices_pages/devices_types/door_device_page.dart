import 'dart:developer';

import 'package:Homey/design/colors.dart';
import 'package:Homey/design/dialogs.dart';
import 'package:Homey/design/widgets/buttons/round_button.dart';
import 'package:Homey/design/widgets/network_status.dart';
import 'package:Homey/helpers/mqtt.dart';
import 'package:Homey/helpers/sql_helper/data_models/sensor_model.dart';
import 'package:Homey/helpers/utils.dart';
import 'package:Homey/helpers/states_manager.dart';
import 'package:Homey/models/devices_models/device_page_model.dart';
import 'package:Homey/screens/devices_pages/device_info.dart';
import 'package:Homey/states/devices_states/devices_temp_state.dart';
import 'package:Homey/states/on_result_callback.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class DoorDevicePage extends StatefulWidget {
  const DoorDevicePage({@required this.sensor}) : super();

  final SensorModel sensor;

  @override
  _DoorDevicePageState createState() => _DoorDevicePageState();
}

class _DoorDevicePageState extends State<DoorDevicePage> {
  final DeviceTempState _state = getIt.get<DeviceTempState>();

  final GlobalKey<State> _keyLoader = GlobalKey<State>();

  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  @override
  void dispose() {
    super.dispose();
    getIt.get<MqttHelper>().sensor = null;
  }

  Future<void> _onRefresh() async {
    await _state.getDeviceState(widget.sensor, onResult);
  }

  void onResult(dynamic data, ResultState resultState) {
    switch (resultState) {
      case ResultState.successful:
        if (data is DevicePageModel) {
          _refreshController.refreshCompleted();
        }
        break;
      case ResultState.error:
        if (data is DevicePageModel) {
          _refreshController.refreshFailed();
        } else {
          Dialogs.showSimpleDialog('Error', data, _keyLoader.currentContext);
        }
        break;
      case ResultState.loading:
        // do nothing
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    getIt.get<MqttHelper>().sensor = widget.sensor;
    return Scaffold(
      key: _keyLoader,
      body: SmartRefresher(
        controller: _refreshController,
        enablePullDown: true,
        onRefresh: _onRefresh,
        child: Stack(
          children: <Widget>[
            StreamBuilder<DevicePageModel>(
                stream: _state.dataStream$,
                builder: (BuildContext context,
                    AsyncSnapshot<DevicePageModel> snapshot) {
                  return Positioned.fill(
                    child: Container(
                      height:
                          Utils.getPercentValueFromScreenHeight(100, context),
                      child: AnimatedCrossFade(
                        duration: const Duration(seconds: 1),
                        firstChild: Container(
                          height: Utils.getPercentValueFromScreenHeight(
                              100, context),
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Colors.grey,
                              BlendMode.saturation,
                            ),
                            child: Image.asset(
                              'assets/images/door1.jpg',
                              fit: BoxFit.cover,
                              color:
                                  ColorsTheme.backgroundDarker.withOpacity(0.2),
                              colorBlendMode: BlendMode.multiply,
                            ),
                          ),
                        ),
                        secondChild: Container(
                          height: Utils.getPercentValueFromScreenHeight(
                              100, context),
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Colors.grey,
                              BlendMode.saturation,
                            ),
                            child: Image.asset(
                              'assets/images/door1.jpg',
                              fit: BoxFit.cover,
                              color:
                                  ColorsTheme.backgroundDarker.withOpacity(0.7),
                              colorBlendMode: BlendMode.multiply,
                            ),
                          ),
                        ),
                        crossFadeState: _state.device.networkStatus != null &&
                                _state.device.networkStatus
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                      ),
                    ),
                  );
                }),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      RoundButton(
                        icon: Icon(MdiIcons.chevronLeft, color: Colors.black),
                        padding: const EdgeInsets.all(8),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      StreamBuilder<DevicePageModel>(
                        stream: _state.dataStream$,
                        builder: (BuildContext context,
                            AsyncSnapshot<DevicePageModel> snapshot) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.sensor.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: _state.device.networkStatus != null &&
                                          _state.device.networkStatus
                                      ? ColorsTheme.backgroundDarker
                                      : ColorsTheme.textColor,
                                ),
                              ),
                              NetworkStatusLabel(
                                online: _state.device.networkStatus ?? false,
                              ),
                            ],
                          );
                        },
                      ),
                      const Spacer(),
                      RoundButton(
                        icon: Icon(
                          MdiIcons.informationOutline,
                          color: Colors.black,
                          size: 16,
                        ),
                        padding: const EdgeInsets.all(12),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<DeviceInfo>(
                            builder: (BuildContext context) => DeviceInfo(
                              sensor: widget.sensor,
                              state: _state,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      RoundButton(
                        icon: Icon(
                          MdiIcons.pencil,
                          color: Colors.black,
                          size: 16,
                        ),
                        padding: const EdgeInsets.all(12),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
            FutureBuilder<DevicePageModel>(
              future: _state.getDeviceState(widget.sensor, onResult),
              builder: (BuildContext context,
                  AsyncSnapshot<DevicePageModel> snapshot) {
                return Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 20),
                    child: StreamBuilder<DevicePageModel>(
                      stream: _state.dataStream$,
                      builder: (BuildContext context,
                          AsyncSnapshot<DevicePageModel> snapshot) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              'Door is ',
                              style: TextStyle(
                                fontSize: 24,
                                fontFamily: 'Montserrat',
                                color: _state.device.networkStatus != null &&
                                        _state.device.networkStatus
                                    ? ColorsTheme.background
                                    : ColorsTheme.textColor,
                              ),
                            ),
                            AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                child: _state.device.data != null && _state.device.data['state'] != null && _state.device.data['state']
                                    ? Container(
                                        child: Text(
                                          'closed',
                                          textAlign: TextAlign.left,
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontFamily: 'Montserrat',
                                            color: _state.device
                                                            .networkStatus !=
                                                        null &&
                                                    _state.device.networkStatus
                                                ? ColorsTheme.background
                                                : ColorsTheme.textColor,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        'open',
                                        textAlign: TextAlign.left,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontFamily: 'Montserrat',
                                          color: _state.device.networkStatus !=
                                                      null &&
                                                  _state.device.networkStatus
                                              ? ColorsTheme.background
                                              : ColorsTheme.textColor,
                                        ),
                                      )),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
