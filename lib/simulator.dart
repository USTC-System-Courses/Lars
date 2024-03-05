// import 'dart:ffi';

import './log.dart';
import './Uint32_ext.dart';
import 'package:binary/binary.dart';
import 'dart:core';
import 'config.dart';
import './memory.dart';
import './exception.dart';

class Simulator{
    bool _isEnd = false;
    List<Uint32> reg = List.filled(32, Uint32.zero);
    Uint32 pc = Uint32_t(0x1c000000);
    Log log = Log();
    void reset(){
        _isEnd = false;
        reg = List.filled(32, Uint32.zero);
        pc = Uint32_t(0x1c000000);
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
            case Ins_type.HALT:
            case Ins_type.NULL:
                _isEnd = true;
                break;
            case Ins_type.NOP:
                pc = pc.add(4);
                break;
            case Ins_type.ADDW:
                log.SetLog(pc, (rd, reg[rd], reg[rj] + reg[rk]), null);
                reg[rd] = reg[rj] + reg[rk];
                pc = pc.add(4);
                break;
            case Ins_type.SUBW:
                var temp = Uint32_t((reg[rj] - reg[rk]) & UI32_mask);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.SLT:
                var temp = reg[rj].toSignedInt() < reg[rk].toSignedInt() ? Uint32_t(1) : Uint32_t(0);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.SLTU:
                var temp = reg[rj] < reg[rk] ? Uint32_t(1) : Uint32_t(0);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.NOR:
                var temp = ~(reg[rj] | reg[rk]);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.AND:
                var temp = reg[rj] & reg[rk];
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.OR:
                var temp = reg[rj] | reg[rk];
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.XOR:
                var temp = reg[rj] ^ reg[rk];
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.SLLW:
                var temp = reg[rj] << (reg[rk].bitRange(4, 0));
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.SRAW:
                var sign = reg[rj].getBit(31);
                Uint32 mask = ~(Uint32_t(sign != 0 ? 0xffffffff : 0) >> reg[rk]);
                var temp = reg[rj] >> reg[rk];
                temp = temp | mask;
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.SRLW:
                var temp = reg[rj] >> (reg[rk]);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.MULW:
                var temp = Uint32_t(reg[rj].toSignedInt() * reg[rk].toSignedInt() & UI32_mask);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.MULHW:
                var temp = Uint32_t((reg[rj].toSignedInt() * reg[rk].toSignedInt() >> 32) & UI32_mask);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.MULHWU:
                var temp = Uint32_t((reg[rj].toInt() * reg[rk].toInt() >> 32) & UI32_mask);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.DIVW:
                var temp = Uint32_t(reg[rj].toSignedInt() ~/ reg[rk].toSignedInt());
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.MODW:
                var temp = Uint32_t(reg[rj].toSignedInt() % reg[rk].toSignedInt());
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.DIVWU:
                var temp = Uint32_t(reg[rj].toInt() ~/ reg[rk].toInt());
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.MODWU:
                var temp = Uint32_t(reg[rj].toInt() % reg[rk].toInt());
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.SLLIW:
                var temp = reg[rj] << Uint32_t(ui5);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.SRAIW:
                var sign = reg[rj].getBit(31);
                Uint32 mask = ~(Uint32_t(sign != 0 ? 0xffffffff : 0) >> Uint32_t(ui5));
                var temp = (reg[rj] >> (Uint32_t(ui5))) | mask;
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.SRLIW:
                var temp = reg[rj] >> Uint32_t(ui5);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.SLTI:
                var temp = reg[rj].toSignedInt() < si12 ? Uint32_t(1) : Uint32_t(0);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.SLTUI:
                var temp = reg[rj] < Uint32_t(ui12) ? Uint32_t(1) : Uint32_t(0);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.ADDIW:
                var temp = Uint32_t((reg[rj].toSignedInt() + si12) & UI32_mask);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.ANDI:
                var temp = reg[rj] & Uint32_t(ui12);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.ORI:
                var temp = reg[rj] | Uint32_t(ui12);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.XORI:
                var temp = reg[rj] ^ Uint32_t(ui12);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.LU12IW:
                var temp = Uint32_t(si20) << Uint32_t(12);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.PCADDU12I:
                var temp = pc.add(si20 << 12);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.LDB:
                var temp = memory.read(reg[rj].add(si12), size: 1).signExtend(7);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.LDH:
                var temp = memory.read(reg[rj].add(si12), size: 2).signExtend(15);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.LDW:
                var temp = memory.read(reg[rj].add(si12), size: 4);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.STB:
                var addr = reg[rj].add(si12);
                var temp = memory.read(addr);
                memory.write(addr, reg[rd], size: 1);
                log.SetLog(pc, null, (addr, temp, memory.read(addr)));
                pc = pc.add(4);
                break;
            case Ins_type.STH:
                var addr = reg[rj].add(si12);
                var temp = memory.read(addr);
                memory.write(addr, reg[rd], size: 2);
                log.SetLog(pc, null, (addr, temp, memory.read(addr)));
                pc = pc.add(4);
                break;
            case Ins_type.STW:
                var addr = reg[rj].add(si12);
                var temp = memory.read(addr);
                memory.write(addr, reg[rd], size: 4);
                log.SetLog(pc, null, (addr, temp, memory.read(addr)));
                pc = pc.add(4);
                break;
            case Ins_type.LDBU:
                var temp = memory.read(reg[rj].add(si12), size: 1);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.LDHU:
                var temp = memory.read(reg[rj].add(si12), size: 2);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.JIRL:
                var temp = pc.add(4);
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = reg[rj] + Uint32_t(si16 << 2).signExtend(17);
                break;
            case Ins_type.B:
                log.SetLog(pc, null, null);
                pc = pc + Uint32_t(si26 << 2).signExtend(27);
                break;
            case Ins_type.BL:
                var temp = pc.add(4);
                log.SetLog(pc, (1, reg[1], temp), null);
                reg[1] = temp;
                pc = pc + Uint32_t(si26 << 2).signExtend(27);
                break;
            case Ins_type.BEQ:
                log.SetLog(pc, null, null);
                pc = reg[rj] == reg[rd] ? pc + Uint32_t(si16 << 2).signExtend(17) : pc.add(4);
                break;
            case Ins_type.BNE:
                log.SetLog(pc, null, null);
                pc = reg[rj] != reg[rd] ? pc + Uint32_t(si16 << 2).signExtend(17) : pc.add(4);
                break;
            case Ins_type.BLT:
                log.SetLog(pc, null, null);
                pc = reg[rj].toSignedInt() < reg[rd].toSignedInt() ? pc + Uint32_t(si16 << 2).signExtend(17) : pc.add(4);
                break;
            case Ins_type.BGE:
                log.SetLog(pc, null, null);
                pc = reg[rj].toSignedInt() >= reg[rd].toSignedInt() ? pc + Uint32_t(si16 << 2).signExtend(17) : pc.add(4);
                break;
            case Ins_type.BLTU:
                log.SetLog(pc, null, null);
                pc = reg[rj] < reg[rd] ? pc + Uint32_t(si16 << 2).signExtend(17) : pc.add(4);
                break;
            case Ins_type.BGEU:
                log.SetLog(pc, null, null);
                pc = reg[rj] >= reg[rd] ? pc + Uint32_t(si16 << 2).signExtend(17) : pc.add(4);
                break;
            default: break;
        }
        reg[0] = Uint32.zero;
    }
    void step_back(){
        var info = log.GetLog();
        if(info.reg != null){
            reg[info.reg!.$1] = info.reg!.$2;
        }
        if(info.mem != null){
            memory.write(info.mem!.$1, info.mem!.$2);
        }
        pc = info.pc;
    }
    void run(Set<Uint32> breakpoints){
        bool moved = false;
        while(!_isEnd && (!breakpoints.contains(pc) || !moved)){
            moved = true;
            cycle();
        }
    }
    Ins_type get_inst_type(Uint32 ins){
        if(ins.getBit(31) == 1)
            return Ins_type.HALT;
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
                case 0x29: return Ins_type.AND;
                case 0x2A: return Ins_type.OR;
                case 0x2B: return Ins_type.XOR;
                case 0x2E: return Ins_type.SLLW;
                case 0x2F: return Ins_type.SRLW;
                case 0x30: return Ins_type.SRAW;
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

}