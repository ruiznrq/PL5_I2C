library verilog;
use verilog.vl_types.all;
entity I2Codec is
    port(
        slc_o           : out    vl_logic;
        clk             : in     vl_logic;
        suich           : in     vl_logic_vector(17 downto 0);
        sda_o           : inout  vl_logic;
        clk_100         : out    vl_logic;
        clk_200         : out    vl_logic
    );
end I2Codec;
