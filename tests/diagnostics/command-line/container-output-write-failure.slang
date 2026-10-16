// container-output-write-failure.slang
// A container output (`.slang-module`, `.slang-lib`, `.zip`, `.dir`) that cannot be written must
// be diagnosed and fail the compile, the same way an ordinary `-o` target output is. The
// full-compile runs exercise the container write in `generateOutput()`; the `-skip-codegen` run
// exercises the one in `executeActionsInner()`.

// Each of these writes under a directory that does not exist.
//DIAGNOSTIC_TEST:SIMPLE(filecheck=MODULE):-o tests/diagnostics/command-line/container-output-write-failure-missing-dir/out.slang-module
//DIAGNOSTIC_TEST:SIMPLE(filecheck=LIB):-o tests/diagnostics/command-line/container-output-write-failure-missing-dir/out.slang-lib
//DIAGNOSTIC_TEST:SIMPLE(filecheck=ZIP):-target spirv -entry main -stage compute -o tests/diagnostics/command-line/container-output-write-failure-missing-dir/out.zip
//DIAGNOSTIC_TEST:SIMPLE(filecheck=DIR):-target spirv -entry main -stage compute -o tests/diagnostics/command-line/container-output-write-failure-missing-dir/out.dir
//DIAGNOSTIC_TEST:SIMPLE(filecheck=SKIP):-skip-codegen -o tests/diagnostics/command-line/container-output-write-failure-missing-dir/out.slang-module

// A single-file container holds one artifact, so the module IR plus SPIR-V for the entry point
// cannot be stored in it even when the directory is writable; only `.zip` and `.dir` hold both.
//DIAGNOSTIC_TEST:SIMPLE(filecheck=MULTI):-target spirv -entry main -stage compute -o tests/diagnostics/command-line/container-output-write-failure-multi.slang-module

// A host-callable result built by slang-llvm is a loaded library with no blob form, so the
// container cannot be serialized at all; ordinary `-o` output reports the same E00098 for it.
//DIAGNOSTIC_TEST:SIMPLE(filecheck=HOST):-target host-callable -emit-cpu-via-llvm -entry main -stage compute -o tests/diagnostics/command-line/container-output-write-failure-missing-dir/out-host.zip

[numthreads(1, 1, 1)]
void main()
{
}

// MODULE: result code = -1
// MODULE: error[E00004]: cannot write output file 'tests/diagnostics/command-line/container-output-write-failure-missing-dir/out.slang-module'

// LIB: result code = -1
// LIB: error[E00004]: cannot write output file 'tests/diagnostics/command-line/container-output-write-failure-missing-dir/out.slang-lib'

// ZIP: result code = -1
// ZIP: error[E00004]: cannot write output file 'tests/diagnostics/command-line/container-output-write-failure-missing-dir/out.zip'

// DIR: result code = -1
// DIR: error[E00004]: cannot write output file 'tests/diagnostics/command-line/container-output-write-failure-missing-dir/out.dir'

// SKIP: result code = -1
// SKIP: error[E00004]: cannot write output file 'tests/diagnostics/command-line/container-output-write-failure-missing-dir/out.slang-module'

// MULTI: result code = -1
// MULTI: error[E00004]: cannot write output file 'tests/diagnostics/command-line/container-output-write-failure-multi.slang-module'

// HOST: result code = -1
// HOST: error[E00098]: cannot access as a blob
