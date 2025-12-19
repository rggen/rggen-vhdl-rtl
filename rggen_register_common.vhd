library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_register_common is
  generic (
    READABLE:             boolean   := true;
    WRITABLE:             boolean   := true;
    ADDRESS_WIDTH:        positive  := 8;
    OFFSET_ADDRESS:       unsigned  := x"0";
    BUS_WIDTH:            positive  := 32;
    DATA_WIDTH:           positive  := 32;
    USE_ADDITIONAL_MATCH: boolean   := false;
    USE_ADDITIONAL_MASK:  boolean   := false
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
    i_additional_match:       in  std_logic;
    i_additional_mask:        in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_bit_field_read_valid:   out std_logic;
    o_bit_field_write_valid:  out std_logic;
    o_bit_field_mask:         out std_logic_vector(DATA_WIDTH - 1 downto 0);
    o_bit_field_write_data:   out std_logic_vector(DATA_WIDTH - 1 downto 0);
    i_bit_field_read_data:    in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    i_bit_field_value:        in  std_logic_vector(DATA_WIDTH - 1 downto 0)
  );
end rggen_register_common;

architecture rtl of rggen_register_common is
  component rggen_backdoor
    generic (
      DATA_WIDTH: positive  := 32
    );
    port (
      i_clk:              in  std_logic;
      i_rst_n:            in  std_logic;
      i_frontdoor_valid:  in  std_logic;
      i_frontdoor_ready:  in  std_logic;
      o_backdoor_valid:   out std_logic;
      o_pending_valid:    out std_logic;
      o_write:            out std_logic;
      o_mask:             out std_logic_vector(DATA_WIDTH - 1 downto 0);
      o_write_data:       out std_logic_vector(DATA_WIDTH - 1 downto 0);
      i_read_data:        in  std_logic_vector(DATA_WIDTH - 1 downto 0);
      i_value:            in  std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
  end component;

  constant  WORDS:            positive  := DATA_WIDTH / BUS_WIDTH;
  constant  BUS_BYTE_WIDTH:   positive  := BUS_WIDTH  / 8;
  constant  DATA_BYTE_WIDTH:  positive  := DATA_WIDTH / 8;

  function calc_start_address(
    index:          integer;
    offset_address: unsigned
  ) return unsigned is
    variable  byte_offset:    integer;
    variable  start_address:  unsigned(offset_address'range);
  begin
    byte_offset   := BUS_BYTE_WIDTH * index;
    start_address := offset_address + byte_offset;
    return start_address;
  end calc_start_address;

  function calc_end_address (
    index:          integer;
    offset_address: unsigned
  ) return unsigned is
    variable  start_address:  unsigned(offset_address'range);
    variable  end_address:    unsigned(offset_address'range);
  begin
    start_address := calc_start_address(index, offset_address);
    end_address   := start_address + BUS_BYTE_WIDTH - 1;
    return end_address;
  end calc_end_address;

  function get_mask (
    match:          std_logic_vector;
    strobe:         std_logic_vector;
    additonal_mask: std_logic_vector
  ) return std_logic_vector is
    variable  word_mask:  std_logic_vector(BUS_WIDTH -1 downto 0);
    variable  mask:       std_logic_vector(DATA_WIDTH - 1 downto 0);
    variable  msb:        integer;
    variable  lsb:        integer;
  begin
    if (USE_ADDITIONAL_MASK) then
      word_mask := strobe and additonal_mask;
    else
      word_mask := strobe;
    end if;

    if (BUS_WIDTH = DATA_WIDTH) then
      mask  := word_mask;
    else
      for i in 0 to WORDS - 1 loop
        lsb := BUS_WIDTH * (i + 0) - 0;
        msb := BUS_WIDTH * (i + 1) - 1;
        if (match(i) = '1') then
          mask(msb downto lsb)  := word_mask;
        else
          mask(msb downto lsb)  := (others => '0');
        end if;
      end loop;
    end if;

    return mask;
  end get_mask;

  function get_write_data (
    write_data: std_logic_vector
  ) return std_logic_vector is
    variable  data: std_logic_vector(DATA_WIDTH - 1 downto 0);
  begin
    for i in 0 to WORDS - 1 loop
      data(BUS_WIDTH*(i+1)-1 downto BUS_WIDTH*i)  := write_data;
    end loop;
    return data;
  end get_write_data;

  signal  match:              std_logic_vector(WORDS - 1 downto 0);
  signal  active:             std_logic;
  signal  frontdoor_valid:    std_logic;
  signal  backdoor_valid:     std_logic;
  signal  pending_valid:      std_logic;
  signal  register_ready:     std_logic;
  signal  register_read_data: std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  write_0:            std_logic;
  signal  write_1:            std_logic;
  signal  mask_0:             std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal  mask_1:             std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal  write_data_0:       std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal  write_data_1:       std_logic_vector(DATA_WIDTH - 1 downto 0);
begin
  --  Decode Address
  active  <= '1' when unsigned(match) /= 0 else '0';

  g_decoder: for i in 0 to WORDS - 1 generate
  begin
    u_decoder: entity work.rggen_address_decoder
      generic map (
        READABLE              => READABLE,
        WRITABLE              => WRITABLE,
        ADDRESS_WIDTH         => ADDRESS_WIDTH,
        BUS_WIDTH             => BUS_WIDTH,
        START_ADDRESS         => calc_start_address(i, OFFSET_ADDRESS),
        END_ADDRESS           => calc_end_address(i, OFFSET_ADDRESS),
        USE_ADDITIONAL_MATCH  => USE_ADDITIONAL_MATCH
      )
      port map (
        i_address           => i_register_address,
        i_access            => i_register_access,
        i_additional_match  => i_additional_match,
        o_match             => match(i)
      );
  end generate;

  --  Request
  o_bit_field_write_valid <= ((frontdoor_valid or pending_valid) and write_0) or
                             ( backdoor_valid                    and write_1);
  o_bit_field_read_valid  <= ((frontdoor_valid or pending_valid) and (not write_0)) or
                             ( backdoor_valid                    and (not write_1));
  o_bit_field_mask        <= mask_1       when backdoor_valid = '1' else mask_0;
  o_bit_field_write_data  <= write_data_1 when backdoor_valid = '1' else write_data_0;

  frontdoor_valid <= i_register_valid and active;
  write_0         <= i_register_access(0);
  mask_0          <= get_mask(match, i_register_strobe, i_additional_mask);
  write_data_0    <= get_write_data(i_register_write_data);

  --  Response
  o_register_active     <= active;
  o_register_ready      <= register_ready;
  o_register_status     <= (others => '0');
  o_register_read_data  <= register_read_data;
  o_register_value      <= i_bit_field_value;

  register_ready  <= (not backdoor_valid) and active;

  u_read_data_mux: entity work.rggen_mux
    generic map (
      WIDTH   => BUS_WIDTH,
      ENTRIES => WORDS
    )
    port map (
      i_select  => match,
      i_data    => i_bit_field_read_data,
      o_data    => register_read_data
    );

  --  Backdoor access
  u_backdoor: rggen_backdoor
    generic map (
      DATA_WIDTH  => DATA_WIDTH
    )
    port map (
      i_clk             => i_clk,
      i_rst_n           => i_rst_n,
      i_frontdoor_valid => frontdoor_valid,
      i_frontdoor_ready => register_ready,
      o_backdoor_valid  => backdoor_valid,
      o_pending_valid   => pending_valid,
      o_write           => write_1,
      o_mask            => mask_1,
      o_write_data      => write_data_1,
      i_read_data       => i_bit_field_read_data,
      i_value           => i_bit_field_value
    );
end rtl;
