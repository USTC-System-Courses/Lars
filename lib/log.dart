// import 'Uint32_ext.dart';
import 'package:binary/binary.dart';
import 'package:LARS/Uint32_ext.dart';
import './assembler.dart';

class Info{
    final Uint32 pc;
    final (int index, Uint32 before_change, Uint32 after_change)? reg;
    final (Uint32 addr, Uint32 before_change, Uint32 after_change)? mem;
    Info(this.pc, this.reg, this.mem){}
    String print(Map<Uint32, SentenceBack> rec){
        String temp = "PC: ${pc.toInt().toRadixString(16)}\t\t";
        temp += ((rec[pc] == null) ? "" : rec[pc]!.sentence + "\n");
        temp += ((reg == null) ? "" : "\tR" + reg!.$1.toString() + " : " + reg!.$2.toInt().toRadixString(16) + " -> " + reg!.$3.toInt().toRadixString(16) + "\n");
        temp += ((mem == null) ? "" : "\tMEM " + mem!.$1.toInt().toRadixString(16) + " : " + mem!.$2.toInt().toRadixString(16) + " -> " + mem!.$3.toInt().toRadixString(16) + "\n");
        return temp;
    }
}

class Log{
    List<Info> _info = [];
    log(){}
    void SetLog(Uint32 pc, (int index, Uint32 before_change, Uint32 after_change)? reg, (Uint32 addr, Uint32 before_change, Uint32 after_change)? mem){
        if(reg != null && reg.$1 == 0) reg = null; 
        _info.add(Info(pc, reg, mem));
    }
    Info GetLog(){
        try{
            var temp = _info.last;
            _info.removeLast();
            return temp;
        } on StateError {
            return Info(Uint32(0x1c000000), null, null);
        }
    }
    String print(Map<Uint32, SentenceBack> rec){
        String temp = "";
        for(var i in _info){
            temp += (i.print(rec) + '\n');
        }
        return temp;
    }
}