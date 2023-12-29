import 'package:flutter/material.dart';
import 'package:helloworld/assembler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// import 'package:binary/binary.dart';

void main() => runApp(MyApp());

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

class _MyTextPaginatingWidgetState extends State<MyTextPaginatingWidget> {
    TextEditingController _textEditingController = TextEditingController();
    List<String> textLines = [];
    final ScrollController _scrollController = ScrollController();
    // Uint32 rd = Uint32(0);
    
    @override
    Widget build(BuildContext context) {
        return Row(
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
                                decoration: InputDecoration(
                                labelText: '请输入LA32R汇编代码',
                                border: InputBorder.none,
                                ),
                            ),
                        ),
                    ),
                ),
                Expanded(
                    flex: 1,
                    child: ElevatedButton(
                        onPressed: () async {
                            String text = _textEditingController.text;
                            // Split the text into lines
                            textLines = text.split('\n');
                            _scrollController.jumpTo(0);
                            setState(() {});

                            // Save the text to a file
                            final directory = await getApplicationDocumentsDirectory();
                            print(directory.path);
                            final file = File('${directory.path}/input.txt');
                            await file.writeAsString(text);
                        },
                        child: Text('显示文本'),
                    ),
                ),
                Expanded(
                    flex: 4,
                    child: Container(
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.all(Radius.circular(5.0)),
                        ),
                        child: ListView(
                            controller: _scrollController,
                            children:
                                Assembler(textLines).print().map((e) => Text(e)).toList(),
                        ),
                    ),
                ),
            ],
        );
    }
}
