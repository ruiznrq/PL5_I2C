library verilog;
use verilog.vl_types.all;
entity I2Codec_vlg_check_tst is
    port(
        clk_100         : in     vl_logic;
        clk_200         : in     vl_logic;
        sda_o           : in     vl_logic;
        slc_o           : in     vl_logic;
        sampler_rx      : in     vl_logic
    );
end I2Codec_vlg_check_tst;
