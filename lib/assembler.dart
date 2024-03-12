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
    // List<String> _machine_code = [];
    Label _label = Label();
    // Memory memory = Memory();
    Map<Uint32, SentenceBack> inst_rec = {};
    SyntaxParser lp = SyntaxParser();
    Assembler(List<String> temp){
        inst_input = temp;
        Uint32 text_build = Uint32_t(0x1c000000);
        Uint32 data_build = Uint32_t(0x1c800000);
        Uint32 build = text_build;
        analyze_mode mode = analyze_mode.TEXT;
        for (var element in inst_input){
            var pkg = lp.Parse(element);
            if(pkg.is_empty) continue;
            // sign: execute the opration
            if(pkg.is_sign){
                switch(pkg.sign_type){
                    case Sign_type.TEXT:
                        data_build = mode == analyze_mode.TEXT ? build : data_build;
                        build = text_build;
                        mode = analyze_mode.TEXT;
                        break;
                    case Sign_type.DATA:
                        text_build = mode == analyze_mode.DATA ? build : text_build;
                        build = data_build;
                        mode = analyze_mode.DATA;
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
                    default: throw SentenceException(Exception_type.INVALID_LABEL, pkg.sentence);
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
        // write the upper bound of text and data
        if(mode == analyze_mode.TEXT){
            memory.text_upper = build;
            memory.data_upper = data_build;
        }
        else{
            memory.data_upper = build;
            memory.text_upper = text_build;
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
                if(with_label16.contains(element.type) || element.type == Ins_type.JIRL){
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
            // _machine_code.add(element.print());
        }
    }

    bool addr_range_check(Ins_type type, Uint32 addr, Uint32 build){
        if ((with_label16.contains(type) || type == Ins_type.JIRL) && !((build - addr) > -(1 << 15) || (build - addr) < (1 << 15) - 1)) return false;
        else if (with_label26.contains(type) && !((build - addr) > -(1 << 25) || (build - addr) < (1 << 25) - 1)) return false;
        else return true;
    }

    // List<String> print(){
    //     return _machine_code;
    // }
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
