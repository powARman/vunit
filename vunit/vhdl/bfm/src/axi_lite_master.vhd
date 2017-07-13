-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com


library ieee;
use ieee.std_logic_1164.all;

use work.axi_pkg.all;
use work.queue_pkg.all;
use work.bus_pkg.all;
context work.com_context;

entity axi_lite_master is
  generic (
    bus_handle : bus_t
    );
  port (
    aclk : in std_logic;

    arready : in std_logic;
    arvalid : out std_logic;
    araddr : out std_logic_vector;

    rready : out std_logic;
    rvalid : in std_logic;
    rdata : in std_logic_vector;
    rresp : in std_logic_vector(1 downto 0);

    awready : in std_logic;
    awvalid : out std_logic;
    awaddr : out std_logic_vector;

    wready : in std_logic;
    wvalid : out std_logic;
    wdata : out std_logic_vector;
    wstb : out std_logic_vector;

    bvalid : in std_logic;
    bready : out std_logic;
    bresp : in std_logic_vector(1 downto 0));
end entity;

architecture a of axi_lite_master is
begin
  main : process
    variable request_msg, reply_msg : msg_t;
    --TODO: Assumes same length address buses
    variable bus_request : bus_request_t(address(awaddr'range), data(wdata'range));

    variable w_done, aw_done : boolean;
  begin
    loop
      receive(event, bus_handle.p_actor, request_msg);
      decode(request_msg, bus_request);

      case bus_request.access_type is
        when read_access =>
          araddr <= bus_request.address;
          arvalid <= '1';
          wait until (arvalid and arready) = '1' and rising_edge(aclk);
          arvalid <= '0';

          rready <= '1';
          wait until (rvalid and rready) = '1' and rising_edge(aclk);
          assert rresp = axi_resp_ok report "Got non-OKAY rresp";
          rready <= '0';
          reply_msg := create;
          push_std_ulogic_vector(reply_msg.data, rdata);
          reply(event, request_msg, reply_msg);
          delete(request_msg);

        when write_access =>
          awaddr <= bus_request.address;
          wdata <= bus_request.data;
          wstb <= (wstb'range => '1');

          wvalid <= '1';
          awvalid <= '1';

          w_done := false;
          aw_done := false;
          while not (w_done and aw_done) loop
            wait until ((awvalid and awready) = '1' or (wvalid and wready) = '1') and rising_edge(aclk);

            if (awvalid and awready) = '1' then
              awvalid <= '0';
              aw_done := true;
            end if;

            if (wvalid and wready) = '1' then
              wvalid <= '0';
              w_done := true;
            end if;
          end loop;

          bready <= '1';
          wait until (bvalid and bready) = '1' and rising_edge(aclk);
          bready <= '0';
          assert bresp = axi_resp_ok report "Got non-OKAY bresp";
      end case;
    end loop;
  end process;
end architecture;
