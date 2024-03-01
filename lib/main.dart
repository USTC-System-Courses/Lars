import 'package:binary/binary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:helloworld/Uint32_ext.dart';
import 'package:helloworld/assembler.dart';
import 'package:helloworld/exception.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// import 'package:binary/binary.dart';

void main() => runApp(MyApp());

List<String> temp = [];

class MyApp extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
        return MaterialApp(
            home: Scaffold(
            appBar: AppBar(
                leading: Icon(Icons.copyright, color: Color.fromARGB(255, 255, 215, 0)),
                title: Text('Lars', style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 255, 215, 0))),
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
    TextEditingController _textEditingController = TextEditingController(), memtext_ctrl = TextEditingController();
    List<String> textLines = [];
    Assembler asm = Assembler([]);
    int mem_search = 0x1c000000;
    final ScrollController _scrollController = ScrollController();
    List<String> Warnings = [];
    List<Uint32> reg = List.filled(32, Uint32.zero);
    List<bool> reg_change = List.filled(32, false);

    /* build the code text */
    Widget _buildCodeText(){
        return Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2.0),
                borderRadius: BorderRadius.all(Radius.circular(5.0)),
                color: Color.fromARGB(160, 188, 233, 254),
            ),
            child: SingleChildScrollView(
                child: TextField(
                    controller: _textEditingController,
                    maxLines: null,
                    minLines: 20,
                    expands: false,
                    decoration: InputDecoration(
                    labelText: '请输入LA32R汇编代码',
                    border: InputBorder.none,
                    ),
                ),
            ),
        );
    }

    /* build the pc info */
    Widget _buildPCStateInfo(double width){
        return Container(
            child: Center(
                child:Text('PC\n0x${asm.pc.toInt().toRadixString(16)}', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center,)
            ),
            margin: EdgeInsets.only(left: width/60, right: width/60),
            width: width*12/60,
            decoration: BoxDecoration(
                color: Color.fromARGB(255, 252, 239, 0),
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
        );
    }

    /* build the inst info */
    Widget _buildInstStateInfo(double width){
        return Container(
            child: Center(
                child:Text('Inst\n${asm.inst_rec[asm.pc]==null?'NOP':asm.inst_rec[asm.pc]!.sentence}', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center,)
            ),
            width: width*12/60,
            margin: EdgeInsets.only(left: width/60, right: width/60),
            decoration: BoxDecoration(
                color: Color.fromARGB(255, 252, 239, 0),
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
                                        color: reg_change[4*i+j]?Color.fromARGB(255, 255, 98, 98):Color.fromARGB(255, 249, 200, 104),
                                        border: Border.all(color: Colors.black),
                                        borderRadius: BorderRadius.all(Radius.circular(6))
                                    ),
                                    child: Center(child:Text('R${4*i+j}\n0x${asm.reg[4*i+j].toInt().toRadixString(16)}', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center,)),
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
                        color: Color.fromARGB(200, 115, 142, 255)
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
                            color: Color.fromARGB(200, 115, 142, 255)
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
    Widget _buildMemoryTable(double width){
        return Container(
            width: width*44/60,
            child: Table(
                border: TableBorder.all(),
                children: [
                    TableRow(
                        children: [
                            Container(
                                child: Text('Memory', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold),),
                                decoration: BoxDecoration(border: Border.all(color: Colors.black),),
                            ),
                            for(int i = 0; i < 16; i += 4)
                                Container(
                                    child: Text('+${i.toRadixString(16)}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold),),
                                    decoration: BoxDecoration(border: Border.all(color: Colors.black),),
                                )
                        ],
                        decoration: BoxDecoration(
                            color: Color.fromARGB(255, 255, 224, 201)
                        )
                    ),
                    for (int i = 0; i < 10; i++)
                        TableRow(
                            children: [
                                Container(
                                    child: Text('0x${(mem_search + i*16).toRadixString(16).padLeft(8, '0')}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold),),
                                    decoration: BoxDecoration(border: Border.all(color: Colors.black),),
                                ),
                                for(int j = 0; j < 16; j += 4)
                                    Container(
                                        child: Tooltip(
                                            verticalOffset: 8,
                                            // 设置边框
                                            message: (asm.inst_rec[Uint32(mem_search + i*16 + j)] != null) ? asm.inst_rec[Uint32(mem_search + i*16 + j)]!.sentence: '', 
                                            child: Text('0x${asm.memory[Uint32(mem_search + i*16 + j)].toInt().toRadixString(16).padLeft(8, '0')}', textAlign: TextAlign.center,),
                                        ),
                                        decoration: BoxDecoration(border: Border.all(color: Colors.black),),
                                    ),
                            ],
                            decoration: BoxDecoration(
                                color: (i%2==0)?Color.fromARGB(255, 218, 245, 251):Color.fromARGB(255, 198, 228, 252)
                            )
                        ),
                ],
            ),
        );
    }

    Widget _buildMemoryAddrInput(double width){
        return Container(
            width: width / 8,
            child: TextField(
                decoration: InputDecoration(
                    hintText: '输入内存地址(16进制)',
                    // 减小字体
                    hintStyle: TextStyle(textBaseline: TextBaseline.alphabetic, fontSize: 12),
                    border: InputBorder.none,
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
                child: Text('查看内存')
            ),
            width: width / 10
        );

    }
    Widget _buildCompileButton(double width){
        return Container(
            child: ElevatedButton(
                onPressed: () async {
                    String text = _textEditingController.text + '\nBREAK';
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
                    
                },
                child: Text('编译'),
            ),
            width: width / 10,
        );
        
    }
    Widget _buildSingleStepButton(double width){
        return Container(
            child: ElevatedButton(
                onPressed: (){
                    for(int i = 0; i < 32; i++){
                        reg[i] = asm.reg[i];
                    }
                    asm.cycle();
                    for(int i = 0; i < 32; i++){
                        // Uint32 a = reg[i], b = asm.reg[i];
                        reg_change[i] = (reg[i] != asm.reg[i])?true:false;
                    }
                    setState(() {});
                },
                child: Text('单步执行')
            ),
            width: width / 10,
        );
    }

    @override
    Widget build(BuildContext context) {
        final size = MediaQuery.of(context).size;
        final width = size.width;
        final height = size.height;
        return Row(children: [
            // orgnize the items by column
            // first column: Code write, compile and single step, use two row
            SizedBox(width: width / 60,),
            Expanded(
                flex: 40,
                child: Column(children: [
                    SizedBox(height: height / 60,),
                    // 1. code write
                    Expanded(
                        flex: 38,
                        child: _buildCodeText(),
                    ),
                    SizedBox(height: height / 60,),
                    // 2. compile and single step
                    Expanded(
                        flex: 2,
                        child: Row(children: [
                            _buildCompileButton(width),
                            SizedBox(width: width / 120,),
                            _buildSingleStepButton(width),
                            SizedBox(width: width / 30,),
                            _buildMemoryCheckButton(width),
                            SizedBox(width: width / 120,),
                            _buildMemoryAddrInput(width),
                        ],),
                    ),
                    SizedBox(height: height / 60,),
                ],)
            ),
            SizedBox(width: width / 60,),
            // second column: Processor state info, memory table, use two row
            Expanded(
                flex: 40,
                child: Column(children: [
                    SizedBox(height: height / 60,),
                    // 1. processor state info
                    Expanded(
                        flex: 12,
                        child: _buildProcessorStateInfo(width, height),
                    ),
                    SizedBox(height: height / 60,),
                    // 2. memory table
                    Expanded(
                        flex: 12,
                        child: _buildMemoryTable(width),
                    ),
                    SizedBox(height: height / 60,),
                ],)
            ),
            SizedBox(width: width / 60,),
            
        ],);
        
    }
}
