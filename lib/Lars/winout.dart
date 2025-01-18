import 'package:path_provider/path_provider.dart';
import 'dart:io';

void downloadTxtFile(String name, String textList) async{
    final directory = await getApplicationDocumentsDirectory();
    // directory.then((value) {
    final dir_str = directory.path;
    final dir = Directory("$dir_str/LARS_OUTFILES");
    dir.create().then((sub_dir) {
        final sub_dir_str = sub_dir.path;
        final file = File("$sub_dir_str/$name");
        file.create().then((value) => 
            value.writeAsString(textList, flush: true)
        );
    });
    // });
}