onerror {quit -f}
vlib work
vlog -work work I2Codec.vo
vlog -work work I2Codec.vt
vsim -novopt -c -t 1ps -L cycloneii_ver -L altera_ver -L altera_mf_ver -L 220model_ver -L sgate work.I2Codec_vlg_vec_tst
vcd file -direction I2Codec.msim.vcd
vcd add -internal I2Codec_vlg_vec_tst/*
vcd add -internal I2Codec_vlg_vec_tst/i1/*
add wave /*
run -all
