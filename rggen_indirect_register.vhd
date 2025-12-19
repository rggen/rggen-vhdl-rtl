library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_indirect_register is
  generic (
    READABLE:             boolean   := true;
    WRITABLE:             boolean   := true;
    ADDRESS_WIDTH:        positive  := 8;
    OFFSET_ADDRESS:       unsigned  := x"0";
    BUS_WIDTH:            positive  := 32;
    DATA_WIDTH:           positive  := 32;
    INDIRECT_MATCH_WIDTH: positive  := 1
  );
  port (
    i_clk:                    in  std_logic;
    i_rst_n:                  in  std_logic;
    i_register_valid:         in  std_logic;
    i_register_access:        in  std_logic_vector(1 downto 0);
    i_register_address:       in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_register_write_data:    in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    i_register_strobe:        in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_register_active:        out std_logic;
    o_register_ready:         out std_logic;
    o_register_status:        out std_logic_vector(1 downto 0);
    o_register_read_data:     out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_register_value:         out std_logic_vector(DATA_WIDTH - 1 downto 0);
    i_indirect_match:         in  std_logic_vector(INDIRECT_MATCH_WIDTH - 1 downto 0);
    o_bit_field_read_valid:   out std_logic;
    o_bit_field_write_valid:  out std_logic;
    o_bit_field_mask:         out std_logic_vector(DATA_WIDTH - 1 downto 0);
    o_bit_field_write_data:   out std_logic_vector(DATA_WIDTH - 1 downto 0);
    i_bit_field_read_data:    in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    i_bit_field_value:        in  std_logic_vector(DATA_WIDTH - 1 downto 0)
  );
end rggen_indirect_register;

architecture rtl of rggen_indirect_register is
  signal  additional_match: std_logic;
begin
  additional_match  <= '1' when unsigned(not i_indirect_match) = 0 else '0';

  u_register_common: entity work.rggen_register_common
    generic map (
      READABLE              => READABLE,
      WRITABLE              => WRITABLE,
      ADDRESS_WIDTH         => ADDRESS_WIDTH,
      OFFSET_ADDRESS        => OFFSET_ADDRESS,
      BUS_WIDTH             => BUS_WIDTH,
      DATA_WIDTH            => DATA_WIDTH,
      USE_ADDITIONAL_MATCH  => true
    )
    port map (
      i_clk                   => i_clk,
      i_rst_n                 => i_rst_n,
      i_register_valid        => i_register_valid,
      i_register_access       => i_register_access,
      i_register_address      => i_register_address,
      i_register_write_data   => i_register_write_data,
      i_register_strobe       => i_register_strobe,
      o_register_active       => o_register_active,
      o_register_ready        => o_register_ready,
      o_register_status       => o_register_status,
      o_register_read_data    => o_register_read_data,
      o_register_value        => o_register_value,
      i_additional_match      => additional_match,
      i_additional_mask       => (others => '1'),
      o_bit_field_read_valid  => o_bit_field_read_valid,
      o_bit_field_write_valid => o_bit_field_write_valid,
      o_bit_field_mask        => o_bit_field_mask,
      o_bit_field_write_data  => o_bit_field_write_data,
      i_bit_field_read_data   => i_bit_field_read_data,
      i_bit_field_value       => i_bit_field_value
    );
end rtl;
