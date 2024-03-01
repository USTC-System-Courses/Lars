import 'package:binary/binary.dart';
const int UI32_mask = 0xffffffff;
extension Uint32_ext on Uint32{
    Uint32 operator +(Uint32 other){
        return Uint32((this.toInt() + other.toInt()) & UI32_mask);
    }

    Uint32 add(int other){
        return Uint32((this.toInt() + other) & UI32_mask);
    }

    Uint8 operator [](int byte_offset){
        int temp = 0;
        for(int i = 8 * byte_offset + 7; i > 8 * byte_offset - 1; i--){
            temp = (temp << 1) + this.getBit(i);
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

    int toSignedInt(){
        if(this.getBit(31) == 1){
            return -((~this).add(1).toInt());
        }
        return this.toInt();
    }

    int operator -(Uint32 other){
        return this.toInt() - other.toInt();
    }
}

extension Uint8_ext on Uint8{
    int toInt(){
        int a = 0;
        for(int i = 7; i >= 0; i--){
            a = (a << 1) + this.getBit(i);
        }
        return a;
    }
}


    Uint32_t(int a){
        return Uint32(a & UI32_mask);
    }