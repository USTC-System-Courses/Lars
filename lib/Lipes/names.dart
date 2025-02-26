class Tuple<T1, T2> {
  final T1 first;
  final T2 second;
  
  const Tuple(this.first, this.second);
}

Map<String, Tuple<String, String>> names = {};