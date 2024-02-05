// import 'dart:ffi' as ffi;
// import 'dart:js_util';

import 'package:flutter/foundation.dart';

import './Uint32_ext.dart';
import 'package:binary/binary.dart';
import 'dart:core';
import 'config.dart';
import './memory.dart';
import './label.dart';
import './exception.dart';

class Assembler{
    List<String> inst_input = [];
    List<Sentence> _inst = [];
    List<String> _machine_code = [];
    Label _label = Label();
    Memory _memory = Memory();
    Assembler(List<String> temp){
        
        inst_input = temp;
        analyze_mode cur_mode = analyze_mode.TEXT;
        Uint32 text_build = Uint32(0x1c000000);
        Uint32 data_build = Uint32(0x1c800000);
        for (var element in inst_input) {
            try {
                if(cur_mode == analyze_mode.TEXT){
                    _inst.add(Sentence(element));
                    // _memory.write(text_build, Uint32(int.parse(_inst.last.print(), radix: 2)));
                    // text_build = text_build.add(4);
                }
                else{
                    //这里处理数据段的Label
                    String temp = process(element);
                    List<String> temp_spilt = temp.split(' ');
                    if(temp_spilt.first == '.TEXT:') throw LabelException(temp_spilt);
                    if(temp_spilt.length != 3) throw SentenceException(Exception_type.INVALID_LABEL);
                    switch (temp_spilt[1]) {
                        case '.BYTE':
                            _memory.write(data_build, Uint32(int.parse(temp_spilt[2])), size: 1);
                            _label.add(temp_spilt[0], data_build);
                            data_build = data_build.add(1);
                            break;
                        case '.HALF':
                            if (data_build.isSet(0)) data_build = data_build.add(1);
                            _memory.write(data_build, Uint32(int.parse(temp_spilt[2])), size: 2);
                            _label.add(temp_spilt[0], data_build);
                            data_build = data_build.add(2);
                            break;
                        case '.WORD':
                            if (data_build.isSet(0)) data_build = data_build.add(1);
                            if (data_build.isSet(1)) data_build = data_build.add(2);
                            _memory.write(data_build, Uint32(int.parse(temp_spilt[2])), size: 4);
                            _label.add(temp_spilt[0], data_build);
                            data_build = data_build.add(4);
                            break;
                        // case '.DWORD':
                        //     if (data_build.isSet(0)) data_build = data_build.add(1);
                        //     if (data_build.isSet(1)) data_build = data_build.add(2);
                        //     if (data_build.isSet(2)) data_build = data_build.add(4);
                        //     _memory.write(data_build, Uint32(int.parse(temp_spilt[2])), size: 8);
                        //     _label.add(temp_spilt[0], data_build);
                        //     data_build = data_build.add(8);
                        //     break;
                        case '.SPACE':
                            _label.add(temp_spilt[0], data_build);
                            for(int i = 0; i < int.parse(temp_spilt[2]); i++){
                                _memory.write(data_build, Uint32(0), size: 1);
                                data_build = data_build.add(1);
                            }
                            break;
                        default:
                            throw SentenceException(Exception_type.INVALID_LABEL);
                    }
                }
            } on LabelException catch (e) {
                //TODO:
                var spilt = e.Sentence_Spilt;
                //这里切换模式
                if(spilt.first == '.DATA:'){
                    cur_mode = analyze_mode.DATA;
                    if (spilt.length != 1) throw SentenceException(Exception_type.INVALID_SEGMENT);
                }
                else if(spilt.first == '.TEXT:'){
                    cur_mode = analyze_mode.TEXT;
                    if (spilt.length != 1) throw SentenceException(Exception_type.INVALID_SEGMENT);
                }
                //这里处理代码段的Label
                else{
                    _label.add(spilt.first, text_build);
                    _inst.add(Sentence(element.replaceAll(RegExp(r'.*:'), '')));
                    _inst.last.addr = text_build;
                    _memory.write(text_build, Uint32(int.parse(_inst.last.print(), radix: 2)));
                    text_build = text_build.add(4);
                }
            }
        }
        for (var element in _inst) {
            if((with_label.contains(element.type) || with_LDST.contains(element.type)) && element.imm == Uint32.zero){
                var addr = _label.find(element.sentence_spilt.last);
                var temp = judge(element, addr);
                if(temp != 0){
                    element.imm = Uint32(temp);
                    if(with_label16.contains(element)) {
                        element._machine_code_i |= element.imm.bitRange(15, 0) << Uint32(10);
                    }
                    else if(with_label26.contains(element)){
                        element._machine_code_i |= element.imm.bitRange(15, 0) << Uint32(10);
                        element._machine_code_i |= element.imm.bitRange(25, 16);
                    }
                    else{
                        element._machine_code_i |= element.imm.bitRange(11, 0) << Uint32(10);
                    }
                }
                else throw SentenceException(Exception_type.LABEL_TOO_FAR);
            }
            _memory.write(text_build, Uint32(int.parse(element.print(), radix: 2)));
            _inst.last.addr = text_build;
            text_build = text_build.add(4);
            _machine_code.add(element.print());
        }
    }

