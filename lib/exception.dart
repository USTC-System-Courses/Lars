class LabelException implements Exception {
    // final String message;
    List<String> Sentence_Spilt = [];
    LabelException(this.Sentence_Spilt);
}

class SentenceException implements Exception {
    String message = "";
    String Exception_String;
    final Exception_type type;
    SentenceException(this.type, this.Exception_String){
        message = Exception_Info[type]!;
    }

    @override
    String toString() => 'in Sentence \' ' + Exception_String + '\' \n\t' + type.toString() + ': ' + message;
}

class MemoryException implements Exception {
    final MEM_EXP_type type;
    MemoryException(this.type);
}

class SimulateException implements Exception {
    final bool type;
    SimulateException(this.type);
}

enum MEM_EXP_type{
    MEM_READ_UNINIT,
    MEM_OUT_OF_RANGE,
    MEM_NOT_ALIGNED,
    UNEXPECTED_MEM_ERROR,
}

enum Exception_type{
    UNKNOWN_INST,
    RESTRICT_REG,
    REG_OUT_OF_RANGE,
    IMM_OUT_OF_RANGE,
    INVALID_LABEL,
    INVALID_SEGMENT,
    LABEL_NOT_FOUND,
    LABEL_TOO_FAR,
    INVALID_REGNAME,
    INVALID_IMM,
}

Map<Exception_type, String> Exception_Info = {
    Exception_type.UNKNOWN_INST: 'Can\'t Find Such Opcode in LoongArch32 Instruction Set',
    Exception_type.RESTRICT_REG: 'The 21st Register is Restricted',
    Exception_type.REG_OUT_OF_RANGE: 'The Register Number is Out of Range',
    Exception_type.IMM_OUT_OF_RANGE: 'The Immediate Number is Out of Range',
    Exception_type.INVALID_LABEL: 'Invalid Label Name',
    Exception_type.INVALID_SEGMENT: '.Text or .Data shall follow a new line',
    Exception_type.LABEL_NOT_FOUND: 'Label Not Found',
    Exception_type.LABEL_TOO_FAR: 'Label can\'t reach',
    Exception_type.INVALID_REGNAME: 'Invalid Register Name',
    Exception_type.INVALID_IMM: 'Invalid Immediate Number',
};