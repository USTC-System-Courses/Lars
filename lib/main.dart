/// LARS - LA32R Assembler and Runtime Simulator
///
/// A Flutter-based assembler and simulator for the LA32R (LoongArch 32-bit Reduced)
/// instruction set architecture. This application provides a modern IDE-like interface
/// for assembly programming and simulation.
///
/// Features:
/// - Real-time syntax highlighting for LA32R assembly
/// - Interactive code editor with modern features
/// - Visual debugging with register state display
/// - Memory inspection and modification
/// - Breakpoint support
/// - Code and data export in various formats
///
/// Copyright (c) 2024 LARS Team
/// Licensed under MIT License

import 'package:binary/binary.dart';
import 'package:flutter/material.dart';
import 'package:lars/Lars/arch.dart';
import 'package:lars/Lars/Uint32_ext.dart';
import 'package:lars/Lars/assembler.dart';
import 'package:lars/Lars/config.dart';
import 'package:lars/Lars/exception.dart';
import 'package:lars/Lars/codefield.dart';
import 'package:lars/Lars/memory.dart';
import 'package:lars/Lars/simulator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lars/Lars/dump.dart' if (dart.library.io) 'winout.dart';
import 'package:flutter/services.dart';
import 'package:lars/Lipes/Lipes.dart';
import 'package:lars/Lipes/names.dart' as lipes_names;
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
// import 'package:binary/binary.dart';

/// Application entry point
void main() => runApp(MyApp());

List<String> temp = [];

enum WorkspaceMode { lars, lipes }

