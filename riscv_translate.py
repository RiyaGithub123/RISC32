#!/usr/bin/env python3
"""
riscv_translate.py
Translates a subset of standard RISC-V assembly instructions (.s) 
into machine code hex for the custom 32-bit pipelined RISC processor.
"""

import sys
import re

# Opcode constants for the custom RISC processor
OP_MOV      = 0
OP_ADD      = 1
OP_SUB      = 2
OP_MUL      = 3
OP_MOVSGPR  = 4
OP_RAND     = 5
OP_ROR      = 6
OP_RXOR     = 7
OP_RXNOR    = 8
OP_RNAND    = 9
OP_RNOR     = 10
OP_RNOT     = 11
OP_STOREREG = 12
OP_STOREDIN = 13
OP_SENDDOUT = 14
OP_SENDREG  = 15
OP_JUMP     = 16
OP_JC       = 17
OP_JNC      = 18
OP_JS       = 19
OP_JNS      = 20
OP_JZ       = 21
OP_JNZ      = 22
OP_JV       = 23
OP_JNV      = 24
OP_NOP      = 26
OP_HALT     = 27

# Map standard RISC-V register names to r0-r31
REG_MAP = {
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
    't0': 5, 't1': 6, 't2': 7, 's0': 8, 'fp': 8, 's1': 9,
    'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15, 'a6': 16, 'a7': 17,
    's2': 18, 's3': 19, 's4': 20, 's5': 21, 's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
    't3': 28, 't4': 29, 't5': 30, 't6': 31
}

# Add x0-x31 and r0-r31 mapping
for i in range(32):
    REG_MAP[f'x{i}'] = i
    REG_MAP[f'r{i}'] = i

def parse_reg(reg_str):
    reg_str = reg_str.strip().lower().replace(',', '')
    if reg_str in REG_MAP:
        return REG_MAP[reg_str]
    raise ValueError(f"Unknown register: '{reg_str}'")

def parse_imm(imm_str):
    imm_str = imm_str.strip().replace(',', '')
    if imm_str.startswith('0x') or imm_str.startswith('0X'):
        return int(imm_str, 16)
    return int(imm_str, 10)

def encode(opcode, rdes, rsrc1, imm_mode, rsrc2_or_imm):
    val = 0
    val |= (opcode & 0x1F) << 27
    val |= (rdes & 0x1F) << 22
    val |= (rsrc1 & 0x1F) << 17
    val |= (imm_mode & 0x01) << 16
    if imm_mode == 1:
        # Two's complement for 16-bit immediate
        val |= (int(rsrc2_or_imm) & 0xFFFF)
    else:
        val |= (rsrc2_or_imm & 0x1F) << 11
    return f"{val:08x}"

