// import 'dart:ffi' as ffi;
// import 'dart:js_util';

import './Uint32_ext.dart';
import 'package:binary/binary.dart';
import 'dart:core';
import 'config.dart';
import './memory.dart';
import './label.dart';
import './exception.dart';


class Assembler{
    List<String> inst_input = [];
    List<SentenceBack> _inst = [];
    List<String> _machine_code = [];
    Label _label = Label();
    Memory memory = Memory();
    Map<Uint32, SentenceBack> inst_rec = {};
    bool _isEnd = false;
    Assembler(List<String> temp){
        _isEnd = false;
        inst_input = temp;
        analyze_mode cur_mode = analyze_mode.TEXT;
        Uint32 text_build = Uint32_t(0x1c000000);
        Uint32 data_build = Uint32_t(0x1c800000);
        for (var element in inst_input){
            try {
                if(cur_mode == analyze_mode.TEXT){
                    var _elem = Sentence(element);
                    var elem1 = SentenceBack(_elem, false);
                    _inst.add(elem1);
                    text_build = text_build.add(4);
                    if(_elem.isdouble){
                        var elem2 = SentenceBack(_elem, true);
                        _inst.add(elem2);
                        text_build = text_build.add(4);
                    }

                    // memory.write(text_build, Uint32_t(int.parse(_inst.last.print(), radix: 2)));
                    // text_build = text_build.add(4);
                }
                else{
                    //这里处理数据段的Label
                    String temp = process(element);
                    List<String> temp_spilt = temp.split(' ');
                    if(temp_spilt.first == '.TEXT:') throw LabelException(temp_spilt);
                    if(temp_spilt.length != 3) throw SentenceException(Exception_type.INVALID_LABEL, element);
                    switch (temp_spilt[1]) {
                        case '.BYTE':
                            memory.write(data_build, Uint32_t((int.parse(temp_spilt[2]) & UI32_mask)), size: 1);
                            _label.add(temp_spilt[0], data_build);
                            data_build = data_build.add(1);
                            break;
                        case '.HALF':
                            if (data_build.isSet(0)) data_build = data_build.add(1);
                            memory.write(data_build, Uint32_t((int.parse(temp_spilt[2]) & UI32_mask)), size: 2);
                            _label.add(temp_spilt[0], data_build);
                            data_build = data_build.add(2);
                            break;
                        case '.WORD':
                            if (data_build.isSet(0)) data_build = data_build.add(1);
                            if (data_build.isSet(1)) data_build = data_build.add(2);
                            memory.write(data_build, Uint32_t((int.parse(temp_spilt[2]) & UI32_mask)), size: 4);
                            _label.add(temp_spilt[0], data_build);
                            data_build = data_build.add(4);
                            break;
                        // case '.DWORD':
                        //     if (data_build.isSet(0)) data_build = data_build.add(1);
                        //     if (data_build.isSet(1)) data_build = data_build.add(2);
                        //     if (data_build.isSet(2)) data_build = data_build.add(4);
                        //     memory.write(data_build, Uint32_t(int.parse(temp_spilt[2])), size: 8);
                        //     _label.add(temp_spilt[0], data_build);
                        //     data_build = data_build.add(8);
                        //     break;
                        case '.SPACE':
                            _label.add(temp_spilt[0], data_build);
                            for(int i = 0; i < int.parse(temp_spilt[2]); i++){
                                memory.write(data_build, Uint32_t(0), size: 1);
                                data_build = data_build.add(1);
                            }
                            break;
                        default:
                            throw SentenceException(Exception_type.INVALID_LABEL, element);
                    }
                }
            } on LabelException catch (e) {
                var spilt = e.Sentence_Spilt;
                //这里切换模式
                if(spilt.first == '.DATA:'){
                    cur_mode = analyze_mode.DATA;
                    if (spilt.length != 1) throw SentenceException(Exception_type.INVALID_SEGMENT, element);
                }
                else if(spilt.first == '.TEXT:'){
                    cur_mode = analyze_mode.TEXT;
                    if (spilt.length != 1) throw SentenceException(Exception_type.INVALID_SEGMENT, element);
                }
                //这里处理代码段的Label
                else{
                    _label.add(spilt.first, text_build);
                    var sen_temp = Sentence(element.replaceAll(RegExp(r'^[^:]*:'), ''));
                    var elem1 = SentenceBack(sen_temp, false);
                    _inst.add(elem1);
                    text_build = text_build.add(4);
                    if(sen_temp.isdouble){
                        var elem2 = SentenceBack(sen_temp, true);
                        _inst.add(elem2);
                        text_build = text_build.add(4);
                    }
                    // _inst.add(Sentence(element.replaceAll(RegExp(r'^[^:]*:'), '')));
                    // _inst.last.addr = text_build;
                    // memory.write(text_build, Uint32_t((int.parse(_inst.last.print(), radix: 2) & UI32_mask)));
                    // text_build = text_build.add(4);
                }
            }
        }
        text_build = Uint32_t(0x1c000000);
        for (var element in _inst) {
            element.addr = text_build;
            if((with_label.contains(element.type)) || element.gen_by_lalocal){
                var addr = _label.find(element.sentence_spilt.last);//标签的地址
                var valid = judge(element, addr);
                if(valid){
                    var pc_offset = Uint32_t(element.addr - addr);
                    var absolute  = addr;
                    if(with_label16.contains(element.type)) {
                        element.machine_code |= pc_offset.bitRange(17, 2) << Uint32_t(10);
                    }
                    else if(with_label26.contains(element.type)){
                        element.machine_code |= pc_offset.bitRange(17, 2) << Uint32_t(10);
                        element.machine_code |= pc_offset.bitRange(27, 18);
                    }
                    else{
                        if(element.type == Ins_type.LU12IW){
                            element.machine_code |= absolute.bitRange(31, 12) << Uint32_t(5);
                            element.sentence_spilt[2] = '0x' + absolute.bitRange(31, 12).toInt().toRadixString(16);
                            element.sentence = element.sentence_spilt.join(' ');
                        }else{
                            element.machine_code |= absolute.bitRange(11, 0) << Uint32_t(10);
                            element.sentence_spilt[3] = '0x' + absolute.bitRange(11, 0).toInt().toRadixString(16);
                            element.sentence = element.sentence_spilt.join(' ');
                        }
                    }
                }
                else throw SentenceException(Exception_type.LABEL_TOO_FAR, element.sentence_ori);
            }
            if(element.type != Ins_type.NULL){
                memory.write(text_build, Uint32_t(int.parse(element.print(), radix: 2)));
                if(inst_rec.containsKey(text_build)){
                    inst_rec[text_build] = element;
                }
                else inst_rec.putIfAbsent(text_build, () => (element));
                text_build = text_build.add(4);
                _machine_code.add(element.print());
            }
        }
    }

