import 'package:binary/binary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helloworld/Uint32_ext.dart';
import 'package:helloworld/assembler.dart';
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
          title: Text('Lars'),
        ),
        body: MyTextPaginatingWidget(),
      ),
    );
  }
}

class MyTextPaginatingWidget extends StatefulWidget {
  @override
  _MyTextPaginatingWidgetState createState() => _MyTextPaginatingWidgetState();
}

class SecondPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Second Page'),
      ),
      body: Center(
        child: Text('This is the second page'),
      ),
    );
  }
}

class _MyTextPaginatingWidgetState extends State<MyTextPaginatingWidget> {
    TextEditingController _textEditingController = TextEditingController(), memtext_ctrl = TextEditingController();
    List<String> textLines = [];
    Assembler asm = Assembler([]);
    int mem_search = 0x1c000000;
    final ScrollController _scrollController = ScrollController();

    @override
    Widget build(BuildContext context) {
        final size = MediaQuery.of(context).size;
        return Column(
            children: [
                Expanded(
                    flex: 20,
                    child: Row(
                        children: [
                            Expanded(
                                flex: 4,
                                child: Container(
                                    decoration: BoxDecoration(
                                        border: Border.all(color: Colors.black),
                                        borderRadius: BorderRadius.all(Radius.circular(5.0)),
                                    ),
                                    child: SingleChildScrollView(
                                        child: TextField(
                                            controller: _textEditingController,
                                            maxLines: null,
                                            minLines: 10,
                                            expands: false,
                                            decoration: InputDecoration(
                                            labelText: '请输入LA32R汇编代码',
                                            border: InputBorder.none,
                                            
                                            ),
                                        ),
                                    ),
                                ),
                            ),
                            
                            Expanded(
                                flex: 4,
                                child: Container(
                                    decoration: BoxDecoration(
                                        border: Border.all(color: Colors.transparent),
                                        borderRadius: BorderRadius.all(Radius.circular(5.0)),
                                    ),
                                    child: ListView(
                                        controller: _scrollController,
                                        children:[
                                                
                                            Row(
                                                children: [
                                                    Expanded(
                                                        child: Center(
                                                            child:Text('PC: 0x${asm.pc.toInt().toRadixString(16)}\n')
                                                        ),
                                                        flex: 1
                                                    ),
                                                    Expanded(child: Center(child:Text('Inst: 0x${asm.inst_rec[asm.pc]==null?'NOP':asm.inst_rec[asm.pc]!.sentence}\n')), flex: 1,),
                                                ],
                                            
                                            ),
                                            for(int i = 0; i < 8; i++)
                                                Flex(direction: Axis.vertical,
                                                    children: [
                                                        Container(
                                                            height: 10,
                                                        ),
                                                        Row(children: [
                                                            for(int j = 0; j < 4; j++)
                                                                Flex(direction: Axis.horizontal, children: [
                                                                    Container(
                                                                        width: 20,
                                                                        decoration: BoxDecoration(
                                                                            color: Colors.transparent
                                                                        ),
                                                                    ),
                                                                    Container(
                                                                        width: 100,
                                                                        alignment: Alignment.center,
                                                                        decoration: BoxDecoration(
                                                                            color: Colors.green,
                                                                            border: Border.all(color: Colors.transparent),
                                                                            borderRadius: BorderRadius.all(Radius.circular(6))
                                                                        ),
                                                                        child: Center(child:Text('R${4*i+j}: 0x${asm.reg[4*i+j].toInt().toRadixString(16)}\n', style: TextStyle(fontWeight: FontWeight.bold),)),
                                                                    ),
                                                                    Container(
                                                                        width: 20,
                                                                        decoration: BoxDecoration(
                                                                            color: Colors.transparent
                                                                        ),
                                                                    ),
                                                                ],
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                                )
                                                            
                                                            
                                                            ],
                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                        ),
                                                        Container(
                                                            height: 10,
                                                        ),
                                                    ],
                                                )
                                                
                                            // endfor
                                        ],
                    
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
                Expanded(
                    flex: 10,
                    child: Table(
                        border: TableBorder.all(),
                        children: [
                            TableRow(
                                children: [
                                    Text(''),
                                    Text('+0'),
                                    Text('+4'),
                                    Text('+8'),
                                    Text('+C'),
                                ]
                            ),
                            for (int i = 0; i < 6; i++)
                                TableRow(
                                    children: [
                                        Text('0x${(mem_search + i*16).toRadixString(16)}'),
                                        Text(asm.memory[Uint32(mem_search + i*16)].toRadixString(16)+ ((asm.inst_rec[Uint32(mem_search + i*16)] != null) ? ' (' + asm.inst_rec[Uint32(mem_search + i*16)]!.sentence + ')' : '')),
                                        Text(asm.memory[Uint32(mem_search + i*16 + 4)].toRadixString(16)+ (asm.inst_rec[Uint32(mem_search + i*16 + 4)] != null ? ' (' + asm.inst_rec[Uint32(mem_search + i*16 + 4)]!.sentence + ')' : '')),
                                        Text(asm.memory[Uint32(mem_search + i*16 + 8)].toRadixString(16)+ (asm.inst_rec[Uint32(mem_search + i*16 + 8)] != null ? ' (' +asm.inst_rec[Uint32(mem_search + i*16 + 8)]!.sentence + ')' : '')),
                                        Text(asm.memory[Uint32(mem_search + i*16 + 12)].toRadixString(16)+ (asm.inst_rec[Uint32(mem_search + i*16 + 12)] != null ? ' (' +asm.inst_rec[Uint32(mem_search + i*16 + 12)]!.sentence + ')' : '')),
                                    ]
                                ),
                        ],
                    ),
                ),
                Expanded(
                    flex: 2,
                    child: Row(
                        children: [
                            ElevatedButton(
                                onPressed: () async {
                                    String text = _textEditingController.text;
                                    // Split the text into lines
                                    textLines = text.split('\n');
                                    asm = Assembler(textLines);
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
                            ElevatedButton(
                                child: Text('Go to second page'),
                                onPressed: () {
                                    Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => SecondPage()),
                                    );
                                },
                            ),
                            ElevatedButton(
                                child: Text('复制代码段'),
                                onPressed: () async{
                                    await Clipboard.setData(ClipboardData(text: _textEditingController.text));
                                },
                            ),
                            ElevatedButton(
                                onPressed: (){
                                    asm.cycle();
                                    setState(() {});
                                }, 
                                child: Text('单步执行')
                            ),
                            Container(
                                width: 200,
                                child: TextField(
                                    decoration: InputDecoration(
                                        hintText: '输入内存地址(16进制)',
                                        border: InputBorder.none,
                                    ),
                                    controller: memtext_ctrl,
                                    maxLines: 1,
                                ),
                                decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black),
                                    borderRadius: BorderRadius.all(Radius.circular(5.0)),
                                ),
                            ),
                            ElevatedButton(onPressed: (){
                                mem_search = int.parse(memtext_ctrl.text, radix: 16);
                                setState(() {});
                            }, child: Text('查看内存')),
                        ] 
                    ),
                    
                ),
            ],
        );
    }
}
