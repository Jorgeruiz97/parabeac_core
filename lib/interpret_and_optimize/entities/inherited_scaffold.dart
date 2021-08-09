import 'dart:math';
import 'package:parabeac_core/eggs/injected_app_bar.dart';
import 'package:parabeac_core/eggs/injected_tab_bar.dart';
import 'package:parabeac_core/generation/generators/layouts/pb_scaffold_gen.dart';
import 'package:parabeac_core/generation/prototyping/pb_prototype_node.dart';
import 'package:parabeac_core/interpret_and_optimize/entities/alignments/padding.dart';
import 'package:parabeac_core/interpret_and_optimize/entities/layouts/stack.dart';
import 'package:parabeac_core/interpret_and_optimize/entities/layouts/temp_group_layout_node.dart';
import 'package:parabeac_core/interpret_and_optimize/entities/pb_shared_instance.dart';
import 'package:parabeac_core/interpret_and_optimize/entities/subclasses/pb_attribute.dart';
import 'package:parabeac_core/interpret_and_optimize/entities/subclasses/pb_intermediate_constraints.dart';
import 'package:parabeac_core/interpret_and_optimize/entities/subclasses/pb_intermediate_node.dart';
import 'package:parabeac_core/interpret_and_optimize/entities/subclasses/pb_visual_intermediate_node.dart';
import 'package:parabeac_core/interpret_and_optimize/helpers/pb_context.dart';
import 'package:parabeac_core/interpret_and_optimize/helpers/pb_context.dart';
import 'package:json_annotation/json_annotation.dart';

part 'inherited_scaffold.g.dart';

@JsonSerializable()
class InheritedScaffold extends PBVisualIntermediateNode
    with PBColorMixin
    implements
        /* with GeneratePBTree */ /* PropertySearchable,*/ PBInheritedIntermediate,
        IntermediateNodeFactory {
  @override
  @JsonKey(
      fromJson: PrototypeNode.prototypeNodeFromJson, name: 'prototypeNodeUUID')
  PrototypeNode prototypeNode;

  @JsonKey(defaultValue: false, name: 'isFlowHome')
  bool isHomeScreen = false;
    AlignStrategy alignStrategy = NoAlignment();//PaddingAlignment();
  @override
  @JsonKey(ignore: true)
  Point topLeftCorner;
  @override
  @JsonKey(ignore: true)
  Point bottomRightCorner;

  @override
  @JsonKey()
  String type = 'artboard';

  @override
  String UUID;

  @override
  @JsonKey(fromJson: PBIntermediateNode.sizeFromJson, name: 'boundaryRectangle')
  Map size;

  @override
  @JsonKey(ignore: true)
  PBContext currentContext;

  @override
  @JsonKey(ignore: true)
  PBIntermediateNode get child => getAttributeNamed('body')?.attributeNode;

  @override
  List<PBIntermediateNode> get children => [child, navbar, tabbar];

  PBIntermediateNode get navbar => getAttributeNamed('appBar')?.attributeNode;

  PBIntermediateNode get tabbar =>
      getAttributeNamed('bottomNavigationBar')?.attributeNode;

  @override
  set child(PBIntermediateNode node) {
    if (!hasAttribute('body')) {
      addAttribute(PBAttribute('body', attributeNodes: [node]));
    } else {
      getAttributeNamed('body').attributeNode = node;
    }
  }

  @override
  @JsonKey(ignore: true)
  List<PBIntermediateNode> get children => super.children;

  @override
  @JsonKey(ignore: true)
  Map<String, dynamic> originalRef;

  InheritedScaffold({
    this.originalRef,
    this.topLeftCorner,
    this.bottomRightCorner,
    String name,
    this.currentContext,
    this.isHomeScreen,
    this.UUID,
    this.prototypeNode,
    this.size,
  }) : super(
          topLeftCorner,
          bottomRightCorner,
          currentContext,
          name,
          UUID: UUID ?? '',
        ) {
    this.name = name
        ?.replaceAll(RegExp(r'[\W]'), '')
        ?.replaceFirst(RegExp(r'^([\d]|_)+'), '');

    generator = PBScaffoldGenerator();

    // Add body attribute
    addAttribute(PBAttribute('body'));
  }

  List<PBIntermediateNode> layoutInstruction(List<PBIntermediateNode> layer) {
    return layer;
  }

  @override
  void addChild(node) {
    print(this.name);
    if (this.name == 'ArtboardTRpinnoscale') {
      print('object');
    }
    if (node is PBSharedInstanceIntermediateNode) {
      if (node.name.contains('<navbar>')) {
        addAttribute(PBAttribute('appBar', attributeNodes: [node]));
        currentContext.canvasTLC =
            Point(currentContext.canvasTLC.x, node.bottomRightCorner.y);
        return;
      }
      if (node.name.contains('<tabbar>')) {
        addAttribute(
            PBAttribute('bottomNavigationBar', attributeNodes: [node]));
        return;
      }
    }

    if (node is InjectedAppbar) {
      addAttribute(PBAttribute('appBar', attributeNodes: [node]));
      currentContext.canvasTLC =
          Point(currentContext.canvasTLC.x, node.bottomRightCorner.y);
      return;
    }
    if (node is InjectedTabBar) {
      addAttribute(PBAttribute('bottomNavigationBar', attributeNodes: [node]));
      return;
    }

    if (child is TempGroupLayoutNode) {
      child.addChild(node);
      return;
    }
    // If there's multiple children add a temp group so that layout service lays the children out.
    if (child != null) {
      var temp =
          TempGroupLayoutNode(currentContext: currentContext, name: node.name);
      temp.addChild(child);
      temp.addChild(node);
      child = temp;
    } else {
      if (child != null) {
        child.addChild(node);
      } else {
        var stack = PBIntermediateStackLayout(currentContext,
            name: node.name,
            constraints: PBIntermediateConstraints(
                pinBottom: false,
                pinLeft: false,
                pinRight: false,
                pinTop: false));
        stack.addChild(node);
        child = stack;
      }
    }
  }

  static PBIntermediateNode fromJson(Map<String, dynamic> json) {
    var artboard = _$InheritedScaffoldFromJson(json)
      ..topLeftCorner = Point.topLeftFromJson(json)
      ..bottomRightCorner = Point.bottomRightFromJson(json)
      ..originalRef = json;

    //Map artboard children by calling `addChild` method
    artboard.mapRawChildren(json);
    return artboard;
  }

  @override
  PBIntermediateNode createIntermediateNode(Map<String, dynamic> json) =>
      InheritedScaffold.fromJson(json);
}
