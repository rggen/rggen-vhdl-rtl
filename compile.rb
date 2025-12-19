[
  'rggen_rtl.vhd',
  'rggen_or_reducer.vhd',
  'rggen_mux.vhd',
  'rggen_bit_field.vhd',
  'rggen_bit_field_w01trg.vhd',
  'rggen_address_decoder.vhd',
  'rggen_register_common.vhd',
  'rggen_default_register.vhd',
  'rggen_indirect_register.vhd',
  'rggen_external_register.vhd',
  'rggen_maskable_register.vhd',
  'rggen_adapter_common.vhd',
  'rggen_apb_adapter.vhd',
  'rggen_apb_bridge.vhd',
  'rggen_axi4lite_skid_buffer.vhd',
  'rggen_axi4lite_adapter.vhd',
  'rggen_axi4lite_bridge.vhd',
  'rggen_avalon_adapter.vhd',
  'rggen_avalon_bridge.vhd',
  'rggen_wishbone_adapter.vhd',
  'rggen_wishbone_bridge.vhd',
  'rggen_native_adapter.vhd',
].each { |file| source_file file }

unless macro_defined? :RGGEN_ENABLE_BACKDOOR
  source_file 'rggen_backdoor_dummy.vhd'
end
