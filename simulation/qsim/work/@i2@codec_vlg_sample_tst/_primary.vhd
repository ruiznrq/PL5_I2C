library verilog;
use verilog.vl_types.all;
entity I2Codec_vlg_sample_tst is
    port(
        clk             : in     vl_logic;
        sda_o           : in     vl_logic;
        suich           : in     vl_logic_vector(17 downto 0);
        sampler_tx      : out    vl_logic
    );
end I2Codec_vlg_sample_tst;
