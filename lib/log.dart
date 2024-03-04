// import 'Uint32_ext.dart';
import 'package:binary/binary.dart';

class Info{
    final Uint32 pc;
    final (int index, Uint32 before_change, Uint32 after_change)? reg;
    final (Uint32 addr, Uint32 before_change, Uint32 after_change)? mem;
    Info(this.pc, this.reg, this.mem){}
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
        } on StateError catch(e){
            return Info(Uint32(0x1c000000), null, null);
        }
    }
}