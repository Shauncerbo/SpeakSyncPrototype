// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_preferences.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppPreferencesAdapter extends TypeAdapter<AppPreferences> {
  @override
  final int typeId = 1;

  @override
  AppPreferences read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppPreferences(
      userId: fields[0] as String,
      defaultLanguage: fields[1] as String,
      defaultDuration: fields[2] as String,
      liveFeedback: fields[3] as bool,
      bodyMonitoring: fields[4] as bool,
      cameraAttentionMonitoring: fields[5] as bool,
      fillerMonitoring: fields[6] as bool,
      paceMonitoring: fields[7] as bool,
      alertFrequency: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AppPreferences obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.defaultLanguage)
      ..writeByte(2)
      ..write(obj.defaultDuration)
      ..writeByte(3)
      ..write(obj.liveFeedback)
      ..writeByte(4)
      ..write(obj.bodyMonitoring)
      ..writeByte(5)
      ..write(obj.cameraAttentionMonitoring)
      ..writeByte(6)
      ..write(obj.fillerMonitoring)
      ..writeByte(7)
      ..write(obj.paceMonitoring)
      ..writeByte(8)
      ..write(obj.alertFrequency);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppPreferencesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
