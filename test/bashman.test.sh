#!/usr/bin/env bash

source ../bashman.sh

test_should_find_all_bash_files(){
  SOURCE_DIR=$(realpath "./_data")
  files=$(find_bash_files | wc -l)
  assertEquals 2 $files
}

test_should_create_target_dir() {
  SOURCE_DIR=$(realpath "./_data")
  TARGET_DIR="./_target/docs"
  check_target_directory
  assertTrue "[ -d $(realpath $TARGET_DIR) ]"
}

test_should_extract_doc_comments_simple() {
  SOURCE_DIR=$(realpath "./_data")
  TARGET_DIR="./_target/docs"
  temp_file=$(extract_doc_comments "$SOURCE_DIR/simple.sh")
  sep_lines=$(grep -i -c "${_SEGMENT_SEPARATOR}" $temp_file)
  assertEquals 4 $sep_lines
}

test_should_extract_doc_comments_complex() {
  SOURCE_DIR=$(realpath "./_data")
  TARGET_DIR="./_target/docs"
  temp_file=$(extract_doc_comments "$SOURCE_DIR/complex.sh")
  sep_lines=$(grep -i -c "${_SEGMENT_SEPARATOR}" $temp_file)
  assertEquals 1 $sep_lines
}

test_should_produce_gz_files() {
  SOURCE_DIR=$(realpath "./_data")
  TARGET_DIR="./_target/docs"
  bashman -t $TARGET_DIR $SOURCE_DIR
  assertTrue "[ -d $(realpath $TARGET_DIR/simple) ]"
  assertTrue "[ -d $(realpath $TARGET_DIR/complex) ]"
}

tearDown() {
  rm -rf docs
  rm -rf _target
}

. $WORKSPACE_TOOLS/shunit2/shunit2