    int judge(Sentence a, Uint32 addr){
        if (with_label16.contains(a.type) && ((a.addr - addr) < -(1 << 15) || (a.addr - addr) > (1 << 15) - 1)) return ((a.addr - addr));
        else if (with_label26.contains(a.type) && ((a.addr - addr) < -(1 << 25) || (a.addr - addr) > (1 << 25) - 1)) return ((a.addr - addr));
        else if (with_LDST.contains(a.type) && ((a.addr - addr) < -(1 << 11) || (a.addr - addr) > (1 << 11) - 1)) return a.addr - addr;
        else return 0;
    }

    List<Uint32> reg = List.filled(32, Uint32.zero);
    Uint32 pc = Uint32(0x1c000000);

    void cycle(){
        Uint32 ins = _memory.read(pc);
        int rd = ins.bitRange(4, 0).toInt(), rj = ins.bitRange(9, 5).toInt(), rk = ins.bitRange(14, 10).toInt();
        int ui12 = ins.bitRange(21, 10).toInt(), ui5 = ins.bitRange(14, 10).toInt();
        int si12 = ins.getBit(21) == 1 ? (~(ins.bitRange(21, 10).signExtend(12))).add(1).toInt():ui12;
        switch(get_inst_type(ins)){
            case Ins_type.NOP:
                pc = pc.add(4);
                break;
            case Ins_type.ADDW:
                reg[rd] = reg[rj].add32(reg[rk]);
                pc = pc.add(4);
                break;
            
        }
    }

    Ins_type get_inst_type(Uint32 ins){
        if(ins.getBit(30) == 1)
            switch(ins.bitRange(31, 26).toInt()){
                case 0x13: return Ins_type.JIRL;
                case 0x14: return Ins_type.B;
                case 0x15: return Ins_type.BL;
                case 0x16: return Ins_type.BEQ;
                case 0x17: return Ins_type.BNE;
                case 0x18: return Ins_type.BLT;
                case 0x19: return Ins_type.BGE;
                case 0x1A: return Ins_type.BLTU;
                case 0x1B: return Ins_type.BGEU;
                default: throw MemoryException(MEM_EXP_type.UNEXPECTED_MEM_ERROR);
            }
        else if (ins.getBit(29) == 1) 
            switch(ins.bitRange(31, 22).toInt()){
                case 0xA0: return Ins_type.LDB;
                case 0xA1: return Ins_type.LDH;
                case 0xA2: return Ins_type.LDW;
                case 0xA4: return Ins_type.STB;
                case 0xA5: return Ins_type.STH;
                case 0xA6: return Ins_type.STW;
                case 0xA8: return Ins_type.LDBU;
                case 0xA9: return Ins_type.LDHU;
                default: throw MemoryException(MEM_EXP_type.UNEXPECTED_MEM_ERROR);
            }
        else if (ins.getBit(28) == 1)
            switch(ins.bitRange(31, 25).toInt()){
                case 0x0C: return Ins_type.LU12IW;
                case 0x0E: return Ins_type.PCADDU12I;
                default: throw MemoryException(MEM_EXP_type.UNEXPECTED_MEM_ERROR);
            }
        else if (ins.getBit(25) == 1)
            switch(ins.bitRange(31, 22).toInt()){
                case 0x08: return Ins_type.SLTI;
                case 0x09: return Ins_type.SLTUI;
                case 0x0A: return Ins_type.ADDIW;
                case 0x0D: return Ins_type.ANDI;
                case 0x0E: return Ins_type.ORI;
                case 0x0F: return Ins_type.XORI;
                default: throw MemoryException(MEM_EXP_type.UNEXPECTED_MEM_ERROR);
            }
        else
            switch(ins.bitRange(31, 12).toInt()){
                case 0x00100: return Ins_type.ADDW;
                case 0x00110: return Ins_type.SUBW;
                case 0x00120: return Ins_type.SLT;
                case 0x00128: return Ins_type.SLTU;
                case 0x00140: return Ins_type.NOR;
                case 0x00148: return Ins_type.AND;
                case 0x00150: return Ins_type.OR;
                case 0x00158: return Ins_type.XOR;
                case 0x00170: return Ins_type.SLLW;
                case 0x00178: return Ins_type.SRLW;
                case 0x00180: return Ins_type.SRAW;
                case 0x001C0: return Ins_type.MULW;
                case 0x001C8: return Ins_type.MULHW;
                case 0x001D0: return Ins_type.MULHWU;
                case 0x00200: return Ins_type.DIVW;
                case 0x00208: return Ins_type.MODW;
                case 0x00210: return Ins_type.DIVWU;
                case 0x00218: return Ins_type.MODWU;
                case 0x00408: return Ins_type.SLLIW;
                case 0x00448: return Ins_type.SRLIW;
                case 0x00488: return Ins_type.SRAIW;
                case 0: return Ins_type.NOP;
                default: throw MemoryException(MEM_EXP_type.UNEXPECTED_MEM_ERROR);
            }
    }

