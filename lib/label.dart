import 'package:binary/binary.dart';
import 'package:helloworld/exception.dart';
import './Uint32_ext.dart';

class Label{
    Map <String, Uint32> label = {};
    Label(){}
    bool add(String name, Uint32 address){
        RegExp reg = RegExp(r'\.?[A-Za-z0-9_]+:');
        if(!reg.hasMatch(name)){
            throw SentenceException(Exception_type.INVALID_LABEL);
        }
        if(label.containsKey(name)){
            return false;
        }
        name = name.replaceAll(':', '');
        label[name] = address;
        return true;
    }
}