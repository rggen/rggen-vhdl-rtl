library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_bit_field is
  generic (
    WIDTH:                    positive            := 8;
    INITIAL_VALUE:            unsigned            := x"0";
    PRECEDENCE_ACCESS:        rggen_sw_hw_access  := RGGEN_HW_ACCESS;
    SW_READ_ACTION:           rggen_sw_action     := RGGEN_READ_DEFAULT;
    SW_WRITE_ACTION:          rggen_sw_action     := RGGEN_WRITE_DEFAULT;
    SW_WRITE_ONCE:            boolean             := false;
    SW_WRITE_ENABLE_POLARITY: rggen_polarity      := RGGEN_ACTIVE_HIGH;
    HW_WRITE_ENABLE_POLARITY: rggen_polarity      := RGGEN_ACTIVE_HIGH;
    HW_SET_WIDTH:             positive            := 1;
    HW_CLEAR_WIDTH:           positive            := 1;
    STORAGE:                  boolean             := true;
    EXTERNAL_READ_DATA:       boolean             := false;
    TRIGGER:                  boolean             := false
  );
  port (
    i_clk:              in  std_logic;
    i_rst_n:            in  std_logic;
    i_sw_valid:         in  std_logic;
    i_sw_read_mask:     in  std_logic_vector(WIDTH - 1 downto 0);
    i_sw_write_enable:  in  std_logic_vector(0 downto 0);
    i_sw_write_mask:    in  std_logic_vector(WIDTH - 1 downto 0);
    i_sw_write_data:    in  std_logic_vector(WIDTH - 1 downto 0);
    o_sw_read_data:     out std_logic_vector(WIDTH - 1 downto 0);
    o_sw_value:         out std_logic_vector(WIDTH - 1 downto 0);
    o_write_trigger:    out std_logic_vector(0 downto 0);
    o_read_trigger:     out std_logic_vector(0 downto 0);
    i_hw_write_enable:  in  std_logic_vector(0 downto 0);
    i_hw_write_data:    in  std_logic_vector(WIDTH - 1 downto 0);
    i_hw_set:           in  std_logic_vector(HW_SET_WIDTH - 1 downto 0);
    i_hw_clear:         in  std_logic_vector(HW_CLEAR_WIDTH - 1 downto 0);
    i_value:            in  std_logic_vector(WIDTH - 1 downto 0);
    i_mask:             in  std_logic_vector(WIDTH - 1 downto 0);
    o_value:            out std_logic_vector(WIDTH - 1 downto 0);
    o_value_unmasked:   out std_logic_vector(WIDTH - 1 downto 0)
  );
end rggen_bit_field;

