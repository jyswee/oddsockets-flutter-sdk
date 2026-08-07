// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'types.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PresenceInfo _$PresenceInfoFromJson(Map<String, dynamic> json) => PresenceInfo(
      channel: json['channel'] as String,
      users: (json['users'] as List<dynamic>).map((e) => e as String).toList(),
      count: (json['count'] as num).toInt(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$PresenceInfoToJson(PresenceInfo instance) =>
    <String, dynamic>{
      'channel': instance.channel,
      'users': instance.users,
      'count': instance.count,
      'timestamp': instance.timestamp.toIso8601String(),
    };

PublishResult _$PublishResultFromJson(Map<String, dynamic> json) =>
    PublishResult(
      messageId: json['messageId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      channel: json['channel'] as String,
      success: json['success'] as bool,
    );

Map<String, dynamic> _$PublishResultToJson(PublishResult instance) =>
    <String, dynamic>{
      'messageId': instance.messageId,
      'timestamp': instance.timestamp.toIso8601String(),
      'channel': instance.channel,
      'success': instance.success,
    };

BulkMessage _$BulkMessageFromJson(Map<String, dynamic> json) => BulkMessage(
      json['channel'] as String,
      json['message'],
      json['options'] == null
          ? null
          : PublishOptions.fromJson(json['options'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BulkMessageToJson(BulkMessage instance) =>
    <String, dynamic>{
      'channel': instance.channel,
      'message': instance.message,
      'options': instance.options,
    };

BulkResult _$BulkResultFromJson(Map<String, dynamic> json) => BulkResult(
      success: json['success'] as bool,
      result: json['result'] == null
          ? null
          : PublishResult.fromJson(json['result'] as Map<String, dynamic>),
      error: json['error'] as String?,
    );

Map<String, dynamic> _$BulkResultToJson(BulkResult instance) =>
    <String, dynamic>{
      'success': instance.success,
      'result': instance.result,
      'error': instance.error,
    };

SubscribeOptions _$SubscribeOptionsFromJson(Map<String, dynamic> json) =>
    SubscribeOptions(
      enablePresence: json['enablePresence'] as bool? ?? false,
      retainHistory: json['retainHistory'] as bool? ?? false,
      filterExpression: json['filterExpression'] as String?,
    );

Map<String, dynamic> _$SubscribeOptionsToJson(SubscribeOptions instance) =>
    <String, dynamic>{
      'enablePresence': instance.enablePresence,
      'retainHistory': instance.retainHistory,
      'filterExpression': instance.filterExpression,
    };

PublishOptions _$PublishOptionsFromJson(Map<String, dynamic> json) =>
    PublishOptions(
      ttl: (json['ttl'] as num?)?.toInt(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      storeInHistory: json['storeInHistory'] as bool? ?? false,
    );

Map<String, dynamic> _$PublishOptionsToJson(PublishOptions instance) =>
    <String, dynamic>{
      'ttl': instance.ttl,
      'metadata': instance.metadata,
      'storeInHistory': instance.storeInHistory,
    };

HistoryOptions _$HistoryOptionsFromJson(Map<String, dynamic> json) =>
    HistoryOptions(
      limit: (json['limit'] as num?)?.toInt(),
      start: json['start'] == null
          ? null
          : DateTime.parse(json['start'] as String),
      end: json['end'] == null ? null : DateTime.parse(json['end'] as String),
      reverse: json['reverse'] as bool? ?? false,
    );

Map<String, dynamic> _$HistoryOptionsToJson(HistoryOptions instance) =>
    <String, dynamic>{
      'limit': instance.limit,
      'start': instance.start?.toIso8601String(),
      'end': instance.end?.toIso8601String(),
      'reverse': instance.reverse,
    };
