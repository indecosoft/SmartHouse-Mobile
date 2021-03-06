import 'dart:developer';
import 'dart:io';

import 'package:Homey/helpers/data_types.dart';
import 'package:Homey/helpers/sql_helper/data_models/home_model.dart';
import 'package:Homey/helpers/sql_helper/data_models/sensor_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../app_data_manager.dart';
import 'data_models/room_model.dart';
import 'data_models/user_model.dart';

class SqlHelper {
  factory SqlHelper() {
    return _instance;
  }

  SqlHelper._internal() {
    log('SqlHelper create');
  }

  @protected
  Database _database;
  @protected
  String path;
  @protected
  static final SqlHelper _instance = SqlHelper._internal();

  Future<void> initDatabase() async {
    final String databasesPath = await getDatabasesPath();
    path = join(databasesPath, 'data.db');
// Make sure the directory exists
    try {
      await Directory(databasesPath).create(recursive: true);
    } catch (_) {}

// open the database
    _database = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS UserData (id INTEGER PRIMARY KEY, email TEXT, firstName TEXT, lastName TEXT);');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS Houses (id INTEGER PRIMARY KEY, userId INTEGER, dbId INTEGER, name TEXT, address TEXT);');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS Rooms (id INTEGER PRIMARY KEY, houseId INTEGER, dbId INTEGER, name TEXT);');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS Sensors (id INTEGER PRIMARY KEY, roomId INTEGER, dbId INTEGER, name TEXT, sensorType INTEGER, ipAddress TEXT, macAddress TEXT, readingFrequency INTEGER, networkStatus BOOLEAN, data TEXT);');
    });
  }

  Future<void> dropDatabase() async {
    await deleteDatabase(path);
    await _database.close();
  }

  Future<void> insert(dynamic data) async {
    if (!_database.isOpen) {
      await initDatabase();
    }
    await _database.transaction((Transaction transaction) async {
      final int userId = await transaction.rawInsert(
          'INSERT INTO UserData(email, firstName, lastName) VALUES ("${data['email']}", "${data['firstName']}", "${data['lastName']}");');
      for (final Map<String, dynamic> house in data['houses']) {
        final int houseId = await transaction.rawInsert(
            'INSERT INTO Houses(userId, dbId, name, address) VALUES ($userId, ${house['id']}, "${house['name']}", "${house['address']}");');
        for (final Map<String, dynamic> room in house['rooms']) {
          final int roomId = await transaction.rawInsert(
              'INSERT INTO Rooms(houseId, dbId, name) VALUES ($houseId, ${room['id']}, "${room['name']}");');
          for (final Map<String, dynamic> sensor in room['sensors']) {
            await transaction.rawInsert(
                'INSERT INTO Sensors(roomId, dbId, name, sensorType, readingFrequency, macAddress, networkStatus, data) VALUES ($roomId, ${sensor['id']}, "${sensor['name']}", "${int.parse(sensor['sensorType'].toString())}",${sensor['readingFrequency']}, "${sensor['macAddress']}", "${sensor['networkStatus']}", "${sensor['data'].toString()}");');
          }
        }
      }
      for (final Map<String, dynamic> device in data['unassignedSensors']) {
        await transaction.rawInsert(
            'INSERT INTO Sensors(dbId, name, sensorType, readingFrequency, macAddress, networkStatus, data) VALUES (${device['id']}, "${device['name']}", "${int.parse(device['sensorType'].toString())}",${device['readingFrequency']}, "${device['macAddress']}", "${device['networkStatus']}", "${device['data'].toString()}");');
      }
    }).then((_) async {
      await AppDataManager().fetchData();
    }, onError: (Object e) {
      log('transaction error', error: e);
    });
  }

  Future<List<HomeModel>> getAllHouses() async {
    final List<Map<String, dynamic>> list =
        await _database.rawQuery('SELECT DISTINCT * FROM Houses ORDER BY dbId');
    return List<HomeModel>.generate(list.length, (int i) {
      return HomeModel(
        id: list[i]['id'],
        dbId: list[i]['dbId'],
        name: list[i]['name'],
      );
    });
  }

  Future<List<SensorModel>> getAllSensors() async {
    try {
      final List<Map<String, dynamic>> list = await _database
          .rawQuery('SELECT DISTINCT * FROM SENSORS ORDER BY dbId');
      return List<SensorModel>.generate(list.length, (int i) {
        return SensorModel(
          id: list[i]['id'],
          dbId: list[i]['dbId'],
          roomId: list[i]['roomId'],
          readingFrequency: list[i]['readingFrequency'],
          ipAddress: list[i]['ipAddress'],
          macAddress: list[i]['macAddress'],
          sensorType: DevicesType.values[list[i]['sensorType']],
          networkStatus: list[i]['networkStatus'] == 'true',
          name: list[i]['name'],
        );
      });
    } catch (e) {
      log('error', error: e);
    }
  }

  Future<bool> getSwitchLastStatus(int roomId) async {
    final List<Map<String, dynamic>> list = await _database.rawQuery(
        'SELECT data FROM SENSORS WHERE roomId = $roomId AND sensorType = 2');
    for (final Map<String, dynamic> element in list) {
      if (element['data'].toString().contains('status') &&
          element['data'].toString().contains('1')) {
        return true;
      }
    }
    return false;
  }

  Future<List<String>> getRoomSensorsMacAddress(int roomId) async {
    final List<Map<String, dynamic>> list = await _database.rawQuery(
        'SELECT DISTINCT macAddress FROM SENSORS WHERE roomId = $roomId AND sensorType = 2 ORDER BY dbId');
    log('devices', error: list.toString());
    return List<String>.generate(list.length, (int i) {
      return list[i]['macAddress'];
    });
  }

  Future<void> addHome(HomeModel house) async {
    await _database.rawInsert(
        'INSERT INTO Houses(userId, dbId, name, address) VALUES (${house.userId}, ${house.dbId}, "${house.name}", "${house.address}");');
  }

  Future<void> addRoom(RoomModel room) async {
    await _database.rawInsert(
        'INSERT INTO Rooms(houseId, dbId, name) VALUES (${room.houseId}, ${room.dbId}, "${room.name}");');
  }

  Future<void> addSensor(SensorModel sensor) async {
    await _database.rawInsert(
        'INSERT INTO Sensors(roomId, dbId, name, sensorType, ipAddress, macAddress) VALUES (${sensor.roomId}, ${sensor.dbId}, "${sensor.name}", "${sensor.sensorType.index}", "${sensor.ipAddress}", "${sensor.macAddress}");');
  }

  Future<void> addSensorsToRoom(int roomId, List<SensorModel> devices) async {
    await _database.transaction((Transaction transaction) async {
      for (final SensorModel device in devices) {
        log('dev', error: device);
        await transaction.rawUpdate(
            'UPDATE Sensors SET roomId = $roomId WHERE macAddress = "${device.macAddress}";');
      }
    });
  }

  Future<void> updateSensor(SensorModel sensor) async {
    await _database.rawUpdate(
        'UPDATE Sensors SET roomId = ${sensor.roomId}, dbId = ${sensor.dbId}, name = "${sensor.name}", sensorType = ${sensor.sensorType.index}, ipAddress = "${sensor.ipAddress}", networkStatus = "${sensor.networkStatus}", readingFrequency = ${sensor.readingFrequency} WHERE macAddress = "${sensor.macAddress}";');
  }

  Future<void> updateSensorData(String data, String macAddress) async {
    try {
      await _database.rawUpdate(
          'UPDATE Sensors SET data = "$data" WHERE macAddress = "$macAddress";');
    } catch (e) {
      log('error', error: e);
    }
  }

  Future<void> updateSensorStatus(bool data, String macAddress) async {
//    AppDataManager().sensors.map((SensorModel device) => device.networkStatus = data);
    for (SensorModel device in AppDataManager()
        .sensors
        .where((SensorModel sensor) => sensor.macAddress == macAddress)
        .toList()) {
      device.networkStatus = data;
    }
    try {
      await _database.rawUpdate(
          'UPDATE Sensors SET networkStatus = "$data" WHERE macAddress = "$macAddress";');
    } catch (e) {
      log('error', error: e);
    }
//    await AppDataManager().fetchData();
  }

  Future<void> removeDeviceFromRoom(SensorModel sensor) async {
    await _database.rawUpdate(
        'UPDATE Sensors SET roomId = NULL WHERE macAddress = "${sensor.macAddress}";');
  }

  Future<void> removeRoom(int roomId) async {
    await _database.transaction((Transaction transaction) async {
      try {
        await transaction.rawUpdate(
            'UPDATE Sensors SET roomId = NULL WHERE roomId = $roomId;');
        await transaction.rawDelete('DELETE FROM Rooms WHERE id = $roomId;');
      } catch (e) {
        print(e);
      }
    });
  }

  Future<void> updateRoom(int roomId, String name) async {
    await _database.transaction((Transaction transaction) async {
      try {
        await transaction
            .rawUpdate('UPDATE Rooms SET name = "$name" WHERE id = $roomId;');
      } catch (e) {
        print(e);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getRoomsByHouseId(int houseId) async {
    final List<Map<String, dynamic>> list = await _database
        .rawQuery('SELECT * FROM Rooms WHERE houseId = $houseId');
    if (list.isEmpty) {
      return null;
    }
    return list;
  }

  Future<UserDataModel> getUserData() async {
//    log('getUserData database', error: _database.isOpen);

    final List<Map<String, dynamic>> list =
        await _database.rawQuery('SELECT DISTINCT * FROM UserData LIMIT 1');
//    log('list Users', error: list);
    if (list.isEmpty) {
      return null;
    }
    return UserDataModel(
      id: list[0]['id'],
      email: list[0]['email'],
      firstName: list[0]['firstName'],
      lastName: list[0]['lastName'],
    );
  }

  Future<HomeModel> getHomeInfoById(int homeId) async {
    final List<Map<String, dynamic>> list = await _database
        .rawQuery('SELECT DISTINCT * FROM Houses WHERE id = $homeId');

    final List<Map<String, dynamic>> rooms = await _database.rawQuery(
        'SELECT DISTINCT r.* FROM Rooms AS r INNER JOIN Houses AS h ON h.id = r.houseId WHERE h.id = $homeId ORDER BY r.name');
    final List<Map<String, dynamic>> sensors =
        await _database.rawQuery('SELECT DISTINCT s.* '
            'FROM Sensors AS s '
            'INNER JOIN Rooms AS r ON r.id = s.roomId '
            'INNER JOIN Houses AS h ON h.id = r.houseId '
            'WHERE h.id = $homeId '
            'ORDER BY s.sensorType');
//    log('gggg', error: sensors.toString());
//    log('list', error: list.toString());
    if (list.isEmpty) {
      return null;
    }
    final HomeModel home = HomeModel(
        id: list[0]['id'],
        dbId: list[0]['dbId'],
        userId: list[0]['userId'],
        name: list[0]['name'],
        address: list[0]['address'],
        rooms: List<RoomModel>.generate(rooms.length, (int i) {
          final List<dynamic> sortedSensors = sensors
              .where((Map<String, dynamic> sensor) =>
                  sensor['roomId'] == rooms[i]['id'])
              .toList();
//          log('tst', error:DevicesType.values[sortedSensors[i]['sensorType']]);
          return RoomModel(
              id: rooms[i]['id'],
              houseId: homeId,
              dbId: rooms[i]['dbId'],
              name: rooms[i]['name'],
              sensors:
                  List<SensorModel>.generate(sortedSensors.length, (int j) {
                return SensorModel(
                  id: sortedSensors[j]['id'],
                  dbId: sortedSensors[j]['dbId'],
                  roomId: sortedSensors[j]['roomId'],
                  name: sortedSensors[j]['name'],
                  macAddress: sortedSensors[j]['macAddress'],
                  networkStatus: sortedSensors[j]['networkStatus'] == 'true',
                  sensorType: DevicesType.values[sortedSensors[j]['sensorType']],
                ); // sortedSensors[j]['sensorType']);
              }));
        }));
//    log(home.toMap().toString());
    return home;
  }

//  Future<void> selectAll() async {
//    final List<Map<String, dynamic>> list =
//        await _database.rawQuery('SELECT DISTINCT * FROM UserData');
//    final List<Map<String, dynamic>> list1 =
//        await _database.rawQuery('SELECT DISTINCT* FROM Houses');
//    final List<Map<String, dynamic>> list2 =
//        await _database.rawQuery('SELECT DISTINCT * FROM Rooms');
//    final List<Map<String, dynamic>> list3 =
//        await _database.rawQuery('SELECT DISTINCT * FROM Sensors');
//    log('selectU', error: list);
//    log('selectH', error: list1);
//    log('selectR', error: list2);
//    log('selectS', error: list3);
//  }
}
