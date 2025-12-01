---
author: Dr. Steffen Hirschmann<br/>(Slides can be shared under CC-BY-SA.)
title: Embedded Memory Optimization (RAM & ROM)
subtitle: ESE Kongress 2025, Sindelfingen
date: 2025-12-01
slideNumber: true
width: 1280
height: 900
transitionSpeed: fast
---

# The Good News

It's not rocket science!


## Who am I?

- 2015–2021: PhD in Scientific Computing / HPC
    - Optimize large-scale simulations
- 2021–2024 Performance Engineer at Bosch
    - Embedded Optimizations (ARMv7, ARMv8, TriCore, and more)
    - ROM/RAM/Runtime ROI impact: Saved millions EUR
- 2024–2025 Performance Engineer at Efficientware


## Agenda

Part 1 (why, what, how):

- What exactly is ROM? What "consumes" it?
- File Formats: ELF
- Memory Layout?
- Measuring ROM Consumption

Part 2 & 3: ROM & RAM optimization

- Examples, dig deep
- Understand mapping of C/C++ to binary
- Compiler/runtime environment trade-offs
- Guiding compiler
- General guardrails and rules


# Part 1: Why? What? (Approach)


## Reasons to Optimize for RAM and/or ROM

- SW does not fit on HW (cannot be flashed anymore)
    - Project dead (we have seen projects on the edge of failure due to ROM issues)
    - Contractual penalty
- Smaller device
    - Larger profit margin, save $$$
- Outperform competition
    - Have more features on the same device
- Update to existing Embedded device
    - Extend lifetime of product


## Cost

Past experience:

- Project requires about 100 kB more ROM than available on SoC.
- Cost estimated at around 0.00014 €/kB (0.014 cent).

- 230 million devices => 32,000 €/kB
- 100 kB => 3.2 mio €.


This cost does not include any complications that adding more memory to a device brings along, like the need for more elaborate packaging and cooling solutions!



## Green Software

IPhone 14: 61 kg CO2e (GWP100)

| | % | 1 device | 230 mio. devices |
|-|---|----------|------------------|
|Production|79% | 49.4 kg CO2e | 11.4 mio tons CO2e |
|Use| 18% | 11 kg CO2e |	2.52 mio tons CO2e |

230 mio iPhone 14: ~ Slovenia or Estonia


- Less production CO2
- Less energy use during runtime (e.g. only 13.5% of new cars in the EU are "emission-free")



## Optimization Cycle

![](img/optimization-process-2.png){ height=50% }



## Optimization Cycle

![](img/optimization-process.png){ height=50% }



## How can we Understand ROM & RAM Consumption?

Understand...

1. what ROM is,
1. how to measure it,
1. mapping of C/C++/... to binary,
1. continuously monitor in your project



## What is RAM & ROM

| ROM | RAM |
|-----|-----|
| Read Only Memory | Random Access Memory |
| EEPROM or Flash | DRAM |

Analogy to PCs: ROM = Disk space; RAM = RAM

What do we store there?

- ROM: Code, read-only data (“constants”), initialization data
- RAM: State (variables, etc.)

Embedded devices *may not* be able to execute from flash.

- ROM might need to be completely loaded into RAM (see PC)

Problem: Disparity between C/C++ and ROM / RAM consumption.



## Software Build Pipeline

![](img/compilation-pipeline.png){ height=70% }



## ELF Structure

- ELF Header
- Program headers (also called “segment headers”)
- Binary blob
- Optional: Section headers


## ELF Structure

![Image copyright Ange Albertini, CC-BY](img/elf.png){ height=700px }


## ELF Structure

Segment headers:

- Information for loading at runtime / flashed to device

Section headers:

- For participation in linking (static or dynamic)
- Not inspected by loader / flashing

Sections are valuable:

- Names come from linker scripts
- We will inspect sections because they define what the data is
- Debug info comes in extra sections
- Therefore, we need a non-stripped executable



## ELF Example

```
$ readelf -h my_program
ELF Header:
  Magic:   7f 45 4c 46 01 01 01 00 [...] 
  Class:                     ELF32
  Data:                      2's complement, little endian
  Version:                   1 (current)
  OS/ABI:                    UNIX - System V
  ABI Version:               0
  Type:                      EXEC (Executable file)
  Machine:                   ARM
  Version:                   0x1
  Entry point address:       0x8125
  Start of program headers:  52 (bytes into file)
  Start of section headers:  6393040 (bytes into file)
  Flags:                     Version5 EABI, hard-float ABI
  [...]
```

