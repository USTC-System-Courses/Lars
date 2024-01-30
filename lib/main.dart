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
    TextEditingController _textEditingController = TextEditingController();
    List<String> textLines = [];
    final ScrollController _scrollController = ScrollController();
    
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
                                minLines: 12,
                                decoration: InputDecoration(
                                labelText: '请输入LA32R汇编代码',
                                border: InputBorder.none,
                                ),
                            ),
                        ),
                    ),
                ),
                Expanded(
                    flex: 2,
                    child: Column(
                        children: [
                            ElevatedButton(
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
                            ElevatedButton(
                                child: Text('Go to second page'),
                                onPressed: () {
                                    Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => SecondPage()),
                                    );
                                },
                            ),
                        ] 
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
