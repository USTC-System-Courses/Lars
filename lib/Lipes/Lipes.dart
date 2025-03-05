import 'utils.dart';
import 'modules.dart';

class Lipes {
  Context _context = Context();

  Lipes();

  void addModule(Module Function(Context) moduleConstructor) {
    moduleConstructor(this._context);
  }
 
  void checkclk(){
    _context.getModule('clk').simT();
  }
  
}

