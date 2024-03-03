import './Uint32_ext.dart';
import 'package:binary/binary.dart';
import 'dart:core';
import 'config.dart';
import './exception.dart';
import 'arch.dart';

class LexPackage {
    bool is_empty = false;
    bool is_code = false;
    Uint32 machine_code = Uint32(0);
    Ins_type type = Ins_type.NOP;

    bool is_label = false;
    bool has_label = false;
    String label = "";

    bool is_sign = false;
    Sign_type sign_type = Sign_type.TEXT;
    Uint32 sign_item = Uint32(0);

    // li.w la.local
    bool is_double = false;
    Uint32 machine_code_2 = Uint32(0);
    Ins_type type_2 = Ins_type.NOP;
    bool has_label_2 = false;
    String label_2 = "";

    // for debug
    String sentence = "";
    String sentence_ori = "";
    String sentence_2 = "";
    String sentence_2_ori = "";

    LexPackage(String s){
        sentence_ori = s;
    }
    void clear(){
        is_empty = false;
        is_code = false;

        is_label = false;
        has_label = false;

        is_sign = false;

        is_double = false;
        has_label_2 = false;
    }

}
class LexParser {
    Map<String, String> _register_rename_table = register_rename_table;
    Map<Ins_type, Uint32> _opcode_table = opcode_table;

    LexPackage package = LexPackage("");
    String s = "";
    String s_regular = "";
    List<String> s_regular_spilt = [];
    Uint32 rd = Uint32_t(0);
    Uint32 rj = Uint32_t(0);
    Uint32 rk = Uint32_t(0);

    // regularize the input string
    String _regularize(String s){
        // , -> " "
        s = s.replaceAll(RegExp(r','), " ");
        // \t -> " "
        s = s.replaceAll(RegExp(r'\t'), " ");
        // " " x n -> "
        s = s.replaceAll(RegExp(r' +'), " ");
        // remove leading and trailing spaces
        s = s.trim();
        // to upper case
        s = s.toUpperCase();
        // remove comments
        s = s.replaceAll(RegExp(r'#.*'), '');
        return s;
    }

    // Register Alias Resolution
    String _rename_register(String s){
        return _register_rename_table[s] ?? s;
    }

    Uint32 _parse_opcode(Ins_type type){
        return _opcode_table[type] ?? Uint32(0);
    }

    // generate li.w
    void _gen_liw(){
        var imm = Uint32.zero;
        try{
            imm = Uint32_t(int.parse(s_regular_spilt[2]));
        } catch(e){
            throw SentenceException(Exception_type.INVALID_IMM, s_regular);
        }
        if(imm.bitRange(31, 20) != Uint32.zero){
            // 1. lu12i.w rd, imm & 0xfffff000 >> 12
            var imm_1 = imm.bitRange(31, 12);
            package.machine_code = (Uint32_t(0x0C << 25) | (imm_1 << Uint32_t(5)) | rd);
            package.sentence = "LU12I.W " + s_regular_spilt[1] + ", 0x" + imm_1.toSignedInt().toRadixString(16);
            package.type = Ins_type.LU12IW;
            // 2. ori rd, rd, imm & 0x00000fff
            var imm_2 = imm.bitRange(11, 0);
            package.machine_code_2 = (Uint32_t(0x0E << 22) | (imm_2 << Uint32_t(10)) | rd << Uint32_t(5) | rd);
            package.sentence_2 = "ORI " + s_regular_spilt[1] + ", " + s_regular_spilt[1] + ", 0x" + imm_2.toInt().toRadixString(16);
            package.type_2 = Ins_type.ORI;

            package.is_double = true;
        }
        else{
            // 1. ori rd, zero, imm & 0xfff
            var imm_2 = imm.bitRange(11, 0);
            package.machine_code = (Uint32_t(0x0E << 22) | (imm_2 << Uint32_t(10)) | Uint32.zero << Uint32_t(5) | rd);
            package.sentence = "ORI " + s_regular_spilt[1] + ", \$R0, 0x" + imm_2.toInt().toRadixString(16);
            package.type = Ins_type.ORI;
        }
    }

    // generate la.local
    void _gen_lalocal(){
        // 1. lu12i.w rd, label
        package.machine_code = (Uint32_t(0x0C << 25) | rd);
        package.sentence = "LU12I.W " + s_regular_spilt[1] + ", ";
        package.type = Ins_type.LU12IW;
        // 2. ori rd, rd, imm & 0x00000fff
        package.machine_code_2 = (Uint32_t(0x0E << 22)  | rd << Uint32_t(5) | rd);
        package.sentence_2 = "ORI " + s_regular_spilt[1] + ", " + s_regular_spilt[1] + ", ";
        package.type_2 = Ins_type.ORI;

        package.is_double = true;
    }

