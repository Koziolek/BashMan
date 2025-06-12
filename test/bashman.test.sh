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

test_should_extract_doc_comments() {
  SOURCE_DIR=$(realpath "./_data")
  TARGET_DIR="./_target/docs"
  _SEGMENT_SEPARATOR='#;;;;#'
  temp_file=$(extract_doc_comments "$SOURCE_DIR/simple.sh")
  sep_lines=$(grep -i -c "${_SEGMENT_SEPARATOR}" $temp_file)
  assertEquals 3 $sep_lines
}



#tearDown() {
#  rm -rf docs
#  rm -rf _target
#}

. $WORKSPACE_TOOLS/shunit2/shunit2