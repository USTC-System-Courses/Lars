// import 'dart:ffi' as ffi;
// import 'dart:js_util';

import './Uint32_ext.dart';
import 'package:binary/binary.dart';
import 'dart:core';
import 'config.dart';
import './memory.dart';
import './label.dart';
import './exception.dart';
import 'syntaxparser.dart';


class Assembler{
    List<String> inst_input = [];
    List<SentenceBack> _inst = [];
    List<String> _machine_code = [];
    Label _label = Label();
    Memory memory = Memory();
    Map<Uint32, SentenceBack> inst_rec = {};
    bool _isEnd = false;
    SyntaxParser lp = SyntaxParser();
    Assembler(List<String> temp){
        _isEnd = false;
        inst_input = temp;
        Uint32 text_build = Uint32_t(0x1c000000);
        Uint32 data_build = Uint32_t(0x1c800000);
        // build: mark the current address
        Uint32 build = text_build;
        for (var element in inst_input){
            var pkg = lp.Parse(element);
            if(pkg.is_empty) continue;
            // sign: execute the opration
            if(pkg.is_sign){
                switch(pkg.sign_type){
                    case Sign_type.TEXT:
                        data_build = build;
                        build = text_build;
                        break;
                    case Sign_type.DATA:
                        text_build = build;
                        build = data_build;
                        break;
                    case Sign_type.BYTE:
                        memory.write(build, pkg.sign_item, size: 1);
                        build = build.add(1);
                        break;
                    case Sign_type.HALF:
                        memory.write(build, pkg.sign_item, size: 2);
                        build = build.add(2);
                        break;
                    case Sign_type.WORD:
                        memory.write(build, pkg.sign_item, size: 4);
                        build = build.add(4);
                        break;
                    case Sign_type.SPACE:
                        for(int i = 0; i < pkg.sign_item.toInt(); i++){
                            memory.write(build, Uint32_t(0), size: 1);
                        }
                        build = build.add(pkg.sign_item.toInt());
                        break;
                    default: break;
                }
                continue;
            }
            // label: add label to label table
            if(pkg.is_label){
                _label.add(pkg.label, build);
                continue;
            }
            // code: add code to inst list
            if(pkg.is_code){
                _inst.add(SentenceBack(pkg, false));
                build = build.add(4);
                if(pkg.is_double){
                    _inst.add(SentenceBack(pkg, true));
                    build = build.add(4);
                }
                continue;
            }
        }
        build = Uint32_t(0x1c000000);
        // redirect and write inst
        for (var element in _inst) {
            if(element.has_label){
                var addr = _label.find(element.label); // throw exception in it
                if(!addr_range_check(element.type, addr, build)){
                    throw SentenceException(Exception_type.LABEL_TOO_FAR, element.sentence_ori);
                }
                var pc_offset = Uint32_t(addr - build);
                if(with_label16.contains(element.type)){
                    element.machine_code |= pc_offset.bitRange(17, 2) << Uint32_t(10);
                }
                else if(with_label26.contains(element.type)){
                    element.machine_code |= pc_offset.bitRange(17, 2) << Uint32_t(10);
                    element.machine_code |= pc_offset.bitRange(27, 18);
                }
                else{
                    if(element.type == Ins_type.LU12IW){
                        element.machine_code |= addr.bitRange(31, 12) << Uint32_t(5);
                        element.sentence += '0x' + addr.bitRange(31, 12).toInt().toRadixString(16);
                    }else{
                        element.machine_code |= addr.bitRange(11, 0) << Uint32_t(10);
                        element.sentence += '0x' + addr.bitRange(11, 0).toInt().toRadixString(16);
                    }
                }
            }
            memory.write(build, Uint32_t(int.parse(element.print(), radix: 2)));
            if(inst_rec.containsKey(build)){
                inst_rec[build] = element;
            }
            else inst_rec.putIfAbsent(build, () => (element));
            build = build.add(4);
            _machine_code.add(element.print());
        }
    }

    bool addr_range_check(Ins_type type, Uint32 addr, Uint32 build){
        if (with_label16.contains(type) && !((build - addr) > -(1 << 15) || (build - addr) < (1 << 15) - 1)) return false;
        else if (with_label26.contains(type) && !((build - addr) > -(1 << 25) || (build - addr) < (1 << 25) - 1)) return false;
        // else if(a.gen_by_lalocal) return true;
        // else return false;
        else return true;
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
class SentenceBack{
    String       sentence_ori        = '';
    String       sentence            = '';
    Uint32       machine_code        = Uint32_t(0);
    Ins_type     type                = Ins_type.NULL;
    bool         is_code             = false;
    bool         is_label            = false;
    bool         has_label           = false;
    String       label               = '';
    bool         is_sign             = false;
    Uint32       sign_item           = Uint32_t(0);
    Sign_type    sign_type           = Sign_type.TEXT;

    SentenceBack(SyntaxPackage l, bool use2){
        if(!use2){
            sentence_ori    = l.sentence_ori;
            sentence        = l.sentence;
            machine_code    = l.machine_code;
            type            = l.type;
            is_code         = l.is_code;
            is_label        = l.is_label;
            has_label       = l.has_label;
            label           = l.label;
            is_sign         = l.is_sign;
            sign_item       = l.sign_item;
            sign_type       = l.sign_type;
        }else{
            sentence_ori    = l.sentence_2_ori;
            sentence        = l.sentence_2;
            machine_code    = l.machine_code_2;
            type            = l.type_2;
            is_code         = l.is_code;
            is_label        = l.is_label;
            has_label       = l.has_label;
            label           = l.label;
            is_sign         = l.is_sign;
            sign_item       = l.sign_item;
            sign_type       = l.sign_type;
        }
    }
    String print(){
        return machine_code.toBinaryPadded();
    }
}
