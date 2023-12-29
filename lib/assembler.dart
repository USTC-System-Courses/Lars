// import 'dart:ffi';
// import 'dart:js_util';

import 'package:binary/binary.dart';
import 'config.dart';
class Assembler{
    List<String> inst_input = [];
    List<Sentense> _inst = [];
    List<String> _machine_code = [];
    Assembler(List<String> temp){
        inst_input = temp;
        for (var element in inst_input) {
            _inst.add(Sentense(element));
        }
        for (var element in _inst) {
            _machine_code.add(element.print());
        }
    }
    List<String> print(){
        return _machine_code;
    }
}

class Sentense{
    String sentense = '';                               //输入的汇编指令
    String _machine_code = '';                           //输出的机器码(字符串形式)
    Uint32 _machine_code_i = Uint32(0);                  //输出的机器码
    Ins_type type = Ins_type.NOP;                       //指令类型
    List<String> sentense_spilt = [];                   //将输入的汇编指令按空格分词结果
    Uint32 rd = Uint32(0), rj = Uint32(0), rk = Uint32(0);  //寄存器编号
    Uint32 imm = Uint32(0);                             //立即数
    

    String _rename_register(String inst){
        String res = inst;
        var r21 = RegExp(r'$R21').allMatches(res);
        if(!r21.isEmpty) throw(Exception.RESTRICT_REG);
        res = res.replaceAll(r'$ZERO', r'$R0');
        res = res.replaceAll(r'$RA', r'$R1');
        res = res.replaceAll(r'$TP', r'$R2');
        res = res.replaceAll(r'$SP', r'$R3');
        res = res.replaceAll(r'$A0', r'$R4');
        res = res.replaceAll(r'$A1', r'$R5');
        res = res.replaceAll(r'$A2', r'$R6');
        res = res.replaceAll(r'$A3', r'$R7');
        res = res.replaceAll(r'$A4', r'$R8');
        res = res.replaceAll(r'$A5', r'$R9');
        res = res.replaceAll(r'$A6', r'$R10');
        res = res.replaceAll(r'$A7', r'$R11');
        res = res.replaceAll(r'$T0', r'$R12');
        res = res.replaceAll(r'$T1', r'$R13');
        res = res.replaceAll(r'$T2', r'$R14');
        res = res.replaceAll(r'$T3', r'$R15');
        res = res.replaceAll(r'$T4', r'$R16');
        res = res.replaceAll(r'$T5', r'$R17');
        res = res.replaceAll(r'$T6', r'$R18');
        res = res.replaceAll(r'$T7', r'$R19');
        res = res.replaceAll(r'$T8', r'$R20');
        res = res.replaceAll(r'$FP', r'$R22');
        res = res.replaceAll(r'$S9', r'$R22');
        res = res.replaceAll(r'$S0', r'$R23');
        res = res.replaceAll(r'$S1', r'$R24');
        res = res.replaceAll(r'$S2', r'$R25');
        res = res.replaceAll(r'$S3', r'$R26');
        res = res.replaceAll(r'$S4', r'$R27');
        res = res.replaceAll(r'$S5', r'$R28');
        res = res.replaceAll(r'$S6', r'$R29');
        res = res.replaceAll(r'$S7', r'$R30');
        res = res.replaceAll(r'$S8', r'$R31');
        return res;
    }

    Sentense(String temp){
        //将逗号替换为空格
        temp = temp.replaceAll(RegExp(','), ' ');
        //将所有制表符替换为空格
        temp = temp.replaceAll(RegExp(r'\t'), ' ');
        //将多个空格替换为一个空格
        temp = temp.replaceAll(RegExp(r' +'), ' ');
        //将所有点(.)删除
        temp = temp.replaceAll(RegExp(r'\.'), '');
        //将所有小写字母替换为大写字母
        temp = temp.toUpperCase();
        //将寄存器别名改为标准写法
        sentense = _rename_register(temp);
        //判断指令类型的合法性并赋值
        sentense_spilt = sentense.split(' ');
        if(!Ins_type.values.map((inst) => inst.toString()).contains('Ins_type.'+sentense_spilt.first)) throw(Exception.UNKNOWN_INST);
        type = Ins_type.values.byName(sentense_spilt.first);
        get_inst();
        _machine_code = _machine_code_i.toBinaryPadded();
    }

    String print(){
        return _machine_code;
    }

    void get_inst(){
        switch (type) {
            case Ins_type.NOP:
                break;
            case Ins_type.ADDW:
                _machine_code_i = Uint32(0x00100 << 12);
                break;
            case Ins_type.SUBW:
                _machine_code_i = Uint32(0x00101 << 12);
                break;
            default:
                break;
        }
        rd = Uint32(int.parse(sentense_spilt[1].substring(2))); //TODO异常处理寄存器超出范围
        rj = Uint32(int.parse(sentense_spilt[2].substring(2)));
        rk = Uint32(int.parse(sentense_spilt[3].substring(2)));
        _machine_code_i |= (rd << Uint32(10));
        _machine_code_i |= (rj << Uint32(5));
        _machine_code_i |= rk;
    }

    
}