    Uint32 _parse_reg(Ins_type type){
        Uint32 result = Uint32_t(0);
        if(!without_rd.contains(type)){
            String rd_s = _rename_register(s_regular_spilt[1]).split("\$")[1].substring(1);
            try{
                rd = Uint32_t(int.parse(rd_s));
            } catch(e){
                throw SentenceException(Exception_type.INVALID_REGNAME, s_regular);
            }
            if(rd > Uint32_t(31)){
                throw SentenceException(Exception_type.REG_OUT_OF_RANGE, s_regular);
            }
            result |= rd;
        }
        if(!without_rj.contains(type)){
            String rj_s = _rename_register(s_regular_spilt[2]).split("\$")[1].substring(1);
            try{
                rj = Uint32_t(int.parse(rj_s));
            } catch(e){
                throw SentenceException(Exception_type.INVALID_REGNAME, s_regular);
            }
            if(rj > Uint32_t(31)){
                throw SentenceException(Exception_type.REG_OUT_OF_RANGE, s_regular);
            }
            result |= rj << Uint32_t(5);
        }
        if(!without_rk.contains(type)){
            String rk_s = _rename_register(s_regular_spilt[3]).split("\$")[1].substring(1);
            try{
                rk = Uint32_t(int.parse(rk_s));
            } catch(e){
                throw SentenceException(Exception_type.INVALID_REGNAME, s_regular);
            }
            if(rk > Uint32_t(31)){
                throw SentenceException(Exception_type.REG_OUT_OF_RANGE, s_regular);
            }
            result |= rk << Uint32_t(10);
        }
        return result;
    }

    Uint32 _parse_imm(Ins_type type){
        Uint32 imm = Uint32_t(0);
        if(with_ui5.contains(type)){
            try{
                imm = Uint32_t(int.parse(s_regular_spilt[3]));
            } catch(e){
                throw SentenceException(Exception_type.INVALID_IMM, s_regular);
            }
            if(imm > Uint32_t(31)){
                throw SentenceException(Exception_type.IMM_OUT_OF_RANGE, s_regular);
            }
            return (imm << Uint32_t(10)).bitRange(14, 0);
        }
        if(with_ui12.contains(type)){
            try{
                imm = Uint32_t(int.parse(s_regular_spilt[3]));
            } catch(e){
                throw SentenceException(Exception_type.INVALID_IMM, s_regular);
            }
            if(imm > Uint32_t(4095)){
                throw SentenceException(Exception_type.IMM_OUT_OF_RANGE, s_regular);
            }
            return (imm << Uint32_t(10)).bitRange(21, 0);
        }
        if(with_si12.contains(type)){
            try{
                imm = Uint32_t(int.parse(s_regular_spilt[3]));
            } catch(e){
                throw SentenceException(Exception_type.INVALID_IMM, s_regular);
            }
            if(imm.toSignedInt() > 2047 || imm.toSignedInt() < -2048){
                throw SentenceException(Exception_type.IMM_OUT_OF_RANGE, s_regular);
            }
            return (imm << Uint32_t(10)).bitRange(21, 0);
        }
        if(with_si20.contains(type)){
            try{
                imm = Uint32_t(int.parse(s_regular_spilt[3]));
            } catch(e){
                throw SentenceException(Exception_type.INVALID_IMM, s_regular);
            }
            if(imm.toSignedInt() > 1048575 || imm.toSignedInt() < -1048576){
                throw SentenceException(Exception_type.IMM_OUT_OF_RANGE, s_regular);
            }
            return (imm << Uint32_t(5)).bitRange(24, 0);
        }

        return Uint32.zero;
    }
    
    

    // Parse the input string
    LexPackage Parse(String _s){
        // LexPackage package = LexPackage(s);
        // regularize the input string
        package.clear();
        s = _s;
        s_regular = _regularize(s);
        if(s_regular.isEmpty){
            package.is_empty = true;
            return package;
        }
        s_regular_spilt = s_regular.split(' ');

        package.sentence_ori = s;
        package.sentence = s_regular;

        // check if it is a sign
        if(s_regular_spilt[0][0] == '.'){
            package.is_sign = true;
            package.label = s_regular_spilt[0].substring(1);
            if(!Sign_type.values.map((e) => e.toString().split(".")[1]).contains(package.label)){
                throw SentenceException(Exception_type.INVALID_SEGMENT, s); // TODO: add more info
            }
            if(s_regular_spilt.length > 1){
                try{
                    package.sign_item = Uint32_t(int.parse(s_regular_spilt[1]));
                    package.sign_type = Sign_type.values.byName(package.label);
                }catch(e){
                    throw SentenceException(Exception_type.INVALID_IMM, s);
                }
            }
            return package;
        }

        // chcek if it is a label
        if(s_regular_spilt[0][s_regular_spilt[0].length - 1] == ':'){
            package.is_label = true;
            package.label = s_regular_spilt[0];
            return package;
        }

        // it is a inst
        package.is_code = true;
        if(!RegExp(opcheckString).hasMatch(s_regular_spilt[0])){
            throw SentenceException(Exception_type.UNKNOWN_INST, s);
        }
        var opcode = s_regular_spilt[0].replaceAll(RegExp(r'\.'), "");
        var type = Ins_type.values.byName(opcode);
        package.type = type;
        package.machine_code = _parse_opcode(type) | _parse_reg(type) | _parse_imm(type);
        if(with_label.contains(type)){
            package.has_label = true;
            package.label = s_regular_spilt[s_regular_spilt.length - 1];
        }
        if(type == Ins_type.LIW){
            _gen_liw();
        }
        if(type == Ins_type.LALOCAL){
            _gen_lalocal();
        }
        return package;
    }



}