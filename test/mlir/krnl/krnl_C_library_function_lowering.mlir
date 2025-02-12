// RUN: onnx-mlir-opt -O3 --convert-krnl-to-affine --convert-krnl-to-llvm %s -split-input-file | FileCheck %s

// -----

// Test that krnl.strlen can be called when the argument is passed into the function.
func private @test_krnl_strlen1(%arg0: !krnl.string) -> i64  {
  %len = "krnl.strlen"(%arg0) : (!krnl.string) -> i64
  return %len : i64

// CHECK:       llvm.func @strlen(!llvm.ptr<i8>) -> i64
// CHECK-LABEL: @test_krnl_strlen1(%arg0: !llvm.struct<(ptr<i8>, ptr<i8>, i64, array<1 x i64>, array<1 x i64>)>)
// CHECK:       [[STR:%.+]] = llvm.extractvalue %arg0[1] : !llvm.struct<(ptr<i8>, ptr<i8>, i64, array<1 x i64>, array<1 x i64>)>
// CHECK:       [[LEN:%.+]] = llvm.call @strlen([[STR]]) : (!llvm.ptr<i8>) -> i64
// CHECK:       llvm.return [[LEN]] : i64
}

// -----

// Test that krnl.strlen can be called when the argument is created via a load.
func private @test_krnl_strlen2() -> i64  {
  %c0 = arith.constant 0 : index  
  %ptr_str = memref.alloc() {alignment = 16 : i64} : memref<1x!krnl.string>
  %str = krnl.load %ptr_str[%c0] : memref<1x!krnl.string>
  %len = "krnl.strlen"(%str) : (!krnl.string) -> i64
  return %len : i64

// CHECK:       llvm.func @strlen(!llvm.ptr<i8>) -> i64
// CHECK-LABEL: @test_krnl_strlen2() -> i64
// CHECK:       [[LOAD:%.+]] = llvm.load {{.*}} : !llvm.ptr<struct<(ptr<i8>, ptr<i8>, i64, array<1 x i64>, array<1 x i64>)>>
// CHECK:       [[STR:%.+]] = llvm.extractvalue [[LOAD]][1] : !llvm.struct<(ptr<i8>, ptr<i8>, i64, array<1 x i64>, array<1 x i64>)>
// CHECK:       [[LEN:%.+]] = llvm.call @strlen([[STR]]) : (!llvm.ptr<i8>) -> i64
// CHECK:       llvm.return [[LEN]] : i64
}

// -----

// Test that krnl.strncmp is lowered to a call to the strncmp standard C function.
func private @test_strncmp(%str: !krnl.string, %len: i64) -> i32  {
  %c0 = arith.constant 0 : index
  %ptr = memref.alloc() {alignment = 16 : i64} : memref<1x!krnl.string>
  %str1 = krnl.load %ptr[%c0] : memref<1x!krnl.string>
  %cmp = "krnl.strncmp"(%str, %str1, %len) : (!krnl.string, !krnl.string, i64) -> i32
  return %cmp : i32

// CHECK:       llvm.func @strncmp(!llvm.ptr<i8>, !llvm.ptr<i8>, i64) -> i32
// CHECK-LABEL: @test_strncmp(%arg0: !llvm.struct<(ptr<i8>, ptr<i8>, i64, array<1 x i64>, array<1 x i64>)>, %arg1: i64) -> i32
// CHECK:       [[LOAD:%.+]] = llvm.load {{.*}} : !llvm.ptr<struct<(ptr<i8>, ptr<i8>, i64, array<1 x i64>, array<1 x i64>)>>
// CHECK:       [[STR1:%.+]] = llvm.extractvalue %arg0[1] : !llvm.struct<(ptr<i8>, ptr<i8>, i64, array<1 x i64>, array<1 x i64>)>
// CHECK:       [[STR2:%.+]] = llvm.extractvalue [[LOAD]][1] : !llvm.struct<(ptr<i8>, ptr<i8>, i64, array<1 x i64>, array<1 x i64>)>
// CHECK:       [[CMP:%.+]] = llvm.call @strncmp([[STR1]], [[STR2]], %arg1) : (!llvm.ptr<i8>, !llvm.ptr<i8>, i64) -> i32
// CHECK:       llvm.return [[CMP]] : i32
}