architecture rtl of rggen_bit_field is
  constant  ENABLE_WRITE_TRIGGER: boolean := TRIGGER and (SW_WRITE_ACTION /= RGGEN_WRITE_NONE);
  constant  ENABLE_READ_TRIGGER:  boolean := TRIGGER and (SW_READ_ACTION  /= RGGEN_READ_NONE );

  function get_sw_update (
    valid:        std_logic;
    read_mask:    std_logic_vector;
    write_enable: std_logic;
    write_mask:   std_logic_vector;
    write_done:   std_logic
  ) return std_logic_vector is
    variable  read_action:      boolean;
    variable  write_no_action:  boolean;
    variable  read_access:      boolean;
    variable  write_access:     boolean;
    variable  sw_update:        std_logic_vector(1 downto 0);
  begin
    read_action     := (SW_READ_ACTION  = RGGEN_READ_CLEAR) or
                       (SW_READ_ACTION  = RGGEN_READ_SET  );
    write_no_action := (SW_WRITE_ACTION = RGGEN_WRITE_NONE);

    read_access   := (unsigned(read_mask)  /= 0);
    write_access  := (unsigned(write_mask) /= 0) and (write_enable = '1') and (write_done = '0');

    sw_update := "00";
    if (valid = '1' and read_action and read_access) then
      sw_update(0)  := '1';
    end if;
    if (valid = '1' and (not write_no_action) and write_access) then
      sw_update(1)  := '1';
    end if;

    return sw_update;
  end get_sw_update;

  function get_hw_update (
    write_enable: std_logic;
    set:          std_logic_vector;
    clear:        std_logic_vector
  ) return std_logic is
  begin
    if (write_enable = '1') then
      return '1';
    elsif (unsigned(set) /= 0) then
      return '1';
    elsif (unsigned(clear) /= 0) then
      return '1';
    else
      return '0';
    end if;
  end get_hw_update;

  function get_sw_next_value (
    current_value:  std_logic_vector;
    update:         std_logic_vector(1 downto 0);
    write_mask:     std_logic_vector;
    write_data:     std_logic_vector
  ) return std_logic_vector is
    variable  value_0:        std_logic_vector(current_value'range);
    variable  value_1:        std_logic_vector(current_value'range);
    variable  masked_data_0:  std_logic_vector(current_value'range);
    variable  masked_data_1:  std_logic_vector(current_value'range);
  begin
    case SW_READ_ACTION is
      when RGGEN_READ_CLEAR => value_0  := (others => '0');
      when RGGEN_READ_SET   => value_0  := (others => '1');
      when others           => value_0  := current_value;
    end case;

    masked_data_0 := write_mask and (not write_data);
    masked_data_1 := write_mask and (    write_data);
    case SW_WRITE_ACTION is
      when RGGEN_WRITE_DEFAULT  => value_1  := (current_value and (not write_mask)) or masked_data_1;
      when RGGEN_WRITE_0_CLEAR  => value_1  := current_value and (not masked_data_0);
      when RGGEN_WRITE_1_CLEAR  => value_1  := current_value and (not masked_data_1);
      when RGGEN_WRITE_CLEAR    => value_1  := (others => '0');
      when RGGEN_WRITE_0_SET    => value_1  := current_value or masked_data_0;
      when RGGEN_WRITE_1_SET    => value_1  := current_value or masked_data_1;
      when RGGEN_WRITE_SET      => value_1  := (others => '1');
      when RGGEN_WRITE_0_TOGGLE => value_1  := current_value xor masked_data_0;
      when RGGEN_WRITE_1_TOGGLE => value_1  := current_value xor masked_data_1;
      when others               => value_1  := current_value;
    end case;

    if (update(0) = '1') then
      return value_0;
    elsif (update(1) = '1') then
      return value_1;
    else
      return current_value;
    end if;
  end get_sw_next_value;

  function get_hw_next_value (
    current_value:  std_logic_vector;
    write_enable:   std_logic;
    write_data:     std_logic_vector;
    set:            std_logic_vector;
    clear:          std_logic_vector
  ) return std_logic_vector is
    variable  set_actual:   std_logic_vector(current_value'range);
    variable  clear_actual: std_logic_vector(current_value'range);
    variable  value:        std_logic_vector(current_value'range);
  begin
    if (HW_SET_WIDTH = WIDTH) then
      set_actual(HW_SET_WIDTH - 1 downto 0) := set;
    else
      set_actual  := (others => set(0));
    end if;

    if (HW_CLEAR_WIDTH = WIDTH) then
      clear_actual(HW_CLEAR_WIDTH - 1 downto 0) := clear;
    else
      clear_actual  := (others => clear(0));
    end if;

    if (write_enable = '1') then
      value := write_data;
    else
      value := current_value;
    end if;

    value := (value and (not clear_actual)) or set_actual;
    return value;
  end get_hw_next_value;

  function get_next_value (
    current_value:    std_logic_vector;
    sw_update:        std_logic_vector(1 downto 0);
    sw_write_mask:    std_logic_vector;
    sw_write_data:    std_logic_vector;
    hw_write_enable:  std_logic;
    hw_write_data:    std_logic_vector;
    hw_set:           std_logic_vector;
    hw_clear:         std_logic_vector
  ) return std_logic_vector is
    variable  value_0:  std_logic_vector(current_value'range);
    variable  value_1:  std_logic_vector(current_value'range);
  begin
    if (PRECEDENCE_ACCESS = RGGEN_SW_ACCESS) then
      value_0 :=
        get_hw_next_value(
          current_value, hw_write_enable, hw_write_data,
          hw_set, hw_clear
        );
      value_1 :=
        get_sw_next_value(
          value_0, sw_update, sw_write_mask, sw_write_data
        );
    else
      value_0 :=
        get_sw_next_value(
          current_value, sw_update, sw_write_mask, sw_write_data
        );
      value_1 :=
        get_hw_next_value(
          value_0, hw_write_enable, hw_write_data,
          hw_set, hw_clear
        );
    end if;

    return value_1;
  end get_next_value;

  constant  SW_READABLE:  boolean := SW_READ_ACTION /= RGGEN_READ_NONE;

  signal  sw_write_enable:  std_logic;
  signal  sw_update:        std_logic_vector(1 downto 0);
  signal  sw_write_done:    std_logic;
  signal  hw_write_enable:  std_logic;
  signal  hw_update:        std_logic;
  signal  write_trigger:    std_logic;
  signal  read_trigger:     std_logic;
  signal  value:            std_logic_vector(WIDTH - 1 downto 0);
  signal  value_masked:     std_logic_vector(WIDTH - 1 downto 0);
  signal  read_data:        std_logic_vector(WIDTH - 1 downto 0);
begin
  o_sw_read_data      <= read_data and i_mask;
  o_sw_value          <= value;
  o_write_trigger(0)  <= write_trigger;
  o_read_trigger(0)   <= read_trigger;
  o_value             <= value and i_mask;
  o_value_unmasked    <= value;

  process (i_sw_write_enable) begin
    if (SW_WRITE_ENABLE_POLARITY = RGGEN_ACTIVE_HIGH) then
      sw_write_enable <= i_sw_write_enable(0);
    else
      sw_write_enable <= not i_sw_write_enable(0);
    end if;
  end process;

  process (i_hw_write_enable) begin
    if (HW_WRITE_ENABLE_POLARITY = RGGEN_ACTIVE_HIGH) then
      hw_write_enable <= i_hw_write_enable(0);
    else
      hw_write_enable <= not i_hw_write_enable(0);
    end if;
  end process;

  sw_update <=
    get_sw_update(
      i_sw_valid, i_sw_read_mask, sw_write_enable,
      i_sw_write_mask, sw_write_done
    );
  hw_update <=
    get_hw_update(hw_write_enable, i_hw_set, i_hw_clear);

  g_sw_write_onece: if (SW_WRITE_ONCE) generate
    process (i_clk, i_rst_n) begin
      if (i_rst_n = '0') then
        sw_write_done <= '0';
      elsif (rising_edge(i_clk)) then
        if (sw_update(1) = '1') then
          sw_write_done <= '1';
        end if;
      end if;
    end process;
  end generate;

  g_sw_write_anytime: if (not SW_WRITE_ONCE) generate
    sw_write_done <= '0';
  end generate;

  g_write_trigger: if (ENABLE_WRITE_TRIGGER) generate
  begin
    process (i_clk, i_rst_n) begin
      if (i_rst_n = '0') then
        write_trigger <= '0';
      elsif (rising_edge(i_clk)) then
        write_trigger <= sw_update(1);
      end if;
    end process;
  end generate;

  g_no_write_trigger: if (not ENABLE_WRITE_TRIGGER) generate
  begin
    write_trigger <= '0';
  end generate;

  g_read_trigger: if (ENABLE_READ_TRIGGER) generate
  begin
    process (i_clk, i_rst_n) begin
      if (i_rst_n = '0') then
        read_trigger  <= '0';
      elsif (rising_edge(i_clk)) then
        if (i_sw_valid = '1' and unsigned(i_sw_read_mask) /= 0) then
          read_trigger  <= '1';
        else
          read_trigger  <= '0';
        end if;
      end if;
    end process;
  end generate;

  g_no_read_trigger: if (not ENABLE_READ_TRIGGER) generate
  begin
    read_trigger  <= '0';
  end generate;

  g_storage: if (STORAGE) generate
    signal  value_next: std_logic_vector(WIDTH - 1 downto 0);
  begin
    value_next  <=
      get_next_value(
        value, sw_update, i_sw_write_mask, i_sw_write_data,
        hw_write_enable, i_hw_write_data, i_hw_set, i_hw_clear
      );
    process (i_clk, i_rst_n) begin
      if (i_rst_n = '0') then
        value <= std_logic_vector(INITIAL_VALUE);
      elsif (rising_edge(i_clk)) then
        if (sw_update /= "00" or hw_update = '1') then
          value <= value_next;
        end if;
      end if;
    end process;
  end generate;

  g_through: if (not STORAGE) generate
    value <= i_value;
  end generate;

  g_internal_read_data: if (SW_READABLE and (not EXTERNAL_READ_DATA)) generate
    read_data <= value;
  end generate;

  g_external_read_data: if (SW_READABLE and EXTERNAL_READ_DATA) generate
    read_data <= i_value;
  end generate;

  g_no_read_data: if (not SW_READABLE) generate
    read_data <= (others => '0');
  end generate;
end rtl;
