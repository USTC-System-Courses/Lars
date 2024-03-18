import 'package:binary/binary.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:helloworld/arch.dart';
import 'package:helloworld/Uint32_ext.dart';
import 'package:helloworld/assembler.dart';
import 'package:helloworld/config.dart';
import 'package:helloworld/exception.dart';
import 'package:helloworld/codefield.dart';
import 'package:helloworld/memory.dart';
import 'package:helloworld/simulator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:helloworld/dump.dart';
import 'package:flutter/services.dart';
import 'dart:io';
// import 'package:binary/binary.dart';

void main() => runApp(MyApp());

List<String> temp = [];

class MyApp extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
        
        return MaterialApp(
            // theme: ThemeData(fontFamily: 'FiraCode'),
            home: Scaffold(
            appBar: AppBar(
                leading: Icon(Icons.memory, color: Color.fromARGB(255, 255, 215, 0)),
                title: Text('LARS', style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 255, 215, 0))),
                backgroundColor: Colors.black,
                toolbarHeight: 50,
            ),
            body: Stack(
                children: [
                    Container(
                        decoration: BoxDecoration(
                            color: Color.fromARGB(255, 239, 241, 254)
                        ),
                    ),
                    MyTextPaginatingWidget(),
                ]
            ) 

            ),
        );
    }
}

class MyTextPaginatingWidget extends StatefulWidget {
    @override
    _MyTextPaginatingWidgetState createState() => _MyTextPaginatingWidgetState();
}

// class SecondPage extends StatelessWidget {
//     @override
//     Widget build(BuildContext context) {
//         return Scaffold(
//         appBar: AppBar(
//             title: Text('Second Page'),
//         ),
//         body: Center(
//             child: Text('This is the second page'),
//         ),
//         );
//     }
// }

// class SecondPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Second Page'),
//       ),
//       body: Center(
//         child: Text('This is the second page'),
//       ),
//     );
//   }
// }

class _MyTextPaginatingWidgetState extends State<MyTextPaginatingWidget> {
    TextEditingController memtext_ctrl = TextEditingController(), memdata_ctrl = TextEditingController();
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

    TextFieldController _controller = TextFieldController(
        patternMatchMap: {
            RegExp(opString):TextStyle(color:Color.fromARGB(255, 5, 107, 245)),
            RegExp(regString): TextStyle(color:Color.fromARGB(255, 239, 157, 5)),
            RegExp(signString):TextStyle(color:Color.fromARGB(255, 65, 155, 87)),

        },
        onMatch: (List<String> matches){
        },
        deleteOnBack: false,
        // You can control the [RegExp] options used:
        regExpUnicode: true,
    );