    List<String> print(){
        return _machine_code;
    }
}

String process(String temp){
    //将逗号替换为空格
    temp = temp.replaceAll(RegExp(','), ' ');
    temp = temp.replaceAll(RegExp(r'#.*'), '');
    //将所有制表符替换为空格
    temp = temp.replaceAll(RegExp(r'\t'), ' ');
    //将多个空格替换为一个空格
    temp = temp.replaceAll(RegExp(r' +'), ' ');
    //将所有小写字母替换为大写字母
    temp = temp.toUpperCase();
    //保留代码段和数据段的标识符
    temp = temp.replaceAll(RegExp(r'.DATA'), '\$DATA');
    temp = temp.replaceAll(RegExp(r'.TEXT'), '\$TEXT');
    temp = temp.replaceAll(RegExp(r'.BYTE'), '\$BYTE');
    temp = temp.replaceAll(RegExp(r'.HALF'), '\$HALF');
    temp = temp.replaceAll(RegExp(r'.WORD'), '\$WORD');
    // temp = temp.replaceAll(RegExp(r'.DWORD'), '\$DWORD');
    temp = temp.replaceAll(RegExp(r'.SPACE'), '\$SPACE');
    //将所有点(.)删除
    temp = temp.replaceAll(RegExp(r'\.'), '');//TODO: ADDW这种可能会遮掩问题
    //还原代码段/数据段的标识符
    temp = temp.replaceAll(RegExp(r'\$DATA'), '.DATA:');
    temp = temp.replaceAll(RegExp(r'\$TEXT'), '.TEXT:');
    temp = temp.replaceAll(RegExp(r'\$BYTE'), '.BYTE');
    temp = temp.replaceAll(RegExp(r'\$HALF'), '.HALF');
    temp = temp.replaceAll(RegExp(r'\$WORD'), '.WORD');
    // temp = temp.replaceAll(RegExp(r'$DWORD'), '.DWORD');
    temp = temp.replaceAll(RegExp(r'\$SPACE'), '.SPACE');
    return temp;
}

class Sentence{
    String sentence = '';                               //输入的汇编指令
    Uint32 _machine_code_i = Uint32(0);                  //输出的机器码
    
    Ins_type type = Ins_type.NOP;                       //指令类型
    List<String> sentence_spilt = [];                   //将输入的汇编指令按空格分词结果
    Uint32 rd = Uint32(0), rj = Uint32(0), rk = Uint32(0);  //寄存器编号
    Uint32 imm = Uint32(0);                             //立即数
    
