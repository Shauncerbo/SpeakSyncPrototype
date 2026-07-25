// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rehearsal_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RehearsalSessionAdapter extends TypeAdapter<RehearsalSession> {
  @override
  final int typeId = 3;

  @override
  RehearsalSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RehearsalSession(
      sessionId: fields[0] as String,
      userId: fields[1] as String,
      speechProfileId: fields[2] as String,
      speechTitle: fields[3] as String,
      speechType: fields[4] as String,
      languageMode: fields[5] as String,
      targetDurationSeconds: fields[6] as int,
      durationSeconds: fields[7] as int,
      sessionDate: fields[8] as DateTime,
      liveAlertsEnabled: fields[9] as bool,
      bodyLanguageEnabled: fields[10] as bool,
      fillerWordEnabled: fields[11] as bool,
      speakingPaceEnabled: fields[12] as bool,
      cameraAttentionEnabled: fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RehearsalSession obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.sessionId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.speechProfileId)
      ..writeByte(3)
      ..write(obj.speechTitle)
      ..writeByte(4)
      ..write(obj.speechType)
      ..writeByte(5)
      ..write(obj.languageMode)
      ..writeByte(6)
      ..write(obj.targetDurationSeconds)
      ..writeByte(7)
      ..write(obj.durationSeconds)
      ..writeByte(8)
      ..write(obj.sessionDate)
      ..writeByte(9)
      ..write(obj.liveAlertsEnabled)
      ..writeByte(10)
      ..write(obj.bodyLanguageEnabled)
      ..writeByte(11)
      ..write(obj.fillerWordEnabled)
      ..writeByte(12)
      ..write(obj.speakingPaceEnabled)
      ..writeByte(13)
      ..write(obj.cameraAttentionEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RehearsalSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
