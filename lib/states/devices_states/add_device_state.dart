import 'dart:developer';

import 'package:Homey/app_data_manager.dart';
import 'package:Homey/helpers/data_types.dart';

import 'package:Homey/helpers/sql_helper/data_models/room_model.dart';
import 'package:Homey/helpers/sql_helper/data_models/sensor_model.dart';
import 'package:Homey/helpers/web_requests_helpers/web_requests_helpers.dart';
import 'package:Homey/models/add_house_model.dart';
import 'package:Homey/models/devices_models/add_device_model.dart';
import 'package:Homey/models/devices_models/network_config_model.dart';
import 'package:Homey/states/on_result_callback.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:smartconfig/smartconfig.dart';

class AddDeviceState {
  final BehaviorSubject<String> _deviceName =
      BehaviorSubject<String>.seeded('');
  final BehaviorSubject<NetworkConfigModel> _networkConfig =
      BehaviorSubject<NetworkConfigModel>.seeded(NetworkConfigModel());
  final BehaviorSubject<AddDeviceModel> _deviceConfig =
      BehaviorSubject<AddDeviceModel>.seeded(
          AddDeviceModel(sensor: SensorModel(name: '')));
  final BehaviorSubject<bool> _networkConfigAutoValidate =
      BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<bool> _deviceConfigAutoValidate =
      BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<bool> _networkConfigPassword =
      BehaviorSubject<bool>.seeded(false);

  Stream<bool> get networkFormStream$ => _networkConfigAutoValidate.stream;

  Stream<bool> get networkConfigPasswordStream$ =>
      _networkConfigPassword.stream;

  Stream<bool> get deviceFormStream$ => _deviceConfigAutoValidate.stream;

  String get deviceName => _deviceName.value;

  set deviceName(String state) {
    _deviceName.value = state;
  }

  NetworkConfigModel get networkConfig => _networkConfig.value;

  set networkConfig(NetworkConfigModel value) {
    _networkConfig.value = value;
  }

  AddDeviceModel get deviceConfig => _deviceConfig.value;

  set deviceConfig(AddDeviceModel state) {
    _deviceConfig.value = state;
  }

  bool get networkConfigAutoValidate => _networkConfigAutoValidate.value;

  set networkConfigAutoValidate(bool state) {
    _networkConfigAutoValidate.value = state;
  }

  bool get deviceConfigAutoValidate => _deviceConfigAutoValidate.value;

  set deviceConfigAutoValidate(bool state) {
    _deviceConfigAutoValidate.value = state;
  }

  bool get networkConfigPassword => _networkConfigPassword.value;

  void toggleNetworkConfigAPassword() {
    _networkConfigPassword.value = !_networkConfigPassword.value;
  }

  Future<void> addDevice({@required AddDeviceModel model}) async {
    model.onResult('Loading...', ResultState.loading);
    log('data', error: model.toMap());
    await WebRequestsHelpers.post(route: '/api/add/sensor', body: model.toMap())
        .then((dynamic response) async {
      final dynamic data = response.json();
      if (data['success'] != null) {
        model.onResult(data, ResultState.successful);
      } else {
        model.onResult(data['error'].toString(), ResultState.error);
      }
    }, onError: (Object e) {
      model.onResult(e.toString(), ResultState.error);
    });
  }

