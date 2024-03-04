import 'package:binary/binary.dart';
import 'package:flutter/cupertino.dart';
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
import 'dart:io';
// import 'package:binary/binary.dart';

void main() => runApp(MyApp());

List<String> temp = [];

class MyApp extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
        
        return MaterialApp(
            theme: ThemeData(fontFamily: 'FiraCode'),
            home: Scaffold(
            appBar: AppBar(
                leading: Icon(Icons.copyright, color: Color.fromARGB(255, 255, 215, 0)),
                title: Text('LARS', style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 255, 215, 0))),
                backgroundColor: Colors.black,
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
    TextEditingController memtext_ctrl = TextEditingController();
    List<String> textLines = [];
    Assembler asm = Assembler([]);
    Simulator sim = Simulator();
    // DumpCode dp = DumpCode();
    int mem_search = 0x1c000000;
    final ScrollController _scrollController = ScrollController();
    List<String> Warnings = [];
    List<Uint32> reg = List.filled(32, Uint32.zero);
    List<bool> reg_change = List.filled(32, false);
    Set<Uint32> breakpoints = {};

    TextFieldController _controller = TextFieldController(
        patternMatchMap: {
            RegExp(opString):TextStyle(color:Color.fromARGB(255, 5, 107, 245)),
            RegExp(regString): TextStyle(color:Color.fromARGB(255, 244, 161, 5)),
            RegExp(immString):TextStyle(color:Color.fromARGB(255, 65, 155, 87)),

        },
        onMatch: (List<String> matches){
        },
        deleteOnBack: false,
        // You can control the [RegExp] options used:
        regExpUnicode: true,
    );

    /* build the code text */
    Widget _buildCodeText(){
        return Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2.0),
                borderRadius: BorderRadius.all(Radius.circular(5.0)),
                color: Color.fromARGB(180, 207, 236, 254),
            ),
            child: SingleChildScrollView(
                child: TextField(
                    controller: _controller,
                    maxLines: null,
                    minLines: 40,
                    expands: false,
                    decoration: InputDecoration(
                    hintText: '请输入LA32R汇编代码',
                        border: InputBorder.none,
                        hintStyle: TextStyle(textBaseline: TextBaseline.alphabetic),
                    ),
                    // style: TextStyle(fontFamily: 'Monospace'),
                ),
                
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
                                    child: Center(child:Text('R${4*i+j} / ' + register_name[4*i+j] + '\n0x${sim.reg[4*i+j].toInt().toRadixString(16)}', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center,)),
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
                            SizedBox(width: width / 240,),
                            // pc
                            _buildPCStateInfo(width),
                            // inst
                            _buildInstStateInfo(width),
                        ],
                    ),
                    padding: EdgeInsets.only(top: 5, bottom: 5),
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
                        margin: EdgeInsets.only(top: 5, bottom: 0),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.all(Radius.circular(5.0)),
                            color: Color.fromARGB(255, 151, 196, 255)
                        ),
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
            // width: width*44/60,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                // borderRadius: BorderRadius.all(Radius.circular(5.0)),
                // color: Color.fromARGB(255, 151, 196, 255)
            ),
            child: SingleChildScrollView(child:
            Table(
                border: TableBorder.all(color: Colors.black),
                children: [
                    TableRow(
                        children: [
                            Container(
                                child: Text('Memory', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold),),
                                // decoration: BoxDecoration(border: Border.all(color: Colors.black),),
                            ),
                            for(int i = 0; i < 16; i += 4)
                                Container(
                                    child: Text('+${i.toRadixString(16)}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold),),
                                    // decoration: BoxDecoration(border: Border.all(color: Colors.black),),
                                )
                        ],
                        decoration: BoxDecoration(
                            color: Color.fromARGB(255, 255, 231, 0)
                        )
                    ),
                    for (int i = 0; i < 16; i++)
                        TableRow(
                            children: [
                                TableCell(
                                    child: Container(
                                        child: Text('0x${(mem_search + i*16).toRadixString(16).padLeft(8, '0')}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold),),
                                        // decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: Colors.black), end: BorderSide(color: Colors.black))),
                                    ),
                                    verticalAlignment: TableCellVerticalAlignment.middle,
                                ),
                                
                                for(int j = 0; j < 16; j += 4)
                                    Container(
                                        child: Tooltip(
                                            verticalOffset: 8,
                                            // 设置边框
                                            message: (asm.inst_rec[Uint32(mem_search + i*16 + j)] != null) ? asm.inst_rec[Uint32(mem_search + i*16 + j)]!.sentence: '', 
                                            padding: EdgeInsets.all(0),
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
                                                        // minimumSize: MaterialStateProperty.all(Size(0, 0)),
                                                        backgroundColor: breakpoints.contains(Uint32(mem_search + i*16 + j)) ? MaterialStateProperty.all(const Color.fromARGB(255, 245, 177, 172)):MaterialStateProperty.all(Colors.transparent),
                                                    )
                                                ),
                                            )
                                            //child: TextButton(onPressed: (){}, child: Text('0x${memory[Uint32(mem_search + i*16 + j)].toInt().toRadixString(16).padLeft(8, '0')}', textAlign: TextAlign.center, style: TextStyle(color: Colors.black),)),
                                        ),
                                        // decoration: BoxDecoration(border: Border.all(color: Colors.black),),
                                        // height: height/23,
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

    Widget _buildMemoryAddrInput(double width){
        return Container(
            alignment: Alignment.center,
            width: width / 8,
            height: 30,
            
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
                controller: memtext_ctrl,
                maxLines: 1,
            ),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.all(Radius.circular(5.0)),
            ),
        );
    }
    Widget _buildMemoryCheckButton(double width){
        return Container(
            child: ElevatedButton(
                onPressed: (){
                    try{
                        mem_search = int.parse(memtext_ctrl.text, radix: 16);
                    } catch(e){
                        mem_search = 0x1c000000;
                    }
                    if(mem_search < 0x1c000000 || mem_search > 0x24000000) mem_search = 0x1c000000;
                    setState(() {});
                },
                style: ButtonStyle(
                    elevation: MaterialStateProperty.all(2),
                ),
                child: Text('查看内存'),
            ),
            width: width / 10
        );

    }
    Widget _buildCompileButton(double width){
        return Container(
            child: ElevatedButton(
                onPressed: () async {
                    String text = _controller.text + '\nBREAK';
                    // _textEditingController.value = TextEditingValue(text: text);
                    // Split the text into lines
                    textLines = text.split('\n');
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
                child: Text('编译'),
            ),
            width: width / 16,
        );
        
    }
    Widget _buildSingleStepButton(double width){
        return Container(
            child: ElevatedButton(
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
                child: Text('单步执行')
            ),
            width: width / 16,
        );
    }
    Widget _buildRunButton(double width){
        return Container(
            child: ElevatedButton(
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
                child: Text('运行')
            ),
            width: width / 16,
        );
    }
    Widget _buildStepBackButton(double width){
        return Container(
            child: ElevatedButton(
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
                child: Text('单步回退')
            ),
            width: width / 16,
        );
    }

    Widget _buildDumpTextButton(){
        return Container(
            child: ElevatedButton(
                onPressed: (){
                    downloadTxtFile('text.coe', memory.DumpInstCoe());
                },
                style: ButtonStyle(
                    elevation: MaterialStateProperty.all(2),
                ),
                child: Text('导出')
            ),
        );
    }

    @override
    Widget build(BuildContext context) {
        final size = MediaQuery.of(context).size;
        final width = size.width;
        final height = size.height;
        return Column(children: [
            // orgnize the items by column
            // first column: Code write, state and memory
            SizedBox(height: height / 60,),
            Expanded(
                flex: 100,
                // height: height * 0.82,
                child: Row(children: [
                    // code write
                    SizedBox(width: width / 60,),
                    Expanded(
                        // flex: 100,
                        child: _buildCodeText(),
                    ),
                    SizedBox(width: width / 60,),
                    // processor state info
                    Expanded(
                        // flex: 100,
                        child: Column(children: [
                            // processor state info
                            Expanded(
                                flex: 24,
                                child: _buildProcessorStateInfo(width, height),
                            ),
                            SizedBox(height: height / 60,),
                            // memory table
                            Expanded(
                                flex: 30,
                                child: _buildMemoryTable(width, height),
                            ),
                        ],)
                    ),
                    SizedBox(width: width / 60,),
                ],)
            ),
            SizedBox(height: height / 60,),
            // secode column: tools
            Expanded(
                flex: 10,
                // height: height /20,
                child: Row(children: [
                    SizedBox(width: width / 60,),
                    Expanded(
                        // flex: 40,
                        child: Row(children: [
                            // compile button
                            _buildCompileButton(width),
                            SizedBox(width: width / 60,),
                            // single step button
                            _buildSingleStepButton(width),
                            SizedBox(width: width / 60,),
                            _buildRunButton(width),
                            SizedBox(width: width / 60,),
                            _buildStepBackButton(width),
                        ],)
                    ),
                    SizedBox(width: width / 60,),
                    Expanded(
                        // flex: 40,
                        child: Row(children: [
                            // memory check button
                            _buildMemoryCheckButton(width),
                            SizedBox(width: width / 60,),
                            // memory addr input
                            _buildMemoryAddrInput(width),
                            SizedBox(width: width / 60,),
                            // dump text button
                            _buildDumpTextButton(),
                        ],)
                    ),
                    SizedBox(width: width / 60,),
                ],)
            ),
        ]);
    }
}
