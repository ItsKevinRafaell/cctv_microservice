// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'anomaly.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Anomaly _$AnomalyFromJson(Map<String, dynamic> json) {
  return _Anomaly.fromJson(json);
}

/// @nodoc
mixin _$Anomaly {
  String get id =>
      throw _privateConstructorUsedError; // pakai String agar fleksibel (int/uuid)
  String get cameraId => throw _privateConstructorUsedError; // "cam1"
  String get anomalyType =>
      throw _privateConstructorUsedError; // "intrusion", dst
  double get confidence => throw _privateConstructorUsedError; // 0.0 - 1.0
  String? get videoClipUrl =>
      throw _privateConstructorUsedError; // optional bukti
  DateTime get reportedAt => throw _privateConstructorUsedError;

  /// Serializes this Anomaly to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Anomaly
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnomalyCopyWith<Anomaly> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnomalyCopyWith<$Res> {
  factory $AnomalyCopyWith(Anomaly value, $Res Function(Anomaly) then) =
      _$AnomalyCopyWithImpl<$Res, Anomaly>;
  @useResult
  $Res call(
      {String id,
      String cameraId,
      String anomalyType,
      double confidence,
      String? videoClipUrl,
      DateTime reportedAt});
}

/// @nodoc
class _$AnomalyCopyWithImpl<$Res, $Val extends Anomaly>
    implements $AnomalyCopyWith<$Res> {
  _$AnomalyCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Anomaly
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? cameraId = null,
    Object? anomalyType = null,
    Object? confidence = null,
    Object? videoClipUrl = freezed,
    Object? reportedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      cameraId: null == cameraId
          ? _value.cameraId
          : cameraId // ignore: cast_nullable_to_non_nullable
              as String,
      anomalyType: null == anomalyType
          ? _value.anomalyType
          : anomalyType // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double,
      videoClipUrl: freezed == videoClipUrl
          ? _value.videoClipUrl
          : videoClipUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      reportedAt: null == reportedAt
          ? _value.reportedAt
          : reportedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AnomalyImplCopyWith<$Res> implements $AnomalyCopyWith<$Res> {
  factory _$$AnomalyImplCopyWith(
          _$AnomalyImpl value, $Res Function(_$AnomalyImpl) then) =
      __$$AnomalyImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String cameraId,
      String anomalyType,
      double confidence,
      String? videoClipUrl,
      DateTime reportedAt});
}

/// @nodoc
class __$$AnomalyImplCopyWithImpl<$Res>
    extends _$AnomalyCopyWithImpl<$Res, _$AnomalyImpl>
    implements _$$AnomalyImplCopyWith<$Res> {
  __$$AnomalyImplCopyWithImpl(
      _$AnomalyImpl _value, $Res Function(_$AnomalyImpl) _then)
      : super(_value, _then);

  /// Create a copy of Anomaly
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? cameraId = null,
    Object? anomalyType = null,
    Object? confidence = null,
    Object? videoClipUrl = freezed,
    Object? reportedAt = null,
  }) {
    return _then(_$AnomalyImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      cameraId: null == cameraId
          ? _value.cameraId
          : cameraId // ignore: cast_nullable_to_non_nullable
              as String,
      anomalyType: null == anomalyType
          ? _value.anomalyType
          : anomalyType // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double,
      videoClipUrl: freezed == videoClipUrl
          ? _value.videoClipUrl
          : videoClipUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      reportedAt: null == reportedAt
          ? _value.reportedAt
          : reportedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AnomalyImpl implements _Anomaly {
  const _$AnomalyImpl(
      {required this.id,
      required this.cameraId,
      required this.anomalyType,
      required this.confidence,
      this.videoClipUrl,
      required this.reportedAt});

  factory _$AnomalyImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnomalyImplFromJson(json);

  @override
  final String id;
// pakai String agar fleksibel (int/uuid)
  @override
  final String cameraId;
// "cam1"
  @override
  final String anomalyType;
// "intrusion", dst
  @override
  final double confidence;
// 0.0 - 1.0
  @override
  final String? videoClipUrl;
// optional bukti
  @override
  final DateTime reportedAt;

  @override
  String toString() {
    return 'Anomaly(id: $id, cameraId: $cameraId, anomalyType: $anomalyType, confidence: $confidence, videoClipUrl: $videoClipUrl, reportedAt: $reportedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnomalyImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.cameraId, cameraId) ||
                other.cameraId == cameraId) &&
            (identical(other.anomalyType, anomalyType) ||
                other.anomalyType == anomalyType) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.videoClipUrl, videoClipUrl) ||
                other.videoClipUrl == videoClipUrl) &&
            (identical(other.reportedAt, reportedAt) ||
                other.reportedAt == reportedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, cameraId, anomalyType,
      confidence, videoClipUrl, reportedAt);

  /// Create a copy of Anomaly
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnomalyImplCopyWith<_$AnomalyImpl> get copyWith =>
      __$$AnomalyImplCopyWithImpl<_$AnomalyImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AnomalyImplToJson(
      this,
    );
  }
}

abstract class _Anomaly implements Anomaly {
  const factory _Anomaly(
      {required final String id,
      required final String cameraId,
      required final String anomalyType,
      required final double confidence,
      final String? videoClipUrl,
      required final DateTime reportedAt}) = _$AnomalyImpl;

  factory _Anomaly.fromJson(Map<String, dynamic> json) = _$AnomalyImpl.fromJson;

  @override
  String get id; // pakai String agar fleksibel (int/uuid)
  @override
  String get cameraId; // "cam1"
  @override
  String get anomalyType; // "intrusion", dst
  @override
  double get confidence; // 0.0 - 1.0
  @override
  String? get videoClipUrl; // optional bukti
  @override
  DateTime get reportedAt;

  /// Create a copy of Anomaly
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnomalyImplCopyWith<_$AnomalyImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
