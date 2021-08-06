import 'dart:io';

import 'package:parabeac_core/controllers/main_info.dart';
import 'package:parabeac_core/design_logic/design_node.dart';
import 'package:parabeac_core/generation/generators/util/pb_generation_view_data.dart';
import 'package:parabeac_core/generation/prototyping/pb_prototype_linker_service.dart';
import 'package:parabeac_core/input/helper/design_project.dart';
import 'package:parabeac_core/input/helper/design_page.dart';
import 'package:parabeac_core/input/helper/design_screen.dart';
import 'package:parabeac_core/interpret_and_optimize/helpers/pb_configuration.dart';
import 'package:parabeac_core/interpret_and_optimize/helpers/pb_context.dart';
import 'package:parabeac_core/interpret_and_optimize/helpers/pb_intermediate_node_tree.dart';
import 'package:parabeac_core/interpret_and_optimize/helpers/pb_project.dart';
import 'package:parabeac_core/interpret_and_optimize/services/pb_alignment_generation_service.dart';
import 'package:parabeac_core/interpret_and_optimize/services/pb_constraint_generation_service.dart';
import 'package:parabeac_core/interpret_and_optimize/services/pb_generation_service.dart';
import 'package:parabeac_core/interpret_and_optimize/services/pb_layout_generation_service.dart';
import 'package:parabeac_core/interpret_and_optimize/services/pb_platform_orientation_linker_service.dart';
import 'package:parabeac_core/interpret_and_optimize/services/pb_plugin_control_service.dart';
import 'package:parabeac_core/interpret_and_optimize/services/pb_symbol_linker_service.dart';
import 'package:parabeac_core/interpret_and_optimize/services/pb_visual_generation_service.dart';
import 'package:quick_log/quick_log.dart';
import 'package:tuple/tuple.dart';

class Interpret {
  var log = Logger('Interpret');

  Interpret._internal();

  static final Interpret _interpret = Interpret._internal();

  factory Interpret() {
    return _interpret;
  }

  PBProject _pb_project;
  PBSymbolLinkerService _pbSymbolLinkerService;
  PBPrototypeLinkerService _pbPrototypeLinkerService;
  PBConfiguration configuration;

  void init(String projectName, PBConfiguration configuration) {
    this.configuration ??= configuration;
    log = Logger(runtimeType.toString());
    _interpret._pbSymbolLinkerService = PBSymbolLinkerService();
    _interpret._pbPrototypeLinkerService = PBPrototypeLinkerService();
  }

  Future<PBProject> interpretAndOptimize(
      DesignProject tree, String projectName, String projectPath) async {
    _pb_project = PBProject(projectName, projectPath, tree.sharedStyles);

    ///3rd Party Symbols
    if (tree.miscPages != null) {
      for (var i = 0; i < tree.miscPages?.length; i++) {
        _pb_project.forest
            .addAll((await _generateIntermediateTree(tree.miscPages[i])));
      }
    }

    /// Main Pages
    if (tree.pages != null) {
      for (var i = 0; i < tree.pages?.length; i++) {
        _pb_project.forest
            .addAll((await _generateIntermediateTree(tree.pages[i])));
      }
    }

    return _pb_project;
  }

  /// Taking a design page, returns a PBIntermediateTree verison of it
  Future<Iterable<PBIntermediateTree>> _generateIntermediateTree(
      DesignPage designPage) async {
    var tempForest = <PBIntermediateTree>[];
    var pageItems = designPage.getPageItems();
    for (var i = 0; i < pageItems.length; i++) {
      var tree = await _generateScreen(pageItems[i]);
      if (tree != null && tree.rootNode != null) {
        tree.name = designPage.name;

        tree.data = PBGenerationViewData();
        if (tree.isScreen()) {
          PBPlatformOrientationLinkerService()
              .addOrientationPlatformInformation(tree);
        }

        if (tree != null) {
          log.fine(
              'Processed \'${tree.name}\' in group \'${designPage.name}\' with item type: \'${tree.tree_type}\'');

          tempForest.add(tree);
        }
      }
    }
    return tempForest;
  }

  Future<PBIntermediateTree> _generateScreen(DesignScreen designScreen) async {
    var currentContext = PBContext(configuration);
    currentContext.project = _pb_project;

    var aitServices = [
      PBVisualGenerationService().getIntermediateTree,
      PBSymbolLinkerService(),
      PBPluginControlService(),
      PBLayoutGenerationService(),
      PBConstraintGenerationService(),
      PBAlignGenerationService()
    ];

    var builder =
        AITServiceBuilder(currentContext, designScreen.designNode, aitServices);
    return builder.build();
  }
}