  Future<void> startESPTouchConfiguration(
      {@required NetworkConfigModel networkConfigModel, OnResult event}) async {
    log('model', error: networkConfigModel.toMap());
    networkConfigModel.onResult('Configuring sensor...', ResultState.loading);
    await Smartconfig.start(networkConfigModel.networkSSID,
            networkConfigModel.networkBSSID, networkConfigModel.networkPassword)
        .then((dynamic onValue) async {
      log('devices', error: onValue);
      if (onValue == null) {
        networkConfigModel.onResult(
            'Error configuring sensor', ResultState.error);
      } else {
        final String ip = onValue.values.toList()[0];
        await WebRequestsHelpers.get(
                domain: 'http://$ip', route: '/api/getConfig/')
            .then((dynamic response) {
          final dynamic res = response.json();
          log(res.toString());
          _deviceConfig.value.networkPassword =
              networkConfigModel.networkPassword;
          log(_deviceConfig.value.networkPassword.toString());
          _deviceConfig.value.networkSSID = networkConfigModel.networkSSID;
          log(_deviceConfig.value.networkSSID.toString());
          _deviceConfig.value.sensor = SensorModel(
            name: res['sensorName'],
            sensorType: DevicesType.values[res['sensorType']],
            macAddress: res['macAddress'],
            readingFrequency: res['freqMinutes'],
            ipAddress: ip,
          );
          log('ceva');
          log(_deviceConfig.value.sensor.toMap().toString());
          networkConfigModel.onResult(
              'Device configured', ResultState.successful);
        }, onError: (Object e) {
          networkConfigModel.onResult(e.toString(), ResultState.error);
        });
        log('sm version', error: onValue);
      }
    });
  }

  Future<void> saveDeviceConfiguration({@required AddDeviceModel model}) async {
    model.onResult('Saving configuration...', ResultState.loading);
    _deviceConfig.value.sensor.name = model.sensor.name;
    _deviceConfig.value.sensor.readingFrequency = model.sensor.readingFrequency;
    _deviceConfig.value.server = model.server;
    _deviceConfig.value.port = model.port;
    _deviceConfig.value.sensor.account = AppDataManager().userData.email;
    log(_deviceConfig.value.toMap().toString());
    await WebRequestsHelpers.post(
            domain: 'http://${_deviceConfig.value.sensor.ipAddress}',
            route: '/api/config',
            displayResponse: true,
            body: _deviceConfig.value.toMap())
        .then((dynamic response) async {
      if (response.json()['message'] != null) {
        model.onResult(response.json()['message'], ResultState.successful);
      } else {
        model.onResult(response.json()['error'].toString(), ResultState.error);
      }
    }, onError: (Object e) {
      model.onResult(e.toString(), ResultState.error);
    });
  }

  Future<void> addSensor({RoomModel room, @required OnResult onResult}) async {
    final Map<String, dynamic> _formData = <String, dynamic>{
      'sensorName': _deviceConfig.value.sensor.name,
      'roomId': room == null ? null : room.dbId,
      'macAddress': _deviceConfig.value.sensor.macAddress,
      'sensorType': _deviceConfig.value.sensor.sensorType.index,
      'readingFrequency': _deviceConfig.value.sensor.readingFrequency,
      'userEmail': AppDataManager().userData.email,
    };
    onResult('Saving device...', ResultState.loading);
    await WebRequestsHelpers.post(route: '/api/add/sensor', body: _formData)
        .then((dynamic response) async {
      final dynamic data = response.json();
      log('response', error: data);
      if (data['success'] != null) {
        await AppDataManager().addSensor(SensorModel(
            name: data['sensor']['name'],
            roomId: room == null ? null : room.id,
            dbId: data['sensor']['id'],
            macAddress: data['sensor']['macAddress'],
            sensorType: DevicesType.values[data['sensor']['sensorType']],
            networkStatus: true,
            readingFrequency: data['sensor']['readingFrequency'],
            ipAddress: _deviceConfig.value.sensor.ipAddress));
        await AppDataManager()
            .changeDefaultHome(AppDataManager().defaultHome.id);
        onResult('Device added successfuly', ResultState.successful);
//            Navigator.pop(context);
      } else {
        onResult(response.json()['error'].toString(), ResultState.error);
      }
    }, onError: (Object e) {
      onResult(e.toString(), ResultState.error);
    });
  }

  void dispose() {
    _deviceName.close();
    _deviceConfig.close();
    _networkConfig.close();
    _networkConfigPassword.close();
    _networkConfigAutoValidate.close();
    _deviceConfigAutoValidate.close();
  }
}
