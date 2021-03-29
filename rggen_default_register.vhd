library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_default_register is
  generic (
    READABLE:       boolean   := true;
    WRITABLE:       boolean   := true;
    ADDRESS_WIDTH:  positive  := 8;
    BUS_WIDTH:      positive  := 32;
    DATA_WIDTH:     positive  := 32;
    REGISTER_INDEX: natural   := 0
  );
  port (
    i_clk:                  in  std_logic;
    i_rst_n:                in  std_logic;
    i_offset_address:       in  unsigned(ADDRESS_WIDTH - 1 downto 0);
    i_valid_bits:           in  unsigned(DATA_WIDTH - 1 downto 0);
    i_register_valid:       in  std_logic;
    i_register_access:      in  std_logic_vector(1 downto 0);
    i_register_address:     in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_register_write_data:  in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    i_register_strobe:      in  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    o_register_active:      out std_logic;
    o_register_ready:       out std_logic;
    o_register_status:      out std_logic_vector(1 downto 0);
    o_register_read_data:   out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_register_value:       out std_logic_vector(DATA_WIDTH - 1 downto 0);
    o_bit_field_valid:      out std_logic;
    o_bit_field_read_mask:  out std_logic_vector(DATA_WIDTH - 1 downto 0);
    o_bit_field_write_mask: out std_logic_vector(DATA_WIDTH - 1 downto 0);
    o_bit_field_write_data: out std_logic_vector(DATA_WIDTH - 1 downto 0);
    i_bit_field_read_data:  in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    i_bit_field_value:      in  std_logic_vector(DATA_WIDTH - 1 downto 0)
  );
end rggen_default_register;

architecture rtl of rggen_default_register is
begin
  u_register_common: entity work.rggen_register_common
    generic map (
      READABLE        => READABLE,
      WRITABLE        => WRITABLE,
      ADDRESS_WIDTH   => ADDRESS_WIDTH,
      BUS_WIDTH       => BUS_WIDTH,
      DATA_WIDTH      => DATA_WIDTH,
      REGISTER_INDEX  => REGISTER_INDEX
    )
    port map (
      i_clk                   => i_clk,
      i_rst_n                 => i_rst_n,
      i_offset_address        => i_offset_address,
      i_valid_bits            => i_valid_bits,
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
      i_additional_match      => '1',
      o_bit_field_valid       => o_bit_field_valid,
      o_bit_field_read_mask   => o_bit_field_read_mask,
      o_bit_field_write_mask  => o_bit_field_write_mask,
      o_bit_field_write_data  => o_bit_field_write_data,
      i_bit_field_read_data   => i_bit_field_read_data,
      i_bit_field_value       => i_bit_field_value
    );
end rtl;