    bool judge(SentenceBack a, Uint32 addr){
        if (with_label16.contains(a.type) && ((a.addr - addr) > -(1 << 15) || (a.addr - addr) < (1 << 15) - 1)) return true;
        else if (with_label26.contains(a.type) && ((a.addr - addr) > -(1 << 25) || (a.addr - addr) < (1 << 25) - 1)) return true;
        else if(a.gen_by_lalocal) return true;
        else return false;
    }

    List<Uint32> reg = List.filled(32, Uint32.zero);
    Uint32 pc = Uint32_t(0x1c000000);

    List print_reg(){
        List<String> res = [];
        res.add('PC: ${pc.toInt().toRadixString(16)}');
        for(int i = 0; i < 32; i++){
            res.add('R$i: ${reg[i].toInt().toRadixString(16)}');
        }
        return res;
    }

    void cycle(){
        if(_isEnd) return;
        Uint32 ins = memory.read(pc);
        int rd = ins.bitRange(4, 0).toInt(), rj = ins.bitRange(9, 5).toInt(), rk = ins.bitRange(14, 10).toInt();
        int ui12 = ins.bitRange(21, 10).toInt(), ui5 = ins.bitRange(14, 10).toInt();
        int si12 = ins.getBit(21) == 1 ? (ins.bitRange(21, 10).signExtend(11)).toSignedInt():ui12;
        int ui20 = ins.bitRange(24, 5).toInt();
        int si20 = ins.getBit(24) == 1 ? (ins.bitRange(24, 5).signExtend(19)).toSignedInt():ui20;
        int ui16 = ins.bitRange(25, 10).toInt();
        int si16 = ins.getBit(25) == 1 ? (ins.bitRange(25, 10).signExtend(15)).toSignedInt():ui16;
        int ui26 = (ins.bitRange(25, 10) + ins.bitRange(9, 0) << Uint32_t(15)).toInt();
        int si26 = ins.getBit(9) == 1 ? (ins.bitRange(25, 10) + ins.bitRange(9, 0) << Uint32_t(16)).signExtend(25).toSignedInt():ui26;
        switch(get_inst_type(ins)){
            case Ins_type.BREAK:
            case Ins_type.NULL:
                _isEnd = true;
                break;
            case Ins_type.NOP:
                pc = pc.add(4);
                break;
            case Ins_type.ADDW:
                if(rd != 0) reg[rd] = reg[rj] + reg[rk];
                pc = pc.add(4);
                break;
            case Ins_type.SUBW:
                if(rd != 0) reg[rd] = Uint32_t((reg[rj] - reg[rk]) & UI32_mask);
                pc = pc.add(4);
                break;
            case Ins_type.SLT:
                if(rd != 0) reg[rd] = reg[rj].toSignedInt() < reg[rk].toSignedInt() ? Uint32_t(1) : Uint32_t(0);
                pc = pc.add(4);
                break;
            case Ins_type.SLTU:
                if(rd != 0) reg[rd] = reg[rj] < reg[rk] ? Uint32_t(1) : Uint32_t(0);
                pc = pc.add(4);
                break;
            case Ins_type.NOR:
                if(rd != 0) reg[rd] = ~(reg[rj] | reg[rk]);
                pc = pc.add(4);
                break;
            case Ins_type.AND:
                if(rd != 0) reg[rd] = reg[rj] & reg[rk];
                pc = pc.add(4);
                break;
            case Ins_type.OR:
                if(rd != 0) reg[rd] = reg[rj] | reg[rk];
                pc = pc.add(4);
                break;
            case Ins_type.XOR:
                if(rd != 0) reg[rd] = reg[rj] ^ reg[rk];
                pc = pc.add(4);
                break;
            case Ins_type.SLLW:
                if(rd != 0) reg[rd] = reg[rj] << (reg[rk].bitRange(4, 0));
                pc = pc.add(4);
                break;
            case Ins_type.SRLW:
                if(rd != 0) {
                    if(reg[rk] != Uint32.zero) {
                        reg[rd] = reg[rj] >> Uint32_t(1);
                        reg[rd] = reg[rd].clearBit(31);
                        reg[rd] = reg[rd] >> Uint32_t((reg[rk] - Uint32_t(1)) & UI32_mask);
                    }
                    else reg[rd] = reg[rj];
                }
                pc = pc.add(4);
                break;
            case Ins_type.SRAW:
                if(rd != 0) reg[rd] = reg[rj] >> (reg[rk]);
                pc = pc.add(4);
                break;
            case Ins_type.MULW:
                if(rd != 0) reg[rd] = Uint32_t(reg[rj].toSignedInt() * reg[rk].toSignedInt() & UI32_mask);
                pc = pc.add(4);
                break;
            case Ins_type.MULHW:
                if(rd != 0) reg[rd] = Uint32_t((reg[rj].toSignedInt() * reg[rk].toSignedInt() >> 32) & UI32_mask);
                pc = pc.add(4);
                break;
            case Ins_type.MULHWU:
                if(rd != 0) reg[rd] = Uint32_t((reg[rj].toInt() * reg[rk].toInt() >> 32) & UI32_mask);
                pc = pc.add(4);
                break;
            case Ins_type.DIVW:
                if(rd != 0) reg[rd] = Uint32_t(reg[rj].toSignedInt() ~/ reg[rk].toSignedInt());
                pc = pc.add(4);
                break;
            case Ins_type.MODW:
                if(rd != 0) reg[rd] = Uint32_t(reg[rj].toSignedInt() % reg[rk].toSignedInt());
                pc = pc.add(4);
                break;
            case Ins_type.DIVWU:
                if(rd != 0) reg[rd] = Uint32_t(reg[rj].toInt() ~/ reg[rk].toInt());
                pc = pc.add(4);
                break;
            case Ins_type.MODWU:
                if(rd != 0) reg[rd] = Uint32_t(reg[rj].toInt() % reg[rk].toInt());
                pc = pc.add(4);
                break;
            case Ins_type.SLLIW:
                if(rd != 0) reg[rd] = reg[rj] << Uint32_t(ui5);
                pc = pc.add(4);
                break;
            case Ins_type.SRLIW:
                if(rd != 0) {
                    if(ui5 != 0){
                        reg[rd] = reg[rj] >> Uint32_t(1);
                        reg[rd] = reg[rd].clearBit(31);
                        reg[rd] = reg[rd] >> Uint32_t(ui5 - 1);
                    }
                    else {
                    reg[rd] = reg[rj];
                    }
                }
                pc = pc.add(4);
                break;
            case Ins_type.SRAIW:
                if(rd != 0) reg[rd] = reg[rj] >> Uint32_t(ui5);
                pc = pc.add(4);
                break;
            case Ins_type.SLTI:
                if(rd != 0) reg[rd] = reg[rj].toSignedInt() < si12 ? Uint32_t(1) : Uint32_t(0);
                pc = pc.add(4);
                break;
            case Ins_type.SLTUI:
                if(rd != 0) reg[rd] = reg[rj] < Uint32_t(ui12) ? Uint32_t(1) : Uint32_t(0);
                pc = pc.add(4);
                break;
            case Ins_type.ADDIW:
                if(rd != 0) reg[rd] = Uint32_t((reg[rj].toSignedInt() + si12) & UI32_mask);
                pc = pc.add(4);
                break;
            case Ins_type.ANDI:
                if(rd != 0) reg[rd] = reg[rj] & Uint32_t(ui12);
                pc = pc.add(4);
                break;
            case Ins_type.ORI:
                if(rd != 0) reg[rd] = reg[rj] | Uint32_t(ui12);
                pc = pc.add(4);
                break;
            case Ins_type.XORI:
                if(rd != 0) reg[rd] = reg[rj] ^ Uint32_t(ui12);
                pc = pc.add(4);
                break;
            case Ins_type.LU12IW:
                if(rd != 0) reg[rd] = Uint32_t(si20) << Uint32_t(12);
                pc = pc.add(4);
                break;
            case Ins_type.PCADDU12I:
                if(rd != 0) reg[rd] = pc.add(si20 << 12);
                pc = pc.add(4);
                break;
            case Ins_type.LDB:
                if(rd != 0) reg[rd] = memory.read(reg[rj].add(si12), size: 1).signExtend(7);
                pc = pc.add(4);
                break;
            case Ins_type.LDH:
                if(rd != 0) reg[rd] = memory.read(reg[rj].add(si12), size: 2).signExtend(15);
                pc = pc.add(4);
                break;
            case Ins_type.LDW:
                if(rd != 0) reg[rd] = memory.read(reg[rj].add(si12), size: 4);
                pc = pc.add(4);
                break;
            case Ins_type.STB:
                memory.write(reg[rj].add(si12), reg[rd], size: 1);
                pc = pc.add(4);
                break;
            case Ins_type.STH:
                memory.write(reg[rj].add(si12), reg[rd], size: 2);
                pc = pc.add(4);
                break;
            case Ins_type.STW:
                memory.write(reg[rj].add(si12), reg[rd], size: 4);
                pc = pc.add(4);
                break;
            case Ins_type.LDBU:
                if(rd != 0) reg[rd] = memory.read(reg[rj].add(si12), size: 1);
                pc = pc.add(4);
                break;
            case Ins_type.LDHU:
                if(rd != 0) reg[rd] = memory.read(reg[rj].add(si12), size: 2);
                pc = pc.add(4);
                break;
            case Ins_type.JIRL:
                if(rd != 0) reg[rd] = pc.add(4);
                pc = reg[rj] + Uint32_t(si16 << 2).signExtend(17);
                break;
            case Ins_type.B:
                pc = pc + Uint32_t(si26 << 2).signExtend(27);
                break;
            case Ins_type.BL:
                reg[1] = pc.add(4);
                pc = pc + Uint32_t(si26 << 2).signExtend(27);
                break;
            case Ins_type.BEQ:
                pc = reg[rj] == reg[rd] ? pc + Uint32_t(si16 << 2).signExtend(17) : pc.add(4);
                break;
            case Ins_type.BNE:
                pc = reg[rj] != reg[rd] ? pc + Uint32_t(si16 << 2).signExtend(17) : pc.add(4);
                break;
            case Ins_type.BLT:
                pc = reg[rj].toSignedInt() < reg[rd].toSignedInt() ? pc + Uint32_t(si16 << 2).signExtend(17) : pc.add(4);
                break;
            case Ins_type.BGE:
                pc = reg[rj].toSignedInt() >= reg[rd].toSignedInt() ? pc + Uint32_t(si16 << 2).signExtend(17) : pc.add(4);
                break;
            case Ins_type.BLTU:
                pc = reg[rj] < reg[rd] ? pc + Uint32_t(si16 << 2).signExtend(17) : pc.add(4);
                break;
            case Ins_type.BGEU:
                pc = reg[rj] >= reg[rd] ? pc + Uint32_t(si16 << 2).signExtend(17) : pc.add(4);
                break;
            default: break;
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
                case 0x0A: if(ins.bitRange(21, 0) == 0) return Ins_type.NOP; else return Ins_type.ADDIW;
                case 0x0D: return Ins_type.ANDI;
                case 0x0E: return Ins_type.ORI;
                case 0x0F: return Ins_type.XORI;
                default: throw MemoryException(MEM_EXP_type.UNEXPECTED_MEM_ERROR);
            }
        else
            switch(ins.bitRange(31, 15).toInt()){
                case 0x20: return Ins_type.ADDW;
                case 0x22: return Ins_type.SUBW;
                case 0x24: return Ins_type.SLT;
                case 0x25: return Ins_type.SLTU;
                case 0x28: return Ins_type.NOR;
                case 0x29: return Ins_type.OR;
                case 0x2A: return Ins_type.XOR;
                case 0x2B: return Ins_type.SLLW;
                case 0x2E: return Ins_type.SRLW;
                case 0x2F: return Ins_type.SRAW;
                case 0x38: return Ins_type.MULW;
                case 0x39: return Ins_type.MULHW;
                case 0x3A: return Ins_type.MULHWU;
                case 0x40: return Ins_type.DIVW;
                case 0x41: return Ins_type.MODW;
                case 0x42: return Ins_type.DIVWU;
                case 0x43: return Ins_type.MODWU;
                case 0x54: return Ins_type.BREAK;
                case 0x81: return Ins_type.SLLIW;
                case 0x89: return Ins_type.SRLIW;
                case 0x91: return Ins_type.SRAIW;
                case 0: return Ins_type.NULL;
                default: throw MemoryException(MEM_EXP_type.UNEXPECTED_MEM_ERROR);
            }
    }

