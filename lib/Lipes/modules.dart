import 'utils.dart';




class RegFile extends Module {
  final int regnum;
  final int regwidth;

  RegFile(Context context, {this.regnum = 32, this.regwidth = 32}) 
      : super(context, inputs:[
        PlainWire(context, name: 'read_addr', width: 5),
        PlainWire(context, name: 'write_addr', width: 5),
        PlainWire(context, name: 'write_data', width: regwidth),
        PlainWire(context, name: 'write_en', width: 1),
      ], outputs:[
        PlainWire(context, name: 'read_data', width: regwidth),
      ]) {
    context.addModule(this);

  }
}