/// Root application widget that configures the app theme and basic structure
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  WorkspaceMode _mode = WorkspaceMode.lars;

  bool get _showLipes => _mode == WorkspaceMode.lipes;

  void _toggleWorkspace() {
    setState(() {
      _mode = _showLipes ? WorkspaceMode.lars : WorkspaceMode.lipes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // theme: ThemeData(fontFamily: 'FiraCode'),
      home: Scaffold(
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.memory, color: Colors.white.withAlpha(240)),
            ),
            title: Row(
              children: [
                Text(
                  _showLipes ? 'LIPES' : 'LARS',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                    color: Colors.amber[200],
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  _showLipes ? '五段流水线CPU演示' : '龙芯架构32位精简版指令集 汇编器与模拟器',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(200),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF3949AB),
            elevation: 2,
            toolbarHeight: 56,
            centerTitle: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: TextButton.icon(
                  onPressed: _toggleWorkspace,
                  icon: Icon(Icons.swap_horiz, color: Colors.white),
                  label: Text(
                    _showLipes ? '切换到 Lars' : '切换到 Lipes',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha(28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(children: [
            Container(
              decoration:
                  BoxDecoration(color: Color.fromARGB(255, 239, 241, 254)),
            ),
            _showLipes ? LipesWorkspace() : MyTextPaginatingWidget(),
          ])),
    );
  }
}

class LipesWorkspace extends StatefulWidget {
  @override
  State<LipesWorkspace> createState() => _LipesWorkspaceState();
}

class _LipesWorkspaceState extends State<LipesWorkspace> {
  late SimplePipelineCpu _cpu;
  final TransformationController _diagramController =
      TransformationController();
  _SignalRef? _hoveredSignal;
  Offset? _hoveredScenePosition;

  @override
  void initState() {
    super.initState();
    _cpu = Lipes().createSimplePipelineDemo();
  }

  @override
  void dispose() {
    _diagramController.dispose();
    super.dispose();
  }

  SimplePipelineSnapshot? get _snapshot => _cpu.lastSnapshot;
  SimplePipelineSnapshot? get _previousSnapshot =>
      _cpu.trace.length < 2 ? null : _cpu.trace[_cpu.trace.length - 2];

  void _step() {
    setState(() {
      _cpu.step();
      _hoveredSignal = null;
      _hoveredScenePosition = null;
    });
  }

  void _run() {
    setState(() {
      _cpu.run();
      _hoveredSignal = null;
      _hoveredScenePosition = null;
    });
  }

  void _reset() {
    setState(() {
      _cpu = Lipes().createSimplePipelineDemo();
      _hoveredSignal = null;
      _hoveredScenePosition = null;
    });
  }

  void _updateHover(
    BuildContext context,
    PointerHoverEvent event,
    SimplePipelineSnapshot snapshot,
    SimplePipelineSnapshot? previousSnapshot,
  ) {
    final box = context.findRenderObject() as RenderBox;
    final viewportPoint = box.globalToLocal(event.position);
    final scenePoint = _diagramController.toScene(viewportPoint);
    final painter = PipelineDiagramPainter(
      snapshot: snapshot,
      previousSnapshot: previousSnapshot,
    );
    final signal = painter.signalAt(scenePoint);
    if (signal != _hoveredSignal ||
        (signal != null && scenePoint != _hoveredScenePosition)) {
      setState(() {
        _hoveredSignal = signal;
        _hoveredScenePosition = signal == null ? null : scenePoint;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final previousSnapshot = _previousSnapshot;
    return Column(
      children: [
        Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(14),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildToolButton(
                icon: Icons.restart_alt,
                label: '重置',
                onPressed: _reset,
              ),
              SizedBox(width: 8),
              _buildToolButton(
                icon: Icons.skip_next,
                label: '单步',
                onPressed: _step,
              ),
              SizedBox(width: 8),
              _buildToolButton(
                icon: Icons.play_arrow,
                label: '运行',
                onPressed: _run,
              ),
              Spacer(),
              Text(
                'Cycle ${snapshot?.cycle ?? 0}',
                style: TextStyle(
                  fontFamily: 'FiraCode',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3949AB),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: snapshot == null
              ? _buildEmptyState()
              : Container(
                  margin: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(18),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Builder(
                    builder: (viewerContext) {
                      return MouseRegion(
                        onHover: (event) => _updateHover(
                          viewerContext,
                          event,
                          snapshot,
                          previousSnapshot,
                        ),
                        onExit: (_) => setState(() {
                          _hoveredSignal = null;
                          _hoveredScenePosition = null;
                        }),
                        child: InteractiveViewer(
                          transformationController: _diagramController,
                          constrained: false,
                          boundaryMargin: EdgeInsets.all(280),
                          minScale: 0.25,
                          maxScale: 1.8,
                          child: CustomPaint(
                            size: PipelineDiagramPainter.diagramSize,
                            painter: PipelineDiagramPainter(
                              snapshot: snapshot,
                              previousSnapshot: previousSnapshot,
                              hoveredSignal: _hoveredSignal,
                              hoverPosition: _hoveredScenePosition,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF3949AB),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _step,
        icon: Icon(Icons.skip_next),
        label: Text('开始单步'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF3949AB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class PipelineDiagramPainter extends CustomPainter {
  final SimplePipelineSnapshot snapshot;
  final SimplePipelineSnapshot? previousSnapshot;
  final _SignalRef? hoveredSignal;
  final Offset? hoverPosition;

  PipelineDiagramPainter({
    required this.snapshot,
    required this.previousSnapshot,
    this.hoveredSignal,
    this.hoverPosition,
  });

  static const diagramSize = Size(2700, 2860);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas);
    final nodes = _diagramNodes();
    _drawTitle(canvas);
    for (final wire in _diagramWires()) {
      _drawWire(canvas, wire);
    }
    for (final node in nodes.values) {
      _drawNode(canvas, node);
    }
    _drawControlModules(canvas);
    _drawLegend(canvas);
    _drawModuleIoCatalog(canvas);
    _drawHoverTooltip(canvas);
  }

  @override
  bool shouldRepaint(covariant PipelineDiagramPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.previousSnapshot != previousSnapshot ||
        oldDelegate.hoveredSignal != hoveredSignal ||
        oldDelegate.hoverPosition != hoverPosition;
  }

  _SignalRef? signalAt(Offset point) {
    for (final hit in _catalogSignalHits().reversed) {
      if (hit.rect.inflate(3).contains(point)) return hit.signal;
    }
    for (final hit in _controlSignalHits().reversed) {
      if (hit.rect.inflate(3).contains(point)) return hit.signal;
    }
    for (final wire in _diagramWires().reversed) {
      if (_labelRect(wire.signal.label, wire.labelPosition).contains(point) ||
          _pointNearPolyline(point, wire.points, 7)) {
        return wire.signal;
      }
    }
    return null;
  }

  void _drawBackground(Canvas canvas) {
    canvas.drawRect(
      Offset.zero & diagramSize,
      Paint()..color = Color(0xFFFFFFFF),
    );
  }

  void _drawTitle(Canvas canvas) {
    _drawText(
      canvas,
      'Cycle ${snapshot.cycle}',
      Offset(24, 20),
      fontSize: 28,
      color: Color(0xFF26347A),
      bold: true,
    );
    _drawText(
      canvas,
      '红色线/标签表示该周期相对上一周期发生变化',
      Offset(24, 58),
      fontSize: 15,
      color: Color(0xFF5F6368),
    );
  }

  Map<String, _DiagramNode> _diagramNodes() => {
        'PC': _DiagramNode(
          label: 'PC\n32b',
          rect: Rect.fromLTWH(44, 440, 58, 92),
          fill: Color(0xFFD8EED0),
          border: Color(0xFF7BA36D),
        ),
        'PC_plus': _DiagramNode(
          label: 'ADD4',
          rect: Rect.fromLTWH(145, 354, 62, 46),
          fill: Color(0xFFD8E8FF),
          border: Color(0xFF7395C8),
          moduleName: 'PC_plus',
        ),
        'Inst_Memory': _DiagramNode(
          label: 'IM',
          rect: Rect.fromLTWH(92, 958, 150, 70),
          fill: Color(0xFFE8DFF0),
          border: Color(0xFF9575A8),
          moduleName: 'Inst_Memory',
        ),
        'Seg_reg_IF_ID': _DiagramNode(
          label: 'IF/ID',
          rect: Rect.fromLTWH(330, 110, 94, 775),
          fill: Color(0xFFFFE2BC),
          border: Color(0xFFE5A23A),
          moduleName: 'Seg_reg_IF_ID',
        ),
        'Inst_Decoder': _DiagramNode(
          label: 'DECODER',
          rect: Rect.fromLTWH(500, 466, 108, 90),
          fill: Color(0xFFD8E8FF),
          border: Color(0xFF7395C8),
          moduleName: 'Inst_Decoder',
        ),
        'RegFile.read': _DiagramNode(
          label: 'GLOBAL\nREGISTER\n\n32x32b',
          rect: Rect.fromLTWH(690, 440, 128, 230),
          fill: Color(0xFFD8EED0),
          border: Color(0xFF7BA36D),
          moduleName: 'Reg_File',
        ),
        'Seg_reg_ID_EX': _DiagramNode(
          label: 'ID/EX',
          rect: Rect.fromLTWH(920, 110, 94, 775),
          fill: Color(0xFFFFE2BC),
          border: Color(0xFFE5A23A),
          moduleName: 'Seg_reg_ID_EX',
        ),
        'ALU_src_Mux.a': _DiagramNode(
          label: 'MUX\nsrc1',
          rect: Rect.fromLTWH(1120, 438, 70, 82),
          fill: Color(0xFFD8E8FF),
          border: Color(0xFF7395C8),
          moduleName: 'ALU_src1_Mux',
        ),
        'ALU_src_Mux.b': _DiagramNode(
          label: 'MUX\nsrc2',
          rect: Rect.fromLTWH(1120, 552, 70, 82),
          fill: Color(0xFFD8E8FF),
          border: Color(0xFF7395C8),
          moduleName: 'ALU_src2_Mux',
        ),
        'Branch': _DiagramNode(
          label: 'BRANCH',
          rect: Rect.fromLTWH(1086, 690, 120, 78),
          fill: Color(0xFFD8E8FF),
          border: Color(0xFF7395C8),
          moduleName: 'Branch',
        ),
        'ALU': _DiagramNode(
          label: 'ALU',
          rect: Rect.fromLTWH(1300, 500, 170, 86),
          fill: Color(0xFFD8E8FF),
          border: Color(0xFF7395C8),
          moduleName: 'ALU',
        ),
        'NPC_Mux': _DiagramNode(
          label: 'MUX\nnpc',
          rect: Rect.fromLTWH(1478, 300, 78, 168),
          fill: Color(0xFFD8E8FF),
          border: Color(0xFF7395C8),
          moduleName: 'NPC_Mux',
        ),
        'Seg_reg_EX_MEM': _DiagramNode(
          label: 'EX/MEM',
          rect: Rect.fromLTWH(1650, 110, 98, 775),
          fill: Color(0xFFFFE2BC),
          border: Color(0xFFE5A23A),
          moduleName: 'Seg_reg_EX_MEM',
        ),
        'Data_Memory': _DiagramNode(
          label: 'DM',
          rect: Rect.fromLTWH(1870, 958, 158, 70),
          fill: Color(0xFFE8DFF0),
          border: Color(0xFF9575A8),
          moduleName: 'Data_Memory',
        ),
        'Seg_reg_MEM_WB': _DiagramNode(
          label: 'MEM/WB',
          rect: Rect.fromLTWH(2205, 110, 98, 775),
          fill: Color(0xFFFFE2BC),
          border: Color(0xFFE5A23A),
          moduleName: 'Seg_reg_MEM_WB',
        ),
        'WB_Mux': _DiagramNode(
          label: 'MUX\nwb',
          rect: Rect.fromLTWH(2440, 498, 78, 184),
          fill: Color(0xFFD8E8FF),
          border: Color(0xFF7395C8),
          moduleName: 'WB_Mux',
        ),
      };

  List<_DiagramWire> _diagramWires() => [
        _DiagramWire(
          points: [Offset(102, 486), Offset(145, 486), Offset(145, 377)],
          signal: _SignalRef('pc_if', 'PC', 'pc_IF', output: true),
          labelPosition: Offset(36, 420),
        ),
        _DiagramWire(
          points: [
            Offset(102, 486),
            Offset(74, 486),
            Offset(74, 993),
            Offset(92, 993)
          ],
          signal: _SignalRef('pc_if', 'Inst_Memory', 'pc_IF'),
          labelPosition: Offset(18, 904),
        ),
        _DiagramWire(
          points: [
            Offset(207, 377),
            Offset(300, 377),
            Offset(300, 150),
            Offset(330, 150)
          ],
          signal: _SignalRef('pcadd4_if', 'PC_plus', 'pc_plus_4', output: true),
          labelPosition: Offset(228, 124),
        ),
        _DiagramWire(
          points: [
            Offset(242, 993),
            Offset(292, 993),
            Offset(292, 515),
            Offset(330, 515)
          ],
          signal: _SignalRef('inst_if', 'Inst_Memory', 'inst_opcode_IF',
              output: true),
          labelPosition: Offset(180, 486),
        ),
        _DiagramWire(
          points: [Offset(424, 515), Offset(500, 515)],
          signal: _SignalRef('inst_id', 'Seg_reg_IF_ID', 'inst_opcode_ID',
              output: true),
          labelPosition: Offset(426, 486),
        ),
        _DiagramWire(
          points: [
            Offset(424, 415),
            Offset(900, 415),
            Offset(900, 430),
            Offset(920, 430)
          ],
          signal: _SignalRef('pc_id', 'Seg_reg_IF_ID', 'pc_ID', output: true),
          labelPosition: Offset(535, 388),
        ),
        _DiagramWire(
          points: [Offset(608, 492), Offset(690, 492)],
          signal:
              _SignalRef('rf_ra0_id', 'Inst_Decoder', 'rj_ID', output: true),
          labelPosition: Offset(612, 462),
        ),
        _DiagramWire(
          points: [Offset(608, 532), Offset(690, 532)],
          signal:
              _SignalRef('rf_ra1_id', 'Inst_Decoder', 'rk_ID', output: true),
          labelPosition: Offset(612, 542),
        ),
        _DiagramWire(
          points: [Offset(818, 492), Offset(920, 492)],
          signal:
              _SignalRef('rf_rd0_id', 'Reg_File', 'rj_rdata_ID', output: true),
          labelPosition: Offset(824, 462),
        ),
        _DiagramWire(
          points: [Offset(818, 532), Offset(920, 532)],
          signal:
              _SignalRef('rf_rd1_id', 'Reg_File', 'rk_rdata_ID', output: true),
          labelPosition: Offset(824, 542),
        ),
        _DiagramWire(
          points: [Offset(608, 620), Offset(920, 620)],
          signal: _SignalRef('imm_id', 'Inst_Decoder', 'imm_ID', output: true),
          labelPosition: Offset(635, 590),
        ),
        _DiagramWire(
          points: [Offset(608, 815), Offset(920, 815)],
          signal: _SignalRef('rf_wa_id', 'Inst_Decoder', 'rd_ID', output: true),
          labelPosition: Offset(640, 786),
        ),
        _DiagramWire(
          points: [
            Offset(1014, 430),
            Offset(1100, 430),
            Offset(1100, 470),
            Offset(1120, 470)
          ],
          signal: _SignalRef('pc_ex', 'Seg_reg_ID_EX', 'pc_EX', output: true),
          labelPosition: Offset(1020, 400),
        ),
        _DiagramWire(
          points: [Offset(1014, 492), Offset(1120, 492)],
          signal: _SignalRef('rf_rd0_ex', 'Seg_reg_ID_EX', 'rj_rdata_EX',
              output: true),
          labelPosition: Offset(1020, 462),
        ),
        _DiagramWire(
          points: [
            Offset(1014, 532),
            Offset(1098, 532),
            Offset(1098, 584),
            Offset(1120, 584)
          ],
          signal: _SignalRef('rf_rd1_ex', 'Seg_reg_ID_EX', 'rk_rdata_EX',
              output: true),
          labelPosition: Offset(1020, 542),
        ),
        _DiagramWire(
          points: [
            Offset(1014, 620),
            Offset(1100, 620),
            Offset(1100, 612),
            Offset(1120, 612)
          ],
          signal: _SignalRef('imm_ex', 'Seg_reg_ID_EX', 'imm_EX', output: true),
          labelPosition: Offset(1020, 633),
        ),
        _DiagramWire(
          points: [
            Offset(1190, 480),
            Offset(1265, 480),
            Offset(1265, 526),
            Offset(1300, 526)
          ],
          signal: _SignalRef('alu_src0_ex', 'ALU_src1_Mux', 'alu_src1',
              output: true),
          labelPosition: Offset(1210, 450),
        ),
        _DiagramWire(
          points: [
            Offset(1190, 594),
            Offset(1265, 594),
            Offset(1265, 560),
            Offset(1300, 560)
          ],
          signal: _SignalRef('alu_src1_ex', 'ALU_src2_Mux', 'alu_src2',
              output: true),
          labelPosition: Offset(1210, 604),
        ),
        _DiagramWire(
          points: [
            Offset(1014, 492),
            Offset(1060, 492),
            Offset(1060, 712),
            Offset(1086, 712)
          ],
          signal: _SignalRef('rj_branch_ex', 'Seg_reg_ID_EX', 'rj_rdata_EX',
              output: true),
          labelPosition: Offset(1030, 674),
        ),
        _DiagramWire(
          points: [
            Offset(1014, 532),
            Offset(1040, 532),
            Offset(1040, 746),
            Offset(1086, 746)
          ],
          signal: _SignalRef('rk_branch_ex', 'Seg_reg_ID_EX', 'rk_rdata_EX',
              output: true),
          labelPosition: Offset(1030, 756),
        ),
        _DiagramWire(
          points: [
            Offset(1206, 720),
            Offset(1450, 720),
            Offset(1450, 405),
            Offset(1478, 405)
          ],
          signal:
              _SignalRef('npc_ex', 'Branch', 'jump_target_EX', output: true),
          labelPosition: Offset(1250, 692),
        ),
        _DiagramWire(
          points: [
            Offset(1206, 746),
            Offset(1458, 746),
            Offset(1458, 430),
            Offset(1478, 430)
          ],
          signal: _SignalRef('br_ex_EX', 'Branch', 'br_ex_EX', output: true),
          labelPosition: Offset(1250, 760),
        ),
        _DiagramWire(
          points: [Offset(1470, 543), Offset(1650, 543)],
          signal:
              _SignalRef('alu_res_ex', 'ALU', 'alu_result_EX', output: true),
          labelPosition: Offset(1490, 514),
        ),
        _DiagramWire(
          points: [Offset(1014, 815), Offset(1650, 815)],
          signal:
              _SignalRef('rf_wa_ex', 'Seg_reg_ID_EX', 'rd_EX', output: true),
          labelPosition: Offset(1135, 786),
        ),
        _DiagramWire(
          points: [
            Offset(1556, 384),
            Offset(1600, 384),
            Offset(1600, 60),
            Offset(74, 60),
            Offset(74, 440)
          ],
          signal: _SignalRef('npc', 'NPC_Mux', 'npc', output: true),
          labelPosition: Offset(480, 34),
        ),
        _DiagramWire(
          points: [Offset(1748, 543), Offset(2205, 543)],
          signal: _SignalRef('alu_res_mem', 'Seg_reg_EX_MEM', 'alu_result_MEM',
              output: true),
          labelPosition: Offset(1840, 514),
        ),
        _DiagramWire(
          points: [Offset(1748, 620), Offset(1925, 620), Offset(1925, 958)],
          signal: _SignalRef('dmem_wdata_mem', 'Data_Memory', 'mem_wdata'),
          labelPosition: Offset(1938, 700),
        ),
        _DiagramWire(
          points: [
            Offset(1748, 543),
            Offset(1840, 543),
            Offset(1840, 993),
            Offset(1870, 993)
          ],
          signal: _SignalRef('dmem_addr', 'Data_Memory', 'mem_addr'),
          labelPosition: Offset(1762, 705),
        ),
        _DiagramWire(
          points: [
            Offset(2028, 993),
            Offset(2140, 993),
            Offset(2140, 650),
            Offset(2205, 650)
          ],
          signal: _SignalRef('dmem_rd_out_mem', 'Data_Memory', 'mem_rdata',
              output: true),
          labelPosition: Offset(2055, 966),
        ),
        _DiagramWire(
          points: [Offset(1748, 815), Offset(2205, 815)],
          signal:
              _SignalRef('rf_wa_mem', 'Seg_reg_EX_MEM', 'rd_MEM', output: true),
          labelPosition: Offset(1840, 786),
        ),
        _DiagramWire(
          points: [Offset(2303, 543), Offset(2440, 543)],
          signal: _SignalRef('alu_res_wb', 'Seg_reg_MEM_WB', 'alu_result_WB',
              output: true),
          labelPosition: Offset(2328, 514),
        ),
        _DiagramWire(
          points: [Offset(2303, 650), Offset(2440, 650)],
          signal: _SignalRef(
              'dmem_rd_out_wb', 'Seg_reg_MEM_WB', 'pipe_rdata_WB',
              output: true),
          labelPosition: Offset(2328, 662),
        ),
        _DiagramWire(
          points: [Offset(2518, 590), Offset(2670, 590)],
          signal: _SignalRef('rf_wd_wb', 'WB_Mux', 'rf_wdata_WB', output: true),
          labelPosition: Offset(2535, 560),
        ),
        _DiagramWire(
          points: [
            Offset(2303, 815),
            Offset(2590, 815),
            Offset(2590, 1080),
            Offset(720, 1080),
            Offset(720, 670)
          ],
          signal:
              _SignalRef('rf_wa_wb', 'Seg_reg_MEM_WB', 'rd_WB', output: true),
          labelPosition: Offset(1430, 1054),
        ),
        _DiagramWire(
          points: [
            Offset(2518, 590),
            Offset(2625, 590),
            Offset(2625, 1115),
            Offset(750, 1115),
            Offset(750, 670)
          ],
          signal: _SignalRef('rf_wd_wb', 'WB_Mux', 'rf_wdata_WB', output: true),
          labelPosition: Offset(1430, 1128),
        ),
      ];

  void _drawNode(Canvas canvas, _DiagramNode node) {
    final rect = RRect.fromRectAndRadius(node.rect, Radius.circular(2));
    final changed = _nodeChanged(node);
    canvas.drawRRect(rect, Paint()..color = node.fill);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = changed ? Color(0xFFD32F2F) : node.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = changed ? 3 : 1.4,
    );
    _drawText(
      canvas,
      node.label,
      node.rect.center,
      fontSize: 16,
      color: Color(0xFF111111),
      bold: true,
      centered: true,
    );
  }

  void _drawWire(Canvas canvas, _DiagramWire wire) {
    final changed = _signalChanged(wire.signal);
    final color = changed ? Color(0xFFD32F2F) : Color(0xFF111111);
    final paint = Paint()
      ..color = color
      ..strokeWidth = changed ? 2.3 : 1.2
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(wire.points.first.dx, wire.points.first.dy);
    for (final point in wire.points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
    _drawArrow(
        canvas, wire.points[wire.points.length - 2], wire.points.last, color);

    final labelPoint = wire.labelPosition;
    _drawText(
      canvas,
      wire.signal.label,
      labelPoint,
      fontSize: 13,
      color: color,
      bold: changed,
      background: Color(0xDFFFFFFF),
    );
  }

  void _drawControlModules(Canvas canvas) {
    for (final spec in _controlPortModules()) {
      _drawPortModule(
        canvas,
        title: spec.title,
        moduleName: spec.moduleName,
        ports: spec.ports,
        rect: spec.rect,
        fill: spec.fill,
        border: spec.border,
      );
    }
  }

  List<_ControlPortModuleSpec> _controlPortModules() => [
        _ControlPortModuleSpec(
          title: 'HAZARD',
          moduleName: 'Hazard',
          ports: lipes_names.config.Hazard,
          rect: Rect.fromLTWH(130, 150, 170, 180),
          fill: Color(0xFFFFE6E0),
          border: Color(0xFFD56D5F),
        ),
        _ControlPortModuleSpec(
          title: 'Forwarding',
          moduleName: 'Forward',
          ports: lipes_names.config.Forward,
          rect: Rect.fromLTWH(1110, 870, 170, 250),
          fill: Color(0xFFFFE2BC),
          border: Color(0xFFE5A23A),
        ),
      ];

  void _drawPortModule(
    Canvas canvas, {
    required String title,
    required String moduleName,
    required Map<String, dynamic> ports,
    required Rect rect,
    required Color fill,
    required Color border,
  }) {
    final changed = _nodeChanged(_DiagramNode(
      label: title,
      rect: rect,
      fill: fill,
      border: border,
      moduleName: moduleName,
    ));
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(3));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = changed ? Color(0xFFD32F2F) : border
        ..style = PaintingStyle.stroke
        ..strokeWidth = changed ? 3 : 1.5,
    );
    _drawText(
      canvas,
      title,
      rect.center,
      fontSize: 15,
      color: Color(0xFF111111),
      bold: true,
      centered: true,
    );

    final inputs = (ports['input'] as List).cast<String>();
    final outputs = (ports['output'] as List).cast<String>();
    _drawPortList(
      canvas,
      moduleName: moduleName,
      ports: inputs,
      rect: rect,
      output: false,
    );
    _drawPortList(
      canvas,
      moduleName: moduleName,
      ports: outputs,
      rect: rect,
      output: true,
    );
  }

  void _drawPortList(
    Canvas canvas, {
    required String moduleName,
    required List<String> ports,
    required Rect rect,
    required bool output,
  }) {
    if (ports.isEmpty) return;
    final gap = rect.height / (ports.length + 1);
    for (var i = 0; i < ports.length; i++) {
      final port = ports[i];
      final y = rect.top + gap * (i + 1);
      final signal = _SignalRef(port, moduleName, port, output: output);
      final changed = _signalChanged(signal);
      final color = changed ? Color(0xFFD32F2F) : Color(0xFF111111);
      final start = output ? Offset(rect.right, y) : Offset(rect.left - 26, y);
      final end = output ? Offset(rect.right + 32, y) : Offset(rect.left, y);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = color
          ..strokeWidth = changed ? 2.1 : 1.2,
      );
      _drawArrow(canvas, start, end, color);

      _drawText(
        canvas,
        port,
        output
            ? Offset(rect.right + 36, y - 10)
            : Offset(rect.left - _portLabelWidth(port) - 32, y - 10),
        fontSize: 13,
        color: color,
        bold: changed,
        background: Color(0xEFFFFFFF),
      );
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const length = 9.0;
    const spread = 0.48;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - length * math.cos(angle - spread),
        to.dy - length * math.sin(angle - spread),
      )
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - length * math.cos(angle + spread),
        to.dy - length * math.sin(angle + spread),
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawLegend(Canvas canvas) {
    final y = 1125.0;
    canvas.drawLine(
      Offset(24, y),
      Offset(90, y),
      Paint()
        ..color = Color(0xFFD32F2F)
        ..strokeWidth = 2.3,
    );
    _drawText(canvas, 'changed this cycle', Offset(102, y - 8),
        fontSize: 13, color: Color(0xFFD32F2F), bold: true);
    canvas.drawLine(
      Offset(330, y),
      Offset(396, y),
      Paint()
        ..color = Color(0xFF111111)
        ..strokeWidth = 1.2,
    );
    _drawText(canvas, 'unchanged', Offset(408, y - 8),
        fontSize: 13, color: Color(0xFF111111));
  }

  void _drawModuleIoCatalog(Canvas canvas) {
    final specs = _configuredModuleSpecs();
    final colHeights = List<double>.filled(4, 0);
    const baseY = 1190.0;
    const colWidth = 650.0;
    const left = 40.0;
    _drawText(
      canvas,
      'Module I/O pins from names.dart',
      Offset(left, 1145),
      fontSize: 22,
      color: Color(0xFF26347A),
      bold: true,
    );
    _drawText(
      canvas,
      '每个模块的 input/output 都按 names.dart 完整列出',
      Offset(left, 1172),
      fontSize: 14,
      color: Color(0xFF5F6368),
    );

    for (final spec in specs) {
      final inputCount = (spec.ports['input'] as List).length;
      final outputCount = (spec.ports['output'] as List).length;
      final height =
          math.max(112.0, math.max(inputCount, outputCount) * 17.0 + 54);
      var col = 0;
      for (var i = 1; i < colHeights.length; i++) {
        if (colHeights[i] < colHeights[col]) col = i;
      }
      final rect = Rect.fromLTWH(
        left + col * colWidth,
        baseY + colHeights[col],
        colWidth - 28,
        height,
      );
      colHeights[col] += height + 22;
      _drawCatalogModule(canvas, spec, rect);
    }
  }

  List<_SignalHit> _controlSignalHits() {
    final hits = <_SignalHit>[];
    for (final spec in _controlPortModules()) {
      final inputs = (spec.ports['input'] as List).cast<String>();
      final outputs = (spec.ports['output'] as List).cast<String>();
      hits.addAll(_portListHits(
        moduleName: spec.moduleName,
        ports: inputs,
        rect: spec.rect,
        output: false,
      ));
      hits.addAll(_portListHits(
        moduleName: spec.moduleName,
        ports: outputs,
        rect: spec.rect,
        output: true,
      ));
    }
    return hits;
  }

  List<_SignalHit> _portListHits({
    required String moduleName,
    required List<String> ports,
    required Rect rect,
    required bool output,
  }) {
    if (ports.isEmpty) return const [];
    final gap = rect.height / (ports.length + 1);
    return [
      for (var i = 0; i < ports.length; i++)
        _SignalHit(
          signal: _SignalRef(
            ports[i],
            moduleName,
            ports[i],
            output: output,
          ),
          rect: _labelRect(
            ports[i],
            output
                ? Offset(rect.right + 36, rect.top + gap * (i + 1) - 10)
                : Offset(rect.left - _portLabelWidth(ports[i]) - 32,
                    rect.top + gap * (i + 1) - 10),
          ),
        ),
    ];
  }

  List<_ModulePortSpec> _configuredModuleSpecs() => [
        _ModulePortSpec('PC_plus', lipes_names.config.PC_plus),
        _ModulePortSpec('NPC_Mux', lipes_names.config.NPC_Mux),
        _ModulePortSpec('PC', lipes_names.config.PC),
        _ModulePortSpec('Seg_reg_IF_ID', lipes_names.config.Seg_reg_IF_ID),
        _ModulePortSpec('Inst_Decoder', lipes_names.config.Inst_Decoder),
        _ModulePortSpec('Reg_File', lipes_names.config.Reg_File),
        _ModulePortSpec('Seg_reg_ID_EX', lipes_names.config.Seg_reg_ID_EX),
        _ModulePortSpec('FWD_rj', lipes_names.config.FWD_rj),
        _ModulePortSpec('FWD_rk', lipes_names.config.FWD_rk),
        _ModulePortSpec('ALU_src1_Mux', lipes_names.config.ALU_src1_Mux),
        _ModulePortSpec('ALU_src2_Mux', lipes_names.config.ALU_src2_Mux),
        _ModulePortSpec('Branch', lipes_names.config.Branch),
        _ModulePortSpec('ALU', lipes_names.config.ALU),
        _ModulePortSpec('Seg_reg_EX_MEM', lipes_names.config.Seg_reg_EX_MEM),
        _ModulePortSpec('Memory_Control', lipes_names.config.Memory_Control),
        _ModulePortSpec('Seg_reg_MEM_WB', lipes_names.config.Seg_reg_MEM_WB),
        _ModulePortSpec('WB_Mux', lipes_names.config.WB_Mux),
        _ModulePortSpec('Hazard', lipes_names.config.Hazard),
        _ModulePortSpec('Forward', lipes_names.config.Forward),
        _ModulePortSpec('Inst_Memory', lipes_names.config.Inst_Memory),
        _ModulePortSpec('Data_Memory', lipes_names.config.Data_Memory),
      ];

  List<_SignalHit> _catalogSignalHits() {
    final hits = <_SignalHit>[];
    for (final entry in _catalogModuleRects().entries) {
      final spec = entry.key;
      final rect = entry.value;
      hits.addAll(_catalogPortHits(
        spec.name,
        (spec.ports['input'] as List).cast<String>(),
        Rect.fromLTWH(rect.left + 14, rect.top + 58, rect.width / 2 - 24,
            rect.height - 66),
        output: false,
      ));
      hits.addAll(_catalogPortHits(
        spec.name,
        (spec.ports['output'] as List).cast<String>(),
        Rect.fromLTWH(rect.left + rect.width / 2 + 12, rect.top + 58,
            rect.width / 2 - 26, rect.height - 66),
        output: true,
      ));
    }
    return hits;
  }

  Map<_ModulePortSpec, Rect> _catalogModuleRects() {
    final rects = <_ModulePortSpec, Rect>{};
    final colHeights = List<double>.filled(4, 0);
    const baseY = 1190.0;
    const colWidth = 650.0;
    const left = 40.0;
    for (final spec in _configuredModuleSpecs()) {
      final inputCount = (spec.ports['input'] as List).length;
      final outputCount = (spec.ports['output'] as List).length;
      final height =
          math.max(112.0, math.max(inputCount, outputCount) * 17.0 + 54);
      var col = 0;
      for (var i = 1; i < colHeights.length; i++) {
        if (colHeights[i] < colHeights[col]) col = i;
      }
      final rect = Rect.fromLTWH(
        left + col * colWidth,
        baseY + colHeights[col],
        colWidth - 28,
        height,
      );
      colHeights[col] += height + 22;
      rects[spec] = rect;
    }
    return rects;
  }

  List<_SignalHit> _catalogPortHits(
    String moduleName,
    List<String> ports,
    Rect rect, {
    required bool output,
  }) {
    return [
      for (var i = 0; i < ports.length; i++)
        _SignalHit(
          signal: _SignalRef(
            ports[i],
            moduleName,
            ports[i],
            output: output,
          ),
          rect: _labelRect(ports[i], Offset(rect.left, rect.top + i * 17)),
        ),
    ];
  }

  void _drawCatalogModule(Canvas canvas, _ModulePortSpec spec, Rect rect) {
    final changed = _catalogModuleChanged(spec.name);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(7));
    canvas.drawRRect(rrect, Paint()..color = Color(0xFFF8F9FE));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = changed ? Color(0xFFD32F2F) : Color(0xFFDDE3F5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = changed ? 2.4 : 1.2,
    );
    _drawText(
      canvas,
      spec.name,
      Offset(rect.left + 14, rect.top + 12),
      fontSize: 15,
      color: Color(0xFF26347A),
      bold: true,
    );
    _drawText(
      canvas,
      'input',
      Offset(rect.left + 14, rect.top + 38),
      fontSize: 11,
      color: Color(0xFF5F6368),
      bold: true,
    );
    _drawText(
      canvas,
      'output',
      Offset(rect.left + rect.width / 2 + 12, rect.top + 38),
      fontSize: 11,
      color: Color(0xFF5F6368),
      bold: true,
    );
    _drawCatalogPorts(
      canvas,
      spec.name,
      (spec.ports['input'] as List).cast<String>(),
      Rect.fromLTWH(
          rect.left + 14, rect.top + 58, rect.width / 2 - 24, rect.height - 66),
      output: false,
    );
    _drawCatalogPorts(
      canvas,
      spec.name,
      (spec.ports['output'] as List).cast<String>(),
      Rect.fromLTWH(rect.left + rect.width / 2 + 12, rect.top + 58,
          rect.width / 2 - 26, rect.height - 66),
      output: true,
    );
  }

  void _drawCatalogPorts(
    Canvas canvas,
    String moduleName,
    List<String> ports,
    Rect rect, {
    required bool output,
  }) {
    for (var i = 0; i < ports.length; i++) {
      final port = ports[i];
      final signal = _SignalRef(port, moduleName, port, output: output);
      final changed = _signalChanged(signal);
      final color = changed ? Color(0xFFD32F2F) : Color(0xFF111111);
      _drawText(
        canvas,
        port,
        Offset(rect.left, rect.top + i * 17),
        fontSize: 11,
        color: color,
        bold: changed,
      );
    }
  }

  bool _catalogModuleChanged(String moduleName) {
    final io = snapshot.modules[moduleName];
    if (io == null || previousSnapshot == null) return false;
    for (final port in io.inputs.keys) {
      if (_signalChanged(_SignalRef(port, moduleName, port))) return true;
    }
    for (final port in io.outputs.keys) {
      if (_signalChanged(_SignalRef(port, moduleName, port, output: true))) {
        return true;
      }
    }
    return false;
  }

  bool _nodeChanged(_DiagramNode node) {
    final io = snapshot.modules[node.moduleName];
    if (io == null || previousSnapshot == null) return false;
    for (final signal in io.inputs.keys) {
      if (_signalChanged(_SignalRef(signal, node.moduleName, signal))) {
        return true;
      }
    }
    for (final signal in io.outputs.keys) {
      if (_signalChanged(
          _SignalRef(signal, node.moduleName, signal, output: true))) {
        return true;
      }
    }
    return false;
  }

  bool _signalChanged(_SignalRef signal) {
    if (previousSnapshot == null) return false;
    final current = _readSignal(snapshot, signal);
    final previous = _readSignal(previousSnapshot!, signal);
    return current != null && previous != null && current != previous;
  }

  int? _readSignal(SimplePipelineSnapshot source, _SignalRef signal) {
    final module = source.modules[signal.moduleName];
    if (module == null) return source.wires[signal.portName];
    final ports = signal.output ? module.outputs : module.inputs;
    return ports[signal.portName] ??
        module.outputs[signal.portName] ??
        module.inputs[signal.portName] ??
        source.wires[signal.portName];
  }

  void _drawHoverTooltip(Canvas canvas) {
    final signal = hoveredSignal;
    final point = hoverPosition;
    if (signal == null || point == null) return;
    final value = _readSignal(snapshot, signal);
    if (value == null) return;
    final changed = _signalChanged(signal);
    final text =
        '${signal.moduleName}.${signal.portName}\n${_formatLipesValue(value)}';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: changed ? Color(0xFFD32F2F) : Color(0xFF111111),
          fontSize: 14,
          height: 1.25,
          fontFamily: 'FiraCode',
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 260);
    var topLeft = point + Offset(18, 18);
    if (topLeft.dx + painter.width + 24 > diagramSize.width) {
      topLeft = Offset(point.dx - painter.width - 42, topLeft.dy);
    }
    if (topLeft.dy + painter.height + 22 > diagramSize.height) {
      topLeft = Offset(topLeft.dx, point.dy - painter.height - 36);
    }
    final rect = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      painter.width + 24,
      painter.height + 18,
    );
    canvas.drawShadow(
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(8))),
      Colors.black.withAlpha(80),
      4,
      false,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(8)),
      Paint()..color = Color(0xFFFFFFFF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(8)),
      Paint()
        ..color = changed ? Color(0xFFD32F2F) : Color(0xFFDDE3F5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    painter.paint(canvas, topLeft + Offset(12, 9));
  }

  Rect _labelRect(String text, Offset offset) {
    return Rect.fromLTWH(
      offset.dx - 4,
      offset.dy - 3,
      _portLabelWidth(text) + 8,
      20,
    );
  }

  double _portLabelWidth(String text) {
    return math.max(42, text.length * 8.2);
  }

  bool _pointNearPolyline(Offset point, List<Offset> points, double tolerance) {
    for (var i = 1; i < points.length; i++) {
      if (_distanceToSegment(point, points[i - 1], points[i]) <= tolerance) {
        return true;
      }
    }
    return false;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (length2 == 0) return (p - a).distance;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / length2).clamp(0.0, 1.0);
    final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - projection).distance;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    double fontSize = 12,
    Color color = Colors.black,
    bool bold = false,
    bool centered = false,
    Color? background,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          height: 1.12,
          fontFamily: 'FiraCode',
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: centered ? TextAlign.center : TextAlign.left,
    )..layout(maxWidth: 190);
    final topLeft = centered
        ? offset - Offset(painter.width / 2, painter.height / 2)
        : offset;
    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            topLeft.dx - 3,
            topLeft.dy - 2,
            painter.width + 6,
            painter.height + 4,
          ),
          Radius.circular(3),
        ),
        Paint()..color = background,
      );
    }
    painter.paint(canvas, topLeft);
  }
}

class _DiagramNode {
  final String label;
  final Rect rect;
  final Color fill;
  final Color border;
  final String moduleName;

  _DiagramNode({
    required this.label,
    required this.rect,
    required this.fill,
    required this.border,
    String? moduleName,
  }) : moduleName = moduleName ?? label.split('\n').first;
}

class _DiagramWire {
  final List<Offset> points;
  final _SignalRef signal;
  final Offset labelPosition;

  _DiagramWire({
    required this.points,
    required this.signal,
    required this.labelPosition,
  });
}

class _SignalRef {
  final String label;
  final String moduleName;
  final String portName;
  final bool output;

  _SignalRef(
    this.label,
    this.moduleName,
    this.portName, {
    this.output = false,
  });

  @override
  bool operator ==(Object other) {
    return other is _SignalRef &&
        other.label == label &&
        other.moduleName == moduleName &&
        other.portName == portName &&
        other.output == output;
  }

  @override
  int get hashCode => Object.hash(label, moduleName, portName, output);
}

class _SignalHit {
  final _SignalRef signal;
  final Rect rect;

  _SignalHit({
    required this.signal,
    required this.rect,
  });
}

class _ControlPortModuleSpec {
  final String title;
  final String moduleName;
  final Map<String, dynamic> ports;
  final Rect rect;
  final Color fill;
  final Color border;

  _ControlPortModuleSpec({
    required this.title,
    required this.moduleName,
    required this.ports,
    required this.rect,
    required this.fill,
    required this.border,
  });
}

class _ModulePortSpec {
  final String name;
  final Map<String, dynamic> ports;

  _ModulePortSpec(this.name, this.ports);
}

String _formatLipesValue(int value) {
  final unsigned = value & 0xffffffff;
  return '0x${unsigned.toRadixString(16).padLeft(8, '0')}';
}

/// Main workspace widget that contains the code editor and simulator interface
class MyTextPaginatingWidget extends StatefulWidget {
  @override
  _MyTextPaginatingWidgetState createState() => _MyTextPaginatingWidgetState();
}

/// State class for the main workspace widget that manages:
/// - Code editing and compilation
/// - Simulation control
/// - Memory and register state
/// - Debug features
class _MyTextPaginatingWidgetState extends State<MyTextPaginatingWidget> {
  Lipes lipes = Lipes();

  /// Controllers for memory text and data input
  TextEditingController memtext_ctrl = TextEditingController(),
      memdata_ctrl = TextEditingController(),
      machineCodeInputCtrl = TextEditingController();
  List<String> textLines = [];
  Assembler asm = Assembler([]);
  Simulator sim = Simulator();
  // DumpCode dp = DumpCode();
  int mem_search = 0x1c000000;
  int mem_waddr = 0x1c000000;
  final ScrollController _scrollController = ScrollController();
  List<String> Warnings = [];
  List<Uint32> reg = List.filled(32, Uint32.zero);
  List<bool> reg_change = List.filled(32, false);
  Set<Uint32> breakpoints = {};
  bool is_dumped = false;
  bool need_dump = false;

  /// Code editor controller with syntax highlighting configuration
  TextFieldController _controller = TextFieldController(
    patternMatchMap: {
      RegExp(opString): TextStyle(color: Color.fromARGB(255, 5, 107, 245)),
      RegExp(regString): TextStyle(color: Color.fromARGB(255, 239, 157, 5)),
      RegExp(signString): TextStyle(color: Color.fromARGB(255, 65, 155, 87)),
    },
    onMatch: (List<String> matches) {},
    deleteOnBack: false,
    // You can control the [RegExp] options used:
    regExpUnicode: true,
  );

  @override
  void initState() {
    super.initState();
    // lipes.addModule((context) => clk(context));
    // lipes.checkclk();
  }

  /// Builds the code editor with syntax highlighting and line numbers
  Widget _buildCodeText(double height) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      margin: EdgeInsets.symmetric(vertical: height / 120),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.code, size: 18, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  '代码编辑器',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Actions(
              actions: {InsertTabIntent: InsertTabAction()},
              child: Shortcuts(
                shortcuts: {
                  LogicalKeySet(LogicalKeyboardKey.tab):
                      InsertTabIntent(4, _controller),
                },
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  enableInteractiveSelection: true,
                  selectionControls: MaterialTextSelectionControls(),
                  style: TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 14,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '请输入LA32R汇编代码',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  onChanged: ((value) {
                    is_dumped = false;
                  }),
                  mouseCursor: SystemMouseCursors.text,
                  showCursor: true,
                  cursorWidth: 2.0,
                  cursorRadius: Radius.circular(1),
                  selectionHeightStyle: ui.BoxHeightStyle.max,
                  selectionWidthStyle: ui.BoxWidthStyle.tight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Displays current PC value and execution state
  Widget _buildPCStateInfo(double width) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.amber[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PC',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber[900],
              fontSize: 15,
            ),
          ),
          SizedBox(height: 2),
          Text(
            '0x${sim.pc.toInt().toRadixString(16)}',
            style: TextStyle(
              fontFamily: 'FiraCode',
              color: Colors.amber[900],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows current instruction at PC
  Widget _buildInstStateInfo(double width) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Inst',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
              fontSize: 15,
            ),
          ),
          SizedBox(height: 2),
          Text(
            '${asm.inst_rec[sim.pc] == null ? 'NOP' : asm.inst_rec[sim.pc]!.sentence}',
            style: TextStyle(
              fontFamily: 'FiraCode',
              color: Colors.blue[800],
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Displays register values in a grid layout
  Widget _buildRegStateInfo(double width, double height) {
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.all(8),
      children: [
        for (int i = 0; i < 8; i++)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                for (int j = 0; j < 4; j++)
                  Expanded(
                    child: Card(
                      elevation: 2,
                      color: reg_change[4 * i + j]
                          ? Colors.red[100]
                          : Colors.amber[50],
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'R${4 * i + j}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  if (register_name[4 * i + j].isNotEmpty)
                                    TextSpan(
                                      text: ' / ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  if (register_name[4 * i + j].isNotEmpty)
                                    TextSpan(
                                      text: register_name[4 * i + j],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '0x${sim.reg[4 * i + j].toInt().toRadixString(16)}',
                              style: TextStyle(
                                fontFamily: 'FiraCode',
                                fontSize: 11,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Shows processor state including PC, current instruction and registers
  Widget _buildProcessorStateInfo(double width, height) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          margin: EdgeInsets.only(top: height / 120, bottom: height / 120),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _buildPCStateInfo(width),
              ),
              Expanded(
                flex: 2,
                child: _buildInstStateInfo(width),
              ),
            ],
          ),
        ),
        // reg info
        Expanded(
          flex: 16,
          child: Container(
            child: _buildRegStateInfo(width, height),
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(top: height / 240),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExceptionDialog(double width) {
    return UnconstrainedBox(
      constrainedAxis: Axis.vertical,
      child: Container(
          width: width * 20 / 60,
          child: Column(
            children: [
              AlertDialog(
                title: Text('Error'),
                content: Column(
                  children: Warnings.map((e) => Text(e)).toList(),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('OK'),
                  )
                ],
              ),
            ],
          )),
    );
  }

  /// 构建内存表格的表头行
  TableRow _buildMemoryTableHeader() {
    return TableRow(
      decoration: BoxDecoration(
        color: Colors.indigo[100],
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      children: [
        _buildHeaderCell('Memory'),
        for (int i = 0; i < 16; i += 4)
          _buildHeaderCell('+${i.toRadixString(16)}'),
      ],
    );
  }

  /// 构建表头单元格
  TableCell _buildHeaderCell(String text) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.indigo[900],
          ),
        ),
      ),
    );
  }

  /// 构建内存数据行
  TableRow _buildMemoryRow(int rowIndex, double height) {
    return TableRow(
      decoration: BoxDecoration(
        color: (rowIndex % 2 == 0) ? Colors.grey[50] : Colors.grey[100],
      ),
      children: [
        _buildAddressCell(rowIndex),
        for (int j = 0; j < 16; j += 4) _buildDataCell(rowIndex, j),
      ],
    );
  }

  /// 构建地址单元格
  TableCell _buildAddressCell(int rowIndex) {
    return TableCell(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.indigo[50],
          border: Border(
            right: BorderSide(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Text(
          '0x${(mem_search + rowIndex * 16).toRadixString(16).padLeft(8, '0')}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontWeight: FontWeight.w600,
            color: Colors.indigo[900],
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  /// 构建数据单元格
  TableCell _buildDataCell(int rowIndex, int columnOffset) {
    int address = mem_search + rowIndex * 16 + columnOffset;
    bool isBreakpoint = breakpoints.contains(Uint32(address));
    bool isCurrentPC = sim.pc == Uint32(address);

    return TableCell(
      child: Container(
        color: isCurrentPC ? Colors.amber[100] : Colors.transparent,
        child: _buildMemoryButton(address, isBreakpoint),
      ),
    );
  }

  /// 构建内存按钮
  Widget _buildMemoryButton(int address, bool isBreakpoint) {
    return Tooltip(
      message: _getInstructionTooltip(address),
      waitDuration: Duration(milliseconds: 50),
      child: TextButton(
        onPressed: () => _toggleBreakpoint(address),
        child: _buildMemoryButtonText(address),
        style: _getMemoryButtonStyle(isBreakpoint),
      ),
    );
  }

  /// 获取指令提示文本
  String _getInstructionTooltip(int address) {
    var inst = asm.inst_rec[Uint32(address)];
    return inst != null ? inst.sentence : '';
  }

  /// 切换断点状态
  void _toggleBreakpoint(int address) {
    setState(() {
      var breakpoint = Uint32(address);
      if (breakpoints.contains(breakpoint)) {
        breakpoints.remove(breakpoint);
      } else {
        breakpoints.add(breakpoint);
      }
    });
  }

  /// 构建内存按钮文本
  Widget _buildMemoryButtonText(int address) {
    return Text(
      '0x${memory[Uint32(address)].toInt().toRadixString(16).padLeft(8, '0')}',
      style: TextStyle(
        fontFamily: 'FiraCode',
        fontSize: 13,
        color: Colors.grey[900],
      ),
    );
  }

  /// 获取内存按钮样式
  ButtonStyle _getMemoryButtonStyle(bool isBreakpoint) {
    return ButtonStyle(
      padding: WidgetStateProperty.all(EdgeInsets.symmetric(vertical: 8)),
      backgroundColor: WidgetStateProperty.all(
        isBreakpoint ? Colors.red[100] : Colors.transparent,
      ),
      overlayColor: WidgetStateProperty.all(Colors.grey[200]),
      minimumSize: WidgetStateProperty.all(Size.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// 构建内存表格
  Widget _buildMemoryTable(double width, double height) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      margin: EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        child: Table(
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey[300]!),
            verticalInside: BorderSide(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            _buildMemoryTableHeader(),
            for (int i = 0; i < height ~/ 80; i++) _buildMemoryRow(i, height),
          ],
        ),
      ),
    );
  }

  /// Builds memory input field with validation
  Widget _buildMemoryInput(
    double width,
    double height, {
    required String hintText,
    required TextEditingController controller,
    required Function(String) onSubmitted,
  }) {
    return Container(
      width: width / 8,
      height: height / 25,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }

  /// Creates memory address check button
  Widget _buildMemoryCheckButton(double width, double height) {
    return Container(
      alignment: Alignment.center,
      child: IconButton(
        onPressed: () {
          try {
            mem_search = int.parse(memtext_ctrl.text, radix: 16);
          } catch (e) {
            mem_search = 0x1c000000;
          }
          if (mem_search < 0x1c000000 || mem_search > 0x24000000)
            mem_search = 0x1c000000;
          mem_search = mem_search & 0xfffffff0;
          setState(() {});
        },
        style: ButtonStyle(
          elevation: WidgetStateProperty.all(2),
        ),
        // child: Text('查看内存'),
        icon: Icon(Icons.search),
        iconSize: height / 30,
        tooltip: '查看内存',
      ),
      // width: width / 10
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? iconColor,
  }) {
    iconColor ??= Colors.indigo[700];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Tooltip(
        message: tooltip,
        waitDuration: Duration(milliseconds: 500),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(100),
            border: Border.all(
              color: Colors.indigo.withAlpha(50),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(9),
              hoverColor: Colors.indigo.withAlpha(30),
              splashColor: Colors.indigo.withAlpha(50),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds compile button with error handling
  Widget _buildCompileButton(double width) {
    return _buildToolbarButton(
        icon: Icons.build,
        tooltip: '编译',
        onPressed: () async {
          String text = _controller.text + '\n';
          textLines = text.split('\n');
          memory = Memory();
          memory.write(Uint32(0x23fffffc), Uint32(1));
          Warnings = [];
          reg = List.filled(32, Uint32.zero);
          reg_change = List.filled(32, false);
          try {
            asm = Assembler(textLines);
            if (need_dump)
              downloadTxtFile('your_input.asm', textLines.join('\n'));
            is_dumped = true;
          } on SentenceException catch (e) {
            Warnings.add(e.toString());
          } on MemoryException catch (e) {
            Warnings.add(e.type.toString());
          }

          // if has warnings, show a dialog
          if (Warnings.isNotEmpty) {
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return _buildExceptionDialog(width);
                });
          }
          _scrollController.jumpTo(0);
          setState(() {});

          // Save the text to a file
          try {
            if (Platform.isWindows) {
              final directory = await getApplicationDocumentsDirectory();
              print(directory.path);
              final file = File('${directory.path}/input.txt');
              await file.writeAsString(text);
            }
          } catch (e) {
            print(e);
          }
          sim.reset();
        });
  }

  /// Creates run simulation button
  Widget _buildRunButton(double width) {
    return _buildSimulatorButton(
      icon: Icons.play_arrow,
      tooltip: '运行',
      action: () => sim.run(breakpoints),
    );
  }

  /// Creates single step execution button
  Widget _buildSingleStepButton(double width) {
    return _buildSimulatorButton(
      icon: Icons.arrow_forward,
      tooltip: '单步执行',
      action: () => sim.cycle(),
    );
  }

  /// Creates step back button for debugging
  Widget _buildStepBackButton(double width) {
    return _buildSimulatorButton(
      icon: Icons.arrow_back,
      tooltip: '单步回退',
      action: () => sim.step_back(),
    );
  }

  /// Creates buttons for exporting code and data
  Widget _buildDumpTextButton(double width) {
    return _buildExportButton(
      icon: Icons.file_download,
      tooltip: '导出代码(coe)',
      fileName: 'text.coe',
      exportFunction: () => memory.DumpInstCoe(),
    );
  }

  /// Creates buttons for exporting code and data
  Widget _buildDumpPDUTextButton(double width) {
    return _buildExportButton(
      icon: Icons.file_download,
      tooltip: '导出代码(sim)',
      fileName: 'text_PDU.coe',
      exportFunction: () => memory.DumpInstPdu(),
      isPDU: true,
    );
  }

  /// Creates buttons for exporting code and data
  Widget _buildDumpDataButton(double width) {
    return _buildExportButton(
      icon: Icons.vertical_align_bottom,
      tooltip: '导出数据(coe)',
      fileName: 'data.coe',
      exportFunction: () => memory.DumpDataCoe(),
    );
  }

  /// Creates buttons for exporting code and data
  Widget _buildDumpPDUDataButton(double width) {
    return _buildExportButton(
      icon: Icons.vertical_align_bottom,
      tooltip: '导出数据(sim)',
      fileName: 'data_PDU.coe',
      exportFunction: () => memory.DumpDataPdu(),
      isPDU: true,
    );
  }

  /// Creates buttons for exporting code and data
  Widget _buildlogButton(double width) {
    return _buildToolbarButton(
      icon: Icons.edit_note_rounded,
      tooltip: '查看log',
      onPressed: () {
        downloadTxtFile('log.txt', sim.log.print(asm.inst_rec));
      },
    );
  }

  /// Creates buttons for exporting code and data
  Widget _buildHW2_4Button(double width) {
    return _buildToolbarButton(
      icon: Icons.quiz_rounded,
      tooltip: 'HW2_4',
      onPressed: () {
        textLines = [
          '.text',
          '_start:',
          '#load the program & call main function ',
          '# TODO1:',
          'halt',
          'main:',
          '# prologue 栈式分配内存 注意16字节地址对齐',
          '# TODO2:',
          'main_label_entry:',
          'beq \$a0, \$zero, fail',
          'addi.w \$t0, \$fp, -20',
          'st.w \$t0, \$fp, -12',
          'ld.w \$t0, \$fp, -12',
          'addi.w \$t1, \$zero, 1',
          'st.w \$t1, \$t0, 0',
          'ld.w \$t0, \$fp, -12',
          'ld.w \$t1, \$t0, 0',
          'slli.w \$t1, \$t1, 31',
          'srai.w \$t1, \$t1, 31',
          'st.w \$t1, \$t0, 0',
          'lu12i.w \$t1, 0x80000',
          'srli.w \$t1, \$t1, 31',
          'st.w \$t1, \$t0, 4',
          'ld.w \$t1, \$t0, 0',
          'ld.w \$t2, \$t0, 4',
          'beq \$t1, \$t2, fail',
          'b main_exit',
          'main_exit:',
          '# epilogue 回收内存 并返回(_start)',
          '# TODO2:',
          'fail:',
          'add.w \$fp \$zero \$zero',
          'sub.w \$sp \$zero \$fp',
          'and \$ra, \$zero, \$ra',
          'halt',
        ];
        setState(() {});
        _controller.text = textLines.join('\n');
      },
    );
  }

  /// Toggles auto-export functionality
  Widget _buildneeddumpButton(double width) {
    return _buildToolbarButton(
      icon: need_dump ? Icons.raw_on : Icons.raw_off,
      tooltip: '打开/关闭编译后自动导出',
      onPressed: () {
        is_dumped = need_dump;
        need_dump = !need_dump;
        setState(() {});
      },
    );
  }

  /// 更新寄存器状态
  void _updateRegisterState() {
    for (int i = 0; i < 32; i++) {
      reg[i] = sim.reg[i];
    }
  }

  /// 检查寄存器变化
  void _checkRegisterChanges() {
    for (int i = 0; i < 32; i++) {
      reg_change[i] = (reg[i] != sim.reg[i]);
    }
  }

  /// 通用模拟器按钮构建器
  Widget _buildSimulatorButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback action,
  }) {
    return _buildToolbarButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: () {
        _updateRegisterState();
        action();
        _checkRegisterChanges();
        setState(() {});
      },
    );
  }

  /// 通用导出按钮构建器
  Widget _buildExportButton({
    required IconData icon,
    required String tooltip,
    required String fileName,
    required String Function() exportFunction,
    bool isPDU = false,
  }) {
    return _buildToolbarButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: () => downloadTxtFile(fileName, exportFunction()),
      iconColor: isPDU ? Colors.amber[700] : null,
    );
  }

  /// 通用内存输入框构建器
  Widget _buildMemoryInputField({
    required String hintText,
    required TextEditingController controller,
    required Function(String) onSubmit,
    required double width,
    required double height,
  }) {
    return _buildMemoryInput(
      width,
      height,
      hintText: hintText,
      controller: controller,
      onSubmitted: onSubmit,
    );
  }

  /// 构建解析机器码按钮
  Widget _buildMachineCodeButton(double width) {
    return _buildToolbarButton(
      icon: Icons.memory,
      tooltip: '解析机器码',
      onPressed: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('解析LA机器码'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: machineCodeInputCtrl,
                    decoration: InputDecoration(
                      hintText: '输入十六进制机器码（最多8位）',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 8,
                    onChanged: (value) {
                      // 限制只能输入十六进制字符
                      if (value.isNotEmpty &&
                          !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
                        machineCodeInputCtrl.text =
                            value.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    String hexCode = machineCodeInputCtrl.text;
                    if (hexCode.isEmpty) {
                      return;
                    }

                    try {
                      // 解析十六进制为整数
                      int intValue = int.parse(hexCode, radix: 16);
                      Uint32 machineCode = Uint32_t(intValue);

                      // 获取指令类型
                      Ins_type type = get_inst_type(machineCode);

                      // 解析指令内容
                      String instruction = "未能解析的指令";

                      // 解析寄存器和立即数
                      int rd = machineCode.bitRange(4, 0).toInt();
                      int rj = machineCode.bitRange(9, 5).toInt();
                      int rk = machineCode.bitRange(14, 10).toInt();

                      // 根据指令类型格式化指令文本
                      switch (type) {
                        case Ins_type.ADDW:
                          instruction = "ADD.W \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.SUBW:
                          instruction = "SUB.W \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.SLT:
                          instruction = "SLT \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.SLTU:
                          instruction = "SLTU \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.NOR:
                          instruction = "NOR \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.AND:
                          instruction = "AND \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.OR:
                          instruction = "OR \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.XOR:
                          instruction = "XOR \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.SLLW:
                          instruction = "SLL.W \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.SRLW:
                          instruction = "SRL.W \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.SRAW:
                          instruction = "SRA.W \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.MULW:
                          instruction = "MUL.W \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.MULHW:
                          instruction = "MULH.W \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.MULHWU:
                          instruction = "MULHU.W \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.DIVW:
                          instruction = "DIV.W \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.MODW:
                          instruction = "MOD.W \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.DIVWU:
                          instruction = "DIVU.W \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.MODWU:
                          instruction = "MODU.W \$r$rd, \$r$rj, \$r$rk";
                          break;
                        case Ins_type.SLLIW:
                          int imm = machineCode.bitRange(14, 10).toInt();
                          instruction = "SLLI.W \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.SRLIW:
                          int imm = machineCode.bitRange(14, 10).toInt();
                          instruction = "SRLI.W \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.SRAIW:
                          int imm = machineCode.bitRange(14, 10).toInt();
                          instruction = "SRAI.W \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.SLTI:
                          int imm = machineCode.bitRange(21, 10).toSignedInt();
                          instruction = "SLTI \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.SLTUI:
                          int imm = machineCode.bitRange(21, 10).toSignedInt();
                          instruction = "SLTUI \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.ADDIW:
                          int imm = machineCode.bitRange(21, 10).toSignedInt();
                          instruction = "ADDI.W \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.ANDI:
                          int imm = machineCode.bitRange(21, 10).toInt();
                          instruction =
                              "ANDI \$r$rd, \$r$rj, 0x${imm.toRadixString(16)}";
                          break;
                        case Ins_type.ORI:
                          int imm = machineCode.bitRange(21, 10).toInt();
                          instruction =
                              "ORI \$r$rd, \$r$rj, 0x${imm.toRadixString(16)}";
                          break;
                        case Ins_type.XORI:
                          int imm = machineCode.bitRange(21, 10).toInt();
                          instruction =
                              "XORI \$r$rd, \$r$rj, 0x${imm.toRadixString(16)}";
                          break;
                        case Ins_type.LU12IW:
                          int imm = machineCode.bitRange(24, 5).toSignedInt();
                          instruction =
                              "LU12I.W \$r$rd, 0x${imm.toRadixString(16)}";
                          break;
                        case Ins_type.PCADDU12I:
                          int imm = machineCode.bitRange(24, 5).toSignedInt();
                          instruction =
                              "PCADDU12I \$r$rd, 0x${imm.toRadixString(16)}";
                          break;
                        case Ins_type.LDB:
                          int imm = machineCode.bitRange(21, 10).toSignedInt();
                          instruction = "LD.B \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.LDH:
                          int imm = machineCode.bitRange(21, 10).toSignedInt();
                          instruction = "LD.H \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.LDW:
                          int imm = machineCode.bitRange(21, 10).toSignedInt();
                          instruction = "LD.W \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.STB:
                          int imm = machineCode.bitRange(21, 10).toSignedInt();
                          instruction = "ST.B \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.STH:
                          int imm = machineCode.bitRange(21, 10).toSignedInt();
                          instruction = "ST.H \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.STW:
                          int imm = machineCode.bitRange(21, 10).toSignedInt();
                          instruction = "ST.W \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.LDBU:
                          int imm = machineCode.bitRange(21, 10).toSignedInt();
                          instruction = "LD.BU \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.LDHU:
                          int imm = machineCode.bitRange(21, 10).toSignedInt();
                          instruction = "LD.HU \$r$rd, \$r$rj, $imm";
                          break;
                        case Ins_type.JIRL:
                          int imm = machineCode.bitRange(25, 10).toSignedInt();
                          instruction = "JIRL \$r$rd, \$r$rj, ${imm << 2}";
                          break;
                        case Ins_type.B:
                          int imm = machineCode.bitRange(9, 0).toInt() |
                              (machineCode.bitRange(25, 10).toInt() << 10);
                          imm = ((imm << (32 - 26)) >> (32 - 26)) << 2; // 符号扩展
                          instruction = "B ${imm}";
                          break;
                        case Ins_type.BL:
                          int imm = machineCode.bitRange(9, 0).toInt() |
                              (machineCode.bitRange(25, 10).toInt() << 10);
                          imm = ((imm << (32 - 26)) >> (32 - 26)) << 2; // 符号扩展
                          instruction = "BL ${imm}";
                          break;
                        case Ins_type.BEQ:
                          int imm =
                              machineCode.bitRange(25, 10).toSignedInt() << 2;
                          instruction = "BEQ \$r$rj, \$r$rd, ${imm}";
                          break;
                        case Ins_type.BNE:
                          int imm =
                              machineCode.bitRange(25, 10).toSignedInt() << 2;
                          instruction = "BNE \$r$rj, \$r$rd, ${imm}";
                          break;
                        case Ins_type.BLT:
                          int imm =
                              machineCode.bitRange(25, 10).toSignedInt() << 2;
                          instruction = "BLT \$r$rj, \$r$rd, ${imm}";
                          break;
                        case Ins_type.BGE:
                          int imm =
                              machineCode.bitRange(25, 10).toSignedInt() << 2;
                          instruction = "BGE \$r$rj, \$r$rd, ${imm}";
                          break;
                        case Ins_type.BLTU:
                          int imm =
                              machineCode.bitRange(25, 10).toSignedInt() << 2;
                          instruction = "BLTU \$r$rj, \$r$rd, ${imm}";
                          break;
                        case Ins_type.BGEU:
                          int imm =
                              machineCode.bitRange(25, 10).toSignedInt() << 2;
                          instruction = "BGEU \$r$rj, \$r$rd, ${imm}";
                          break;
                        case Ins_type.BREAK:
                          instruction = "BREAK";
                          break;
                        case Ins_type.HALT:
                          instruction = "HALT";
                          break;
                        case Ins_type.NOP:
                          instruction = "NOP";
                          break;
                        default:
                          instruction = "未支持的指令类型";
                      }

                      // 显示解析结果
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('解析结果'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '机器码: 0x${machineCode.toInt().toRadixString(16).padLeft(8, '0')}'),
                                SizedBox(height: 12),
                                Text('汇编指令:'),
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    instruction,
                                    style: TextStyle(
                                      fontFamily: 'FiraCode',
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('确定'),
                              ),
                            ],
                          );
                        },
                      );
                    } catch (e) {
                      // 显示错误信息
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('错误'),
                            content: Text('无法解析机器码: ${e.toString()}'),
                            actions: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('确定'),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  },
                  child: Text('解析'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    return Row(
      children: [
        // 左侧工具栏
        Container(
          width: 60,
          decoration: BoxDecoration(
            color: Color(0xFFE3E8F0),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 4,
                offset: Offset(2, 0),
              ),
            ],
          ),
          margin: EdgeInsets.only(right: 4),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildCompileButton(width),
                  _buildneeddumpButton(width),
                  _buildRunButton(width),
                  _buildSingleStepButton(width),
                  _buildStepBackButton(width),
                  _buildDumpTextButton(width),
                  _buildDumpPDUTextButton(width),
                  _buildDumpDataButton(width),
                  _buildDumpPDUDataButton(width),
                  _buildlogButton(width),
                  _buildMachineCodeButton(width),
                  Divider(
                    color: Colors.indigo.withAlpha(40),
                    height: 32,
                    thickness: 1,
                    indent: 12,
                    endIndent: 12,
                  ),
                  // _buildHW2_4Button(width),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: width / 90),
        Expanded(
          flex: 80,
          child: _buildCodeText(height),
        ),
        SizedBox(
          width: width / 60,
        ),
        // processor state info
        Expanded(
            flex: 100,
            child: Column(
              children: [
                // processor state info
                Expanded(
                  flex: 22,
                  child: _buildProcessorStateInfo(width, height),
                ),
                Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        _buildMemoryCheckButton(width, height),
                        _buildMemoryInputField(
                          width: width,
                          height: height,
                          hintText: '输入16进制内存地址',
                          controller: memtext_ctrl,
                          onSubmit: (value) {
                            memtext_ctrl.text = value;
                            try {
                              mem_search =
                                  int.parse(memtext_ctrl.text, radix: 16);
                            } catch (e) {
                              mem_search = 0x1c000000;
                            }
                            if (mem_search < 0x1c000000 ||
                                mem_search > 0x24000000)
                              mem_search = 0x1c000000;
                            mem_search = mem_search & 0xfffffff0;
                            setState(() {});
                          },
                        ),
                        Container(
                          width: 10,
                        ),
                        _buildMemoryInputField(
                          width: width,
                          height: height,
                          hintText: '输入16进制内存数据',
                          controller: memdata_ctrl,
                          onSubmit: (value) {
                            memory.write(
                                Uint32(mem_waddr),
                                Uint32(
                                    int.parse(memdata_ctrl.text, radix: 16)));
                            setState(() {});
                          },
                        )
                      ],
                    )),
                // memory table
                Expanded(
                  flex: 30,
                  child: _buildMemoryTable(width, height),
                ),
              ],
            )),
        SizedBox(
          width: width / 60,
        ),
      ],
    );
  }
}
