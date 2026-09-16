// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'performance_report.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PerformanceReportAdapter extends TypeAdapter<PerformanceReport> {
  @override
  final int typeId = 5;

  @override
  PerformanceReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PerformanceReport(
      reportId: fields[0] as String,
      sessionId: fields[1] as String,
      totalWords: fields[2] as int,
      wordsPerMinute: fields[3] as double,
      paceScore: fields[4] as int,
      fillerScore: fields[5] as int,
      goodPostureSeconds: fields[6] as int,
      postureScore: fields[7] as int,
      cameraFacingSeconds: fields[8] as int,
      cameraScore: fields[9] as int,
      overallScore: fields[10] as int,
      coachingTips: (fields[11] as List).cast<String>(),
      textTranscript: fields[12] as String?,
      createdAt: fields[13] as DateTime,
      fillerCounts: (fields[14] as Map).cast<String, int>(),
      recommendedPosture: fields[15] as String,
      isPrototypeData: fields[16] as bool,
      referenceScript: fields[17] as String?,
      referenceDocumentName: fields[18] as String?,
      omittedScriptPortions: fields[19] == null
          ? []
          : (fields[19] as List).cast<String>(),
      addedTranscriptPortions: fields[20] == null
          ? []
          : (fields[20] as List).cast<String>(),
      differentlyDeliveredPortions: fields[21] == null
          ? []
          : (fields[21] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, PerformanceReport obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.reportId)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.totalWords)
      ..writeByte(3)
      ..write(obj.wordsPerMinute)
      ..writeByte(4)
      ..write(obj.paceScore)
      ..writeByte(5)
      ..write(obj.fillerScore)
      ..writeByte(6)
      ..write(obj.goodPostureSeconds)
      ..writeByte(7)
      ..write(obj.postureScore)
      ..writeByte(8)
      ..write(obj.cameraFacingSeconds)
      ..writeByte(9)
      ..write(obj.cameraScore)
      ..writeByte(10)
      ..write(obj.overallScore)
      ..writeByte(11)
      ..write(obj.coachingTips)
      ..writeByte(12)
      ..write(obj.textTranscript)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.fillerCounts)
      ..writeByte(15)
      ..write(obj.recommendedPosture)
      ..writeByte(16)
      ..write(obj.isPrototypeData)
      ..writeByte(17)
      ..write(obj.referenceScript)
      ..writeByte(18)
      ..write(obj.referenceDocumentName)
      ..writeByte(19)
      ..write(obj.omittedScriptPortions)
      ..writeByte(20)
      ..write(obj.addedTranscriptPortions)
      ..writeByte(21)
      ..write(obj.differentlyDeliveredPortions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerformanceReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