    /* build the code text */
    Widget _buildCodeText(double height){
        return Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2.0),
                borderRadius: BorderRadius.all(Radius.circular(5.0)),
                color: Color.fromARGB(180, 207, 236, 254),
            ),
            alignment: Alignment.center,
            margin: EdgeInsets.only(top: height/120, bottom: height/120),
            child: SingleChildScrollView(
                child: Column(
                    children: <Widget>[
                        Actions(
                            actions: {InsertTabIntent: InsertTabAction()},
                            child: Shortcuts(
                                shortcuts: {
                                    LogicalKeySet(LogicalKeyboardKey.tab): InsertTabIntent(4, _controller),
                                },
                                child: TextField(
                                    controller: _controller,
                                    maxLines: null,
                                    minLines: 30,
                                    expands: false,
                                    decoration: InputDecoration(
                                    hintText: '请输入LA32R汇编代码',
                                        border: InputBorder.none,
                                        hintStyle: TextStyle(textBaseline: TextBaseline.alphabetic),
                                    ),
                                    // inputFormatters: [
                                    //     // 限制只能输入英文字母和数字
                                    //     FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\n\s\,\.\:\(\)\[\]\+\-\*\/\%\&\|\^\~\!\=\>\<\_\#]+')),
                                    // ],
                                    style: TextStyle(fontFamily: 'FiraCode'),
                                ),
                            )
                        )
                    ]
                )
            ),
        );
    }

    /* build the pc info */
    Widget _buildPCStateInfo(double width){
        return Container(
            child: Center(
                child:Text('PC\n0x${sim.pc.toInt().toRadixString(16)}', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center,)
            ),
            margin: EdgeInsets.only(left: width/60, right: width/60),
            alignment: Alignment.center,
            width: width*12/60,
            decoration: BoxDecoration(
                color: Color.fromARGB(255, 255, 231, 0),
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
        );
    }

    /* build the inst info */
    Widget _buildInstStateInfo(double width){
        return Container(
            child: Center(
                child:Text('Inst\n${asm.inst_rec[sim.pc]==null?'NOP':asm.inst_rec[sim.pc]!.sentence}', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center,)
            ),
            width: width*12/60,
            margin: EdgeInsets.only(left: width/60, right: width/60),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Color.fromARGB(255, 255, 231, 0),
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
        );
    }

    /* build the reg info */
    Widget _buildRegStateInfo(double width, double height){
        return ListView(
            controller: _scrollController,
            children: [
            for(int i = 0; i < 8; i++)
                Flex(direction: Axis.vertical,children: [
                    SizedBox(height: height / 120,),
                    Row(children: [
                        for(int j = 0; j < 4; j++)
                            Flex(direction: Axis.horizontal, children: [
                                Container(
                                    width: width*5/60,
                                    alignment: Alignment.center,
                                    margin: EdgeInsets.only(left: width/60, right: width/60),
                                    decoration: BoxDecoration(
                                        color: reg_change[4*i+j]?Color.fromARGB(255, 255, 98, 98):Color.fromARGB(255, 248, 174, 39),
                                        border: Border.all(color: Colors.black),
                                        borderRadius: BorderRadius.all(Radius.circular(6))
                                    ),
                                    child: Center(child:Text('R${4*i+j}' + ((register_name[4*i+j].isEmpty) ? "" : " / ") + register_name[4*i+j] + '\n0x${sim.reg[4*i+j].toInt().toRadixString(16)}', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center,)),
                                ),
                            ],
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            )
                        ],
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                    ),
                    SizedBox(height: height / 120,),
                ],
            )],
        );
    }

    /* build the reg and pc info */
    Widget _buildProcessorStateInfo(double width, height){
        return Column(
            children: [
                Container(
                    child: Row(
                        children: [
                            SizedBox(width: width / 40,),
                            // pc
                            _buildPCStateInfo(width),
                            // inst
                            _buildInstStateInfo(width),
                        ],
                    ),
                    alignment: Alignment.center,
                    padding: EdgeInsets.only(top: height/120, bottom: height/120),
                    margin: EdgeInsets.only(top: height / 120, bottom: 0),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.all(Radius.circular(5.0)),
                        color: Color.fromARGB(255, 151, 196, 255)
                    ),
                ),
                // reg info
                Expanded(
                    flex: 16,
                    child: Container(
                        child: _buildRegStateInfo(width, height),
                        padding: EdgeInsets.only(top: 1, bottom: 1),
                        margin: EdgeInsets.only(top: height / 240),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.all(Radius.circular(5.0)),
                            color: Color.fromARGB(255, 151, 196, 255)
                        ),
                        alignment: Alignment.center,
                    ),
                ),
                // SizedBox(height: 5,),
            ],
        );
    }

    // /* exception info */
    // Widget _buildExceptionInfo(double width){
    //     return Container(
    //         width: width*14/60,
    //         child: ListView(
    //             children: Warnings.map((e) => Text(e)).toList(),
    //         ),
    //     );
    // }

    Widget _buildExceptionDialog(double width){
        return UnconstrainedBox(
            constrainedAxis: Axis.vertical, 
            child: Container(
                width: width*20/60,
                child: 
                    Column(children: [
                        AlertDialog(
                        title: Text('Error'),
                        content: Column(
                            children: Warnings.map((e) => Text(e)).toList(),
                        ),
                        actions: [
                            ElevatedButton(
                                onPressed: (){
                                    Navigator.of(context).pop();
                                },
                                child: Text('OK'),
                            )
                        ],
                    ),
                ],)
            ),

        );
    }

    /* memory table */
    Widget _buildMemoryTable(double width, double height){
        return Container(
            // margin: EdgeInsets.only(bottom: height/120),
            alignment: Alignment.center,
            child: SingleChildScrollView(child:
            Table(
                border: TableBorder.all(color: Colors.black),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                    TableRow(
                        // 修改高度
                        children: [
                            TableCell(
                                verticalAlignment: TableCellVerticalAlignment.middle,
                                child: Text('Memory', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold),),
                                // decoration: BoxDecoration(border: Border.all(color: Colors.black),),
                            ),
                            for(int i = 0; i < 16; i += 4)
                                TableCell(
                                    // verticalAlignment: TableCellVerticalAlignment.middle,
                                    child: Text('+${i.toRadixString(16)}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold),),
                                    // decoration: BoxDecoration(border: Border.all(color: Colors.black),),
                                )
                        ],
                        decoration: BoxDecoration(
                            color: Color.fromARGB(255, 255, 231, 0)
                        )
                    ),
                    for (int i = 0; i < height ~/ 80; i++)
                        TableRow(
                            children: [
                                Container(
                                    // height: 40,
                                    child: TableCell(
                                        child: Text('0x${(mem_search + i*16).toRadixString(16).padLeft(8, '0')}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold),),
                                            // decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: Colors.black), end: BorderSide(color: Colors.black))),
                                        // verticalAlignment: TableCellVerticalAlignment.middle,
                                    ),
                                ),
                                
                                for(int j = 0; j < 16; j += 4)
                                    TableCell(
                                        // alignment: Alignment.center,
                                        // verticalAlignment: TableCellVerticalAlignment.middle,
                                        child: Container(
                                            color: (sim.pc == Uint32(mem_search + i*16 + j) ? Color.fromARGB(255, 253, 222, 136) : Colors.transparent),
                                            // height: 40,
                                            child: Tooltip(
                                                waitDuration: Duration(seconds: 1),
                                                verticalOffset: 8,
                                                message: (asm.inst_rec[Uint32(mem_search + i*16 + j)] != null) ? asm.inst_rec[Uint32(mem_search + i*16 + j)]!.sentence: '', 
                                                padding: EdgeInsets.all(1),
                                                child: UnconstrainedBox(
                                                    child: TextButton(
                                                        onPressed: (){
                                                            if(breakpoints.contains(Uint32(mem_search + i*16 + j))){
                                                                breakpoints.remove(Uint32(mem_search + i*16 + j));
                                                            } else {
                                                                breakpoints.add(Uint32(mem_search + i*16 + j));
                                                            }
                                                            setState(() {});
                                                        },
                                                        
                                                        child: Text('0x${memory[Uint32(mem_search + i*16 + j)].toInt().toRadixString(16).padLeft(8, '0')}', textAlign: TextAlign.center, style: TextStyle(color: Colors.black),),
                                                        style: ButtonStyle(
                                                            visualDensity: VisualDensity.compact,
                                                            padding: MaterialStateProperty.all(EdgeInsets.zero),
                                                            minimumSize: MaterialStateProperty.all(Size(0, 0)),
                                                            backgroundColor: breakpoints.contains(Uint32(mem_search + i*16 + j)) ? MaterialStateProperty.all(const Color.fromARGB(255, 245, 177, 172)):MaterialStateProperty.all(Colors.transparent),
                                                        )
                                                    ),
                                                )
                                            ),
                                        ),
                                    ),
                            ],
                            decoration: BoxDecoration(
                                color: (i%2==0)?Color.fromARGB(160, 151, 196, 255):Color.fromARGB(160, 110, 171, 255),
                            ),
                        ),
                ],
            ),
        ));
    }

    Widget _buildMemoryAddrInput(double width, double height){
        return Container(
            alignment: Alignment.center,
            width: width / 8,
            height: height / 30,
            
            child: TextField(
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                    isDense: true,
                    hintText: '输入16进制内存地址',
                    // 减小字体
                    hintStyle: TextStyle(textBaseline: TextBaseline.alphabetic),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (value){
                    memtext_ctrl.text = value;
                    try{
                        mem_search = int.parse(memtext_ctrl.text, radix: 16);
                    } catch(e){
                        mem_search = 0x1c000000;
                    }
                    if(mem_search < 0x1c000000 || mem_search > 0x24000000) mem_search = 0x1c000000;
                    mem_search = mem_search & 0xfffffff0;
                    setState(() {});
                },
                onChanged: (value){
                    mem_waddr = int.parse(value, radix: 16);
                },
                controller: memtext_ctrl,
                maxLines: 1,
            ),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.all(Radius.circular(5.0)),
            ),
        );
    }

    Widget _buildMemoryDataInput(double width, double height){
        return Container(
            alignment: Alignment.center,
            width: width / 8,
            height: height / 30,
            
            child: TextField(
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                    isDense: true,
                    hintText: '输入16进制内存数据',
                    // 减小字体
                    hintStyle: TextStyle(textBaseline: TextBaseline.alphabetic),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (value){
                    memory.write(Uint32(mem_waddr), Uint32(int.parse(memdata_ctrl.text, radix: 16)));
                    setState(() {});
                },
                controller: memdata_ctrl,
                maxLines: 1,
            ),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.all(Radius.circular(5.0)),
            ),
        );
    }

    Widget _buildMemoryCheckButton(double width, double height){
        return Container(
            alignment: Alignment.center,
            child: IconButton(
                onPressed: (){
                    try{
                        mem_search = int.parse(memtext_ctrl.text, radix: 16);
                    } catch(e){
                        mem_search = 0x1c000000;
                    }
                    if(mem_search < 0x1c000000 || mem_search > 0x24000000) mem_search = 0x1c000000;
                    mem_search = mem_search & 0xfffffff0;
                    setState(() {});
                },
                style: ButtonStyle(
                    elevation: MaterialStateProperty.all(2),
                ),
                // child: Text('查看内存'),
                icon: Icon(Icons.search),
                iconSize: height/30,
                tooltip: '查看内存',
            ),
            // width: width / 10
        );

    }
    Widget _buildCompileButton(double width){
        return Tooltip(
            message: '编译',
            waitDuration: Duration(seconds: 1),
            child: IconButton(
                onPressed: () async {
                    String text = _controller.text + '\n';
                    textLines = text.split('\n');
                    memory = Memory();
                    Warnings = [];
                    reg = List.filled(32, Uint32.zero);
                    reg_change = List.filled(32, false);
                    try {
                        asm = Assembler(textLines);
                    } on SentenceException catch (e) {
                        Warnings.add(e.toString());
                    } on MemoryException catch (e){
                        Warnings.add(e.type.toString());
                    }

                    // if has warnings, show a dialog
                    if(Warnings.isNotEmpty){
                        showDialog(
                            context: context,
                            builder: (BuildContext context){
                                return _buildExceptionDialog(width);
                            }
                        );
                    }
                    _scrollController.jumpTo(0);
                    setState(() {});

                    // Save the text to a file
                    try{
                        if(Platform.isWindows){
                            final directory = await getApplicationDocumentsDirectory();
                            print(directory.path);
                            final file = File('${directory.path}/input.txt');
                            await file.writeAsString(text);
                        }
                    }catch(e){
                        print(e);
                    }
                    sim.reset();
                    
                },
                style: ButtonStyle(
                    elevation: MaterialStateProperty.all(2),
                ),
                // child: Text('编译'),
                icon: Icon(Icons.build, color: Colors.white),
                padding: EdgeInsets.zero,
                hoverColor: Colors.brown,
                // iconSize: width / 60,
            ),
            // width: width / 10,
            
        );
        
    }
    Widget _buildSingleStepButton(double width){
        return Tooltip(
            message: '单步执行',
            waitDuration: Duration(seconds: 1),
            child: IconButton(
                onPressed: (){
                    for(int i = 0; i < 32; i++){
                        reg[i] = sim.reg[i];
                    }
                    sim.cycle();
                    for(int i = 0; i < 32; i++){
                        // Uint32 a = reg[i], b = asm.reg[i];
                        reg_change[i] = (reg[i] != sim.reg[i])?true:false;
                    }
                    setState(() {});
                },
                style: ButtonStyle(
                    elevation: MaterialStateProperty.all(2),
                ),
                // child: Text('单步执行')
                icon: Icon(Icons.arrow_forward, color: Colors.white),
                padding: EdgeInsets.zero,
                hoverColor: Colors.brown,
            ),
            // width: width / 10,
        );
    }
    Widget _buildRunButton(double width){
        return Tooltip(
            message: '运行',
            waitDuration: Duration(seconds: 1),
            child: IconButton(
                onPressed: (){
                    for(int i = 0; i < 32; i++){
                        reg[i] = sim.reg[i];
                    }
                    sim.run(breakpoints);
                    for(int i = 0; i < 32; i++){
                        // Uint32 a = reg[i], b = asm.reg[i];
                        reg_change[i] = (reg[i] != sim.reg[i])?true:false;
                    }
                    setState(() {});
                },
                style: ButtonStyle(
                    elevation: MaterialStateProperty.all(2),
                ),
                // child: Text('运行')
                icon: Icon(Icons.play_arrow, color: Colors.white),
                padding: EdgeInsets.zero,
                hoverColor: Colors.brown,
            ),
            // width: width / 10,
        );
    }
    Widget _buildStepBackButton(double width){
        return Tooltip(
            message: '单步回退',
            waitDuration: Duration(seconds: 1),
            child: IconButton(
                onPressed: (){
                    for(int i = 0; i < 32; i++){
                        reg[i] = sim.reg[i];
                    }
                    sim.step_back();
                    for(int i = 0; i < 32; i++){
                        // Uint32 a = reg[i], b = asm.reg[i];
                        reg_change[i] = (reg[i] != sim.reg[i])?true:false;
                    }
                    setState(() {});
                },
                style: ButtonStyle(
                    elevation: MaterialStateProperty.all(2),
                ),
                // child: Text('单步回退')
                icon: Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
                hoverColor: Colors.brown,
            ),
            // width: width / 10,
        );
    }

    Widget _buildDumpTextButton(double width){
        return Tooltip(
            message: '导出代码',
            waitDuration: Duration(seconds: 1),
            child: IconButton(
                onPressed: (){
                    downloadTxtFile('text.coe', memory.DumpInstCoe());
                },
                style: ButtonStyle(
                    elevation: MaterialStateProperty.all(2),
                ),
                // child: Text('导出代码')
                icon: Icon(Icons.file_download, color: Colors.white),
                padding: EdgeInsets.zero,
                hoverColor: Colors.brown,
            ),
            // width: width / 10,
        );
    }

    Widget _buildDumpDataButton(double width){
        return Tooltip(
            message: '导出数据',
            waitDuration: Duration(seconds: 1),
            child: IconButton(
                onPressed: (){
                    downloadTxtFile('data.coe', memory.DumpDataCoe());
                },
                style: ButtonStyle(
                    elevation: MaterialStateProperty.all(2),
                ),
                // child: Text('导出数据')
                icon: Icon(Icons.vertical_align_bottom, color: Colors.white),
                
                padding: EdgeInsets.zero,
                hoverColor: Colors.brown,
            ),
            // width: width / 10,
        );
    }

    Widget _buildlogButton(double width){
        return Tooltip(
            message: '查看log',
            waitDuration: Duration(seconds: 1),
            child: IconButton(
                onPressed: (){
                    downloadTxtFile('log.txt', sim.log.print(asm.inst_rec));
                },
                style: ButtonStyle(
                    elevation: MaterialStateProperty.all(2),
                ),
                // child: Text('导出数据')
                icon: Icon(Icons.edit_note_rounded, color: Colors.white),
                
                padding: EdgeInsets.zero,
                hoverColor: Colors.brown,
            ),
            // width: width / 10,
        );
    }

    // Future<String> readFileAsString(String filePath) async {
    //     File file = File(filePath);
    //     try {
    //         // 读取文件内容
    //         String fileContent = await file.readAsString();
    //         return fileContent;
    //     } catch (e) {
    //         print('Error reading file: $e');
    //         return '';
    //     }
    // }

