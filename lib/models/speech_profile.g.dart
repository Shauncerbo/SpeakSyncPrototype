// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speech_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SpeechProfileAdapter extends TypeAdapter<SpeechProfile> {
  @override
  final int typeId = 2;

  @override
  SpeechProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SpeechProfile(
      speechProfileId: fields[0] as String,
      userId: fields[1] as String,
      speechTitle: fields[2] as String,
      speechType: fields[3] as String,
      languageMode: fields[4] as String,
      targetDurationSeconds: fields[5] as int,
      speechContent: fields[6] as String?,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SpeechProfile obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.speechProfileId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.speechTitle)
      ..writeByte(3)
      ..write(obj.speechType)
      ..writeByte(4)
      ..write(obj.languageMode)
      ..writeByte(5)
      ..write(obj.targetDurationSeconds)
      ..writeByte(6)
      ..write(obj.speechContent)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeechProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
