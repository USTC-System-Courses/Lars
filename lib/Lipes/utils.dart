import 'modules.dart';
class Context {
  List<Register> _registers = [];
  List<Wire> _wires = [];
  List<Module> _modules = [];
  late Register _clk;
  addRegister(Register register) {
    _registers.add(register);
  }

  addWire(Wire wire) {
    _wires.add(wire);
  }

  addModule(Module module) {
    _modules.add(module);
  }

  Context() {
    _clk = Register(this, name: 'clk', width: 1);
  }
}

enum ValueType { L, H, X, Z }

enum Operator { AND, OR, XOR, EQ }

// class ComplexOperator extends Value {
//   List<Operator> _operators = [];
//   late Value _left;
//   late Value _right;

//   ComplexOperator(
//       Context context, Value left, Value right, List<Operator> operators)
//       : super(context) {
//     _left = left;
//     _right = right;
//     _operators = operators;
//   }
// }

// Value 基类
abstract class Value {
  List<ValueType> _value = [];
  int _width = 1;
  late Context _context;
  String name = '';

  Value(this._context, {int width = 1, this.name = ''}) {
    _width = width;
    _value = List.filled(width, ValueType.X);
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

  @override
  String toString() {
    return '$name: ${_value.map((v) => v.toString().split('.').last).join('')}';
  }
}

// Wire 类现在继承自 Value
abstract class Wire extends Value {
  bool _isConstant = false;

  Wire(Context context, {int width = 1, String name = ''})
      : super(context, width: width, name: name) {
    _context.addWire(this);
  }

  bool get isConstant => _isConstant;

  @override
  Wire operator &(Value other) {
    if (_width != other.width) {
      throw Exception('位宽不匹配');
    }
    var result = PlainWire(_context, width: _width);
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
    var result = PlainWire(_context, width: _width);
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
    var result = PlainWire(_context, width: _width);
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

  @override
  int get hashCode => _value.toString().hashCode;
}

// 普通Wire
class PlainWire extends Wire {
  PlainWire(Context context, {int width = 1, String name = ''})
      : super(context, width: width, name: name);
}

// 寄存器输出Wire
class RegisterWire extends Wire {
  final Register register;

  RegisterWire(Context context, this.register, {String name = ''})
      : super(context, width: register.width, name: name) {
    register.setOutputWire(this);
  }

  @override
  set value(List<ValueType> newValue) {
    super.value = newValue;
    // 可以添加特定于寄存器输出的逻辑
  }
}

// Register 类现在继承自 Value
class Register extends Value {
  Wire? _input;
  late RegisterWire _output;
  

  Register(Context context, {int width = 1, String name = ''})
      : super(context, width: width, name: name) {
    _context.addRegister(this);
    _output = RegisterWire(_context, this, name: '${name}_out');
  }

  void setOutputWire(RegisterWire wire) {
    _output = wire;
  }

  Wire get output => _output;

  void setInputWire(Wire wire) {
    if (wire.width != _width) {
      throw Exception('位宽不匹配');
    }
    _input = wire;
  }

  @override
  set value(List<ValueType> newValue) {
    super.value = newValue;
    _output.value = _value;
  }

  void posedge() {
    if (_input == null) return;
    value = _input!.value;
  }

  void negedge() {
    if (_input == null) return;
    value = _input!.value;
  }

  void reset() {
    value = List.filled(_width, ValueType.L);
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

class SimpleRule extends PlainWire {
  List<Value> _operands = [];
  Operator _operator = Operator.AND;

  SimpleRule(Context context, List<Value> operands, Operator op,
      {int width = 1, String name = ''})
      : super(context, width: width, name: name) {
    _operands = operands;
    _operator = op;
  }

  // 获取操作数的实际值（如果是Register则使用其output）
  Wire _getOperandWire(Value operand) {
    if (operand is Register) {
      return operand.output;
    }
    return operand as Wire;
  }

  // 更新值
  void evaluate() {
    switch (_operator) {
      case Operator.AND:
        var result = _getOperandWire(_operands[0]);
        for (var i = 1; i < _operands.length; i++) {
          result = result & _getOperandWire(_operands[i]);
        }
        value = result.value;
        break;

      case Operator.OR:
        var result = _getOperandWire(_operands[0]);
        for (var i = 1; i < _operands.length; i++) {
          result = result | _getOperandWire(_operands[i]);
        }
        value = result.value;
        break;

      case Operator.XOR:
        var result = _getOperandWire(_operands[0]);
        for (var i = 1; i < _operands.length; i++) {
          result = result ^ _getOperandWire(_operands[i]);
        }
        value = result.value;
        break;

      case Operator.EQ:
        if (_operands.length != 1) {
          throw Exception('赋值操作只能有一个操作数');
        }
        value = _getOperandWire(_operands[0]).value;
        break;

      default:
        throw Exception('不支持的操作符: $_operator');
    }
  }
}

class Module {
  List<Value> _rules = [];
  List<Wire> _inputs = [];
  List<Wire> _outputs = [];

  Module(Context context, {List<Value> rules = const [], List<Wire> inputs = const [], List<Wire> outputs = const []}){
    _rules = rules;
    _inputs = inputs;
    _outputs = outputs;
  }

  addRule(Value rule){
    _rules.add(rule);
  }

  addInput(Wire input){
    _inputs.add(input);
  }

  addOutput(Wire output){
    _outputs.add(output);
  }
}
