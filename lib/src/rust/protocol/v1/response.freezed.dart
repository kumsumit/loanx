// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Result {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Result&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'Result(field0: $field0)';
}


}

/// @nodoc
class $ResultCopyWith<$Res>  {
$ResultCopyWith(Result _, $Res Function(Result) __);
}


/// Adds pattern-matching-related methods to [Result].
extension ResultPatterns on Result {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Result_Hello value)?  hello,TResult Function( Result_Ping value)?  ping,TResult Function( Result_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Result_Hello() when hello != null:
return hello(_that);case Result_Ping() when ping != null:
return ping(_that);case Result_Error() when error != null:
return error(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Result_Hello value)  hello,required TResult Function( Result_Ping value)  ping,required TResult Function( Result_Error value)  error,}){
final _that = this;
switch (_that) {
case Result_Hello():
return hello(_that);case Result_Ping():
return ping(_that);case Result_Error():
return error(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Result_Hello value)?  hello,TResult? Function( Result_Ping value)?  ping,TResult? Function( Result_Error value)?  error,}){
final _that = this;
switch (_that) {
case Result_Hello() when hello != null:
return hello(_that);case Result_Ping() when ping != null:
return ping(_that);case Result_Error() when error != null:
return error(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( HelloResponse field0)?  hello,TResult Function( PingResponse field0)?  ping,TResult Function( ProtocolError field0)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Result_Hello() when hello != null:
return hello(_that.field0);case Result_Ping() when ping != null:
return ping(_that.field0);case Result_Error() when error != null:
return error(_that.field0);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( HelloResponse field0)  hello,required TResult Function( PingResponse field0)  ping,required TResult Function( ProtocolError field0)  error,}) {final _that = this;
switch (_that) {
case Result_Hello():
return hello(_that.field0);case Result_Ping():
return ping(_that.field0);case Result_Error():
return error(_that.field0);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( HelloResponse field0)?  hello,TResult? Function( PingResponse field0)?  ping,TResult? Function( ProtocolError field0)?  error,}) {final _that = this;
switch (_that) {
case Result_Hello() when hello != null:
return hello(_that.field0);case Result_Ping() when ping != null:
return ping(_that.field0);case Result_Error() when error != null:
return error(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class Result_Hello extends Result {
  const Result_Hello(this.field0): super._();
  

@override final  HelloResponse field0;

/// Create a copy of Result
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Result_HelloCopyWith<Result_Hello> get copyWith => _$Result_HelloCopyWithImpl<Result_Hello>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Result_Hello&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'Result.hello(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $Result_HelloCopyWith<$Res> implements $ResultCopyWith<$Res> {
  factory $Result_HelloCopyWith(Result_Hello value, $Res Function(Result_Hello) _then) = _$Result_HelloCopyWithImpl;
@useResult
$Res call({
 HelloResponse field0
});




}
/// @nodoc
class _$Result_HelloCopyWithImpl<$Res>
    implements $Result_HelloCopyWith<$Res> {
  _$Result_HelloCopyWithImpl(this._self, this._then);

  final Result_Hello _self;
  final $Res Function(Result_Hello) _then;

/// Create a copy of Result
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(Result_Hello(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as HelloResponse,
  ));
}


}

/// @nodoc


class Result_Ping extends Result {
  const Result_Ping(this.field0): super._();
  

@override final  PingResponse field0;

/// Create a copy of Result
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Result_PingCopyWith<Result_Ping> get copyWith => _$Result_PingCopyWithImpl<Result_Ping>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Result_Ping&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'Result.ping(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $Result_PingCopyWith<$Res> implements $ResultCopyWith<$Res> {
  factory $Result_PingCopyWith(Result_Ping value, $Res Function(Result_Ping) _then) = _$Result_PingCopyWithImpl;
@useResult
$Res call({
 PingResponse field0
});




}
/// @nodoc
class _$Result_PingCopyWithImpl<$Res>
    implements $Result_PingCopyWith<$Res> {
  _$Result_PingCopyWithImpl(this._self, this._then);

  final Result_Ping _self;
  final $Res Function(Result_Ping) _then;

/// Create a copy of Result
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(Result_Ping(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as PingResponse,
  ));
}


}

/// @nodoc


class Result_Error extends Result {
  const Result_Error(this.field0): super._();
  

@override final  ProtocolError field0;

/// Create a copy of Result
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Result_ErrorCopyWith<Result_Error> get copyWith => _$Result_ErrorCopyWithImpl<Result_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Result_Error&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'Result.error(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $Result_ErrorCopyWith<$Res> implements $ResultCopyWith<$Res> {
  factory $Result_ErrorCopyWith(Result_Error value, $Res Function(Result_Error) _then) = _$Result_ErrorCopyWithImpl;
@useResult
$Res call({
 ProtocolError field0
});




}
/// @nodoc
class _$Result_ErrorCopyWithImpl<$Res>
    implements $Result_ErrorCopyWith<$Res> {
  _$Result_ErrorCopyWithImpl(this._self, this._then);

  final Result_Error _self;
  final $Res Function(Result_Error) _then;

/// Create a copy of Result
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(Result_Error(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as ProtocolError,
  ));
}


}

// dart format on
