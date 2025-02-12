/*
 * SPDX-License-Identifier: Apache-2.0
 */

#include <iostream>
#include <rapidcheck.h>
#include <string>

#include "llvm/Support/FileSystem.h"

#include "include/OnnxMlirRuntime.h"
#include "src/Runtime/OMTensorHelper.h"
#include "test/modellib/ModelLib.hpp"

static const llvm::StringRef SHARED_LIB_BASE("./TestLSTM_main_graph");

using namespace std;
using namespace mlir;
using namespace onnx_mlir;

// Returns whether onnx-mlir compiled LSTM is producing the same results as a
// naive implementation of LSTM for a specific set of LSTM
// parameters/configuration.
bool isOMLSTMTheSameAsNaiveImplFor(const int direction, const int S,
    const int B, const int I, const int H, bool isDynamicS = false,
    bool isDynamicB = false) {

  LSTMLibBuilder lstm(
      SHARED_LIB_BASE.str(), direction, S, B, I, H, isDynamicS, isDynamicB);
  return lstm.build() && lstm.compileAndLoad() && lstm.prepareInputs() &&
         lstm.run() && lstm.verifyOutputs();
}

int main(int argc, char *argv[]) {
  llvm::FileRemover remover(
      ModelLibBuilder::getSharedLibName(SHARED_LIB_BASE.str()));

  setCompilerOption(OptionKind::CompilerOptLevel, "3");
  llvm::cl::ParseCommandLineOptions(
      argc, argv, "TestLSTM\n", nullptr, "TEST_ARGS");

  // RapidCheck test case generation.
  bool success = rc::check("LSTM implementation correctness", []() {
    // The number of directions.
    // 1: forward, -1: reverse, 2: bidirectional
    const auto D = *rc::gen::element(1, -1, 2);
    // Sequence length.
    const auto S = *rc::gen::inRange(1, 5);
    // Batch size.
    const auto B = *rc::gen::inRange(5, 10);
    // Input size.
    const auto I = *rc::gen::inRange(5, 10);
    // Hidden size.
    const auto H = *rc::gen::inRange(5, 10);
    // Whether test dynamic dimension for sequence.
    const auto isDynS = *rc::gen::element(0, 1);
    // Whether test dynamic dimension for batch size.
    const auto isDynB = *rc::gen::element(0, 1);

    RC_ASSERT(
        isOMLSTMTheSameAsNaiveImplFor(D, S, B, I, H, isDynS == 0, isDynB == 0));
  });
  if (!success)
    return 1;

  // Exhaustive test case generation.
  for (int64_t s = 3; s < 4; s++)
    for (int64_t b = 3; b < 4; b++)
      for (int64_t i = 2; i < 5; i++)
        for (int64_t h = 2; h < 5; h++) {
          // Static dimensions.
          // forward
          assert(isOMLSTMTheSameAsNaiveImplFor(1, s, b, i, h));
          // reverse
          assert(isOMLSTMTheSameAsNaiveImplFor(-1, s, b, i, h));
          // bidirectional
          assert(isOMLSTMTheSameAsNaiveImplFor(2, s, b, i, h));

          // Dynamic dimensions for sequence, batch size.
          // forward
          assert(isOMLSTMTheSameAsNaiveImplFor(1, s, b, i, h, true, true));
          // reverse
          assert(isOMLSTMTheSameAsNaiveImplFor(-1, s, b, i, h, true, true));
          // bidirectional
          assert(isOMLSTMTheSameAsNaiveImplFor(2, s, b, i, h, true, true));
        }
  return 0;
}
