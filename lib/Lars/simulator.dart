// import 'dart:ffi';

import 'log.dart';
import 'Uint32_ext.dart';
import 'package:binary/binary.dart';
import 'dart:core';
import 'config.dart';
import 'memory.dart';
import 'exception.dart';

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
        int ui26 = (ins.bitRange(25, 10) + (ins.bitRange(9, 0) << Uint32_t(16))).toInt();
        int si26 = ins.getBit(9) == 1 ? (ins.bitRange(25, 10) + (ins.bitRange(9, 0) << Uint32_t(16))).signExtend(25).toSignedInt():ui26;
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
                Uint32 temp = reg[rj];
                if((reg[rk].bitRange(4, 0)).toInt()!= 0) temp = reg[rj].signedRightShift((reg[rk].bitRange(4, 0)).toInt());
                log.SetLog(pc, (rd, reg[rd], temp), null);
                reg[rd] = temp;
                pc = pc.add(4);
                break;
            case Ins_type.SRLW:
                var temp = reg[rj] >> (reg[rk].bitRange(4, 0));
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
                Uint32 temp = reg[rj];
                if(ui5 != 0) temp = reg[rj].signedRightShift(ui5);
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
                var temp = reg[rj] < Uint32_t(si12 & UI32_mask) ? Uint32_t(1) : Uint32_t(0);
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
                pc = reg[rj] + Uint32_t(si16 << 2).signExtend(17);
                reg[rd] = temp;
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
        _isEnd = false;
        pc = info.pc;
    }
    void run(Set<Uint32> breakpoints){
        bool moved = false;
        while(!_isEnd && (!breakpoints.contains(pc) || !moved)){
            moved = true;
            cycle();
        }
    }
    

}
