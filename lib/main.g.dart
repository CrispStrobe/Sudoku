// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PuzzleBlueprint _$PuzzleBlueprintFromJson(
  Map<String, dynamic> json,
) => PuzzleBlueprint(
  solutionGrid: (json['solutionGrid'] as List<dynamic>)
      .map((e) => (e as List<dynamic>).map((e) => (e as num).toInt()).toList())
      .toList(),
  regions: (json['regions'] as List<dynamic>)
      .map((e) => (e as List<dynamic>).map((e) => (e as num).toInt()).toList())
      .toList(),
  gridSize: $enumDecode(_$GridSizeEnumMap, json['gridSize']),
  gridShape: $enumDecode(_$GridShapeEnumMap, json['gridShape']),
);

Map<String, dynamic> _$PuzzleBlueprintToJson(PuzzleBlueprint instance) =>
    <String, dynamic>{
      'solutionGrid': instance.solutionGrid,
      'regions': instance.regions,
      'gridSize': _$GridSizeEnumMap[instance.gridSize]!,
      'gridShape': _$GridShapeEnumMap[instance.gridShape]!,
    };

const _$GridSizeEnumMap = {
  GridSize.small: 'small',
  GridSize.medium: 'medium',
  GridSize.large: 'large',
  GridSize.standard: 'standard',
  GridSize.big: 'big',
  GridSize.mega: 'mega',
};

const _$GridShapeEnumMap = {
  GridShape.classic: 'classic',
  GridShape.jigsaw: 'jigsaw',
};