//     Widget Docs(){
//         final String data = '''
// # 使用指南

// 本文将以一段简单的汇编程序为例，介绍如何使用本工具。这段汇编程序是将内存中的数据复制到另一个内存地址中。

// ```assembly
// .data
// a:
// .word 8

// .text
// la.local \$r1, a
// ld.w \$r2, \$r1, 0
// addi.w \$r1, \$r1, 4
// st.w \$r2, \$r1, 0
// ```

// ## 代码编写
// 在界面左侧的文本框中，您可以随心所欲地编写代码：

// // todo

// ## 代码编译

// 当您编写完代码后，点击界面左侧的“编译”按钮，即可将您的代码编译为机器码：

// // todo

// - 代码（.text）段的数据将会顺序放置在以0x1c000000为起始地址的内存中
// - 数据（.data）段的数据将会顺序放置在以0x1c800000为起始地址的内存中。


//         ''';
//         return Scaffold(
//         appBar: AppBar(
//             title: Text('Markdown Example'),
//         ),
//         body: SingleChildScrollView(
//             child: Padding(
//             padding: EdgeInsets.all(16.0),
//             child: Markdown(
//                 data: data,
//             ),
//             ),
//         ),
//         );
//     }
    

    @override
    Widget build(BuildContext context) {
        final size = MediaQuery.of(context).size;
        final width = size.width;
        final height = size.height;
        return Row(children: [
                // code write
                Expanded(
                    flex: 5,
                    child: Container(
                        child: Column(children: [
                            SizedBox(height: height / 120,),
                            _buildCompileButton(width),
                            _buildRunButton(width),
                            _buildSingleStepButton(width),
                            _buildStepBackButton(width),
                            _buildDumpTextButton(width),
                            _buildDumpDataButton(width),
                            _buildlogButton(width),
                            SizedBox(height: height / 120,),
                        ],),
                        decoration: BoxDecoration(
                            color: Colors.black
                        ),
                    )
                ),
                SizedBox(width: width / 90,),
                Expanded(
                    flex: 80,
                    child: _buildCodeText(height),
                    
                ),
                SizedBox(width: width / 60,),
                // processor state info
                Expanded(
                    flex: 100,
                    child: Column(children: [
                        // processor state info
                        Expanded(
                            flex: 22,
                            child: _buildProcessorStateInfo(width, height),
                        ),
                        Expanded(
                            flex: 4,
                            child: Row(children: [
                                _buildMemoryCheckButton(width, height),
                                _buildMemoryAddrInput(width, height),
                                Container(
                                    width: 10,
                                ),
                                _buildMemoryDataInput(width, height)
                            ],)
                        ),
                        // memory table
                        Expanded(
                            flex: 30,
                            child: _buildMemoryTable(width, height),
                        ),
                    ],)
                ),
                SizedBox(width: width / 60,),
            ],);
    }
}
