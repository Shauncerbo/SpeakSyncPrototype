// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filler_word_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FillerWordLogAdapter extends TypeAdapter<FillerWordLog> {
  @override
  final int typeId = 4;

  @override
  FillerWordLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FillerWordLog(
      logId: fields[0] as String,
      sessionId: fields[1] as String,
      fillerWord: fields[2] as String,
      occurrenceCount: fields[3] as int,
      detectedTimes: (fields[4] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, FillerWordLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.logId)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.fillerWord)
      ..writeByte(3)
      ..write(obj.occurrenceCount)
      ..writeByte(4)
      ..write(obj.detectedTimes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FillerWordLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
