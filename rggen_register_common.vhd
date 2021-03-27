library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_register_common is
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
    i_offset_address:       in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_valid_bits:           in  std_logic_vector(DATA_WIDTH - 1 downto 0);
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
    i_additional_match:     in  std_logic;
    o_bit_field_valid:      out std_logic;
    o_bit_field_read_mask:  out std_logic_vector(DATA_WIDTH - 1 downto 0);
    o_bit_field_write_mask: out std_logic_vector(DATA_WIDTH - 1 downto 0);
    o_bit_field_write_data: out std_logic_vector(DATA_WIDTH - 1 downto 0);
    i_bit_field_read_data:  in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    i_bit_field_value:      in  std_logic_vector(DATA_WIDTH - 1 downto 0)
  );
end rggen_register_common;

architecture rtl of rggen_register_common is
  constant  WORDS:            positive  := DATA_WIDTH / BUS_WIDTH;
  constant  BUS_BYTE_WIDTH:   positive  := BUS_WIDTH  / 8;
  constant  DATA_BYTE_WIDTH:  positive  := DATA_WIDTH / 8;

  function calc_start_address(
    index:          integer;
    offset_address: std_logic_vector
  ) return std_logic_vector is
    variable  byte_offset:    integer;
    variable  start_address:  std_logic_vector(offset_address'range);
  begin
    byte_offset   := (DATA_BYTE_WIDTH * REGISTER_INDEX) + (BUS_BYTE_WIDTH * index);
    start_address := std_logic_vector(unsigned(offset_address) + byte_offset);
    return start_address;
  end calc_start_address;

  function calc_end_address (
    index:          integer;
    offset_address: std_logic_vector
  ) return std_logic_vector is
    variable  start_address:  std_logic_vector(offset_address'range);
    variable  end_address:    std_logic_vector(offset_address'range);
  begin
    start_address := calc_start_address(index, offset_address);
    end_address   := std_logic_vector(unsigned(start_address) + BUS_BYTE_WIDTH - 1);
    return end_address;
  end calc_end_address;

  function get_mask (
    write_access:     boolean;
    accessible:       boolean;
    match:            std_logic_vector;
    register_access:  std_logic_vector(1 downto 0);
    strobe:           std_logic_vector
  ) return std_logic_vector is
    variable  match_access: boolean;
    variable  mask:         std_logic_vector(DATA_WIDTH - 1 downto 0);
    variable  msb:          integer;
    variable  lsb:          integer;
  begin
    if (write_access) then
      match_access  := register_access(RGGEN_ACCESS_DATA_BIT) = '1';
    else
      match_access  := register_access(RGGEN_ACCESS_DATA_BIT) = '0';
    end if;

    for i in 0 to WORDS - 1 loop
      for j in 0 to BUS_BYTE_WIDTH - 1 loop
        lsb := BUS_WIDTH * i + 8 * j;
        msb := lsb + 7;
        if (accessible and match_access and (match(i) = '1')) then
          mask(msb downto lsb)  := (others => strobe(j));
        else
          mask(msb downto lsb)  := (others => '0');
        end if;
      end loop;
    end loop;

    return mask;
  end get_mask;

  function get_write_data(
    write_data: std_logic_vector
  ) return std_logic_vector is
    variable  data: std_logic_vector(DATA_WIDTH - 1 downto 0);
  begin
    for i in 0 to WORDS - 1 loop
      data(BUS_WIDTH*(i+1)-1 downto BUS_WIDTH*i)  := write_data;
    end loop;
    return data;
  end get_write_data;

  signal  match:            std_logic_vector(WORDS - 1 downto 0);
  signal  active:           std_logic;
  signal  frontdoor_valid:  std_logic;
  signal  backdoor_valid:   std_logic;
  signal  pending_valid:    std_logic;
  signal  read_strobe:      std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
  signal  read_mask_0:      std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal  read_mask_1:      std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal  write_mask_0:     std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal  write_mask_1:     std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal  write_data_0:     std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal  write_data_1:     std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal  masked_read_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal  masked_value:     std_logic_vector(DATA_WIDTH - 1 downto 0);
begin
  --  Decode Address
  active  <= '1' when unsigned(match) /= 0 else '0';

  g_decoder: for i in 0 to WORDS - 1 generate
    signal  start_address:  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    signal  end_address:    std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  begin
    start_address <= calc_start_address(i, i_offset_address);
    end_address   <= calc_end_address(i, i_offset_address);

    u_decoder: entity work.rggen_address_decoder
      generic map (
        READABLE      => READABLE,
        WRITABLE      => WRITABLE,
        ADDRESS_WIDTH => ADDRESS_WIDTH,
        BUS_WIDTH     => BUS_WIDTH
      )
      port map (
        i_start_address     => start_address,
        i_end_address       => end_address,
        i_address           => i_register_address,
        i_access            => i_register_access,
        i_additional_match  => i_additional_match,
        o_match             => match(i)
      );
  end generate;

  --  Request
  o_bit_field_valid       <= frontdoor_valid or backdoor_valid or pending_valid;
  o_bit_field_read_mask   <= read_mask_1  when backdoor_valid = '1' else read_mask_0;
  o_bit_field_write_mask  <= write_mask_1 when backdoor_valid = '1' else write_mask_0;
  o_bit_field_write_data  <= write_data_1 when backdoor_valid = '1' else write_data_0;

  frontdoor_valid <= i_register_valid and active;
  read_strobe     <= (others => '1');
  read_mask_0     <= get_mask(false, READABLE, match, i_register_access, read_strobe);
  write_mask_0    <= get_mask(true , WRITABLE, match, i_register_access, i_register_strobe);
  write_data_0    <= get_write_data(i_register_write_data);

  --  Response
  o_register_active     <= active;
  o_register_ready      <= (not backdoor_valid) and active;
  o_register_status     <= (others => '0');
  o_register_read_data  <= mux(match, masked_read_data);
  o_register_value      <= masked_value;

  masked_read_data  <= i_valid_bits and i_bit_field_read_data;
  masked_value      <= i_valid_bits and i_bit_field_value;

  --  Backdoor access
  backdoor_valid  <= '0';
  read_mask_1     <= (others => '0');
  write_mask_1    <= (others => '0');
  write_data_1    <= (others => '0');
  pending_valid   <= '0';
end rtl;
