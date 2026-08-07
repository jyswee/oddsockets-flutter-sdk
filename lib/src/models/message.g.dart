// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
      id: json['id'] as String,
      channel: json['channel'] as String,
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
      'id': instance.id,
      'channel': instance.channel,
      'data': instance.data,
      'timestamp': instance.timestamp.toIso8601String(),
      'userId': instance.userId,
      'metadata': instance.metadata,
    };