[https://godbolt.org/z/PqvbceT99](https://godbolt.org/z/PqvbceT99)


## ELF Example: Program headers

```
$ readelf -l my_program
[...]

Program Headers:
  Type       Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  ARM_EXIDX  0x0d9030 0x000d9030 0x000d9030 0x00008 0x00008 R   0x4
  LOAD       0x000000 0x00000000 0x00000000 0xd903c 0xd903c R E 0x10000
  LOAD       0x0d903c 0x000e903c 0x000e903c 0x0080c 0x3719c RW  0x10000

 Section to Segment mapping:
  Segment Sections...
   00     .ARM.exidx 
   01     .init .text .fini .rodata .ARM.exidx .eh_frame 
   02     .init_array .fini_array .data .bss
```


## ELF Example: Section headers

```
$ readelf -S my_program
[...]

Section Headers:
  [Nr] Name     Type      Addr     Off    Size   ES Flg Lk Inf Al
[...]
  [ 2] .text    PROGBITS  00008040 008040 012d90 00  AX  0   0 64
[...]
  [ 4] .rodata  PROGBITS  0001ade0 01ade0 0be250 00   A  0   0 16
[...]
  [ 9] .data    PROGBITS  000e9048 0d9048 000800 00  WA  0   0  8
  [11] .bss     NOBITS    000e9850 0d9848 036988 00  WA  0   0 16
[...]
  [24] .symtab  SYMTAB    00000000 60bfdc 006810 10     25 1133  4
  [25] .strtab  STRTAB    00000000 6127ec 0063cc 00      0   0  1

[...]
```


## Special ELF Sections

Ever encountered this while debugging?

```
0x00007ffff7fc310e in ?? () from ./liba.so
(gdb) where
#0 0x00007ffff7fc310e in ?? () from ./liba.so
#1 0x00007ffff7fc3156 in func1 () from ./liba.so
#2 0x00005555555551b6 in ?? ()
#3 0x00007ffff7de7083 in __libc_start_main () from /lib/x86_64-linux-gnu/libc.so.6
#4 0x00005555555550ce in ?? ()
```

- "Stripped"
- Here, we only see exported or imported symbols ("dynsym")



## Special ELF Sections

Symbol tables in ELF (simplified)

Liba.so internals, “a.c”:
```
static int f2(int i) { ... }		// internal linkage
static int f1(int i) { ... }		// 			"
int func1(int i) { ... }			// external linkage
```

| .dynsym | .symtab | .debug_* |
|---------|---------|----------|
| func1   | f2      | f2: source, params, types, etc. |
|         | f1      | f1: dito                        |
|         | f1      | func: dito                      |

- .dynsym is mandatory if ex-/imported symbols exist (for dynamic linking)
- .symtab is optional (for static linking)
- .debug_* is optional


## Special ELF Sections

Symbol tables in ELF (simplified)

- With .dynsym

```
0x00007ffff7fc310e in ?? () from ./liba.so
(gdb) where
#0 0x00007ffff7fc310e in ?? () from ./liba.so
#1 0x00007ffff7fc3156 in func1 () from ./liba.so
#2 0x00005555555551b6 in ?? ()
#3 0x00007ffff7de7083 in __libc_start_main () from /lib/x86_64-linux-gnu/libc.so.6
#4 0x00005555555550ce in ?? ()
```


## Special ELF Sections

Symbol tables in ELF (simplified)

- With .dynsym, .symtab

```
0x00007ffff7fc310e in f1 () from ./liba.so
(gdb) where
#0 0x00007ffff7fc310e in f2 () from ./liba.so
#1 0x00007ffff7fc3156 in func1 () from ./liba.so
#2 0x00005555555551b6 in main ()
```


## Special ELF Sections

Symbol tables in ELF (simplified)

- With .dynsym, .symtab, .debug_*

```
0x00007ffff7fc310e in f1 (i=321) at a.c:2
(gdb) where
#0 0x00007ffff7fc310e in f2 (i=12) at a.c:6
#1 0x00007ffff7fc3156 in func1 (i=12) at a.c:18
#2 0x00005555555551b6 in main (argc=2, argv=Ox/fffffffd978) at main.c:7
```


# Part 1.5: How to Measure RAM/ROM


## General Idea

Through understanding the binary (ELF), we can attribute RAM/ROM to binary parts of the binary program.

- Segments: Inspect headers.
- Sections: Inspect headers (optional)
- C/C++ names: Inspect debug info and/or symtab (optional sections)
- C/C++ names: Additional linker output ("mapfile")

Be careful: We only measure static consumption (compile-time determined)

- ROM is always static
- RAM typically also in embedded projects (no heap, etc.)



## Which ELF do we Use?

![](img/compilation-pipeline.png){height=50%}

- Can use any ELF file: .o, .a, .so, executable


## Object Files and Static Libraries

You can assess the ROM usage of .o or a .a files

*But be careful:*

- Weak symbols (non-ODR) appear multiple times (in multiple object files), but will only be included once in the final executable
- They might contain functions and/or data (or complete sections) that are not included in the final binary (e.g. -fdata-sections –gc-sections)
- Complete .o or .a files might be skipped if final executable does not need them


## Measuring RAM/ROM: Symtab Information

```c
typedef struct
{
  Elf64_Word	st_name;	/* Symbol name (string tbl index) */
  unsigned char	st_info;	/* Symbol type and binding */
  unsigned char st_other;	/* Symbol visibility */
  Elf64_Section	st_shndx;	/* Section index */
  Elf64_Addr	st_value;	/* Symbol value */
  Elf64_Xword	st_size;	/* Symbol size */
} Elf64_Sym;
```

We can extract this information (if it is available) with tools

- Binutils: `nm -S`, `readelf -s`
- GHS `gfunsize`, Lauterbach Trace32, etc.

![](img/inline-candidates.png)

(Ignore the "candidates" stuff for now).


## Measuring RAM/ROM: Symtab Information with Bloaty

[https://github.com/google/bloaty](https://github.com/google/bloaty)

```sh
bloaty --domain vm -s vm -d sections,symbols -n 0 <elf_file>
```

- `--domain vm`: runtime RAM/ROM consumption (in contrast to file size), `-s vm` sort w.r.t. `vm` usage
- `-d sections,symbols` list sections and for each section the contained symbols (if you have debug symbols, you can also say `-d compileunits`)
- `-n 0` do not truncate


IF you have a toolchain that mangles differently, but it comes with a `c++filt` equivalent (for GHS: `decode`): `bloaty <...> | decode`


## Measuring RAM/ROM: Diffing Two Binaries

```sh
bloaty <options> <new_file> -- <old_file>
```

Be careful of alignment in combination with linker reordering (might cause *arbitrary*, small differences).



## Measuring RAM/ROM: Mapfiles

- Text file that contains detailed information about ELF
- Segments, Sections, Symbols with address *and size*

Additionally:

- Memory usage by translation unit
- Which translation units symbols stem from
- Cross-reference of symbols (where is it referenced?)
- etc.

No need for debug symbols, because Linker outputs this information besides ELF

- GCC's `gold` linker: `-Map`
- Check for your toolchain
- Output by default, examine to check what info is available


## From “What” to “Why”

- Names tell us (roughly) where the problem is
- Typically problem not obvious in C/C++ code

Drill further down from symbols to its parts

- Data memory layout / individual data members
- Inspecting code / disassembly


## Additional Info: Data Memory Layout in DWARF

```text
0x0000a54d:   DW_TAG_structure_type
                DW_AT_byte_size (0x08)
                [...]
                DW_AT_linkage_name      ("2xy")
                [...]
0x0000a55b:     DW_TAG_member
                  DW_AT_name    ("x")
                  [...]
                  DW_AT_type    (0x0000098a "int")
                  DW_AT_data_member_location    (0x00)
0x0000a566:     DW_TAG_member
                  DW_AT_name    ("y")
                  [...]
                  DW_AT_type    (0x0000098a "int")
                  DW_AT_data_member_location    (0x04)
0x0000a571:     NULL
```

## Additional Info: View Data Memory Layout

Information about struct layouts is saved in debug info (e.g. DWARF).
Can be viewed with appropriate tools.

- `dwarfdump`
- `pahole`
- `gdb`: `ptype`  (`ptype /o` for size info)
- Lauterbach Trace32
- etc.



## Additional Info: Inspect Code

- Disassembling
- Debug info for relation to source code

Tools:

- `objdump` (`-S` for source info)
- `gdb`: `disas` (`disas /s` for source info)
- Trace32
- Ghidra
- etc.

And of course:

- Godbolt



## Measuring Stack Consumption

Static upper bound:

- Tools can give conservative estimates
- Only works in constrained environments, e.g. no function pointers (vtable)
- E.g.: GHS gstack, GCC/Clang -fstack-usage / -Wstack-usage=N

Dynamic (no upper bound guarantee!):

- Initialize whole stack segment with known pattern (grab top & bot address in linker script)
- Run expected worst-case workload
- Count #bytes that do not contain pattern anymore



# PART 1.9: Optimization Preliminaries

## The Elephant in the Room: Flags
ASIL toolchains usually come with fixed flags

If you *can* change them (GNU/Clang):

- Optimization flags (-O1, -O2, -O3, -Os)
- Errno and other overheads? (-fno-math-errno, -fno-stack-protector)
- Function cleanup (-ffunction-sections -Wl,--gc-sections)
- No RTTI (-fno-rtti)
- No exceptions (-fno-exceptions)
- Which libc (e.g. GHS offers w/ and w/o exception support)


## Inspecting Assembly

Assembly allows us to

1. Figure out unneeded implementation details
    - E.g.: Errno? (-fno-math-errno)
1. Check for missed optimization opportunity
    - E.g.: Failure to inline
1. Check for suboptimal compiler output (excessive memory usage)
    - E.g.: Loop unrolling, initialization


## Let’s Take the SQRT

```c++
float my_calculation(float x)
{
    return sqrt(x);
}
```

<!---
![](img/sqrt-example.png)
--->

Let's say, we are on ARMv7 with FPU.
What binary code should this generate?

[https://godbolt.org/z/fjfrKb3s8](https://godbolt.org/z/fjfrKb3s8)


## Optimization Agenda

ROM:

- Function inlining & parameter passing
- Constant propagation
- Trivial structures, data initialization
- Streamlining of data transformations (RAM+ROM)

RAM:

- Padding, data sizes, alignment
- (Virtual) inheritance (RAM+ROM)
- Separation of concerns
- Stack


# PART 2: ROM Optimization

## Inlining (Function Calls)

```c++
// ...
do_something(a, b, c, d);
// ...
```

Function calls are an abstraction.
What's the abstraction?


## Inlining (Function Calls)

```c++
// ...
do_something(a, b, c, d);
// ...
```

Function calls are an abstraction.
What's the abstraction?

- Non-local transfer of control
- Parameter passing
- Whatever you do inside does not affect original function
    - local variables
    - calling more functions
    - recursion

(The microarchitectural state of how a caller can be influenced, is potentially large.)


## Function Calls: Implementation

- Some cost mandated by C/C++ standard, e.g. recursion is supported (though environment is free to choose how it is implemented)
- Calling interface specified in ABI. (What do I have to do to call function `f` in assembly?)
- E.g. for ARM: [AAPCS](https://github.com/ARM-software/abi-aa/blob/2982a9f3b512a5bfdc9e3fea5d3b298f9165c36b/aapcs32/aapcs32.rst)
- C++ additions: Itanium ABI, e.g. this pointer, name mangling, exceptions


## Function Calls: Cost

- Control transfer: Call & return (2 insn)
- *ARM:* Save&restore the link register (2 insn)
- *Optional:* Prepare function arguments
    - MOV to argument register, (1+ insn per arg)
    - or: push to stack (2+ insn per arg)
    - For ref/ptr: Move to stack, deref in callee (2+ insn per arg)
- Optional: Setup stack frame in callee
    - E.g. ADD + SUB (+ MOV x2 for frame pointer) (2-4 insn)
- Optional: Save state of caller
    - MOV from volatile to non-volatile register or ST+LD (2+ insn per register)
- ...

(Which one is needed per call-site, which one per function definition?)


## Inlining Example

```c++
template <typename T>
struct StrongAlias {
	StrongAlias(const T&val);
	T& get() const;
private:
	T _v;
};
using Meter = StrongAlias<float>;
using Seconds = StrongAlias<float>;
using MeterPerSecond = StrongAlias<float>;

MeterPerSecond calc_speed(Meter distance, Seconds time) {
	return MeterPerSecond{distance.get() / time.get()};
}
```

[https://godbolt.org/z/e13hrW7jG](https://godbolt.org/z/e13hrW7jG)

- What code should that generate?
- What code does that generate?


## Inlining Example: Are we Done?

```c++
template <typename T>
struct StrongAlias {
	inline StrongAlias(const T&val): _v(val) {}
	inline T& get() const { return _v; }
private:
	T _v;
};
using Meter = StrongAlias<float>;
using Seconds = StrongAlias<float>;
using MeterPerSecond = StrongAlias<float>;

MeterPerSecond calc_speed(Meter distance, Seconds time) {
	return MeterPerSecond{distance.get() / time.get()};
}
```

Are we done?

::: incremental

- No, `calc_speed` suffers from the *exact* same problem.
- *Inlining is a multi-layer problem.*

:::

## Do we Need to do this Manually?!

Myth: "inline is just a hint; the compiler knows best"

Reality: one of the most important things to understand

- *Of course*, compiler must be able to inline in the first place, i.e. define function in header
- What else matters?


## What inline means: ODR vs. "inline"

There are two distinct effects of the inline keyword if it is applied to functions:

1. Exempt the function from the One Definition Rule
2. A hint for the compiler that "the body is supposed to be copied to the call site". This is not required by the standard.


> Every function must be defined exactly once. Exempt from this rule are templates and inline functions.

-- One Definition Rule

## Is Inlining Required?

Compiler philosophy

| "Don't inline if not marked as such" | "Inline is automatic" |
| -------------------------------------|-----------------------|
| Keyword used for ODR *and* inlining  | Keyword only used for ODR |


Deep call hierarchies might still need manual inlining *in either case*.


## What to Inline? (1)

1. Know the overhead of calling a function.

    - E.g.: x86-64 typically 5 Bytes for the call, 3 Bytes per scalar argument that needs to be put into the right register.
    - A very simple rule of thumb is to try to inline every function that is smaller than `5 + 3 * NARG`  Bytes.
    - You can omit “sink” arguments in the count, i.e. data that is not needed anymore after the call.
    - Remember “this” is an implicit argument to any member function, as are large return values

(Adapt this model as you learn more!)


## What to Inline? (2)

2. Get a list of all functions sorted by size.

    - Mapfiles
    - Coreutils NM, GHS gfunsize, bloaty, etc.
    - Possibly: some post-processing to sort by size

![](img/inline-candidates.png){width=70%}

(Attention: Many architectures need functions to be aligned and atop that many compilers align them additionally for performance reasons. Thus, functions can have trailing padding! The tool you choose should optimally not count these towards the function size.)


## What to Inline? (3)

3. Starting with the smallest, inline the functions.
    - Move from CPP to HPP and declare inline,
    - Build and verify ROM got smaller,
    - Repeat by getting a new list (2) and/or refine your cost model (1)


## Parameter Passing: Cost

Let's say, we pass integers.

- Some arguments can go to registers (depends on ABI)
- Excess arguments go to stack

=> Get rid of unused parameters


## Parameter Passing: Cost

By reference or by value?

- ABI dictates what types (dependent on size and layout) are passed how.
- Typically 8-16 Byte types are passable in registers (2-4 registers)
- Some architectures have separate data & pointer registers (e.g. TriCore).

|       | By value | By reference |
|-------|----------|--------------|
| small | Reg/stack|Move to stack & pass pointer |
| large | Copy to stack & pass pointer | Pointer in reg/stack |
| | | |


(Assuming small value is in register, large value in memory.)


## Parameter Passing: General Rules

- Pass integers, floats, etc. by value
- Pass small structs (e.g. `Vector2d`) by value *unless* they have a copy constructor (e.g. `std::string`).
- Keep an eye on the total register count used for parameters
- On TriCore: Do this for both, data arguments and pointer arguments
- Up to 2 implicit pointer arguments: `this`, large return values


## Parameter Passing: Inlining **CAN** Help


```c++
float add(const float&, const float&);

float foo() { return add(1, 2); }
```

What's the codegen of `foo`?

::: incremental

- Move literal `2` to stack, move literal `1` to stack, pass pointers to `add`
- Inlining and consequent compiler optimization typically remedy cost like this!
- Exotic compilers can have issues with omitting loads & stores from inlining reference arguments.

:::


## When **NOT** to Inline?

The misconception "inline increases ROM consumption" *can* be true!

<!---
![](img/no-inline.png){width=80%}
--->


```c++
template <typename T>
struct InterfaceRegistry {
    T* m_ptr;
    void register_interface(T* ptr) {
        m_ptr = ptr;
        if (!m_ptr) {
            set_error(C_REGISTRY, C_REGISTER_CALL, C_CRITICAL, "ptr is null");
        }
    }
};

template class InterfaceRegistry<int>;
```

- Central abstraction
- Instantiated hundreds of times with different types

[https://godbolt.org/z/jh16s7G66](https://godbolt.org/z/jh16s7G66)

::: incremental

- 18 bytes of instructions (movX) that load some error constants in the non-happy path

:::

## When **NOT** to Inline?

What to do?

- "Out"-line: Factor out the set_error call, and mark it as “no inline”
- Inlining for ROM reduction is not trivial (just as with runtime performance)


How to detect?

- Detection of "out-lining" much harder than "inlining"
- Use bloaty to sum up templates and check big entries manually
- Any other proposals?


## Constant Propagation

Compilers can do magic if constants are involved

```c++
int a = b / 871234;
```

vs.

```c++
int a = my_divide(b, 871234);
```

[https://godbolt.org/z/sdo1d6brv](https://godbolt.org/z/sdo1d6brv)


## Constant Prop: Full/partial folding

Fold complete computation at compilation time

```c++
int factorial(int n) { /* ... */ }
extern int N;
int foo() { return factorial(N); }
```

vs.

```c++
int factorial(int n) { /* ... */ }
constexpr int N = 7;
int foo() { return factorial(N); }
```

[https://godbolt.org/z/fdWYfGfe7](https://godbolt.org/z/fdWYfGfe7)

(Also partial compile-time evaluation possible, see e.g. [https://godbolt.org/z/fbxsoPnse](https://godbolt.org/z/fbxsoPnse))


## Constant Prop. at Callee Site

No need for inlining. If all callers pass the same arguments, consider making them constants:

- Control flow optimizations
- (Partially) precompute at runtime
- Peephole optimizations
- ...


## Constant Prop. at Callee Site

```c++
int clamp(int value, int min, int max)
{
    if (value >= max)
        return max;
    else if (value <= min)
        return min;
    else
        return value;
}
```

[https://godbolt.org/z/9TxxrWaqK](https://godbolt.org/z/9TxxrWaqK)

- Example: clamp values to [-128, 127] in int8 neural network.
- Not a single call with `max != 127 || min != -128`


::: incremental

- Declare `max` and `min` as constants
- Hundreds of Bytes ROM saved (inlined into many places)
- ~3% of runtime

:::

<!---
![](img/const-prop.png)
--->



## Data Initialization

What can a compiler translate this to?

```c++
template<typename T, size_t N>
struct Container {
  T data[N];
};

struct Data {
  float a{1.4258F}, b{2342.235F}, c{34213.3F}, d{-4.2243F};
};

// What does the initialization look like?
Container<Data, 100> c{};
Container<Data, 100> foo() {
  return {};
}
```

## Data Initialization

```c++
template<typename T, size_t N>
struct Container { T data[N]; };
struct Data { float a{1.4258F}, b{2342.235F}, c{34213.3F}, d{-4.2243F}; };

Container<Data, 100> c{};
Container<Data, 100> foo() { return {}; }
```

Compiler must pick a trade-off (different resources requirements for each variant):

1. Lay out full pattern (400 floats) in ROM & copy it
2. Lay out single pattern (4 floats) in ROM and copy 100 times
3. Create 4 floats from code onto stack (or first element) and copy 100 times
4. Create 4 floats from code in registers and store 100 times
5. ...?

Additionally: Is there function calls (Constructor, memcpy)?


## Data Initialization: Examples

GCC 15.2: [https://godbolt.org/z/xPf1Y6vve](https://godbolt.org/z/xPf1Y6vve)

- Full pattern for global
- Single pattern and store it 100 times

TI CL430 21.6.1: [https://godbolt.org/z/4r5Mb6M7e](https://godbolt.org/z/4r5Mb6M7e)

- Full pattern for global
- *Second* full pattern for local, (no RVO)

Clang:

- Zero initialization before pattern


## Data Initialization: More Complicated Example

```c++
template<typename T, size_t N>
struct Container {
  T data[N];
  size_t argmax;    // !
};

struct Data {
  float a{1.4258F}, b{2342.235F}, c{34213.3F}, d{-4.2243F};
};

// What does the initialization look like?
Container<Data, 100> c{};
Container<Data, 100> foo() { return {}; }
```

- What happens now?


## Data Initialization: More Complicated Example

- Omit in init list: default initialization
- `()` value initialization / constructor call
- `{}` value initialization / constructor call / aggregate initialization

`{}` is at least zero-initialization (guaranteed). Might add additional overhead, especially in nested structures!


Especially check these:

```c++
MyClass::MyClass()
    : deeply_nested_member{}
    , other_deeply_nested_member{}
{}
```

## Data Initialization: Circumventing Large Patterns


```c++
struct Data {
  Data();               // no longer trivial
  float a{1.4258F};
  float b{2342.235F};
  float c{34213.3F};
  float d{-4.2243F};
};
```

- `Data{}` is now a constructor call
- Constructor not inlined anymore, i.e. array constructor 
    - Calls 100 constructors, or
    - Calls 1 constructor and 99 copies
- Can be slower


## Data Initialization: Uninitialized Data

If you have nested structures, changing `Data` alone might not suffice

```c++
Container<Data, 100> c{};
```

```c++
template<typename T, size_t N>
struct Container {
  Container(): argmax{0} {}  // Add that
  T data[N];
  size_t argmax;
};
```

- `Container<int, 100> c{};` is no longer initialized (besides the `argmax` member).

=> Might be issue for projects that use bit-identity comparisons on the whole memory.


## Non-Trivial Structures

```c++
struct SensorDetection {
    SensorDetection();
    SensorDetection(const SensorDetection&);
    ~SensorDetection();
    std::array<float, 3> coordinate;
    float signal_strength;
};
```

```c++
void sense(SensorDetection& result) {
    SensorDetection c, d;
    // ...
    d = compute();
    c = compute_other();
    // ...
    result = some_condition? d: c;
}
```

- Inlining can definitely help
- Some compilers may not be able to fully optimize away all overheads

[https://godbolt.org/z/6zzvxe9q5](https://godbolt.org/z/6zzvxe9q5)

## Trivial Structures

Empirical observations:

- Most initialization (besides constants) is to zero and overwritten later again
- Most classes do not do resource management: Compiler can decide how to copy
- ...: No destruction required

=> Make structures trivial


## How to Make a Structure Trivial?

```c++
struct NotTrivial {
    NotTrivial();
};

NotTrivial::NotTrivial() = default;
```

```c++
struct NotTrivial {
    NotTrivial() {}
};
```

No (user provided in both cases)


## How to Make a Structure Trivial?

```c++
struct Trivial {
    Trivial() = default;
};
```

```c++
struct Trivial {
};
```


Rule of 0. Do not define any constructor, destructor, assignment operator, etc.

Compiler behavior varies. Check yours!


## Streamline Data Transformation

Example: linear interpolation between two points

<!---
![](img/bad-code-reuse.png)
--->

```c++
enum class ExtrapolationMode { Zero, Constant, Linear};
float piecewiseInterpolationWithExtrapolation(  // existing generic function
    float *xs, float *ys, size_t n,
    float x,
    ExtrapolationMode ep);

struct Point { float x, y; };

float interpolateTwoPoints(Point p0, Point p1, float x) {
    float xs[] = {p0.x, p1.x};
    float ys[] = {p0.y, p1.y};
    return piecewiseInterpolationWithExtrapolation(xs, ys, 2, x,
                /* unused */ ExtrapolationMode::Constant);
}
```

[https://godbolt.org/z/KE38r77bj](https://godbolt.org/z/KE38r77bj)


## Streamline Data Transformation

Two choices:

- Base on generic function, need to satisfy its interface
- Implement yourself, need to do it correct :)

How to detect?

- Copy data around just to satisfy an interface
- Pass constants to an interface that specify things you never use.


## Data Transformation: Even worse

```c++
void implementation_detail(std::vector<Data>& data);

void function(std::list<Data>& data)
{ 
    // ...
    std::vector<Data> vecdata{data.begin(), data.end()};
    implementation_detail(vecdata);
    // ...
}
```

[https://godbolt.org/z/Paf1T1M98](https://godbolt.org/z/Paf1T1M98)


- Can easily be hundreds of Bytes in ROM
- If you need to copy around data to satisfy an interface, it's not the right interface to use at this point!
- If the design says that `function` has to call `implementation_detail` to do something, it's a bug in the design.

This pattern also consumes stack and runtime.


## Code Bloat Templates

Be careful with templates.

```c++
template<typename C>
typename C::value_type best(const C& c) {
  typename C::value_type result{};
  for (auto&& e : c) {
    if (e > result) {
      result = e;
    }
  }
  return result;
}

template int best(const std::array<int, 100>&);
template int best(const std::array<int, 200>&);
```

[https://gcc.godbolt.org/z/KcrPsear7](https://gcc.godbolt.org/z/KcrPsear7)

- Almost exact same code, but for different size

How to detect?

- Bloaty has mode to sum all template instances into the same mangled `best` "function".


## De-templatify

- Move logic to generic non-template function (if impossible, then at least fewer template parameters)

```c++
// actual logic goes here
template<typename It>
auto best(It first, It last) -> typename std::iterator_traits<It>::value_type;

template<typename C>
typename C::value_type best(const C& c) {
  // only determines the range, i.e. evaluates the capacity parameter
  return best(c.begin(), c.end());
}

template int best(const std::array<int, 100>&);
template int best(const std::array<int, 200>&);
```

[https://gcc.godbolt.org/z/1h4Yj867n](https://gcc.godbolt.org/z/1h4Yj867n)



# Part 3: RAM Optimization


## Main Contributors to RAM Consumption

- Global variables (.data & .bss)
- (User) stack (.ustack)

.data is also ROM consumption!

What we'll be looking at:

- Padding
- Data Sizes
- Virtual Inheritance
- Separation of Concerns
- Stack


## What's the RAM issue?

Blow-up due to multi-dimensional arrays through the type hierarchy.

```c++
typedef int32_t Coord1D;                    //    4 Byte
using Coord4D = std::array<Coord1D, 4>;     //   16 Byte
using Polyline = std::array<Coord4D, 256>;  // 4096 Byte

struct Truck {
    std::array<Polyline, 32> possible_routes; // 130 kB
};

struct TrafficParticipants {
    std::array<Truck, 64> trucks;             // 8 MB
};
```

```c++
// Global variable somewhere:
using CommunicationBuffer = TrafficParticipants;
std::array<CommunicationBuffer, 3> bufferedCommCPU0toCPU2;  // 24 MB
```

General rule:

- Look for this blow-up and check the fundamental building blocks used there.


## Data Size of Fundamental Types

```c++
enum Direction { LEFT, RIGHT, UNKNOWN };
```

- How many Bytes does this occupy?
- Check and make sure!

```c++
enum class Direction: uint8_t { LEFT, RIGHT, UNKNOWN };
```

Clear.

Think of the domain of values you want to store and choose an appropriate type.


## Composite Types: Sum or Product?

```c++
struct VehicleType {
    bool isTruck;
    bool isCar;
    bool isBike;
    bool isPedestrian;
    bool isCat;
    /* ... */
};
```

Make clear if the domain is a sum or a product.

- In case of sums: Use enum (& union) / std::variant
- In case of products: Use bitfield / bitset


## Composite Types: Minimal

Get rid of inconsistencies that store information several times

```c++
struct Speed {
    std::array<float, 3> vector;
    float magnitude;
    enum direction { FORWARD, BACKWARD, NONE };
};
```

What's wrong here? How big is this type?

::: incremental

- 3x direction information?! (vector, magnitude and enum)
- Duplication of magnitude? Or is `vector` a unit vector?
- 20 Byte: 4 floats + enum + padding to 4 Byte

:::


## Composite Types: Minimal

Get rid of inconsistencies that store information several times

```c++
struct Probabilities {
    float isTruck;
    float isCar;
    float isOther;
};
```

What's wrong here? How big is this type?

::: incremental

- Mathematical duplication (`isOther == 1 - isTruck - isCar`)?
- 3 floats

:::


## Composite Types: Minimal

Get rid of inconsistencies that store information several times

```c++
enum Direction { LEFT, RIGHT, UNKNOWN };
std::optional<Direction> d;
```

What's wrong here? How big is this type?

::: incremental

- Duplication of "unknown" state: enum and empty optional
- 8 Byte on ARMv7 with GCC (default options)!

:::


## Composite Types: Minimal

Get rid of inconsistencies that store information several times

```c++
struct DirectionData {
    Direction d;
    std::optional<Velocity> v;
    std::optional<Acceleration> a;
};
```

What's wrong here? How big is this type?

::: incremental

- Unclear if `{d, dv, da, dva}` are valid states or only `{d, dva}`
- Is the `UNKNOWN` direction related to the optionals?

:::


## Composite Types: Minimal

Get rid of inconsistencies that store information several times

```c++
struct SomeData {
    std::optional<T*> t;
};

struct SomeOtherData {
    std::optional<std::reference_wrapper<T>> t;
};
```

What's wrong here? How big is this type?

::: incremental

- Is a `NULL` pointer and empty optional different states?
- 8 Byte on ARMv7

:::


## Composite Types: Optionals

`std::optional` is especially vulnerable because it is easy to overlook. The minimalism problem is *not* limited to `std::optional`!

My guardrail:

- Don't store `std::optional` in memory. Use it as interface type only.
- Don't have multiple `std::optional` in the same struct.
- Don't use it with pointers or references.


## Padding

```c++
struct Data {
    /* 0x00 */ uint32_t a;   // 4 Byte
    /* 0x04  -- 4 Byte padding */
    /* 0x08 */ uint64_t b;   // 8 Byte
    /* 0x10 */ uint8_t c;    // 1 Byte
    /* 0x11  -- 7 Byte padding */
    /* 0x18 */ uint64_t d;   // 8 Byte
    /* 0x20 */ uint8_t e;    // 1 Byte
    /* 0x21  -- 7 Byte padding */
};
// Total size: 0x28 = 40 Byte
```

- 22 Byte of data occupy 40 Byte of memory = **45% waste**


## Padding

```c++
struct Data {
    /* 0x00 */ uint64_t b;   // 8 Byte
    /* 0x08 */ uint64_t d;   // 8 Byte
    /* 0x10 */ uint32_t a;   // 4 Byte
    /* 0x14 */ uint8_t c;    // 1 Byte
    /* 0x15 */ uint8_t e;    // 1 Byte
    /* 0x16  -- 2 Byte padding */
};
// Total size: 0x18 = 24 Byte
```

- 22 Byte of data occupy 24 Byte of memory = 8.5% waste


Rule:

- Always sort struct members by size (descending), unless you have a good reason.
- Deep struct nesting is considered harmful because it makes it unnecessarily hard to do this.


## DON'T: Automatic packing

"Do I really need to reorder the attributes? There's this convenient pragma..."

```c++
__attribute__((packed))
struct Data {
    uint32_t a;
    uint64_t b;
    uint8_t c;
    uint64_t d;
    uint8_t e;
};
```

- This is for a *different* purpose (model HW frames)
- **DO NOT** use it for struct packing to save ROM, conversely get rid of it if you see it (without a reason)


## DON'T: Automatic packing

```c++
__attribute__((packed))
struct Data {
    uint32_t a;
    uint64_t b;
    uint8_t c;
    uint64_t d;
    uint8_t e;
};

uint64_t get_d(Data *d) { return d->d; }
```

[https://godbolt.org/z/sx47YTrhK](https://godbolt.org/z/sx47YTrhK)

Unaligned data will either give

- Unaligned memory accesses (slow, LSU breaks it down into multiple loads & stores)
- Manual stitching together the value from aligned accesses (slow + ROM overhead)


## (Virtual) Inheritance

```c++
struct A {
    virtual void fn1();
    virtual void fn2();
    int member1;
    // ...
};
```

```text
                            Class A's vtbl (.rodata)
                            +--------------------+
                            | ...                |
                            +--------------------+      +-----+
Object of type A:           | typeinfo ptr       | ---> | ... | ---> ...
+-----------+               +--------------------+      +-----+
| vptr      | ------------> | ptr to virtual fn1 |
+-----------+               +--------------------+
| member1   |               | ptr to virtual fn2 |
+-----------+               +--------------------+
| ...       |               | ...                |
+-----------+               +--------------------+
```
(simplified)

- With multiple inheritance, you get multiple vptrs


## Effects of Virtual Inheritance

- Inline boundary
    - Stops all other cross-function optimizations of the compiler


Rules:

- Get rid of unneeded parents that contain virtual functions
- Get rid of unneeded virtual functions
- If possible, devirtualize functions


## Avoid Type Erasure

```c++
struct MyData {
    DataClass1 a;
    DataClass2 b;
    DataClass3 c;
    DataClass4 d;

    std::array<CommonInterface*, 4> alldata = {&a, &b, &c, &d};
};

// Somewhere in the code:
for (auto& data: alldata)
    data->some_function();
```

- Additional pointers to use loops
- Consumes RAM
- ... and ROM due to virtual inheritance from `CommonInterface`.

[https://godbolt.org/z/z6GKhh7hG](https://godbolt.org/z/z6GKhh7hG)


## Avoid Type Erasure

```c++
struct MyData {
    DataClass1 a;
    DataClass2 b;
    DataClass3 c;
    DataClass4 d;
};

// Somewhere in the code:
a.some_function();
b.some_function();
c.some_function();
d.some_function();
```

What memory do we save?


## Avoid Type Erasure

```c++
struct MyData {
    DataClass1 a; DataClass2 b; DataClass3 c; DataClass4 d;
};

// Somewhere in the code:
a.some_function();
b.some_function();
c.some_function();
d.some_function();
```

- Saves 4*4 Bytes (32-bit pointers) = 16 Bytes RAM for object list
- Saves 4*4 Bytes (32-bit pointers) = 16 Bytes RAM for vptrs
- Might save RAM due to less padding within a, b, c, d or in `MyData` because the alignment of a, b, c, d changed.
- Loop will be about as big as the four function calls.
- Saves ROM for all vtables
- Saves ROM in the constructor for initializing the array
- Might save ROM for (empty?) destructor calls


## Separation of Concerns

Assume we have this system:


```text
        Sensor    --->  Preprocessing  --->  Perception, etc.
      (Core 0)  --comm-->  (Core 1)  --comm--> (Core 2)
```

```c++
struct MeasurementData {
    std::array<float, 3> xyz;
    Matrix<float, 3, 3> covariances;
};

CommBuf<std::array<MeasurementData, 1024>, 3> sensorToPreproc;
CommBuf<std::array<MeasurementData, 1024>, 3> preprocToPerception;
```

Assume:

- Sensor measures `xyz`
- Preprocessing component calculates covariances based on system state


## Effect

```text
        Sensor    --->  Preprocessing  --->  Perception, etc.
      (Core 0)  --comm-->  (Core 1)  --comm--> (Core 2)
```

```c++
struct MeasurementData {
    std::array<float, 3> xyz;
    Matrix<float, 3, 3> covariances;
};

CommBuf<std::array<MeasurementData, 1024>, 3> sensorToPreproc;
CommBuf<std::array<MeasurementData, 1024>, 3> preprocToPerception;
```

- Radar sensor never measures covariances
- First communication buffer covariances are *unused*

- Blow up: 4 Byte/float * 1024 * 3 = 12 kB/float
- 9 floats * 12 kB/float = 104 kB *wasted*


## Better Design

```text
    Radar Sensor  --->  Preprocessing  --->  Perception, etc.
      (Core 0)  --comm-->  (Core 1)  --comm--> (Core 2)
```

```c++
// Radar Sensor  --->  Preprocessing
struct Meas1 {
    std::array<float, 3> xyz;
};
```

```c++
// Preprocessing  --->  Perception
struct Meas2 {
    std::array<float, 3> xyz;
    Matrix<float, 3, 3> covariances;
};
```


## Removing Redundant Elements

```text
    Radar Sensor  --->  Preprocessing  --->  Perception, etc.
      (Core 0)  --comm-->  (Core 1)  --comm--> (Core 2)
```

```c++
// Radar Sensor  --->  Preprocessing
struct Meas1 {
    std::array<float, 3> xyz;
};
```

```c++
// Preprocessing  --->  Perception
struct Meas2 {
    std::array<float, 3> xyz;
    std::array<float, 3+2+1> covariances;
};
```

- Saves 3 floats (36 kB) because of symmetric matrix


## More Unused Elements?

- Just because (x, y, z) is *the* state does not mean all states co-vary with each other!
- Let's hypothetically say, z and (x,y) are completely independent

```c++
struct MeasurementData {
    std::array<float, 3> xyz;
    // v[0]  0    0
    // xyc  v[1]  0
    // 0     0  v[2]
    std::array<float, 3> variances;
    float xycovariance;
};
```

- Another 2 floats (24 kB) saved


## How to Detect Redundancy?

- Manual inspection :(
- Static/dynamic code analysis: What is being read and written to?
- E.g. valgrind based: instrument loads & stores to save address and data width. At the end, determine all addresses that have not been read or written at the end and relate these addresses to symbols.

Why will that likely not work?


## How to Detect Redundancy?

```text
    Radar Sensor  --->  Preprocessing  --->  Perception, etc.
      (Core 0)  --comm-->  (Core 1)  --comm--> (Core 2)
```

Somewhere in the communication code, there will be:

```c++
CommBuf<std::array<MeasurementData, 1024>, 3> sensorToPreproc;
CommBuf<std::array<MeasurementData, 1024>, 3> preprocToPerception;

memcpy(preprocToPerception[j], sensorToPreproc[i], sizeof(std::array<MeasurementData, 1024>));
```

- This `memcpy` reads/writes the complete buffer *although* the values are not being used in the actual code


What can I do?

- Hack something manual: Run code w/o communication and other overheads, so the unused data is actually not read and/or written.
- Domain-specific knowledge (e.g. of the radar sensor) and manual code inspection.


## Static Destruction

- Destruction order is defined by the C++ standard
- Inverse of construction order
- Construction order needs to be recorded somewhere!

[https://godbolt.org/z/qeoE95Pcv](https://godbolt.org/z/qeoE95Pcv)

Rule:

- Make every global variable trivially destructible.


## Stack Reduction

Trivial things:

- Forgotten reference `&`:
    - `void foo(LargeStruct s);`
    - `for (auto x: list)`
- Streamline data transformation. (see above)
    - Try to get rid of “data conversion to satisfy interface”
    - E.g.: Caller receives array of Cartesian coords, callee needs array of polar coords
- Use rich data structures stored once and manipulate them

Afterwards, measure stack consumption during execution and reduce allocation in linker script.


# Conclusion

- Know your goal and the artifacts you work with
- Measure, measure, measure
- Try to understand how C/C++ is implemented, refine this model regularly
- Relate memory consumption back to C/C++ constructs by manual inspection
- Know your toolchain

Get right from the start:

- Inlining
- Padding
- Design: Separation of concerns, minimal data structures


# Thank you for your Attention!

Any questions?
