import 'utils.dart';




final class RegFile extends Module {
  final int regnum;
  final int regwidth;

  late List<Wire> regs;

  RegFile(Context context, {this.regnum = 32, this.regwidth = 32}) 
      : super(context, inputs:{
        'read_addr': Wire(context, name: 'read_addr', width: 5),
        'write_addr': Wire(context, name: 'write_addr', width: 5),
        'write_data': Wire(context, name: 'write_data', width: regwidth),
        'write_en': Wire(context, name: 'write_en', width: 1),
      }, outputs:{
        'read_data': Wire(context, name: 'read_data', width: regwidth),
      }) {
    regs = List.generate(regnum, (index) => Wire(context, name: 'r$index', width: regwidth));
    
    context.addModule(this);
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

final class clk extends Module {
  clk(Context context) : super(context, inputs:{
    
  }, outputs:{
    'clk': Wire(context, name: 'clk', width: 1),
  });
}