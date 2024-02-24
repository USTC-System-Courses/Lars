import 'package:binary/binary.dart';
import 'package:helloworld/exception.dart';
import './Uint32_ext.dart';

class Memory{
    final Uint32 CONFIG_PMEM_BASE = Uint32(0x1c000000);
    final Uint32 CONFIG_PMEM_SIZE = Uint32(0x08000000); //128Mb

    Map<Uint32, Uint8> pmem = {};

    bool in_pmem(Uint32 addr) {
        return addr >= (CONFIG_PMEM_BASE) && addr < (CONFIG_PMEM_BASE + CONFIG_PMEM_SIZE);
    }

    void write(Uint32 w_addr, Uint32 w_data, {int size = 4}){
        if(pmem.containsKey(w_addr)){
            pmem[w_addr] = w_data[0];
            if (size > 1) pmem[w_addr.add(1)] = w_data[1];
            if (size > 2) {
                pmem[w_addr.add(2)] = w_data[2];
                pmem[w_addr.add(3)] = w_data[3]; 
            }
        }
        else {
            pmem.putIfAbsent(w_addr, () => w_data[0]);
            if (size > 1) pmem.putIfAbsent(w_addr.add(1), () => w_data[1]);
            if (size > 2) {
                pmem.putIfAbsent(w_addr.add(2), () => w_data[2]);
                pmem.putIfAbsent(w_addr.add(3), () => w_data[3]);
            }
        }
    }

    Uint32 read(Uint32 r_addr, {int size = 4}){
        int temp = 0;
        if(size > 4) return Uint32(0);
        for(int i = size - 1; i >= 0; i--){
            temp = (temp << 8) + _read_byte(r_addr.add(i)).toInt();
        }
        return Uint32(temp);
    }

    Uint32 _read_byte(Uint32 r_addr){
        if(pmem.containsKey(r_addr)){
            var temp = pmem[r_addr];
            return Uint32(temp!.toInt());
        }
        else throw MemoryException(MEM_EXP_type.MEM_READ_UNINIT);
    }

    int operator [](Uint32 r_addr){
        int temp = 0;
        for(int i = 3; i >= 0; i--){
            try {
                temp = (temp << 8) + _read_byte(r_addr.add(i)).toInt();
            } catch (e) {
                temp = (temp << 8);
            }
        }
        return (temp);
    }
    Memory(){}
}