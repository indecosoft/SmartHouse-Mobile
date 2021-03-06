import 'dart:developer';

import 'package:Homey/app_data_manager.dart';
import 'package:Homey/helpers/sql_helper/data_models/sensor_model.dart';
import 'package:Homey/helpers/sql_helper/sql_helper.dart';
import 'package:Homey/helpers/states_manager.dart';
import 'package:Homey/helpers/web_requests_helpers/web_requests_helpers.dart';
import 'package:Homey/states/menu_state.dart';
import 'package:Homey/states/on_result_callback.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class DeviceSelectorState {
  final BehaviorSubject<int> _selectedDevicesCount =
      BehaviorSubject<int>.seeded(0);
  final List<SensorModel> selectedDevices = <SensorModel>[];

  Stream<int> get selectedDevicesCount$ => _selectedDevicesCount.stream;

  void changeElement(SensorModel device) {
    if (selectedDevices.contains(device)) {
      selectedDevices
          .removeWhere((SensorModel d) => d.macAddress == device.macAddress);
    } else {
      selectedDevices.add(device);
    }
    _selectedDevicesCount.value = selectedDevices.length;
  }

  void clear() {
    _selectedDevicesCount.value = 0;
    selectedDevices.clear();
  }

  Future<void> addDevices(
      {@required int roomId, @required int roomDbId, OnResult onResult}) async {
    onResult('Loading...', ResultState.loading);
    final Map<String, dynamic> model = <String, dynamic>{
      'roomId': roomDbId,
      'devices': selectedDevices.map((SensorModel d) => d.macAddress).toList()
    };
    log('body', error: model);
    await WebRequestsHelpers.post(
            route: '/api/add/sensorsToRoom', body: model, displayResponse: true)
        .then((dynamic response) async {
      final dynamic data = response.json();
      if (data['success'] != null) {
        await SqlHelper().addSensorsToRoom(roomId, selectedDevices);
        await AppDataManager().fetchData();
        getIt.get<MenuState>().selectedHome = AppDataManager().defaultHome;
        onResult(data['success'], ResultState.successful);
      } else {
        onResult(data['error'].toString(), ResultState.error);
      }
    }, onError: (Object e) {
      onResult(e.toString(), ResultState.error);
    });
  }

  void dispose() {
    _selectedDevicesCount.close();
  }
}