    List<String> print(){
        return _machine_code;
    }
}

String reg_name(int reg){
    switch (reg) {
        case 0: return r'ZERO';
        case 1: return r'RA';
        case 2: return r'TP';
        case 3: return r'SP';
        case 4: return r'A0';
        case 5: return r'A1';
        case 6: return r'A2';
        case 7: return r'A3';
        case 8: return r'A4';
        case 9: return r'A5';
        case 10: return r'A6';
        case 11: return r'A7';
        case 12: return r'T0';
        case 13: return r'T1';
        case 14: return r'T2';
        case 15: return r'T3';
        case 16: return r'T4';
        case 17: return r'T5';
        case 18: return r'T6';
        case 19: return r'T7';
        case 20: return r'T8';
        case 21: return r'FP';
        case 22: return r'S9';
        case 23: return r'S0';
        case 24: return r'S1';
        case 25: return r'S2';
        case 26: return r'S3';
        case 27: return r'S4';
        case 28: return r'S5';
        case 29: return r'S6';
        case 30: return r'S7';
        case 31: return r'S8';
        default: return '';
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
    //将开头空格删除
    temp = temp.replaceAll(RegExp(r'^ +'), '');
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
class SentenceBack{
    String       sentence_ori        = '';
    String       sentence            = '';
    List<String> sentence_spilt      = [];
    Uint32       machine_code        = Uint32_t(0);
    Uint32       addr                = Uint32_t(0);
    Ins_type     type                = Ins_type.NULL;
    bool         gen_by_lalocal      = false;

    SentenceBack(Sentence s, bool use2){
        if(!use2){
            sentence_ori    = s.sentence_ori;
            sentence        = s.sentence;
            sentence_spilt  = s.sentence_spilt;
            machine_code    = s._machine_code_i;
            addr            = s.addr;
            type            = s.type;
            gen_by_lalocal  = s.gen_by_lalocal;
        }else{
            sentence_ori    = s.sentence_ori;
            sentence        = s.sentence_2;
            sentence_spilt  = s.sentence_spilt_2;
            machine_code    = s._machine_code_i_2;
            addr            = s.addr;
            type            = s.type_2;
            gen_by_lalocal  = s.gen_by_lalocal;
        }
    }
    String print(){
        return machine_code.toBinaryPadded();
    }
}

class Sentence{
    String          sentence_ori            = '';                           //输入的汇编指令(原始)
    String          sentence                = '';                               //输入的汇编指令(经处理)
    Uint32          _machine_code_i         = Uint32_t(0);                  //输出的机器码
    
    Ins_type        type                    = Ins_type.NULL;                       //指令类型
    List<String>    sentence_spilt          = [];                   //将输入的汇编指令按空格分词结果
    Uint32          rd                      = Uint32_t(0);
    Uint32          rj                      = Uint32_t(0);
    Uint32          rk                      = Uint32_t(0);  //寄存器编号
    Uint32          imm                     = Uint32_t(0);                             //立即数
    bool            gen_by_lalocal          = false;
    
    Uint32          addr                    = Uint32_t(0);                            //指令所在内存地址

    bool            isdouble                = false;

    // some inst has two basic inst
    String          sentence_2              = '';
    List<String>    sentence_spilt_2        = [];
    Uint32          _machine_code_i_2       = Uint32_t(0);
    Ins_type        type_2                  = Ins_type.NULL;       
    
    Uint32          rd_2                    = Uint32_t(0);
    Uint32          rj_2                    = Uint32_t(0);
    Uint32          rk_2                    = Uint32_t(0);
    Uint32          imm_2                   = Uint32_t(0);
    

    Sentence(this.sentence_ori){

        if(sentence_ori == '') return;
        sentence = process(sentence_ori);
        //将寄存器别名改为标准写法
        sentence = _rename_register(sentence);
        //判断指令类型的合法性并赋值
        sentence_spilt = sentence.split(' ');
        if(!Ins_type.values.map((inst) => inst.toString()).contains('Ins_type.' + sentence_spilt.first)) {
            if(sentence_spilt.first == '.DATA:' || sentence_spilt.first == '.TEXT:') throw LabelException(sentence_spilt);
            else if(RegExp(r'\.?[A-Za-z0-9_]+:').hasMatch(sentence_spilt.first)) throw LabelException(sentence_spilt);
            else throw SentenceException(Exception_type.UNKNOWN_INST, this.sentence_ori);
        }
        type = Ins_type.values.byName(sentence_spilt.first);
        _machine_code_i = opcode_gen();
        _machine_code_i |= reg_gen();
        _machine_code_i |= imm_gen();

        if(type == Ins_type.LIW){
            liw_gen();
        }
        if(type == Ins_type.LALOCAL){
            lalocal_gen();
        }
    }

    String print(){
        return _machine_code_i.toBinaryPadded();
    }

    
    String _rename_register(String inst){
        String res = inst;
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
    
    Uint32 opcode_gen(){
        switch (type) {
            case Ins_type.NOP:       return Uint32_t(0x0A << 20);
            case Ins_type.ADDW:      return Uint32_t(0x00100 << 12);
            case Ins_type.SUBW:      return Uint32_t(0x00110 << 12);
            case Ins_type.SLT:       return Uint32_t(0x00120 << 12);
            case Ins_type.SLTU:      return Uint32_t(0x00128 << 12);
            case Ins_type.NOR:       return Uint32_t(0x00140 << 12);
            case Ins_type.AND:       return Uint32_t(0x00148 << 12); 
            case Ins_type.OR:        return Uint32_t(0x00150 << 12);
            case Ins_type.XOR:       return Uint32_t(0x00158 << 12);  
            case Ins_type.SLLW:      return Uint32_t(0x00170 << 12);
            case Ins_type.SRLW:      return Uint32_t(0x00178 << 12);  
            case Ins_type.SRAW:      return Uint32_t(0x00180 << 12);
            case Ins_type.MULW:      return Uint32_t(0x001C0 << 12);    
            case Ins_type.MULHW:     return Uint32_t(0x001C8 << 12);
            case Ins_type.MULHWU:    return Uint32_t(0x001D0 << 12);
            case Ins_type.DIVW:      return Uint32_t(0x00200 << 12);
            case Ins_type.MODW:      return Uint32_t(0x00208 << 12);
            case Ins_type.DIVWU:     return Uint32_t(0x00210 << 12);
            case Ins_type.MODWU:     return Uint32_t(0x00218 << 12);
            case Ins_type.SLLIW:     return Uint32_t(0x00408 << 12);
            case Ins_type.SRLIW:     return Uint32_t(0x00448 << 12);
            case Ins_type.SRAIW:     return Uint32_t(0x00488 << 12);
            case Ins_type.SLTI:      return Uint32_t(0x08 << 22);
            case Ins_type.SLTUI:     return Uint32_t(0x09 << 22);
            case Ins_type.ADDIW:     return Uint32_t(0x0A << 22);
            case Ins_type.ANDI:      return Uint32_t(0x0D << 22);
            case Ins_type.ORI:       return Uint32_t(0x0E << 22);
            case Ins_type.XORI:      return Uint32_t(0x0F << 22);
            case Ins_type.LU12IW:    return Uint32_t(0x0C << 25);
            case Ins_type.PCADDU12I: return Uint32_t(0x0E << 25);
            case Ins_type.LDB:       return Uint32_t(0xA0 << 22);
            case Ins_type.LDH:       return Uint32_t(0xA1 << 22);
            case Ins_type.LDW:       return Uint32_t(0xA2 << 22);
            case Ins_type.STB:       return Uint32_t(0xA4 << 22);
            case Ins_type.STH:       return Uint32_t(0xA5 << 22);
            case Ins_type.STW:       return Uint32_t(0xA6 << 22);
            case Ins_type.LDBU:      return Uint32_t(0xA8 << 22);
            case Ins_type.LDHU:      return Uint32_t(0xA9 << 22);
            case Ins_type.JIRL:      return Uint32_t(0x13 << 26);  
            case Ins_type.B:         return Uint32_t(0x14 << 26);
            case Ins_type.BL:        return Uint32_t(0x15 << 26);    
            case Ins_type.BEQ:       return Uint32_t(0x16 << 26);
            case Ins_type.BNE:       return Uint32_t(0x17 << 26);
            case Ins_type.BLT:       return Uint32_t(0x18 << 26);
            case Ins_type.BGE:       return Uint32_t(0x19 << 26);
            case Ins_type.BLTU:      return Uint32_t(0x1A << 26);
            case Ins_type.BGEU:      return Uint32_t(0x1B << 26);
            case Ins_type.BREAK:     return Uint32_t(0x54 << 15);
            default:                 return Uint32_t(0);
        }
    }
    
    Uint32 reg_gen(){
        Uint32 result = Uint32_t(0);
        if(!without_rd.contains(type)) {
            try{
                rd = Uint32_t(int.parse(sentence_spilt[1].substring(2)));
            } catch (e) {
                throw SentenceException(Exception_type.INVALID_REGNAME, this.sentence_ori);
            }
            if(rd > Uint32_t(31)) throw SentenceException(Exception_type.REG_OUT_OF_RANGE, this.sentence_ori);
            result |= rd;
        } 
        if(!without_rj.contains(type)) {
            try{
                rj = Uint32_t(int.parse(sentence_spilt[2].substring(2)));
            } catch (e) {
                throw SentenceException(Exception_type.INVALID_REGNAME, this.sentence_ori);
            }
            if(rj > Uint32_t(31)) throw SentenceException(Exception_type.REG_OUT_OF_RANGE, this.sentence_ori);
            result |= (rj << Uint32_t(5));
        }
        if(!without_rk.contains(type)) {
            try{
                rk = Uint32_t(int.parse(sentence_spilt[3].substring(2)));
            } catch (e) {
                throw SentenceException(Exception_type.INVALID_REGNAME, this.sentence_ori);
            }
            if(rk > Uint32_t(31)) throw SentenceException(Exception_type.REG_OUT_OF_RANGE, this.sentence_ori);
            result |= (rk << Uint32_t(10));
        }
        return result;
    }
    
    Uint32 imm_gen(){
        if(with_ui5.contains(type)) {
            try{
                imm = Uint32_t(int.parse(sentence_spilt[3]));
            } catch (e) {
                throw SentenceException(Exception_type.INVALID_IMM, this.sentence_ori);
            }
            if(imm > Uint32_t(31)) throw SentenceException(Exception_type.IMM_OUT_OF_RANGE, this.sentence_ori);
            return (imm << Uint32_t(10));
        }
        if(with_ui12.contains(type)) {
            try{
                imm = Uint32_t(int.parse(sentence_spilt[3]) & 0xfff);
            } catch (e) {
                throw SentenceException(Exception_type.INVALID_IMM, this.sentence_ori);
            }
            return (imm << Uint32_t(10));
        }
        if(with_si12.contains(type)) {
            try{
                imm = Uint32_t(int.parse(sentence_spilt[3])& 0xfff);
            } catch (e) {
                throw SentenceException(Exception_type.INVALID_IMM, this.sentence_ori);
            }
            return (imm << Uint32_t(10));
        }
        if(with_si20.contains(type)){
            var temp_int = 0;
            try{
                temp_int = int.parse(sentence_spilt[2]);
            } catch (e) {
                throw SentenceException(Exception_type.INVALID_IMM, this.sentence_ori);
            }
            temp_int = temp_int.replaceBitRange(63, 32, 0);
            imm = Uint32_t(temp_int & 0xfffff);
            // if(imm > Uint32_t(0xfffff)) throw SentenceException(Exception_type.IMM_OUT_OF_RANGE, this.sentence_ori);
            return (imm << Uint32_t(5));
        }
        return Uint32_t(0);
    }
    
    void liw_gen(){
        try{
            imm = Uint32_t(int.parse(sentence_spilt[2]));
        } catch (e) {
            throw SentenceException(Exception_type.INVALID_IMM, this.sentence_ori);
        }
        if(imm.bitRange(31, 20) != Uint32_t(0)){
                // 1. lu12i.w rd, imm & 0xfffff000 >> 12
                var imm_lu12iw = imm & Uint32_t(0xfffff000) >> Uint32_t(12);
                _machine_code_i |= (Uint32_t(0x0C << 25) | (imm_lu12iw << Uint32_t(5)));
                type = Ins_type.LU12IW;
                sentence = "LU12IW " + sentence_spilt[1] + " 0x" + imm_lu12iw.toSignedInt().toRadixString(16);
                sentence_spilt = sentence.split(' ');

                // 2. ori rd, rd, imm & 0xfff
                var imm_ori = imm & Uint32_t(0xfff);
                _machine_code_i_2 |= Uint32_t(0x0E << 22) | ((rd << Uint32_t(5)) | rd)| (imm_ori << Uint32_t(10));
                type_2 = Ins_type.ORI;
                sentence_2 = "ORI " + sentence_spilt[1] + " " + sentence_spilt[1] + " 0x" + imm_ori.toInt().toRadixString(16);
                sentence_spilt_2 = sentence_2.split(' ');
                isdouble = true;

            }else{
                // 2. ori rd, zero, imm & 0xfff
                var imm_ori = imm & Uint32_t(0xfff);
                _machine_code_i = Uint32_t(0x0E << 22) | rd | imm_ori << Uint32_t(10);
                type = Ins_type.ORI;
                sentence = "ORI " + sentence_spilt[1] + " " + "\$R0" + " 0x" + imm_ori.toSignedInt().toRadixString(16);
                sentence_spilt = sentence.split(' ');
            }
    }
    
    void lalocal_gen(){
        // 1. lu12i.w rd, label
        type = Ins_type.LU12IW;
        _machine_code_i |= (Uint32_t(0x0C << 25) | (Uint32_t(0) << Uint32_t(5)));
        sentence = "LU12IW " + sentence_spilt[1] + " " + sentence_spilt[2];
        sentence_spilt = sentence.split(' ');

        // 2. ori rd, rd, label
        type_2 = Ins_type.ORI;
        _machine_code_i_2 |= Uint32_t(0x0E << 22) | ((rd << Uint32_t(5)) | rd)| (Uint32_t(0) << Uint32_t(10));
        sentence_2 = "ORI " + sentence_spilt[1] + " " + sentence_spilt[1] + " " + sentence_spilt[2];
        sentence_spilt_2 = sentence_2.split(' ');

        isdouble = true;
        gen_by_lalocal = true;
    }
    
}