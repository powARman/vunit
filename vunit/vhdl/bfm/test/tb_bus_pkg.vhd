-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context work.com_context;

use work.queue_pkg.all;
use work.bus_pkg.all;
use work.memory_pkg.all;
use work.fail_pkg.all;

entity tb_bus_pkg is
  generic (runner_cfg : string);
end entity;

architecture a of tb_bus_pkg is
  constant memory : memory_t := new_memory;
  constant bus_handle : bus_t := new_bus(data_length => 32, address_length => 32);
begin
  main : process
    variable alloc : alloc_t;
    variable read_data : std_logic_vector(data_length(bus_handle)-1 downto 0);
    variable reference : bus_reference_t;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test write_bus") then
      alloc := allocate(memory, 12, permissions => write_only);
      set_expected_word(memory, base_address(alloc), x"00112233");
      set_expected_word(memory, base_address(alloc) + 4, x"00112233");
      set_expected_word(memory, base_address(alloc) + 8, x"00112233");
      write_bus(event, bus_handle, x"00000000", x"00112233");
      write_bus(event, bus_handle, x"4", x"00112233");
      write_bus(event, bus_handle, x"00000008", x"112233");

    elsif run("test read_bus") then
      alloc := allocate(memory, 8, permissions => read_only);
      write_word(memory, base_address(alloc), x"00112233", ignore_permissions => True);
      write_word(memory, base_address(alloc) + 4, x"00112233", ignore_permissions => True);
      read_bus(event, bus_handle, x"00000000", read_data);
      check_equal(read_data, std_logic_vector'(x"00112233"));
      read_bus(event, bus_handle, x"4", reference);
      await_read_bus_reply(event, reference, read_data);
      check_equal(read_data, std_logic_vector'(x"00112233"));

    elsif run("test check_bus") then
      alloc := allocate(memory, 4, permissions => read_only);
      write_word(memory, base_address(alloc), x"00112233", ignore_permissions => True);
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"00112233"));
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"00112244"), mask => std_logic_vector'(x"ffffff00"));

      disable_failure(bus_handle.p_fail_log);
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"00112244"));
      check_equal(pop_failure(bus_handle.p_fail_log), "check_bus(x""00000000"") - Got x""00112233"" expected x""00112244""");
      check_no_failures(bus_handle.p_fail_log);

      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"00112244"), msg => "msg");
      check_equal(pop_failure(bus_handle.p_fail_log), "msg - Got x""00112233"" expected x""00112244""");
      check_no_failures(bus_handle.p_fail_log);

      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"00112244"), mask => std_logic_vector'(x"00ffffff"));
      check_equal(pop_failure(bus_handle.p_fail_log), "check_bus(x""00000000"") - Got x""00112233"" expected x""00112244"" using mask x""00FFFFFF""");
      check_no_failures(bus_handle.p_fail_log);

    elsif run("test check_bus support reduced data length") then
      alloc := allocate(memory, 4, permissions => read_only);
      write_word(memory, base_address(alloc), x"00112233", ignore_permissions => True);
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"112233"));

      write_word(memory, base_address(alloc), x"77112233", ignore_permissions => True);
      disable_failure(bus_handle.p_fail_log);
      check_bus(event, bus_handle, x"00000000", std_logic_vector'(x"112233"));
      check_equal(pop_failure(bus_handle.p_fail_log), "check_bus(x""00000000"") - Got x""77112233"" expected x""00112233""");
      check_no_failures(bus_handle.p_fail_log);
    end if;
    test_runner_cleanup(runner);
  end process;

  memory_model : process
    variable msg : message_ptr_t;
    variable reply_msg : message_ptr_t;
    variable bus_access_type : bus_access_type_t;

    variable addr  : std_logic_vector(address_length(bus_handle)-1 downto 0);
    variable data  : std_logic_vector(data_length(bus_handle)-1 downto 0);

    variable index : positive;
  begin
    loop
      receive(event, bus_handle.p_actor, msg);
      index := msg.payload.all'left;
      bus_access_type := bus_access_type_t'val(character'pos(msg.payload.all(index)));
      index := index + 1;
      decode(msg.payload.all, index, addr);

      case bus_access_type is
        when read_access =>
          data := read_word(memory, to_integer(unsigned(addr)), bytes_per_word => data'length/8);
          reply_msg := compose(encode(data));
          reply(event, msg, reply_msg);

        when write_access =>
          decode(msg.payload.all, index, data);
          write_word(memory, to_integer(unsigned(addr)), data);
      end case;
    end loop;
  end process;

end architecture;
