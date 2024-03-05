#  LARS使用手册

## 目录

## 寄存器命名规范

在LARS中，寄存器命名既可以采用LA32R规定的标准寄存器格式书写，也可以使用龙芯“新世界2.0ABI”约定的寄存器别名格式书写，对照表如下：

| 寄存器格式 | 寄存器别名 |
| :---: | :---: |
| $r0 | $zero |
| $r1 | $ra |
| $r2 | $tp |
| $r3 | $sp |
|$r4 - $r11| $a0 - $a7|
|$r12 - $r20| $t0 - $t8|
|$r21|无别名|
|$r22| $s9/$fp|
|$r23 - $r31| $s0 - $s7|

需要注意的是：
* **寄存器名称不区分大小写**，即$zero和$ZERO是等价的, $s0和$S0是等价的。
* **寄存器名称首个'$'符号可以省略**，即zero和$zero是等价的, s0和$s0是等价的。

## 汇编指令格式

### 架构指令
LARS支持LA32R架构的绝大部分**基础整数指令**和一条自定义停机指令，指令定义及说明如下：

|指令格式|指令功能|说明|
|:---:|:---:|:---:|
|add.w rd, rj, rk|rd = rj + rk|整数加法|
|sub.w rd, rj, rk|rd = rj - rk|整数减法|
|slt rd, rj, rk|rd = (rj.s < rk.s)|有符号整数比较|
|sltu rd, rj, rk|rd = (rj < rk)|无符号整数比较|
|and rd, rj, rk|rd = rj & rk|按位与|
|or rd, rj, rk|rd = rj \| rk|按位或|
|xor rd, rj, rk|rd = rj ^ rk|按位异或|
|sll.w rd, rj, rk|rd = rj << rk|逻辑左移|
|srl.w rd, rj, rk|rd = rj >> rk|逻辑右移|
|sra.w rd, rj, rk|rd = rj >>> rk|算术右移|
|mul.w rd, rj, rk|rd = rj * rk|整数乘法|
|mulh.w rd, rj, rk|rd = (rj.s * rk.s) >> 32|有符号整数乘法，取高32位|
|mulh.wu rd, rj, rk|rd = (rj * rk) >> 32|无符号整数乘法，取高32位|
|div.w rd, rj, rk|rd = rj / rk|有符号整数除法|
|mod.w rd, rj, rk|rd = rj % rk|有符号整数取模|
|divu.w rd, rj, rk|rd = rj / rk|无符号整数除法|
|modu.w rd, rj, rk|rd = rj % rk|无符号整数取模|
|slli.w rd, rj, imm|rd = rj << imm|逻辑左移|
|srli.w rd, rj, imm|rd = rj >> imm|逻辑右移|
|srai.w rd, rj, imm|rd = rj >>> imm|算术右移|
|slti rd, rj, imm|rd = (rj.s < imm.s)|有符号整数比较|
|sltiu rd, rj, imm|rd = (rj < imm)|无符号整数比较|
|andi rd, rj, imm|rd = rj & imm|按位与|
|ori rd, rj, imm|rd = rj \| imm|按位或|
|xori rd, rj, imm|rd = rj ^ imm|按位异或|
|lu12i rd, imm|rd = imm << 12|加载高20位立即数|
|auipc rd, imm|rd = pc + (imm << 12)|加载加上pc的高20位立即数|
|ld.b rd, rj, imm|rd = SE(Mem[rj + imm])|加载字节并符号拓展|
|ld.h rd, rj, imm|rd = SE(Mem[rj + imm])|加载半字并符号拓展|
|ld.w rd, rj, imm|rd = Mem[rj + imm]|加载字|
|st.b rd, rj, imm|Mem[rj + imm] = rd|存储字节|
|st.h rd, rj, imm|Mem[rj + imm] = rd|存储半字|
|st.w rd, rj, imm|Mem[rj + imm] = rd|存储字|
|ld.bu rd, rj, imm|rd = Mem[rj + imm]|加载字节并零拓展|
|ld.hu rd, rj, imm|rd = Mem[rj + imm]|加载半字并零拓展|
|jirl rd, rj, *label*|rd = pc + 4; pc = *label*|间接相对跳转并链接|
|b *label*|pc = *label*|无条件跳转|
|bl *label*|$ra = pc + 4; pc = *label*|函数（子程序）调用并链接|
|beq rj, rd, *label*|if (rj == rd) pc = *label*|相等跳转|
|bne rj, rd, *label*|if (rj != rd) pc = *label*|不等跳转|
|blt rj, rd, *label*|if (rj.s < rd.s) pc = *label*|有符号小于跳转|
|bge rj, rd, *label*|if (rj.s >= rd.s) pc = *label*|有符号大于等于跳转|
|bltu rj, rd, *label*|if (rj < rd) pc = *label*|无符号小于跳转|
|bgeu rj, rd, *label*|if (rj >= rd) pc = *label*|无符号大于等于跳转|

> 注：
> * **rd, rj, rk, rs**为32位整数寄存器，**imm**为32位立即数，***label***为标签。
> .s表示将寄存器中的值视为有符号整数。
> * **SE**表示符号拓展，即将字节或半字拓展为32位整数。
> * **Mem**表示内存，内存地址空间为32位。
> * 各指令立即数的范围详见《龙芯架构32位精简版指令集》。

### 宏指令
LARS支持LA32R编译器规定的两条宏指令，指令定义及说明如下：

#### 加载32位立即数：li rd, imm

该指令将32位立即数imm加载到寄存器rd中，指令格式如下：

```assembly
li rd, imm
```

该指令会尽可能少地转换为lu12i.w和ori指令，最多转换为两条指令。

#### 加载地址：la rd, *label*

该指令将标签*label*的地址加载到寄存器rd中，指令格式如下：

```assembly
la rd, label
```

该指令会转换为一条lu12i.w指令和一条ori指令。

## 标记和标签规范

### 标记
LARS支持LA32R编译器规定的6个标记，标记定义及说明如下：

|标记|说明|
|:---:|:---:|
|.text|代码段标记|
|.data|数据段标记|
|.word num| 此处存放一个32位立即数num|
|.byte num| 此处存放一个8位立即数num|
|.half num| 此处存放一个16位立即数num|
|.space num| 此处存放num个字节的0|

### 标签

程序标签需要由字母、数字和下划线组成，且不能以数字开头。标签对应的地址为标签下方第一条指令的地址，例如

```assembly
    mul.w $r1, $r2, $r3
label:
    add.w $r1, $r2, $r3
    sub.w $r4, $r5, $r6
```

label对应的地址为add.w指令的地址。

