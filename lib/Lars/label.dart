import 'package:binary/binary.dart';
import 'package:lars/Lars/exception.dart';

class Label{
    Map <String, Uint32> label = {};
    Label(){}
    bool add(String name, Uint32 address){
        RegExp reg = RegExp(r'\.?[A-Za-z0-9_]+:');
        if(!reg.hasMatch(name)){
            throw SentenceException(Exception_type.INVALID_LABEL, name);
        }
        if(label.containsKey(name)){
            return false;
        }
        name = name.replaceAll(':', '');
        label[name] = address;
        return true;
    }
    Uint32 find(String name){
        RegExp reg = RegExp(r'\.?[A-Za-z0-9_]+');
        if(!reg.hasMatch(name)){
            throw SentenceException(Exception_type.INVALID_LABEL, name);
        }
        name = name.replaceAll(':', '');
        if(!label.containsKey(name)){
            throw SentenceException(Exception_type.LABEL_NOT_FOUND, name);
        }
        return label[name]!;
    }
}