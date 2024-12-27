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
import 'package:lars/arch.dart';
import 'package:lars/Uint32_ext.dart';
import 'package:lars/assembler.dart';
import 'package:lars/config.dart';
import 'package:lars/exception.dart';
import 'package:lars/codefield.dart';
import 'package:lars/memory.dart';
import 'package:lars/simulator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lars/dump.dart' if (dart.library.io) 'winout.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
// import 'package:binary/binary.dart';

/// Application entry point
void main() => runApp(MyApp());

List<String> temp = [];

/// Root application widget that configures the app theme and basic structure
class MyApp extends StatelessWidget {
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
                  'LARS',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                    color: Colors.amber[200],
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '龙芯架构32位精简版指令集 汇编器与模拟器',
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
          ),
          body: Stack(children: [
            Container(
              decoration:
                  BoxDecoration(color: Color.fromARGB(255, 239, 241, 254)),
            ),
            MyTextPaginatingWidget(),
          ])),
    );
  }
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
  /// Controllers for memory text and data input
  TextEditingController memtext_ctrl = TextEditingController(),
      memdata_ctrl = TextEditingController();
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
                            Text(
                              'R${4 * i + j}${register_name[4 * i + j].isNotEmpty ? " / ${register_name[4 * i + j]}" : ""}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
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
      waitDuration: Duration(seconds: 1),
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
                  Divider(
                    color: Colors.indigo.withAlpha(40),
                    height: 32,
                    thickness: 1,
                    indent: 12,
                    endIndent: 12,
                  ),
                  _buildHW2_4Button(width),
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
