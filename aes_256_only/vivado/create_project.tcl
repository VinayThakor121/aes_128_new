set proj_name "aes_256_only"
set proj_dir  [file normalize "./build/$proj_name"]
file mkdir $proj_dir
create_project $proj_name $proj_dir -part xc7a35tcpg236-1 -force

set root [file normalize "../"]

add_files [glob -nocomplain "$root/rtl/*.v"]
add_files [glob -nocomplain "$root/uart/*.v"]
add_files -fileset constrs_1 "$root/constraints/basys3_aes256_only.xdc"

set_property top uart_aes256_top [current_fileset]
update_compile_order -fileset sources_1

puts "Project created: $proj_dir"