class AITServiceBuilder {
  Logger log;

  PBIntermediateTree _intermediateTree;
  set intermediateTree(PBIntermediateTree tree) => _intermediateTree = tree;

  final PBContext _context;
  Stopwatch _stopwatch;

  /// These are the [AITHandler]s that are going to be transforming
  /// the [_intermediateTree] in a [Tuple2]. The [Tuple2.item1] is the id, if any, and
  /// [Tuple2.item2] is the actual [AITHandler]
  final List<Tuple2> _transformations = [];

  final DesignNode designNode;

  AITServiceBuilder(this._context, this.designNode, [List transformations]) {
    log = Logger(runtimeType.toString());
    _stopwatch = Stopwatch();

    if (transformations != null) {
      transformations.forEach(addTransformation);
      if (_verifyTransformationsFailed()) {
        throw Error();
      }
    }
  }

  /// Adding a [transformation] that will be applyed to the [PBIntermediateTree]. The [id]
  /// is to [log] the [transformation].
  AITServiceBuilder addTransformation(transformation, {String id}) {
    id ??= transformation.runtimeType.toString();
    if (transformation is AITHandler) {
      _transformations.add(Tuple2(id, transformation.handleTree));
    } else if (transformation is AITNodeTransformation ||
        transformation is PBDLConversion) {
      _transformations.add(Tuple2(id, transformation));
    }
    return this;
  }

  /// Verifies that only the allows data types are within the [_transformations]
  bool _verifyTransformationsFailed() {
    return _transformations.any((transformation) =>
        transformation.item2 is! AITHandler &&
        transformation.item2 is! AITNodeTransformation &&
        transformation.item2 is! PBDLConversion &&
        transformation.item2 is! AITTransformation);
  }

  Future<PBIntermediateTree> _pbdlConversion(PBDLConversion conversion) async {
    try {
      _stopwatch.start();
      log.fine('Converting ${designNode.name} to AIT');
      _intermediateTree = await conversion(designNode, _context);

      assert(_intermediateTree != null,
          'All PBDL conversions should yield a IntermediateTree');
      _context.tree = _intermediateTree;
      _stopwatch.stop();
      log.fine(
          'Finished with ${designNode.name} (${_stopwatch.elapsedMilliseconds}');
      return _intermediateTree;
    } catch (e) {
      MainInfo().captureException(e);
      log.error('PBDL Conversion was not possible because of - \n$e');

      exit(1);
    }
  }

  Future<PBIntermediateTree> build() async {
    var pbdlConversion = _transformations
        .firstWhere((transformation) => transformation.item2 is PBDLConversion)
        .item2;
    if (pbdlConversion == null) {
      throw Error();
    }
    _transformations.removeWhere((element) => element.item2 is PBDLConversion);
    await _pbdlConversion(pbdlConversion);

    if (_intermediateTree == null || _intermediateTree.rootNode == null) {
      log.warning(
          'Skipping ${designNode.name} as either $PBIntermediateTree or $PBIntermediateTree.rootNode is null');
      return Future.value(_intermediateTree);
    }

    var treeName = _intermediateTree.name;
    log.fine('Transforming $treeName ...');

    for (var transformationTuple in _transformations) {
      var transformation = transformationTuple.item2;
      var name = transformationTuple.item1;

      _stopwatch.start();
      log.debug('Started running $name...');
      try {
        if (transformation is AITNodeTransformation) {
          for (var node in _intermediateTree) {
            node = await transformation(_context, node);
          }
        } else if (transformation is AITTransformation) {
          _intermediateTree = await transformation(_context, _intermediateTree);
        }

        if (_intermediateTree == null || _intermediateTree.rootNode == null) {
          log.error(
              'The $name returned a null \"$treeName\" $PBIntermediateTree (or its rootnode is null)\n after its transformation, this will remove the tree from the process!');
          throw NullThrownError();
        }
      } catch (e) {
        MainInfo().captureException(e);
        log.error('${e.toString()} at $name');
      } finally {
        _stopwatch.stop();
        log.debug(
            'Stoped running $name (${_stopwatch.elapsed.inMilliseconds})');
      }
    }
    log.fine('Finish transforming $treeName');
    return _intermediateTree;
  }
}
