import 'package:binary/binary.dart';
extension Uint32_ext on Uint32{
    Uint32 operator +(Uint32 other){
        return Uint32(this.toInt() + other.toInt());
    }

    Uint32 add(int other){
        return Uint32(this.toInt() + other);
    }

    Uint32 add32(Uint32 other){
        return Uint32(this.toInt() + other.toInt());
    }

    Uint8 operator [](int byte_offset){
        int temp = 0;
        for(int i = 8 * byte_offset + 7; i > 8 * byte_offset - 1; i--){
            temp = (temp << 1) + temp.getBit(i);
        }
        return Uint8(temp);
    }
    
    int toInt(){
        int a = 0;
        for(int i = 31; i >= 0; i--){
            a = (a << 1) + this.getBit(i);
        }
        return a;
    }

    int operator -(Uint32 other){
        return this.toInt() - other.toInt();
    }
}

extension Uint8_ext on Uint8{
    int toInt(){
        int a = 0;
        for(int i = 31; i >= 0; i--){
            a = (a << 1) + this.getBit(i);
        }
        return a;
    }
}