def main():
    if len(sys.argv) < 3:
        print("Usage: python riscv_translate.py <input_assembly.s> <output_mem_file.mem>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    # Step 1: Read assembly file and pre-process
    with open(input_file, 'r') as f:
        lines = f.readlines()

    # Pre-processed instructions and label tracker
    raw_instructions = []
    labels = {}
    
    # Track labels and expansion
    instruction_idx = 0

    for line in lines:
        # Strip comments and whitespace
        line = line.split('#')[0].split(';')[0].strip()
        if not line:
            continue
            
        # Ignore compiler directives
        if line.startswith('.'):
            continue

        # Check for label
        label_match = re.match(r'^([a-zA-Z0-9_\.]+):$', line)
        if label_match:
            labels[label_match.group(1)] = instruction_idx
            continue

        # Inside line instructions, handle inline labels e.g., 'main: li a0, 5'
        inline_label_match = re.match(r'^([a-zA-Z0-9_\.]+):\s*(.*)$', line)
        if inline_label_match:
            labels[inline_label_match.group(1)] = instruction_idx
            line = inline_label_match.group(2).strip()

        # Split instruction name and arguments
        parts = re.split(r'\s+', line, maxsplit=1)
        inst_name = parts[0].lower()
        args = parts[1] if len(parts) > 1 else ""

        # Estimate how many custom instructions this expands to
        # Branches expand to 2 instructions (sub + branch)
        if inst_name in ['beq', 'bne', 'blt', 'bge', 'ble', 'bgt', 'beqz', 'bnez', 'bltz', 'bgez']:
            instruction_idx += 2
        else:
            instruction_idx += 1

        raw_instructions.append((inst_name, args, len(raw_instructions)))

    # Step 2: Translate instructions
    machine_code = []
    current_idx = 0

    for inst_name, args, orig_line in raw_instructions:
        try:
            # Parse arguments
            arg_list = [a.strip() for a in args.split(',') if a.strip()]

            # NOP
            if inst_name == 'nop':
                machine_code.append(encode(OP_NOP, 0, 0, 0, 0))
                current_idx += 1
                
            # HALT (custom or unimp)
            elif inst_name in ['halt', 'unimp']:
                machine_code.append(encode(OP_HALT, 0, 0, 0, 0))
                current_idx += 1

            # LI rd, imm -> MOV rd, r0, #imm (since OP_MOV uses rsrc1=0, imm_mode=1)
            elif inst_name == 'li':
                rd = parse_reg(arg_list[0])
                imm = parse_imm(arg_list[1])
                machine_code.append(encode(OP_MOV, rd, 0, 1, imm))
                current_idx += 1

            # MV rd, rs -> MOV rd, r0, rs (imm_mode=0)
            elif inst_name == 'mv':
                rd = parse_reg(arg_list[0])
                rs = parse_reg(arg_list[1])
                machine_code.append(encode(OP_MOV, rd, 0, 0, rs))
                current_idx += 1

            # ADD rd, rs1, rs2
            elif inst_name == 'add':
                rd = parse_reg(arg_list[0])
                rs1 = parse_reg(arg_list[1])
                rs2 = parse_reg(arg_list[2])
                machine_code.append(encode(OP_ADD, rd, rs1, 0, rs2))
                current_idx += 1

            # ADDI rd, rs1, imm
            elif inst_name == 'addi':
                rd = parse_reg(arg_list[0])
                rs1 = parse_reg(arg_list[1])
                imm = parse_imm(arg_list[2])
                machine_code.append(encode(OP_ADD, rd, rs1, 1, imm))
                current_idx += 1

            # SUB rd, rs1, rs2
            elif inst_name == 'sub':
                rd = parse_reg(arg_list[0])
                rs1 = parse_reg(arg_list[1])
                rs2 = parse_reg(arg_list[2])
                machine_code.append(encode(OP_SUB, rd, rs1, 0, rs2))
                current_idx += 1

            # MUL rd, rs1, rs2
            elif inst_name == 'mul':
                rd = parse_reg(arg_list[0])
                rs1 = parse_reg(arg_list[1])
                rs2 = parse_reg(arg_list[2])
                machine_code.append(encode(OP_MUL, rd, rs1, 0, rs2))
                current_idx += 1

            # AND rd, rs1, rs2
            elif inst_name == 'and':
                rd = parse_reg(arg_list[0])
                rs1 = parse_reg(arg_list[1])
                rs2 = parse_reg(arg_list[2])
                machine_code.append(encode(OP_RAND, rd, rs1, 0, rs2))
                current_idx += 1

            # ANDI rd, rs1, imm
            elif inst_name == 'andi':
                rd = parse_reg(arg_list[0])
                rs1 = parse_reg(arg_list[1])
                imm = parse_imm(arg_list[2])
                machine_code.append(encode(OP_RAND, rd, rs1, 1, imm))
                current_idx += 1

            # OR rd, rs1, rs2
            elif inst_name == 'or':
                rd = parse_reg(arg_list[0])
                rs1 = parse_reg(arg_list[1])
                rs2 = parse_reg(arg_list[2])
                machine_code.append(encode(OP_ROR, rd, rs1, 0, rs2))
                current_idx += 1

            # ORI rd, rs1, imm
            elif inst_name == 'ori':
                rd = parse_reg(arg_list[0])
                rs1 = parse_reg(arg_list[1])
                imm = parse_imm(arg_list[2])
                machine_code.append(encode(OP_ROR, rd, rs1, 1, imm))
                current_idx += 1

            # XOR rd, rs1, rs2
            elif inst_name == 'xor':
                rd = parse_reg(arg_list[0])
                rs1 = parse_reg(arg_list[1])
                rs2 = parse_reg(arg_list[2])
                machine_code.append(encode(OP_RXOR, rd, rs1, 0, rs2))
                current_idx += 1

            # XORI rd, rs1, imm
            elif inst_name == 'xori':
                rd = parse_reg(arg_list[0])
                rs1 = parse_reg(arg_list[1])
                imm = parse_imm(arg_list[2])
                machine_code.append(encode(OP_RXOR, rd, rs1, 1, imm))
                current_idx += 1

            # NOT rd, rs
            elif inst_name == 'not':
                rd = parse_reg(arg_list[0])
                rs = parse_reg(arg_list[1])
                machine_code.append(encode(OP_RNOT, rd, rs, 0, 0))
                current_idx += 1

            # LW rd, offset(rs1)
            elif inst_name == 'lw':
                rd = parse_reg(arg_list[0])
                # Parse offset(rs1)
                mem_match = re.match(r'^(-?\d+|0x[0-9a-fA-F]+)\((.+)\)$', arg_list[1])
                if mem_match:
                    offset = parse_imm(mem_match.group(1))
                    rs1 = parse_reg(mem_match.group(2))
                else:
                    raise ValueError(f"Invalid memory operand: {arg_list[1]}")
                machine_code.append(encode(OP_SENDREG, rd, rs1, 1, offset))
                current_idx += 1

            # SW rs2, offset(rs1)
            elif inst_name == 'sw':
                rs2 = parse_reg(arg_list[0])
                mem_match = re.match(r'^(-?\d+|0x[0-9a-fA-F]+)\((.+)\)$', arg_list[1])
                if mem_match:
                    offset = parse_imm(mem_match.group(1))
                    rs1 = parse_reg(mem_match.group(2))
                else:
                    raise ValueError(f"Invalid memory operand: {arg_list[1]}")
                # For STOREREG, rdes=source register rs2, rsrc1=base register rs1
                machine_code.append(encode(OP_STOREREG, rs2, rs1, 1, offset))
                current_idx += 1

            # JUMP / J label (unconditional branch)
            elif inst_name in ['j', 'jal']:
                # jal in standard rv32i is usually jal x0, label (or jal rd, label)
                # If jal rd, label is used where rd != x0, we only support unconditional branch here.
                target_label = arg_list[-1]
                if target_label not in labels:
                    raise ValueError(f"Undefined label: {target_label}")
                target_addr = labels[target_label]
                # JUMP uses imm_mode=1 with target_addr
                machine_code.append(encode(OP_JUMP, 0, 0, 1, target_addr))
                current_idx += 1

            # Conditional branches (translate to: sub r0, rs1, rs2 + conditional jump)
            elif inst_name in ['beq', 'bne', 'blt', 'bge', 'ble', 'bgt']:
                rs1 = parse_reg(arg_list[0])
                rs2 = parse_reg(arg_list[1])
                target_label = arg_list[2]
                if target_label not in labels:
                    raise ValueError(f"Undefined label: {target_label}")
                target_addr = labels[target_label]

                # Step 2a: Subtraction to set flags (dest=0, i.e., r0/x0)
                if inst_name in ['beq', 'bne', 'blt', 'bge']:
                    machine_code.append(encode(OP_SUB, 0, rs1, 0, rs2))
                else:  # ble, bgt
                    machine_code.append(encode(OP_SUB, 0, rs2, 0, rs1))
                current_idx += 1

                # Step 2b: Conditional jump based on subtraction flags
                if inst_name == 'beq':
                    machine_code.append(encode(OP_JZ, 0, 0, 1, target_addr))
                elif inst_name == 'bne':
                    machine_code.append(encode(OP_JNZ, 0, 0, 1, target_addr))
                elif inst_name in ['blt', 'bgt']:
                    # if rs1 < rs2, rs1 - rs2 is negative, Sign flag is set.
                    # if rs2 > rs1, rs2 - rs1 is positive, Sign flag is not set.
                    machine_code.append(encode(OP_JS, 0, 0, 1, target_addr))
                elif inst_name in ['bge', 'ble']:
                    # if rs1 >= rs2, rs1 - rs2 is positive, Sign flag is not set.
                    machine_code.append(encode(OP_JNS, 0, 0, 1, target_addr))
                current_idx += 1

            # Pseudo branches comparing against zero (e.g. beqz rs, label)
            elif inst_name in ['beqz', 'bnez', 'bltz', 'bgez']:
                rs = parse_reg(arg_list[0])
                target_label = arg_list[1]
                if target_label not in labels:
                    raise ValueError(f"Undefined label: {target_label}")
                target_addr = labels[target_label]

                # sub x0, rs, x0
                machine_code.append(encode(OP_SUB, 0, rs, 0, 0))
                current_idx += 1

                if inst_name == 'beqz':
                    machine_code.append(encode(OP_JZ, 0, 0, 1, target_addr))
                elif inst_name == 'bnez':
                    machine_code.append(encode(OP_JNZ, 0, 0, 1, target_addr))
                elif inst_name == 'bltz':
                    machine_code.append(encode(OP_JS, 0, 0, 1, target_addr))
                elif inst_name == 'bgez':
                    machine_code.append(encode(OP_JNS, 0, 0, 1, target_addr))
                current_idx += 1

            else:
                raise ValueError(f"Unsupported instruction: {inst_name}")

        except Exception as e:
            print(f"Error on line: '{inst_name} {args}'")
            print(e)
            sys.exit(1)

    # Pad with NOPs to 64 instructions (instruction memory size)
    while len(machine_code) < 64:
        machine_code.append(encode(OP_NOP, 0, 0, 0, 0))

    # Write out hex representation
    with open(output_file, 'w') as f:
        for code in machine_code[:64]:
            f.write(code + '\n')

    print(f"Successfully translated {input_file} to {output_file} ({len(machine_code)} instructions).")

if __name__ == '__main__':
    main()
