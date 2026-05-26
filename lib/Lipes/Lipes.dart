import 'utils.dart';
import 'simple_pipeline_cpu.dart';

export 'simple_pipeline_cpu.dart';

class Lipes {
  Context _context = Context();

  Lipes();

  void addModule(Module Function(Context) moduleConstructor) {
    moduleConstructor(this._context);
  }

  void checkclk() {
    _context.getModule('clk').simT();
  }

  SimplePipelineCpu createSimplePipelineDemo() {
    return SimplePipelineCpu.demo();
  }
}
