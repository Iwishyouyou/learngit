# run_create_project.tcl
# 作用:自动定位到本脚本所在目录,再调用原始的 creat_project.tcl
# 这样无论从哪里执行,都不用手动 cd

set this_script_dir [file dirname [file normalize [info script]]]
cd $this_script_dir
source [file join $this_script_dir "creat_project.tcl"]