    Uint32 addr = Uint32(0);                            //指令所在内存地址
    
    

    Sentence(String temp){
        if(temp == '') return;
        temp = process(temp);
        //将寄存器别名改为标准写法
        sentence = _rename_register(temp);
        //判断指令类型的合法性并赋值
        sentence_spilt = sentence.split(' ');
        if(!Ins_type.values.map((inst) => inst.toString()).contains('Ins_type.' + sentence_spilt.first)) {
            if(sentence_spilt.first == '.DATA:' || sentence_spilt.first == '.TEXT:') throw LabelException(sentence_spilt);
            else if(RegExp(r'\.?[A-Za-z0-9_]+:').hasMatch(sentence_spilt.first)) throw LabelException(sentence_spilt);
            else throw SentenceException(Exception_type.UNKNOWN_INST);
        }
        type = Ins_type.values.byName(sentence_spilt.first);
        get_inst();
    }

    String print(){
        return _machine_code_i.toBinaryPadded();
    }
    
    String _rename_register(String inst){
        String res = inst;
        var r21 = RegExp(r'$R21').allMatches(res);
        if(!r21.isEmpty) throw SentenceException(Exception_type.RESTRICT_REG);
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

    void get_inst(){
        switch (type) {
            case Ins_type.NOP:
                break;
            case Ins_type.ADDW:
                _machine_code_i = Uint32(0x00100 << 12);
                break;
            case Ins_type.SUBW:
                _machine_code_i = Uint32(0x00110 << 12);
                break;
            case Ins_type.SLT:
                _machine_code_i = Uint32(0x00120 << 12);
                break;
            case Ins_type.SLTU:
                _machine_code_i = Uint32(0x00128 << 12);
                break;
            case Ins_type.NOR:
                _machine_code_i = Uint32(0x00140 << 12);
                break;
            case Ins_type.AND:
                _machine_code_i = Uint32(0x00148 << 12);
                break;
            case Ins_type.OR:
                _machine_code_i = Uint32(0x00150 << 12);
                break;
            case Ins_type.XOR:
                _machine_code_i = Uint32(0x00158 << 12);
                break;
            case Ins_type.SLLW:
                _machine_code_i = Uint32(0x00170 << 12);
                break;
            case Ins_type.SRLW:
                _machine_code_i = Uint32(0x00178 << 12);
                break;
            case Ins_type.SRAW:
                _machine_code_i = Uint32(0x00180 << 12);
                break;
            case Ins_type.MULW:
                _machine_code_i = Uint32(0x001C0 << 12);
                break;
            case Ins_type.MULHW:
                _machine_code_i = Uint32(0x001C8 << 12);
                break;
            case Ins_type.MULHWU:
                _machine_code_i = Uint32(0x001D0 << 12);
                break;
            case Ins_type.DIVW:
                _machine_code_i = Uint32(0x00200 << 12);
                break;
            case Ins_type.MODW:
                _machine_code_i = Uint32(0x00208 << 12);
                break;
            case Ins_type.DIVWU:
                _machine_code_i = Uint32(0x00210 << 12);
                break;
            case Ins_type.MODWU:
                _machine_code_i = Uint32(0x00218 << 12);
                break;
            case Ins_type.SLLIW:
                _machine_code_i = Uint32(0x00408 << 12);
                break;
            case Ins_type.SRLIW:
                _machine_code_i = Uint32(0x00448 << 12);
                break;
            case Ins_type.SRAIW:
                _machine_code_i = Uint32(0x00488 << 12);
                break;
            case Ins_type.SLTI:
                _machine_code_i = Uint32(0x08 << 22);
                break;
            case Ins_type.SLTUI:
                _machine_code_i = Uint32(0x09 << 22);
                break;
            case Ins_type.ADDIW:
                _machine_code_i = Uint32(0x0A << 22);
                break;
            case Ins_type.ANDI:
                _machine_code_i = Uint32(0x0D << 22);
                break;
            case Ins_type.ORI:
                _machine_code_i = Uint32(0x0E << 22);
                break;
            case Ins_type.XORI:
                _machine_code_i = Uint32(0x0F << 22);
                break;
            case Ins_type.LU12IW:
                _machine_code_i = Uint32(0x0C << 25);
                break;
            case Ins_type.PCADDU12I:
                _machine_code_i = Uint32(0x0E << 25);
                break;
            case Ins_type.LDB:
                _machine_code_i = Uint32(0xA0 << 22);
                break;
            case Ins_type.LDH:
                _machine_code_i = Uint32(0xA1 << 22);
                break;
            case Ins_type.LDW:
                _machine_code_i = Uint32(0xA2 << 22);
                break;
            case Ins_type.STB:
                _machine_code_i = Uint32(0xA4 << 22);
                break;
            case Ins_type.STH:
                _machine_code_i = Uint32(0xA5 << 22);
                break;
            case Ins_type.STW:
                _machine_code_i = Uint32(0xA6 << 22);
                break;
            case Ins_type.LDBU:
                _machine_code_i = Uint32(0xA8 << 22);
                break;
            case Ins_type.LDHU:
                _machine_code_i = Uint32(0xA9 << 22);
                break;
            case Ins_type.JIRL:
                _machine_code_i = Uint32(0x13 << 26);
                break;
            case Ins_type.B:
                _machine_code_i = Uint32(0x14 << 26);
                break;
            case Ins_type.BL:
                _machine_code_i = Uint32(0x15 << 26);
                break;
            case Ins_type.BEQ:
                _machine_code_i = Uint32(0x16 << 26);
                break;
            case Ins_type.BNE:
                _machine_code_i = Uint32(0x17 << 26);
                break;
            case Ins_type.BLT:
                _machine_code_i = Uint32(0x18 << 26);
                break;
            case Ins_type.BGE:
                _machine_code_i = Uint32(0x19 << 26);
                break;
            case Ins_type.BLTU:
                _machine_code_i = Uint32(0x1A << 26);
                break;
            case Ins_type.BGEU:
                _machine_code_i = Uint32(0x1B << 26);
                break;
            default:
                break;
        }
        
        //TODO异常处理寄存器超出范围
        if(!without_rd.contains(type)) {
            rd = Uint32(int.parse(sentence_spilt[1].substring(2)));
            if(rd > Uint32(31)) throw SentenceException(Exception_type.REG_OUT_OF_RANGE);
            _machine_code_i |= rd;
        } 
        if(!without_rj.contains(type)) {
            rj = Uint32(int.parse(sentence_spilt[2].substring(2)));
            if(rj > Uint32(31)) throw SentenceException(Exception_type.REG_OUT_OF_RANGE);
            _machine_code_i |= (rj << Uint32(5));
        }
        if(!without_rk.contains(type)) {
            rk = Uint32(int.parse(sentence_spilt[3].substring(2)));
            if(rk > Uint32(31)) throw SentenceException(Exception_type.REG_OUT_OF_RANGE);
            _machine_code_i |= (rk << Uint32(10));
        }
        if(with_ui5.contains(type)) {
            imm = Uint32(int.parse(sentence_spilt[3]));
            if(imm > Uint32(31)) throw SentenceException(Exception_type.IMM_OUT_OF_RANGE);
            _machine_code_i |= (imm << Uint32(10));
        }
        if(with_ui12.contains(type)) {
            imm = Uint32(int.parse(sentence_spilt[3]));
            if(imm > Uint32(4095)) throw SentenceException(Exception_type.IMM_OUT_OF_RANGE);
            _machine_code_i |= (imm << Uint32(10));
        }
        if(with_si12.contains(type)) {
            imm = Uint32(int.parse(sentence_spilt[3]));
            if(imm > Uint32(4095)) throw SentenceException(Exception_type.IMM_OUT_OF_RANGE);
            _machine_code_i |= (imm << Uint32(10));
        }
        if(with_label16.contains(type)) {
            RegExp regnum16 = RegExp(r'^0x[0-9A-F]+$'), regnum10 = RegExp(r'^[0-9]+$');
            if(regnum16.hasMatch(sentence_spilt[3])){
                imm = Uint32(int.parse(sentence_spilt[3].substring(2), radix: 16));
            }
            else if(regnum10.hasMatch(sentence_spilt[3])){
                imm = Uint32(int.parse(sentence_spilt[3]));
            }
            
        }
    }
    
}