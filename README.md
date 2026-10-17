Hardware RSA Cryptoprocessor --- VHDL
A VHDL implementation of an RSA cryptographic coprocessor, designed
around synchronous, iterative hardware blocks. The project brings
together RSA key generation, modular arithmetic, encryption, and
decryption in a single top-level design.
It is intended as an educational hardware-design project: the source
code and testbench illustrate how a public-key cryptographic algorithm
can be decomposed into RTL modules and coordinated with finite-state
machines (FSMs).
> **Important security note:** This project is for learning and RTL
> simulation, not for protecting real data. It uses a pseudo-random LFSR
> and textbook RSA without a padding scheme. Those choices are not
> suitable for production cryptography. The fixed Miller--Rabin
> witnesses described in the report also do not establish deterministic
> primality for arbitrary 512-bit candidates.
Table of contents
1. What does the project do?
2. RSA in a nutshell
3. High-level operation
4. Architecture and modules
5. Main design parameters
6. External interface
7. Simulation and verification
8. Performance estimates
9. Repository structure
10. How to run the simulation
11. Current limitations
12. Concepts demonstrated
1. What does the project do?
RSA is an asymmetric cryptographic algorithm: a public key is used for
encryption, while a corresponding private key is used for decryption.
This design implements the main RSA flow in VHDL:
Generate candidate prime numbers.
Test the candidates with Miller--Rabin.
Compute the RSA modulus and Euler's totient.
Derive the private exponent using the extended Euclidean algorithm.
Encrypt an input message with the public exponent.
Decrypt the ciphertext with the private exponent.
Assert a completion signal when the result is ready.
The design uses a 1024-bit RSA modulus in the report's default
configuration. Its arithmetic is organized into iterative hardware units
to avoid building every large-number operation as one large
combinational calculation.
2. RSA in a nutshell
RSA uses two prime numbers, (p) and (q), to create a key pair.
Key generation
The design computes:
(N = p `\times `{=tex}q): the RSA modulus.
(`\varphi`{=tex}(N) = (p-1)(q-1)): Euler's totient for the generated
primes.
(e = 65537): the public exponent.
(d = e^{-1} `\bmod `{=tex}`\varphi`{=tex}(N)): the private
exponent.
The public key is ((N,e)), and the private key is ((N,d)).
Encryption
For a message (m), where (0 `\le `{=tex}m < N), encryption computes:
[ c = m^e `\bmod `{=tex}N ]
Decryption
Decryption computes:
[ m' = c^d `\bmod `{=tex}N ]
For a correct RSA key pair and a valid input, the expected result is
(m'=m). The testbench checks this round-trip property.
3. High-level operation
The main module is `RSA_TOP`. It coordinates key generation and then
waits for encryption or decryption requests.
Reset/start-up: the top-level controller starts key generation.
Key generation: candidate primes are generated and tested; the
modulus and private exponent are calculated.
Ready: the controller waits for a request through `start`.
Operation selection: `mode = '0'` selects encryption;
`mode = '1'` selects decryption.
Calculation: the RSA wrapper launches modular exponentiation.
Completion: `o_result` contains the result and `o_done` pulses
for one clock cycle.
The encryption and decryption paths use the same modular-exponentiation
hardware, with different exponents.
```{=html}
<!-- Optional: add an architecture diagram to the repository and replace the path below.
<p align="center">
  <img src="documents/rsa_architecture.png" alt="RSA coprocessor architecture" width="850">
</p>
-->
```
4. Architecture and modules
The design is divided into modules so that each major mathematical
operation has a separate RTL implementation.
---
VHDL file / entity                  Responsibility
---
`RSA_PKG.vhd` / `RSA_PKG`           Shared constants, widths, and
helper functions used by the
design.
`RSA_TOP.vhd` / `RSA_TOP`           Top-level controller and external
interface; coordinates key
generation, encryption, and
decryption.
`RSA_KEYGEN.vhd` / `RSA_KEYGEN`     Coordinates prime generation,
primality testing, and private-key
calculation.
`RANDOM_GEN.vhd` / `RANDOM_GEN`     Generates pseudo-random candidates
using a 128-bit LFSR.
`MILLER_RABIN.vhd` / `MILLER_RABIN` Tests candidate numbers for
probable primality.
`EXT_GCD.vhd` / `EXT_GCD`           Calculates the modular inverse used
to obtain the private exponent.
`RSA.vhd` / `RSA`                   Wrapper that prepares the message
and starts modular exponentiation.
`MOD_MONTGOMERY_EXP.vhd` /          Computes modular exponentiation
`MOD_MONTGOMERY_EXP`                using square-and-multiply.
`MONTGOMERY_MULT.vhd` /             Performs iterative Montgomery
`MONTGOMERY_MULT`                   modular multiplication.
`TB_RSA_TOP.vhd` / `TB_RSA_TOP`     Testbench for the top-level RSA
round-trip test.
The report also lists `Test.vhd` in the repository. Check that file to
determine whether it is the active testbench or an additional test file;
the report identifies `TB_RSA_TOP.vhd` as the main round-trip testbench.
The key arithmetic block: Montgomery multiplication
Modular exponentiation requires many modular multiplications. A direct
division-based reduction can be expensive in hardware, so the design
uses Montgomery multiplication.
The reported bit-serial implementation processes one bit of an operand
per clock cycle. It conditionally adds the operands, adjusts the
accumulator so it can be shifted, and performs a final modular
correction.
For a (K)-bit operand, the report gives a latency of approximately (K+2)
clock cycles per Montgomery multiplication.
Modular exponentiation
`MOD_MONTGOMERY_EXP` uses a least-significant-bit-first
square-and-multiply approach. It converts operands into the Montgomery
domain, iterates through the exponent bits, then converts the result
back.
Two Montgomery multipliers are instantiated: one for squaring and one
for conditional multiplication. This allows the relevant operations to
run in parallel where the control flow permits it.
5. Main design parameters
The report describes these default parameters:
---
Parameter                           Reported value Meaning
---
`PRIME_WIDTH`                             512 bits Width of each prime
candidate (p) and
(q).
`KEY_WIDTH`                              1024 bits Width of the RSA
modulus and main
operands.
`NUM_WITNESSES`                                  4 Number of
Miller--Rabin
witnesses used by the
implementation.
Public exponent `e`                          65537 Fixed public
exponent.
LFSR seed width                           128 bits Width of the
pseudo-random
generator's seed.
The report states that `KEY_WIDTH` is twice `PRIME_WIDTH`. Confirm the
values in `RSA_PKG.vhd` if you change the configuration.
6. External interface
The top-level entity `RSA_TOP` exposes the following main signals,
according to the report:
---
Signal                  Direction               Description
---
`clk`                   Input                   System clock.
`rst`                   Input                   Active-high
asynchronous reset;
restarts key
generation.
`i_message`             Input                   Message to encrypt or
ciphertext to decrypt.
`mode`                  Input                   `'0'` for encryption,
`'1'` for decryption.
`start`                 Input                   Pulse to request an
operation.
`o_done`                Output                  Pulses high for one
cycle when the result
is ready.
`o_result`              Output                  Result of encryption or
decryption.
`o_N`                   Output                  RSA modulus, provided
for debug.
`o_e`                   Output                  Public exponent,
provided for debug.
`o_d`                   Output                  Private exponent,
provided for debug.
The top-level controller generates keys after reset, so a request should
only be issued once key generation has completed and the design is
ready.
7. Simulation and verification
The report describes a top-level testbench that checks the
encrypt-then-decrypt round trip for multiple messages.
    Input message (m) Check performed                            Reported status
---
                   42 Decrypting the ciphertext recovers 42      PASS
                   99 Decrypting the ciphertext recovers 99      PASS
                12345 Decrypting the ciphertext recovers 12345   PASS

The testbench is described as checking that the recovered message equals
the original message using an assertion.
Simulation setup reported
Testbench: `TB_RSA_TOP.vhd`
Clock period: 10 ns
Clock frequency: 100 MHz
Simulator: the report leaves the final tool to be completed; it
mentions ModelSim, Vivado Simulator, or GHDL as possibilities.
Add waveform screenshots
If you have exported waveform images, put them in a repository folder
such as `documents/images/` and uncomment/update the image paths below.
GitHub paths are case-sensitive.
``` markdown
## Simulation waveforms

### Complete RSA round trip
![RSA top-level round-trip waveform](documents/images/rsa_top_roundtrip.png)

### Modular exponentiation
![Modular exponentiation waveform](documents/images/modular_exponentiation.png)

### Key generation
![RSA key-generation waveform](documents/images/key_generation.png)
```
Only include screenshots whose filenames and paths actually exist in
your repository.
8. Performance estimates
The report gives the following approximate figures for a 1024-bit
modulus at 100 MHz. These are report estimates, not independent timing
or FPGA place-and-route measurements.
---
Operation                  Approximate cycles   Approximate time at 100
MHz
---
Key generation                       Variable Depends on how many prime
candidates are rejected
Encryption using                     ~40,000                  ~0.4 ms
(e=65537)
Decryption with a                 ~2,100,000                   ~21 ms
dense private  
exponent
Worst-case modular                ~2,097,152                   ~21 ms
exponentiation
Encryption is much faster than decryption in this architecture because
65537 has only two set bits. The conditional multiplication step is
therefore required far less often than it is for a typical private
exponent.
These values are analytical/estimated cycle counts from the report.
Actual results depend on the implementation, simulator, synthesis, and
target hardware.
9. Repository structure
The repository currently includes a package file, a test file, an `hdl/`
directory, and a `documents/` directory. The expected RTL hierarchy
described in the report is approximately:
``` text
RSA-IMPLEMENTATION-HDL/
├── RSA_PKG.vhd
├── Test.vhd
├── hdl/
│   ├── RSA_TOP.vhd
│   ├── RSA_KEYGEN.vhd
│   ├── RANDOM_GEN.vhd
│   ├── MILLER_RABIN.vhd
│   ├── EXT_GCD.vhd
│   ├── RSA.vhd
│   ├── MOD_MONTGOMERY_EXP.vhd
│   ├── MONTGOMERY_MULT.vhd
│   └── TB_RSA_TOP.vhd
└── documents/
    └── project report and supporting documentation
```
This is an illustrative structure based on the report, not a verified
listing of every file in the repository. Your actual folders may differ.
10. How to run the simulation
The report identifies `TB_RSA_TOP.vhd` as the main testbench, but it
does not provide a verified, complete compile script or confirm which
simulator is configured for this repository. The exact commands
therefore depend on your simulator and the location of each source file.
In general:
Open your VHDL simulator (for example, Questa/ModelSim, Vivado
Simulator, or GHDL).
Create or select a simulation library/work directory.
Compile `RSA_PKG.vhd` first, because other modules use its
declarations.
Compile the RTL files in dependency order.
Compile the testbench.
Set `TB_RSA_TOP` as the simulation top level.
Run the simulation and check the round-trip assertions and
waveforms.
Do not assume that the illustrative hierarchy above matches your exact
local folder layout. A simulator-specific script should be added after
confirming the source paths and tool version.
11. Current limitations
Educational implementation: this project demonstrates RTL
architecture and arithmetic; it is not a production-ready
cryptographic module.
No RSA padding: the described operation is textbook RSA. Real
systems require an appropriate, standardized padding scheme.
Pseudo-random generation: an LFSR is predictable and is not a
cryptographically secure source of prime candidates.
Primality testing: the report uses fixed Miller--Rabin witnesses
`{2, 3, 5, 7}`. That set is not a deterministic primality guarantee
for arbitrary 512-bit candidates; a security-grade implementation
needs a suitably designed primality-testing strategy.
No hardware implementation results specified: the report
provides simulation setup and cycle estimates, but does not
establish FPGA resource usage, maximum clock frequency after
place-and-route, or hardware bring-up results.
Simulator setup needs confirmation: the report lists several
possible tools but leaves the final simulator unspecified.
12. Concepts demonstrated
This project is useful for exploring:
VHDL RTL design and modular hardware architecture.
Finite-state machines and handshake signals.
Parameterized datapaths for large operands.
Iterative/bit-serial arithmetic.
Montgomery modular multiplication.
Modular exponentiation with square-and-multiply.
Prime-candidate generation and Miller--Rabin testing.
Extended Euclidean algorithm for modular inverses.
Testbench-driven simulation and round-trip assertions.
---
Project summary
The Hardware RSA Cryptoprocessor combines key generation and RSA
encryption/decryption in a VHDL design. Its main architectural idea is
to reuse iterative Montgomery arithmetic blocks under FSM control, and
to verify the overall operation by checking that decrypting encrypted
test messages recovers the original inputs.
For reproducible results, include the exact simulator version, compile
order/script, and waveform screenshots used in your own environment.
