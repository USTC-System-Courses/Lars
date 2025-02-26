import 'modules.dart';
class Context {
  List<Wire> _wires = [];
  List<Module> _modules = [];
  List<Register> _registers = [];


  addWire(Wire wire) {
    _wires.add(wire);
  }

  addModule(Module module) {
    _modules.add(module);
  }

  addRegister(Register register) {
    _registers.add(register);
  }
}

enum ValueType { L, H, X, Z }

enum Operator { AND, OR, XOR, EQ }

// Value 基类
abstract class Value {
  List<ValueType> _value = [];
  int _width = 1;
  late Context _context;
  String name = '';
  ValueType state = ValueType.Z;

  checkState(){
    if (_value.every((v) => (v == ValueType.L || v == ValueType.H))) state = ValueType.L;
    else state = ValueType.X;
  }

  Value(this._context, {int width = 1, this.name = ''}) {
    _width = width;
    _value = List.filled(width, ValueType.Z);
  }

  // 基本属性和方法
  List<ValueType> get value => List.from(_value);
  set value(List<ValueType> newValue) {
    if (newValue.length != _width) {
      throw Exception('位宽不匹配');
    }
    _value = List.from(newValue);
  }

  int get width => _width;

  // 位运算方法
  Value operator &(Value other);
  Value operator |(Value other);
  Value operator ^(Value other);
  @override
  bool operator ==(Object other) {
    if (other is! Value) return false;
    if (other.width != width) return false;
    return _value.toString() == other._value.toString();
  }

  int getValue(){
    int result = 0;
    if (_width > 62) throw Exception('位宽过大 请使用getValue_s');
    checkState();
    if (state == ValueType.X) return -1;
    for (int i = 0; i < _width; i++) {
      result = result << 1 | _value[i].index;
    }
    return result;
  }

  BigInt getValue_s(){
    BigInt result = BigInt.from(0);
    checkState();
    if (state == ValueType.X) return BigInt.from(-1);
    for (int i = 0; i < _width; i++) {
      result = result << 1 | BigInt.from(_value[i].index);
    }
    return result;
  }

  @override
  int get hashCode => _value.toString().hashCode;

  // 辅助方法
  ValueType _bitwiseAnd(ValueType a, ValueType b) {
    if (a == ValueType.L || b == ValueType.L) return ValueType.L;
    if (a == ValueType.X || b == ValueType.X) return ValueType.X;
    if (a == ValueType.Z || b == ValueType.Z) return ValueType.X;
    return ValueType.H;
  }

  ValueType _bitwiseOr(ValueType a, ValueType b) {
    if (a == ValueType.H || b == ValueType.H) return ValueType.H;
    if (a == ValueType.X || b == ValueType.X) return ValueType.X;
    if (a == ValueType.Z || b == ValueType.Z) return ValueType.X;
    return ValueType.L;
  }

  ValueType _bitwiseXor(ValueType a, ValueType b) {
    if (a == ValueType.X || b == ValueType.X) return ValueType.X;
    if (a == ValueType.Z || b == ValueType.Z) return ValueType.X;
    if (a == b) return ValueType.L;
    return ValueType.H;
  }


  static Wire X(Context context, int width){
    return Wire(context, width: width, name: 'X');
  }

  //仿真一次组合逻辑
  void simC(){}
  //仿真一次时序逻辑
  void simT(){}

  @override
  String toString() {
    return '$name: ${_value.map((v) => v.toString().split('.').last).join('')}';
  }
  
  static Wire fromInt(Context context, int value, int width) {
    Wire wire = Wire(context, width: width);
    for (int i = 0; i < width; i++) {
      wire._value[width - 1 - i] = (value & (1 << i)) != 0 ? ValueType.H : ValueType.L;
    }
    return wire;
  }
}

// Wire 类现在继承自 Value
class Wire extends Value {
  bool _isConstant = false;
  late Value parent;

  Wire(Context context, {int width = 1, String name = '', Value? parent})
      : super(context, width: width, name: name) {
    _context.addWire(this);
    if (parent != null) {
      this.parent = parent;
    }
    else{
      this.parent = Wire(context, width: width, name: name);
    }
  }

  bool get isConstant => _isConstant;

  @override
  Wire operator &(Value other) {
    if (_width != other.width) {
      throw Exception('位宽不匹配');
    }
    var result = Wire(_context, width: _width);
    for (int i = 0; i < _width; i++) {
      result._value[i] = _bitwiseAnd(_value[i], other.value[i]);
    }
    return result;
  }

  @override
  Wire operator |(Value other) {
    if (_width != other.width) {
      throw Exception('位宽不匹配');
    }
    var result = Wire(_context, width: _width);
    for (int i = 0; i < _width; i++) {
      result._value[i] = _bitwiseOr(_value[i], other.value[i]);
    }
    return result;
  }

  @override
  Wire operator ^(Value other) {
    if (_width != other.width) {
      throw Exception('位宽不匹配');
    }
    var result = Wire(_context, width: _width);
    for (int i = 0; i < _width; i++) {
      result._value[i] = _bitwiseXor(_value[i], other.value[i]);
    }
    return result;
  }

  @override
  bool operator ==(Object other) {
    if (other is! Value) return false;
    if (other.width != width) return false;
    return _value.toString() == other._value.toString();
  }

  void setValue(Wire value){
    this.value = value.value;
  }

  @override
  int get hashCode => _value.toString().hashCode;
}

// // 普通Wire
// class PlainWire extends Wire {
//   PlainWire(Context context, {int width = 1, String name = '', Value? parent})
//       : super(context, width: width, name: name, parent: parent);
// }

// // 寄存器输出Wire
// class RegisterWire extends Wire {
//   final Register register;

//   RegisterWire(Context context, this.register, {String name = ''})
//       : super(context, width: register.width, name: name, parent: register) {
//     register.setOutputWire(this);
//   }

//   @override
//   set value(List<ValueType> newValue) {
//     super.value = newValue;
//     // 可以添加特定于寄存器输出的逻辑
//   }
// }

// Register 类现在继承自 Value
class Register extends Value {
  late Wire _output;
  

  Register(Context context, {int width = 1, String name = ''})
      : super(context, width: width, name: name) {
    _context.addRegister(this);
    _output = Wire(_context, width: width, name: '${name}_out');
  }


  Wire get output => _output;


  @override
  set value(List<ValueType> newValue) {
    super.value = newValue;
    _output.value = _value;
  }

  @override
  Value operator &(Value other) {
    throw Exception('Register 不支持直接位运算');
  }

  @override
  Value operator |(Value other) {
    throw Exception('Register 不支持直接位运算');
  }

  @override
  Value operator ^(Value other) {
    throw Exception('Register 不支持直接位运算');
  }
}
abstract class Module {
  Map<String, Wire> inputs = {};
  Map<String, Wire> outputs = {};

  List<Module> basedModules = [];
  List<Module> subModules = [];
  List<Module> drivenModules = [];
  late Context _context;
  Module(Context context, {Map<String, Wire> inputs = const {}, Map<String, Wire> outputs = const {}}){
    _context = context;
    context.addModule(this);
  }

  void input(List<Wire> inputs) {
    for(var wire in inputs){
      this.inputs[wire.name] = wire;
    }
  }
  
  Context get context => _context;

  void simC(){}
  void simT(){}
}

class Connection extends Module {
  Module parent, child;
  Connection(Context context, this.parent, this.child) : super(context);
  
}