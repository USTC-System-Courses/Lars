import 'utils.dart';
import 'package:binary/binary.dart';
import 'package:lars/Lars/Uint32_ext.dart';
import 'package:lars/Lars/config.dart';
import 'names.dart';

final class PC_plus extends Module {
  PC_plus(Context context, Map<String, Wire> _inputs, Map<String, Wire> _outputs) : super(context, inputs: _inputs, outputs: _outputs, name: 'PC_plus') {
    context.addModule(this);
  }
  @override
  void simC() {
    int pc = inputs['pc']!.getValue();
    outputs['pc_plus']!.setValue(Value.fromInt(this.context, pc + 4, 32));
  }
}

final class NPC_Mux extends Module {
  NPC_Mux(Context context, Map<String, Wire> _inputs, Map<String, Wire> _outputs) : super(context, inputs: _inputs, outputs: _outputs, name: 'NPC_Mux') {
    context.addModule(this);
  }
  @override
  void simC() {
    int sel = inputs['br_en_EX']!.getValue();
    if(sel == 1) outputs['npc']!.setValue(inputs['jump_target_EX']!);
    else outputs['npc']!.setValue(inputs['pc_plus_4']!);
  }
}

final class PC extends Module {
  PC(Context context, Map<String, Wire> _inputs, Map<String, Wire> _outputs) : super(context, inputs: _inputs, outputs: _outputs, name: 'PC') {
    context.addModule(this);
  }
  @override
  void simC() {
    int sel = inputs['pc_stall']!.getValue();
    if(sel == 1) outputs['pc']!.setValue(inputs['pc']!);
    else outputs['pc']!.setValue(inputs['npc']!);
  }
}

final class Seg_reg_IF_ID extends Module {
  Seg_reg_IF_ID(Context context, Map<String, Wire> _inputs, Map<String, Wire> _outputs) : super(context, inputs: _inputs, outputs: _outputs, name: 'Seg_reg_IF_ID') {
    context.addModule(this);
  }
  @override
  void simT() {
    if(inputs['IF_ID_flush']!.getValue() == 1) {
        outputs['pc_ID']!.setValue(inputs['pc_IF']!);
        outputs['inst_ID']!.setValue(inputs['inst_IF']!);
    }
    else if(inputs['IF_ID_stall']!.getValue() == 0) {
        outputs['pc_ID']!.setValue(inputs['pc_IF']!);
        outputs['inst_ID']!.setValue(inputs['inst_IF']!);
    }
  }
}

final class Inst_Decoder extends Module {
  Inst_Decoder(Context context, Map<String, Wire> _inputs, Map<String, Wire> _outputs) : super(context, inputs: _inputs, outputs: _outputs, name: 'Inst_Decoder') {
    context.addModule(this);
  }

  @override
  void simC() {
    int inst = inputs['inst_ID']!.getValue();
    Uint32 inst_t = Uint32_t(inst);
    Ins_type type = get_inst_type(inst_t);

    // src1_sel_ID
    outputs['src1_sel_ID']!.setValue(Value.fromInt(context, with_label.contains(type) ? 1 : 0, 1));
    // src2_sel_ID
    if(with_imm.contains(type)) outputs['src2_sel_ID']!.setValue(Value.fromInt(context, 1, 2));
    else if (type == Ins_type.JIRL) outputs['src2_sel_ID']!.setValue(Value.fromInt(context, 2, 2));
    else outputs['src2_sel_ID']!.setValue(Value.fromInt(context, 0, 2));
    //imm_ID
    
  }
}

final class RegFile extends Module {
  final int regnum;
  final int regwidth;

  late List<Wire> regs;

  RegFile(Context context, Map<String, Wire> _inputs, Map<String, Wire> _outputs, {this.regnum = 32, this.regwidth = 32}) 
      : super(context, inputs: _inputs
    //   {
    //     'read_addr': Wire(context, name: 'read_addr', width: 5),
    //     'write_addr': Wire(context, name: 'write_addr', width: 5),
    //     'write_data': Wire(context, name: 'write_data', width: regwidth),
    //     'write_en': Wire(context, name: 'write_en', width: 1),
    //   }
      , outputs: _outputs
    //   {
    //     'read_data': Wire(context, name: 'read_data', width: regwidth),
    //   }
      , name: 'RegFile') {
    regs = List.generate(regnum, (index) => Wire(context, name: 'r$index', width: regwidth));
    
    // context.addModule(this);
  }
  @override
  void simC() {
    int raddr = inputs['read_addr']!.getValue();
    if(raddr == -1) outputs['read_data']!.setValue(Value.X(this.context, regwidth));
    int waddr = inputs['write_addr']!.getValue();
    int wen = inputs['write_en']!.getValue();
    if(wen != 1 || waddr != raddr) return;
    int wdata = inputs['write_data']!.getValue();
    outputs['read_data']!.setValue(Value.fromInt(this.context, wdata, regwidth));
  }

  void simT(){
    int wen = inputs['write_en']!.getValue();
    if(wen != 1) return;
    int waddr = inputs['write_addr']!.getValue();
    int wdata = inputs['write_data']!.getValue();
    regs[waddr].setValue(Value.fromInt(this.context, wdata, regwidth));
  }
}

// final class clk extends Module {
//   clk(Context context, Map<String, Wire> _outputs) : super(context, inputs:{
    
//   }, outputs: _outputs
// //   {
// //     'clk': Wire(context, name: 'clk', width: 1, init: Value.fromInt(context, 0, 1)),
// //   }
//   , name: 'clk') {
//   }
//   @override
//   void simT() {
//     outputs['clk']!.setValue((this.outputs['clk']!^Value.fromInt(this.context, 1, 1)));
//   }
// }



