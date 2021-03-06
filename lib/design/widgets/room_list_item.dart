import 'dart:ui';

import 'package:Homey/design/colors.dart';
import 'package:Homey/design/rooms_styles.dart';
import 'package:Homey/design/widgets/buttons/round_button.dart';
import 'package:Homey/helpers/data_types.dart';
import 'package:Homey/helpers/sql_helper/data_models/room_model.dart';
import 'package:Homey/helpers/sql_helper/data_models/sensor_model.dart';
import 'package:Homey/helpers/utils.dart';
import 'package:Homey/states/room_item_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class RoomListItem extends StatelessWidget {
  RoomListItem(this.room,
      {@required this.onPressed, this.selectionOnly = false});

  final RoomModel room;
  final Function onPressed;
  final bool selectionOnly;
  final RoomItemState _state = RoomItemState();

  @override
  Widget build(BuildContext context) {
    _state.init(room.id);
    final Map<String, dynamic> style = RoomsStyles(room.name).getRoomStyle();
    return
//      SlideAnimation(
//      horizontalOffset: Utils.getPercentValueFromScreenHeight(100, context),
//      child:
      Container(
        child: AspectRatio(
          aspectRatio: 21 / 9,
          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            elevation: 0,
            child: InkWell(
                onTap: onPressed,
                splashColor: style['iconColor'],
                child: Stack(
                  overflow: Overflow.clip,
                  fit: StackFit.passthrough,
                  children: <Widget>[
                    Positioned.fill(
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          ColorsTheme.background.withOpacity(0.6),
                          BlendMode.multiply,
                        ),
                        child: Image.asset(
                          style['image'],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.only(
                          left: 16, top: 16, right: 16, bottom: 10),
                      child: Stack(
                        children: <Widget>[
                          Align(
                            alignment: Alignment.topLeft,
                            child: FractionallySizedBox(
                              widthFactor: 0.8,
                              child: Text(
                                room.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withOpacity(0.7)),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topRight,
                            child: Icon(
                              style['icon'],
                              size: 60,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          if (room.sensors.isNotEmpty && !selectionOnly)
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: <Widget>[
//                                  if (room.sensors
//                                      .where((SensorModel sensor) =>
//                                          sensor.sensorType == 3)
//                                      .isNotEmpty)
//                                    RoundButton(
//                                      onPressed: () {},
//                                      backgroundColor:
//                                      ColorsTheme.backgroundDarker.withOpacity(0.8),
//                                      icon: const Icon(
//                                        MdiIcons.lightbulb,
//                                        color: Colors.white,
//                                        size: 20.0,
//                                      ),
//                                    ),
//                                  if (room.sensors
//                                      .where((SensorModel sensor) =>
//                                          sensor.sensorType == 3)
//                                      .isNotEmpty)
//                                    const SizedBox(
//                                      width: 10,
//                                    ),
                                  if (room.sensors
                                      .where((SensorModel sensor) =>
                                          sensor.sensorType == DevicesType.switchDevice)
                                      .isNotEmpty)
                                    StreamBuilder<bool>(
                                        stream: _state.devicesStateStream$,
                                        builder: (_, __) {
                                          return RoundButton(
                                            onPressed: () {
                                              _state.changeSwitchesState(
                                                  !_state.devicesState,
                                                  room.id);
                                            },
                                            backgroundColor: _state.devicesState
                                                ? ColorsTheme.accent
                                                    .withOpacity(0.8)
                                                : ColorsTheme.backgroundDarker
                                                    .withOpacity(0.8),
                                            icon: Icon(
                                              MdiIcons.lightSwitch,
                                              color: Colors.white,
                                              size: 20.0,
                                            ),
                                          );
                                        }),
//                                  if (room.sensors
//                                      .where((SensorModel sensor) =>
//                                          sensor.sensorType == 1)
//                                      .isNotEmpty)
//                                    const SizedBox(
//                                      width: 10,
//                                    ),
//                                  if (room.sensors
//                                      .where((SensorModel sensor) =>
//                                          sensor.sensorType == 2)
//                                      .isNotEmpty)
//                                    RoundButton(
//                                      onPressed: () {},
//                                      backgroundColor:
//                                          ColorsTheme.backgroundDarker.withOpacity(0.8),
//                                      icon: Icon(
//                                        MdiIcons.powerSocketEu,
//                                        color: Colors.white,
//                                        size: 20.0,
//                                      ),
//                                    ),
                                ],
                              ),
                            )
                        ],
                      ),
                    ),
                  ],
                )),
          ),
        ),
//      ),
    );

  }
}
